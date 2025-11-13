/* ===========================
   Civic Chatter — app.js
   =========================== */

// ---- Service Worker Registration ----
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () =>
    navigator.serviceWorker.register("/sw.js").catch(() => {})
  );
}

// ---- Supabase init ----
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

if (!window.supabase) {
  alert("Supabase SDK missing (window.supabase is undefined)");
  throw new Error("Supabase SDK missing");
}

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---- helpers ----
const SECTION_IDS = ["login-section", "signup-section", "private-profile", "public-profile", "debate-page"];

const formatError = (err) => err?.message || err || "Unknown error";

function byId(id) {
  const el = document.getElementById(id);
  if (!el) {
    throw new Error(`Missing DOM element #${id}`);
  }
  return el;
}

function readValue(id, { lowercase = false } = {}) {
  const el = byId(id);
  const value = (el.value ?? "").trim();
  return lowercase ? value.toLowerCase() : value;
}

function writeValue(id, value) {
  const el = byId(id);
  if ("value" in el) el.value = value ?? "";
}

async function withBusyButton(buttonId, busyText, fn) {
  const btn = byId(buttonId);
  const originalDisabled = btn.disabled;
  const originalAriaBusy = btn.getAttribute("aria-busy");
  const originalHtml = btn.innerHTML;

  btn.disabled = true;
  btn.setAttribute("aria-busy", "true");
  if (busyText) btn.textContent = busyText;

  try {
    return await fn();
  } finally {
    btn.disabled = originalDisabled;
    if (originalAriaBusy === null) btn.removeAttribute("aria-busy");
    else btn.setAttribute("aria-busy", originalAriaBusy);
    btn.innerHTML = originalHtml;
  }
}

function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
}

function showSection(id) {
  SECTION_IDS.forEach(secId => {
    const el = document.getElementById(secId);
    if (!el) return;
    if (secId === id) el.classList.remove("hidden");
    else el.classList.add("hidden");
  });
}

function handleActionError(action, err) {
  console.error(`${action} failed:`, err);
  
  // Provide user-friendly error messages for common issues
  let userMessage = formatError(err);
  
  if (err?.message?.includes("Password should be at least")) {
    userMessage = "Password must be at least 6 characters long.";
  } else if (err?.message?.includes("Email signups are disabled")) {
    userMessage = "Email signups are currently disabled. Please contact support.";
  } else if (err?.message?.includes("User already registered")) {
    userMessage = "This email is already registered. Try logging in instead.";
  } else if (err?.message?.includes("Invalid login credentials")) {
    userMessage = "Invalid username/email or password. Please try again.";
  } else if (err?.message?.includes("Handle is already taken")) {
    userMessage = "This handle is already taken. Please choose a different one.";
  } else if (err?.message?.includes("Handle not found")) {
    userMessage = "Handle not found. Please check your username or use your email instead.";
  }
  
  alert(`${action} error: ${userMessage}`);
}

async function requireUser() {
  const { data, error } = await sb.auth.getUser();
  if (error) throw error;
  if (!data?.user) throw new Error("No logged-in user");
  return data.user;
}

async function ensureHandleAvailable(handle, { allowOwnerId = null } = {}) {
  const { data, error } = await sb
    .from("profiles_public")
    .select("id")
    .eq("handle", handle)
    .maybeSingle();

  if (error && error.code !== "PGRST116") {
    throw error;
  }
  if (data && data.id !== allowOwnerId) {
    throw new Error("Handle is already taken");
  }
}

async function createInitialRecords({ userId, handle, name, email, phone, isPrivate }) {
  const upsertOrThrow = async (promise, label) => {
    const { error } = await promise;
    if (error) throw new Error(`${label}: ${error.message}`);
  };

  await upsertOrThrow(
    sb.from("profiles_public").upsert(
      {
        id: userId,
        handle,
        display_name: name,
        is_private: isPrivate,
        is_searchable: !isPrivate,
      },
      { onConflict: "id" }
    ),
    "public profile"
  );

  await upsertOrThrow(
    sb.from("profiles_private").upsert(
      {
        id: userId,
        email,
        phone: phone || null,
        preferred_contact: phone ? "sms" : "email",
      },
      { onConflict: "id" }
    ),
    "private profile"
  );

  await upsertOrThrow(
    sb.from("debate_pages").upsert(
      {
        id: userId,
        handle,
        title: `${name || handle}'s Debates`,
        description: "Debate topics and positions.",
      },
      { onConflict: "id" }
    ),
    "debate page"
  );
}

async function resolveEmailForLogin(identifier) {
  if (identifier.includes("@")) {
    return identifier;
  }

  const handle = identifier.toLowerCase();
  const { data: pubRow, error: pubErr } = await sb
    .from("profiles_public")
    .select("id")
    .eq("handle", handle)
    .maybeSingle();

  if (pubErr) throw pubErr;
  if (!pubRow?.id) throw new Error("Handle not found");

  const { data: privRow, error: privErr } = await sb
    .from("profiles_private")
    .select("email")
    .eq("id", pubRow.id)
    .maybeSingle();

  if (privErr) throw privErr;
  if (!privRow?.email) throw new Error("No email on file for this user");

  return privRow.email;
}

