/* ===========================
   Civic Chatter — app.js
   =========================== */

/* ---------- Supabase ---------- */
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";
const EMAIL_REDIRECT_URL = "https://civicchatter.netlify.app/auth-callback.html";

if (!window.supabase) {
  alert("Supabase SDK missing. Ensure the CDN loads before app.js");
  throw new Error("Supabase SDK missing");
}
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/* ---------- Elements ---------- */
const els = {
  nav: document.getElementById("nav"),
  // sections
  login: document.getElementById("login-section"),
  signup: document.getElementById("signup-section"),
  priv: document.getElementById("private-profile"),
  pub: document.getElementById("public-profile"),
  debate: document.getElementById("debate-page"),
  // login inputs
  loginUsername: document.getElementById("login-username"),
  loginPassword: document.getElementById("login-password"),
  // signup inputs
  signupName: document.getElementById("signup-name"),
  signupHandle: document.getElementById("signup-handle"),
  signupEmail: document.getElementById("signup-email"),
  signupPassword: document.getElementById("signup-password"),
  signupPhone: document.getElementById("signup-phone"),
  signupAddress: document.getElementById("signup-address"),
  signupPrivate: document.getElementById("signup-private"),
  // private fields
  ppHandle: document.getElementById("pp-handle"),
  ppDisplay: document.getElementById("pp-display-name"),
  ppBio: document.getElementById("pp-bio"),
  ppCity: document.getElementById("pp-city"),
  ppAvatar: document.getElementById("pp-avatar-url"),
  prEmail: document.getElementById("pr-email"),
  prPhone: document.getElementById("pr-phone"),
  // public view
  pubAvatar: document.getElementById("pub-avatar"),
  pubDisplay: document.getElementById("pub-display-name"),
  pubHandle: document.getElementById("pub-handle"),
  pubCity: document.getElementById("pub-city"),
  pubBio: document.getElementById("pub-bio"),
  // debate
  debTitle: document.getElementById("deb-title"),
  debDesc: document.getElementById("deb-desc"),
  debContent: document.getElementById("deb-content"),
};

/* ---------- Utils ---------- */
const isValidHandle = (h) => /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());

