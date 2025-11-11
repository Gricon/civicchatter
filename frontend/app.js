/* ===========================
   Civic Chatter — app.js
   =========================== */

// 0) SDK & Client init (safe)
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

// 🔗 Where Supabase should send users after email-confirm
// (matches your Netlify site; adjust if you renamed the domain)
const EMAIL_REDIRECT_URL = "https://civicchatter.netlify.app/auth-callback.html";

function assertSDK() {
  if (!window.supabase) {
    alert("Supabase SDK did not load. Check connectivity/CDN.");
    throw new Error("Supabase SDK missing");
  }
}
assertSDK();

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Surface runtime errors instead of failing silently
window.addEventListener("error", (e) => console.log("JS error:", e.message));

/* 1) DOM refs */
const els = {
  nav: document.getElementById("nav"),
  sections: {
    auth: document.getElementById("auth-section"),
    priv: document.getElementById("private-profile"),
    pub: document.getElementById("public-profile"),
    debate: document.getElementById("debate-page"),
  },
  // Auth inputs
  signupName: document.getElementById("signup-name"),
  signupHandle: document.getElementById("signup-handle"),
  signupEmail: document.getElementById("signup-email"),
  signupPassword: document.getElementById("signup-password"),
  signupPhone: document.getElementById("signup-phone"),
  signupPrivate: document.getElementById("signup-private"),
  // Buttons/links
  btnSignup: document.getElementById("btn-signup"),
  btnLogin: document.getElementById("btn-login"),
  btnSaveProfile: document.getElementById("save-profile"),
  linkLogout: document.getElementById("logout-link"),
  linkPublic: document.getElementById("public-link"),
  // Private form
  ppHandle: document.getElementById("pp-handle"),
  ppDisplay: document.getElementById("pp-display-name"),
  ppBio: document.getElementById("pp-bio"),
  ppCity: document.getElementById("pp-city"),
  ppAvatar: document.getElementById("pp-avatar-url"),
  prEmail: document.getElementById("pr-email"),
  prPhone: document.getElementById("pr-phone"),
  // Public view
  pubAvatar: document.getElementById("pub-avatar"),
  pubDisplay: document.getElementById("pub-display-name"),
  pubHandle: document.getElementById("pub-handle"),
  pubCity: document.getElementById("pub-city"),
  pubBio: document.getElementById("pub-bio"),
  // Debate view
  debTitle: document.getElementById("deb-title"),
  debDesc: document.getElementById("deb-desc"),
  debContent: document.getElementById("deb-content"),
};

/* 2) utils */
const isValidHandle = (h) => /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
function showOnly(...toShow) {
  const { auth, priv, pub, debate } = els.sections;
  [auth, priv, pub, debate].forEach((el) => el?.classList.add("hidden"));
  toShow.forEach((el) => el?.classList.remove("hidden"));
}
async function handleAvailable(handle) {
  const { data, error } = await sb
    .from("profiles_public")
    .select("id")
    .eq("handle", (handle || "").toLowerCase())
    .maybeSingle();
  if (error && error.code !== "PGRST116") console.error(error);
  return !data;
}
async function ensureSession(email, password) {
  const cur = await sb.auth.getSession();
  if (cur.data?.session) return cur.data.session;
  if (email && password) {
    const { data, error } = await sb.auth.signInWithPassword({ email, password });
    if (!error) return data.session;
  }
  return null;
}

/* 3) router */
async function router() {
  const { data: { session } } = await sb.auth.getSession();
  els.nav?.classList.toggle("hidden", !session);

  const hash = location.hash || "#/login";

  // Allow hash-based callback if you ever link to #/auth-callback
  if (hash.startsWith("#/auth-callback")) {
    const { data: { session: s } } = await sb.auth.getSession();
    location.hash = s ? "#/profile" : "#/login";
    return;
  }

  if (hash.startsWith("#/u/")) {
    const handle = hash.split("#/u/")[1]?.toLowerCase();
    await showPublicProfile(handle);
    return;
  }
  if (hash.startsWith("#/d/")) {
    const handle = hash.split("#/d/")[1]?.toLowerCase();
    await showDebatePage(handle);
    return;
  }
  if (hash === "#/profile") {
    if (!session) { location.hash = "#/login"; return; }
    await loadMyProfile();
    showOnly(els.sections.priv);
    return;
  }
  showOnly(els.sections.auth);
}

/* 4) auth actions */
async function signup() {
  try {
    const name = els.signupName.value.trim();
    const handle = els.signupHandle.value.trim().toLowerCase();
    const email = els.signupEmail.value.trim();
    const password = els.signupPassword.value;
    const phone = els.signupPhone.value.trim();
    const isPrivate = !!els.signupPrivate.checked;

    if (!name) return alert("Enter your name");
    if (!isValidHandle(handle)) return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
    if (!(await handleAvailable(handle))) return alert("Handle is taken");
    if (!email || !password) return alert("Email & password required");

    // 🔔 Send the confirmation link to your Netlify callback
    const { data: sign, error: signErr } = await sb.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: EMAIL_REDIRECT_URL },
    });
    if (signErr) throw signErr;

    // With confirmations ON, there may be no session until the email link is clicked.
    let session = sign.session || (await ensureSession(email, password));
    if (!session) {
      alert("Account created. Check your email to confirm, then sign in.");
      location.hash = "#/login";
      return;
    }

    const userId = session.user.id;

    // Public profile
    const { error: pubErr } = await sb.from("profiles_public").upsert({
      id: userId, handle, display_name: name, is_private: isPrivate, is_searchable: !isPrivate
    }, { onConflict: "id" });
    if (pubErr) throw pubErr;

    // Private profile
    const { error: privErr } = await sb.from("profiles_private").upsert({
      id: userId, email, phone: phone || null, preferred_contact: phone ? "sms" : "email"
    }, { onConflict: "id" });
    if (privErr) throw privErr;

    // Debate page
    const { error: debErr } = await sb.from("debate_pages").upsert({
      id: userId, handle, title: `${name || handle}'s Debates`, description: "Debate topics and positions."
    }, { onConflict: "id" });
    if (debErr) throw debErr;

    alert("Account ready!");
    location.hash = isPrivate ? "#/profile" : `#/u/${handle}`;
  } catch (e) {
    console.log("Signup error:", e);
    alert("Signup failed: " + (e?.message || e));
  }
}

