/* ===========================
   Civic Chatter — app.js
   =========================== */

/* ---------- Supabase ---------- */
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";
const EMAIL_REDIRECT_URL = "https://civicchatter.netlify.app/auth-callback.html";

if (!window.supabase) { alert("Supabase SDK missing"); throw new Error("Supabase SDK missing"); }
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/* ---------- Debug console ---------- */
const dbgBox = document.getElementById("cc-debug");
const dbgLog = document.getElementById("cc-debug-log");
function log(...args){ if(!dbgLog) return; const line=document.createElement("div"); line.innerHTML=args.map(a => typeof a==='string'?a:(`<pre>${escapeHtml(JSON.stringify(a,null,2))}</pre>`)).join(' '); dbgLog.appendChild(line); dbgLog.scrollTop=dbgLog.scrollHeight; }
function escapeHtml(s){ return s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
window.__ccClearDebug = () => { if(dbgLog) dbgLog.innerHTML=''; };
window.__ccSelfTest = async () => {
  dbgBox.style.display='block';
  log("<b>Self-test</b>");
  try {
    log('SDK present:', !!window.supabase);
    const g = await sb.auth.getSession();
    log('Session:', g.data?.session ? "<span class='ok'>yes</span>" : "<span class='err'>no</span>");
    const ping = await fetch(`${SUPABASE_URL}/auth/v1/health`).then(r=>r.ok);
    log('Auth health:', ping ? "<span class='ok'>ok</span>" : "<span class='err'>fail</span>");
    const probe = await sb.from('profiles_public').select('id').limit(1);
    log('DB probe error:', probe.error ? `<span class='err'>${probe.error.message}</span>` : "<span class='ok'>none</span>");
  } catch(e){ log("<span class='err'>Self-test failed:</span>", e?.message || e); }
};

/* Auto-open debug panel if route is #/debug */
if (location.hash === "#/debug" && dbgBox) dbgBox.style.display = "block";

/* ---------- Elements ---------- */
const els = {
  nav: document.getElementById("nav"),
  login: document.getElementById("login-section"),
  signup: document.getElementById("signup-section"),
  priv: document.getElementById("private-profile"),
  pub: document.getElementById("public-profile"),
  debate: document.getElementById("debate-page"),
  loginUsername: document.getElementById("login-username"),
  loginPassword: document.getElementById("login-password"),
  signupName: document.getElementById("signup-name"),
  signupHandle: document.getElementById("signup-handle"),
  signupEmail: document.getElementById("signup-email"),
  signupPassword: document.getElementById("signup-password"),
  signupPhone: document.getElementById("signup-phone"),
  signupAddress: document.getElementById("signup-address"),
  signupPrivate: document.getElementById("signup-private"),
  ppHandle: document.getElementById("pp-handle"),
  ppDisplay: document.getElementById("pp-display-name"),
  ppBio: document.getElementById("pp-bio"),
  ppCity: document.getElementById("pp-city"),
  ppAvatar: document.getElementById("pp-avatar-url"),
  prEmail: document.getElementById("pr-email"),
  prPhone: document.getElementById("pr-phone"),
  pubAvatar: document.getElementById("pub-avatar"),
  pubDisplay: document.getElementById("pub-display-name"),
  pubHandle: document.getElementById("pub-handle"),
  pubCity: document.getElementById("pub-city"),
  pubBio: document.getElementById("pub-bio"),
  debTitle: document.getElementById("deb-title"),
  debDesc: document.getElementById("deb-desc"),
  debContent: document.getElementById("deb-content"),
};

/* ---------- Utils ---------- */
const isValidHandle = (h) => /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
function showOnly(...toShow){
  [els.login, els.signup, els.priv, els.pub, els.debate].forEach(s => s?.classList.add("hidden"));
  toShow.forEach(s => s?.classList.remove("hidden"));
}
async function handleAvailable(handle){
  const { data, error } = await sb.from("profiles_public").select("id").eq("handle",(handle||"").toLowerCase()).maybeSingle();
  if (error && error.code !== "PGRST116") log("<span class='err'>handle check:</span>", error.message);
  return !data;
}
async function ensureSession(email,password){
  const cur = await sb.auth.getSession();
  if (cur.data?.session) return cur.data.session;
  if (email && password) {
    const r = await sb.auth.signInWithPassword({ email, password });
    if (!r.error) return r.data.session;
  }
  return null;
}
function withBusyById(id, fn){
  return async (...args)=>{
    const btn = document.getElementById(id);
    const orig = btn?.textContent;
    if (btn){ btn.disabled=true; btn.textContent = (btn.dataset.busyLabel||"Working…"); }
    try { return await fn(...args); }
    finally { if (btn){ btn.disabled=false; btn.textContent = orig; } }
  };
}

/* ---------- Router ---------- */
async function router(){
  const { data:{ session } } = await sb.auth.getSession();
  els.nav?.classList.toggle("hidden", !session);

  const hash = location.hash || "#/login";
  if (hash === "#/debug" && dbgBox) dbgBox.style.display='block';

  if (hash.startsWith("#/auth-callback")){
    const { data:{ session: s } } = await sb.auth.getSession();
    location.hash = s ? "#/profile" : "#/login";
    return;
  }

  if (session && (hash === "#/login" || hash.startsWith("#/signup"))){
    location.hash = "#/profile"; return;
  }

  if (hash.startsWith("#/signup")) { showOnly(els.signup); return; }

  if (hash.startsWith("#/u/")){
    const h = hash.split("#/u/")[1]?.toLowerCase(); await showPublicProfile(h); return;
  }

  if (hash.startsWith("#/d/")){
    const h = hash.split("#/d/")[1]?.toLowerCase();
    if (h === "me"){
      if (!session) return (location.hash="#/login");
      const me = (await sb.auth.getUser()).data.user;
      const { data: row } = await sb.from("profiles_public").select("handle").eq("id", me.id).maybeSingle();
      await showDebatePage(row?.handle); return;
    }
    await showDebatePage(h); return;
  }

  if (hash === "#/profile"){
    if (!session){ location.hash="#/login"; return; }
    await loadMyProfile(); showOnly(els.priv); return;
  }

  showOnly(els.login);
}

/* ---------- Auth ---------- */
const login = withBusyById("btn-login", async function(){
  const uname = (els.loginUsername.value||"").trim();
  const password = els.loginPassword.value;
  if (!uname || !password) return alert("Enter username and password");

  let email = null;
  if (uname.includes("@")) {
    email = uname;
  } else {
    const { data: pubRow, error: pubErr } =
      await sb.from("profiles_public").select("id").eq("handle", uname.toLowerCase()).maybeSingle();
    if (pubErr){ log("<span class='err'>lookup handle:</span>", pubErr.message); return alert("Could not look up handle"); }
    if (!pubRow?.id) return alert("Handle not found");

    const { data: privRow, error: privErr } =
      await sb.from("profiles_private").select("email").eq("id", pubRow.id).maybeSingle();
    if (privErr){ log("<span class='err'>resolve email:</span>", privErr.message); return alert("Could not resolve email"); }
    if (!privRow?.email) return alert("No email on file for this user");
    email = privRow.email;
  }

  const { error } = await sb.auth.signInWithPassword({ email, password });
  if (error) { log("<span class='err'>signIn:</span>", error.message); throw error; }

  location.hash = "#/profile";
});

const signup = withBusyById("btn-signup", async function(){
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

  log("<b>Signup:</b>", {email, handle});

  const { data: sign, error: signErr } = await sb.auth.signUp({
    email, password, options: { emailRedirectTo: EMAIL_REDIRECT_URL }
  });
  if (signErr){ log("<span class='err'>signUp:</span>", signErr.message); throw signErr; }

  let session = sign.session || (await ensureSession(email, password));
  if (!session) {
    alert("Account created. Check your email to confirm, then sign in.");
    location.hash = "#/login";
    return;
  }

  const userId = session.user.id;

  // Public profile
  const up1 = await sb.from("profiles_public").upsert({
    id: userId, handle, display_name: name, is_private: isPrivate, is_searchable: !isPrivate
  }, { onConflict: "id" });
  if (up1.error){ log("<span class='err'>profiles_public:</span>", up1.error.message); throw up1.error; }

  // Private profile (no 'address' column here to avoid schema mismatch)
  const up2 = await sb.from("profiles_private").upsert({
    id: userId, email, phone: phone || null, preferred_contact: phone ? "sms" : "email"
  }, { onConflict: "id" });
  if (up2.error){ log("<span class='err'>profiles_private:</span>", up2.error.message); throw up2.error; }

  // Debate page
  const up3 = await sb.from("debate_pages").upsert({
    id: userId, handle, title: `${name || handle}'s Debates`, description: "Debate topics and positions."
  }, { onConflict: "id" });
  if (up3.error){ log("<span class='err'>debate_pages:</span>", up3.error.message); throw up3.error; }

  alert("Account ready!");
  location.hash = isPrivate ? "#/profile" : `#/u/${handle}`;
});

async function logout(e){ e?.preventDefault?.(); await sb.auth.signOut(); location.hash="#/login"; }

/* ---------- Private profile ---------- */
async function loadMyProfile(){
  const { data:{ user } } = await sb.auth.getUser(); if(!user) return;

  const pub = await sb.from("profiles_public")
    .select("handle, display_name, bio, city, avatar_url, is_private")
    .eq("id", user.id).maybeSingle();
  if (!pub.error && pub.data){
    els.ppHandle.value = pub.data.handle || "";
    els.ppDisplay.value = pub.data.display_name || "";
    els.ppBio.value    = pub.data.bio || "";
    els.ppCity.value   = pub.data.city || "";
    els.ppAvatar.value = pub.data.avatar_url || "";
  }

  const priv = await sb.from("profiles_private")
    .select("email, phone").eq("id", user.id).maybeSingle();
  if (!priv.error && priv.data){
    els.prEmail.value = priv.data.email || "";
    els.prPhone.value = priv.data.phone || "";
  }

  const link = document.getElementById("public-link");
  if (link) link.href = `#/u/${(els.ppHandle.value||"").toLowerCase()}`;
}

async function saveProfile(){
  try{
    const { data:{ user } } = await sb.auth.getUser(); if (!user) return alert("Not signed in");
    const handle = (els.ppHandle.value||"").toLowerCase();

    const u1 = await sb.from("profiles_public").upsert({
      id:user.id, handle, display_name: els.ppDisplay.value||null,
      bio: els.ppBio.value||null, city: els.ppCity.value||null, avatar_url: els.ppAvatar.value||null,
    }, { onConflict:"id" });
    if (u1.error) throw u1.error;

    const u2 = await sb.from("profiles_private").upsert({
      id:user.id, email: els.prEmail.value||null, phone: els.prPhone.value||null,
    }, { onConflict:"id" });
    if (u2.error) throw u2.error;

    alert("Profile saved");
    const link = document.getElementById("public-link");
    if (link) link.href = `#/u/${handle}`;
  } catch(e){
    log("<span class='err'>saveProfile:</span>", e?.message||e);
    alert("Save failed: " + (e?.message || e));
  }
}

/* ---------- Public profile ---------- */
async function showPublicProfile(handle){
  showOnly(els.pub);
  if (!handle){
    els.pubDisplay.textContent="Profile not found"; els.pubHandle.textContent="";
    els.pubBio.textContent=""; els.pubCity.textContent=""; els.pubAvatar?.removeAttribute("src");
    return;
  }
  const { data:row, error } = await sb.from("profiles_public")
    .select("display_name, handle, bio, city, avatar_url, is_private, is_searchable")
    .eq("handle", handle).maybeSingle();
  if (!row || error){
    els.pubDisplay.textContent="Profile not found"; els.pubHandle.textContent="";
    els.pubBio.textContent=""; els.pubCity.textContent=""; els.pubAvatar?.removeAttribute("src");
    return;
  }
  els.pubDisplay.textContent = row.display_name || row.handle;
  els.pubHandle.textContent  = `@${row.handle}`;
  els.pubBio.textContent     = row.bio || "";
  els.pubCity.textContent    = row.city || "";
  if (row.avatar_url) els.pubAvatar.src = row.avatar_url; else els.pubAvatar?.removeAttribute("src");
}

/* ---------- Debate page ---------- */
async function showDebatePage(handle){
  showOnly(els.debate);
  if (!handle){
    els.debTitle.textContent="Debates"; els.debDesc.textContent="No handle given."; els.debContent.innerHTML="";
    return;
  }
  const { data:deb, error } = await sb.from("debate_pages")
    .select("title, description, is_public, handle").eq("handle", handle).maybeSingle();
  if (!deb || error){
    els.debTitle.textContent="Debate page not found"; els.debDesc.textContent=""; els.debContent.innerHTML="";
    return;
  }
  els.debTitle.textContent = deb.title || `@${deb.handle} · Debates`;
  els.debDesc.textContent  = deb.description || (deb.is_public ? "Public debates" : "Private (hidden) debates");
  els.debContent.innerHTML = '<p class="hint">Threads coming soon.</p>';
}

/* ---------- Robust click delegation + boot ---------- */
window.addEventListener("error", (e) => { log("<span class='err'>JS error:</span>", e.message); });

function delegateClicks(){
  document.addEventListener("click", (e) => {
    const t = (e.target && e.target.closest) ? e.target.closest("button,a") : e.target;
    if (!t || !t.id) return;

    if (t.id === "btn-login"){ e.preventDefault(); window.__onLogin(e); }
    if (t.id === "btn-signup"){ e.preventDefault(); window.__onSignup(e); }
    if (t.id === "go-signup"){ e.preventDefault(); location.hash="#/signup"; }
    if (t.id === "go-login"){ e.preventDefault(); location.hash="#/login"; }
    if (t.id === "save-profile"){ e.preventDefault(); window.__onSaveProfile(e); }
    if (t.id === "logout-link"){ e.preventDefault(); logout(e); }
  });
}

function wire(){
  // expose fallbacks for inline onclick
  window.__onLogin = () => login();
  window.__onSignup = () => signup();
  window.__onSaveProfile = () => saveProfile();

  // busy labels
  const bl = document.getElementById("btn-login");
  const bs = document.getElementById("btn-signup");
  if (bl) bl.dataset.busyLabel="Signing in…";
  if (bs) bs.dataset.busyLabel="Creating…";

  // enter submit
  els.loginPassword?.addEventListener("keydown", (e)=>{ if (e.key==="Enter") document.getElementById("btn-login")?.click(); });
  els.signupPassword?.addEventListener("keydown", (e)=>{ if (e.key==="Enter") document.getElementById("btn-signup")?.click(); });

  delegateClicks();
  window.addEventListener("hashchange", router);
  sb.auth.onAuthStateChange(() => router());

  log("<b>Boot</b>");
  __ccSelfTest().catch(()=>{});
  router();
}

document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", wire) : wire();