function showOnly(...toShow) {
  [els.login, els.signup, els.priv, els.pub, els.debate].forEach(s => s?.classList.add("hidden"));
  toShow.forEach(s => s?.classList.remove("hidden"));
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

// Button busy-state wrapper
function withBusy(btn, fn) {
  return async (...args) => {
    if (!btn) return fn(...args);
    btn.disabled = true;
    const orig = btn.textContent;
    btn.textContent = btn.dataset.busyLabel || "Working…";
    try { return await fn(...args); }
    finally { btn.disabled = false; btn.textContent = orig; }
  };
}

/* ---------- Router ---------- */
async function router() {
  const { data: { session } } = await sb.auth.getSession();
  els.nav?.classList.toggle("hidden", !session);

  const hash = location.hash || "#/login";

  // Auth callback route (used when email confirmations are enabled)
  if (hash.startsWith("#/auth-callback")) {
    const { data: { session: s } } = await sb.auth.getSession();
    location.hash = s ? "#/profile" : "#/login";
    return;
  }

  // If logged in, keep user out of login/signup
  if (session && (hash === "#/login" || hash.startsWith("#/signup"))) {
    location.hash = "#/profile";
    return;
  }

  if (hash.startsWith("#/signup")) { showOnly(els.signup); return; }

  if (hash.startsWith("#/u/")) {
    const h = hash.split("#/u/")[1]?.toLowerCase();
    await showPublicProfile(h);
    return;
  }

  if (hash.startsWith("#/d/")) {
    const h = hash.split("#/d/")[1]?.toLowerCase();
    if (h === "me") {
      if (!session) return (location.hash = "#/login");
      const me = (await sb.auth.getUser()).data.user;
      const { data: row } = await sb.from("profiles_public").select("handle").eq("id", me.id).maybeSingle();
      await showDebatePage(row?.handle);
      return;
    }
    await showDebatePage(h);
    return;
  }

  if (hash === "#/profile") {
    if (!session) { location.hash = "#/login"; return; }
    await loadMyProfile();
    showOnly(els.priv);
    return;
  }

  // default
  showOnly(els.login);
}

/* ---------- Auth ---------- */
async function loginCore() {
  const uname = (els.loginUsername.value || "").trim();
  const password = els.loginPassword.value;
  if (!uname || !password) return alert("Enter username and password");

  let email = null;

  if (uname.includes("@")) {
    email = uname;
  } else {
    // Treat username as handle → resolve to email
    const { data: pubRow, error: pubErr } = await sb
      .from("profiles_public").select("id").eq("handle", uname.toLowerCase()).maybeSingle();
    if (pubErr) { console.error(pubErr); return alert("Could not look up handle"); }
    if (!pubRow?.id) return alert("Handle not found");

    const { data: privRow, error: privErr } = await sb
      .from("profiles_private").select("email").eq("id", pubRow.id).maybeSingle();
    if (privErr) { console.error(privErr); return alert("Could not resolve email"); }
    if (!privRow?.email) return alert("No email on file for this user");
    email = privRow.email;
  }

  const { error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;

  location.hash = "#/profile";
}

async function signupCore() {
  const name = els.signupName.value.trim();
  const handle = els.signupHandle.value.trim().toLowerCase();
  const email = els.signupEmail.value.trim();
  const password = els.signupPassword.value;
  const phone = els.signupPhone.value.trim();
  const address = els.signupAddress.value?.trim();
  const isPrivate = !!els.signupPrivate.checked;

  if (!name) return alert("Enter your name");
  if (!isValidHandle(handle)) return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
  if (!(await handleAvailable(handle))) return alert("Handle is taken");
  if (!email || !password) return alert("Email & password required");

  // Sign up (works whether email confirmations are ON or OFF)
  const { data: sign, error: signErr } = await sb.auth.signUp({
    email,
    password,
    options: { emailRedirectTo: EMAIL_REDIRECT_URL }, // safe even if confirmations are disabled
  });
  if (signErr) throw signErr;

  // If confirmations are ON, session may be null until email link clicked
  let session = sign.session || (await ensureSession(email, password));
  if (!session) {
    alert("Account created. Check your email to confirm, then sign in.");
    location.hash = "#/login";
    return;
  }

  const userId = session.user.id;

  // Public profile
  const { error: pubErr } = await sb.from("profiles_public").upsert({
    id: userId,
    handle,
    display_name: name,
    is_private: isPrivate,
    is_searchable: !isPrivate
  }, { onConflict: "id" });
  if (pubErr) throw pubErr;

  // Private profile
  const { error: privErr } = await sb.from("profiles_private").upsert({
    id: userId,
    email,
    phone: phone || null,
    address: address || null,
    preferred_contact: phone ? "sms" : "email",
  }, { onConflict: "id" });
  if (privErr) throw privErr;

  // Debate page
  const { error: debErr } = await sb.from("debate_pages").upsert({
    id: userId,
    handle,
    title: `${name || handle}'s Debates`,
    description: "Debate topics and positions."
  }, { onConflict: "id" });
  if (debErr) throw debErr;

  alert("Account ready!");
  location.hash = isPrivate ? "#/profile" : `#/u/${handle}`;
}

const login = withBusy(document.getElementById("btn-login"), loginCore);
const signup = withBusy(document.getElementById("btn-signup"), signupCore);

async function logout(e) {
  e?.preventDefault?.();
  await sb.auth.signOut();
  location.hash = "#/login";
}

/* ---------- Private profile ---------- */
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

  if (document.getElementById("public-link")) {
    document.getElementById("public-link").href = `#/u/${(els.ppHandle.value || "").toLowerCase()}`;
  }
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
    if (document.getElementById("public-link")) {
      document.getElementById("public-link").href = `#/u/${handle}`;
    }
  } catch (e) {
    console.log("Save profile error:", e);
    alert("Save failed: " + (e?.message || e));
  }
}

/* ---------- Public profile ---------- */
async function showPublicProfile(handle) {
  showOnly(els.pub);

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

/* ---------- Debate page ---------- */
async function showDebatePage(handle) {
  showOnly(els.debate);

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

/* ---------- Robust click delegation + boot ---------- */
window.addEventListener("error", (e) => console.error("JS error:", e.message, e.error));

function delegateClicks() {
  document.addEventListener("click", (e) => {
    const t = e.target;
    if (!(t instanceof HTMLElement)) return;

    if (t.id === "btn-login") {
      e.preventDefault();
      login();
    }
    if (t.id === "btn-signup") {
      e.preventDefault();
      signup();
    }
    if (t.id === "go-signup") {
      e.preventDefault();
      location.hash = "#/signup";
    }
    if (t.id === "go-login") {
      e.preventDefault();
      location.hash = "#/login";
    }
    if (t.id === "save-profile") {
      e.preventDefault();
      saveProfile();
    }
    if (t.id === "logout-link") {
      e.preventDefault();
      logout(e);
    }
  });
}

function wire() {
  // set busy labels
  const btnLogin = document.getElementById("btn-login");
  const btnSignup = document.getElementById("btn-signup");
  if (btnLogin) btnLogin.dataset.busyLabel = "Signing in…";
  if (btnSignup) btnSignup.dataset.busyLabel = "Creating…";

  // enter to submit
  els.loginPassword?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") document.getElementById("btn-login")?.click();
  });
  els.signupPassword?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") document.getElementById("btn-signup")?.click();
  });

  delegateClicks();
  window.addEventListener("hashchange", router);
  sb.auth.onAuthStateChange(() => router());
  router();
}

document.readyState === "loading"
  ? document.addEventListener("DOMContentLoaded", wire)
  : wire();