// ---- Navigation helpers ----
function showSignup() { 
  showSection("signup-section"); 
}

function showLogin() { 
  showSection("login-section"); 
}

// ---- SIGNUP ----
async function ccSignup() {
  await withBusyButton("btn-signup", "Creating…", async () => {
    try {
      const name   = readValue("signup-name");
      const handle = readValue("signup-handle", { lowercase: true });
      const email  = readValue("signup-email");
      const phone  = readValue("signup-phone");
      const passwd = byId("signup-password").value;
      const isPriv = byId("signup-private").checked;

      if (!name) return alert("Enter your name");
      if (!isValidHandle(handle)) return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
      if (!email || !passwd) return alert("Email & password required");
      if (passwd.length < 6) return alert("Password must be at least 6 characters long");

      await ensureHandleAvailable(handle);

      const { data: signData, error: signError } = await sb.auth.signUp({
        email,
        password: passwd,
        // if you re-enable confirmations later, you can add:
        // options: { emailRedirectTo: "https://civicchatter.netlify.app/auth-callback.html" },
      });

      if (signError) {
        throw signError;
      }

      const user = signData.user;
      if (!user) {
        throw new Error("Signup succeeded but no user returned. Check Supabase Auth settings.");
      }

      const userId = user.id;
      await createInitialRecords({ userId, handle, name, email, phone, isPrivate: isPriv });

      alert("Account and pages created successfully!");
      showSection("private-profile");
      await loadMyProfile();
    } catch (err) {
      handleActionError("signup", err);
    }
  });
}

// ---- LOGIN ----
async function ccLogin() {
  try {
    const uname = readValue("login-username");
    const passwd = byId("login-password").value;

    if (!uname || !passwd) {
      return alert("Enter username/email and password");
    }

    const email = await resolveEmailForLogin(uname);
    const { data, error } = await sb.auth.signInWithPassword({ email, password: passwd });

    if (error) {
      throw error;
    }

    alert("Login OK!");
    showSection("private-profile");
    await loadMyProfile();
  } catch (err) {
    handleActionError("login", err);
  }
}

// ---- LOAD MY PROFILE ----
async function loadMyProfile() {
  try {
    const user = await requireUser();

    const { data: pubRow, error: pubErr } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (!pubErr && pubRow) {
      writeValue("pp-handle", pubRow.handle || "");
      writeValue("pp-display-name", pubRow.display_name || "");
      writeValue("pp-bio", pubRow.bio || "");
      writeValue("pp-city", pubRow.city || "");
      writeValue("pp-avatar-url", pubRow.avatar_url || "");

      const link = document.getElementById("public-link");
      if (link && pubRow.handle) link.href = `#/u/${pubRow.handle.toLowerCase()}`;
    }

    const { data: privRow, error: privErr } = await sb
      .from("profiles_private")
      .select("email, phone")
      .eq("id", user.id)
      .maybeSingle();

    if (!privErr && privRow) {
      writeValue("pr-email", privRow.email || "");
      writeValue("pr-phone", privRow.phone || "");
    }
  } catch (err) {
    handleActionError("profile load", err);
  }
}

// ---- SAVE PROFILE ----
async function ccSaveProfile() {
  try {
    const user = await requireUser();

    const handle      = readValue("pp-handle", { lowercase: true });
    const displayName = readValue("pp-display-name");
    const bio         = readValue("pp-bio");
    const city        = readValue("pp-city");
    const avatarUrl   = readValue("pp-avatar-url");
    const email       = readValue("pr-email");
    const phone       = readValue("pr-phone");

    if (!isValidHandle(handle)) {
      return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
    }

    await ensureHandleAvailable(handle, { allowOwnerId: user.id });

    const { error: pubErr } = await sb.from("profiles_public").upsert(
      {
        id: user.id,
        handle,
        display_name: displayName || null,
        bio: bio || null,
        city: city || null,
        avatar_url: avatarUrl || null,
      },
      { onConflict: "id" }
    );
    if (pubErr) {
      throw new Error("Error saving public profile: " + pubErr.message);
    }

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        email: email || null,
        phone: phone || null,
      },
      { onConflict: "id" }
    );
    if (privErr) {
      throw new Error("Error saving private profile: " + privErr.message);
    }

    alert("Profile saved");
  } catch (err) {
    handleActionError("profile save", err);
  }
}

// ---- Event Listener Attachments ----
function attachEventListeners() {
  // Login page buttons
  byId("btn-login").addEventListener("click", ccLogin);
  byId("go-signup").addEventListener("click", showSignup);

  // Signup page buttons
  byId("btn-signup").addEventListener("click", ccSignup);
  byId("go-login").addEventListener("click", showLogin);

  // Profile page button
  byId("save-profile").addEventListener("click", ccSaveProfile);

  console.log("Event listeners attached successfully");
}

// ---- Initialize app when DOM is ready ----
function initApp() {
  attachEventListeners();
  showSection("login-section");
  console.log("App JS fully loaded");
}

// Wait for DOM to be ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  // DOM is already ready
  initApp();
}