async function login() {
  try {
    const email = els.signupEmail.value.trim();
    const password = els.signupPassword.value;
    if (!email || !password) return alert("Enter email & password");

    const { error } = await sb.auth.signInWithPassword({ email, password });
    if (error) throw error;

    location.hash = "#/profile";
  } catch (e) {
    console.log("Login error:", e);
    alert("Login failed: " + (e?.message || e));
  }
}

async function logout(e) {
  e?.preventDefault?.();
  await sb.auth.signOut();
  location.hash = "#/login";
}

/* 5) private profile */
async function loadMyProfile() {
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return;

  const { data: pubRow } = await sb
    .from("profiles_public")
    .select("handle, display_name, bio, city, avatar_url, is_private")
    .eq("id", user.id)
    .maybeSingle();

  els.ppHandle.value = pubRow?.handle || "";
  els.ppDisplay.value = pubRow?.display_name || "";
  els.ppBio.value = pubRow?.bio || "";
  els.ppCity.value = pubRow?.city || "";
  els.ppAvatar.value = pubRow?.avatar_url || "";

  const { data: privRow } = await sb
    .from("profiles_private")
    .select("email, phone")
    .eq("id", user.id)
    .maybeSingle();

  els.prEmail.value = privRow?.email || "";
  els.prPhone.value = privRow?.phone || "";

  if (els.linkPublic) els.linkPublic.href = `#/u/${(els.ppHandle.value || "").toLowerCase()}`;
}

async function saveProfile() {
  try {
    const { data: { user } } = await sb.auth.getUser();
    if (!user) return alert("Not signed in");

    const handle = (els.ppHandle.value || "").toLowerCase();

    const { error: pubErr } = await sb.from("profiles_public").upsert({
      id: user.id,
      handle,
      display_name: els.ppDisplay.value || null,
      bio: els.ppBio.value || null,
      city: els.ppCity.value || null,
      avatar_url: els.ppAvatar.value || null,
    }, { onConflict: "id" });
    if (pubErr) throw pubErr;

    const { error: privErr } = await sb.from("profiles_private").upsert({
      id: user.id,
      email: els.prEmail.value || null,
      phone: els.prPhone.value || null,
    }, { onConflict: "id" });
    if (privErr) throw privErr;

    alert("Profile saved");
    if (els.linkPublic) els.linkPublic.href = `#/u/${handle}`;
  } catch (e) {
    console.log("Save profile error:", e);
    alert("Save failed: " + (e?.message || e));
  }
}

/* 6) public profile */
async function showPublicProfile(handle) {
  showOnly(els.sections.pub);
  if (!handle) {
    els.pubDisplay.textContent = "Profile not found";
    els.pubHandle.textContent = "";
    els.pubBio.textContent = "";
    els.pubCity.textContent = "";
    els.pubAvatar?.removeAttribute("src");
    return;
  }
  const { data: row, error } = await sb
    .from("profiles_public")
    .select("display_name, handle, bio, city, avatar_url, is_private, is_searchable")
    .eq("handle", handle)
    .maybeSingle();

  if (!row || error) {
    els.pubDisplay.textContent = "Profile not found";
    els.pubHandle.textContent = "";
    els.pubBio.textContent = "";
    els.pubCity.textContent = "";
    els.pubAvatar?.removeAttribute("src");
    return;
  }

  els.pubDisplay.textContent = row.display_name || row.handle;
  els.pubHandle.textContent = `@${row.handle}`;
  els.pubBio.textContent = row.bio || "";
  els.pubCity.textContent = row.city || "";
  if (row.avatar_url) els.pubAvatar.src = row.avatar_url;
  else els.pubAvatar?.removeAttribute("src");
}

/* 7) debate */
async function showDebatePage(handle) {
  showOnly(els.sections.debate);
  if (!handle) {
    els.debTitle.textContent = "Debates";
    els.debDesc.textContent = "No handle given.";
    els.debContent.innerHTML = "";
    return;
  }
  const { data: deb, error } = await sb
    .from("debate_pages")
    .select("title, description, is_public, handle")
    .eq("handle", handle)
    .maybeSingle();

  if (!deb || error) {
    els.debTitle.textContent = "Debate page not found";
    els.debDesc.textContent = "";
    els.debContent.innerHTML = "";
    return;
  }

  els.debTitle.textContent = deb.title || `@${deb.handle} · Debates`;
  els.debDesc.textContent = deb.description || (deb.is_public ? "Public debates" : "Private (hidden) debates");
  els.debContent.innerHTML = '<p class="hint">Threads coming soon.</p>';
}

/* 8) wire events after DOM ready */
function wire() {
  els.btnSignup?.addEventListener("click", signup);
  els.btnLogin?.addEventListener("click", login);
  els.btnSaveProfile?.addEventListener("click", saveProfile);
  els.linkLogout?.addEventListener("click", (e) => { e.preventDefault(); logout(e); });

  window.addEventListener("hashchange", router);
  sb.auth.onAuthStateChange(() => router());
  router();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", wire);
} else {
  wire();
}
