/* ===========================
   Civic Chatter — app.js
   =========================== */

// ---- Service Worker Registration ----
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  });
}

// ---- Supabase init ----
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

if (!window.supabase) {
  alert("Supabase SDK missing (window.supabase is undefined)");
  throw new Error("Supabase SDK missing");
}

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---- Helpers ----
const SECTION_IDS = [
  "login-section",
  "signup-section",
  "forgot-password-section",
  "private-profile",
  "public-profile",
  "debate-page",
  "settings-page",
];

const formatError = (err) => err?.message || err || "Unknown error";

function byId(id) {
  const el = document.getElementById(id);
  if (!el) throw new Error(`Missing DOM element #${id}`);
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

function showSection(id) {
  SECTION_IDS.forEach((secId) => {
    const el = document.getElementById(secId);
    if (!el) return;
    if (secId === id) el.classList.remove("hidden");
    else el.classList.add("hidden");
  });
}

function showNav() {
  const nav = document.getElementById("nav");
  if (nav) nav.classList.remove("hidden");
}

function hideNav() {
  const nav = document.getElementById("nav");
  if (nav) nav.classList.add("hidden");
}

function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
}

function handleActionError(action, err) {
  console.error(`${action} failed:`, err);
  let userMessage = formatError(err);

  if (err?.message?.includes("Password should be at least")) {
    userMessage = "Password must be at least 6 characters long.";
  } else if (err?.message?.includes("Email signups are disabled")) {
    userMessage = "Email signups are currently disabled. Please contact support.";
  } else if (err?.message?.includes("User already registered")) {
    userMessage = "This email is already registered. Try logging in instead.";
  } else if (err?.message?.includes("Invalid login credentials")) {
    userMessage =
      "Invalid credentials.\n\n" +
      "• Check your email or handle\n" +
      "• Make sure your password is correct\n" +
      "• Be sure you created an account first\n\n" +
      "Tip: Try logging in with your EMAIL instead of your handle.";
  } else if (err?.message?.includes("Handle is already taken")) {
    userMessage = "This handle is already taken. Please choose a different one.";
  } else if (err?.message?.includes("Handle not found")) {
    userMessage =
      "Handle not found.\n\n" +
      "• Check your handle spelling\n" +
      "• Or try logging in with your EMAIL instead\n" +
      "• Make sure you created an account first";
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

  if (error && error.code !== "PGRST116") throw error;
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
  if (!identifier) throw new Error("Missing username or email");

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

// ---- Navigation helper actions ----
function showSignup() {
  hideNav();
  showSection("signup-section");
}

function showLogin() {
  hideNav();
  showSection("login-section");
}

function showForgotPassword() {
  hideNav();
  showSection("forgot-password-section");
}

// ---- AUTH: Login ----
async function ccLogin() {
  try {
    const identifier = readValue("login-username");
    const password = byId("login-password").value;

    if (!identifier || !password) {
      return alert("Enter username/email and password");
    }

    const email = await resolveEmailForLogin(identifier);
    const { data, error } = await sb.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw error;

    console.log("Sign in successful", data);
    alert("Login OK!");
    showNav();
    showSection("private-profile");
  } catch (err) {
    handleActionError("login", err);
  }
}

// ---- AUTH: Signup ----
async function ccSignup() {
  try {
    const name = readValue("signup-name");
    const handle = readValue("signup-handle", { lowercase: true });
    const email = readValue("signup-email");
    const phone = readValue("signup-phone");
    const password = byId("signup-password").value;
    const address = readValue("signup-address"); // not used yet, but can be added to private table later
    const isPrivate = byId("signup-private").checked;

    if (!name) return alert("Enter your name");
    if (!isValidHandle(handle))
      return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
    if (!email || !password) return alert("Email & password required");
    if (password.length < 6)
      return alert("Password must be at least 6 characters long");

    await ensureHandleAvailable(handle);

    const { data: signData, error: signError } = await sb.auth.signUp({
      email,
      password,
    });
    if (signError) throw signError;

    const user = signData.user;
    if (!user) {
      throw new Error(
        "Signup succeeded but no user returned. Check Supabase Auth settings."
      );
    }

    await createInitialRecords({
      userId: user.id,
      handle,
      name,
      email,
      phone,
      isPrivate,
    });

    alert("Account and pages created successfully!");
    showNav();
    showSection("private-profile");
  } catch (err) {
    handleActionError("signup", err);
  }
}

// ---- AUTH: Logout ----
async function ccLogout() {
  try {
    const { error } = await sb.auth.signOut();
    if (error) throw error;
    alert("Logged out successfully");
    hideNav();
    showLogin();
  } catch (err) {
    handleActionError("logout", err);
  }
}

// ---- AUTH: Forgot/reset password ----
async function ccResetPassword() {
  try {
    const email = readValue("forgot-email");
    if (!email) return alert("Enter your email address");
    if (!email.includes("@")) return alert("Enter a valid email address");

    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password.html`,
    });
    if (error) throw error;

    alert("Password reset email sent! Check your inbox (and spam folder).");
    writeValue("forgot-email", "");
    showLogin();
  } catch (err) {
    handleActionError("password reset", err);
  }
}

// ---- SETTINGS: Load profile & preferences ----
async function loadSettings() {
  try {
    const user = await requireUser();

    // Load public profile
    const { data: pubRow } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url, is_private")
      .eq("id", user.id)
      .maybeSingle();

    if (pubRow) {
      writeValue("settings-name", pubRow.display_name || "");
      writeValue("settings-handle", pubRow.handle || "");
      writeValue("settings-bio", pubRow.bio || "");
      writeValue("settings-city", pubRow.city || "");
      writeValue("settings-avatar-url", pubRow.avatar_url || "");

      const privacySelect = document.getElementById("settings-privacy");
      if (privacySelect) {
        privacySelect.value = pubRow.is_private ? "private" : "public";
      }
    }

    // Load private profile
    const { data: privRow } = await sb
      .from("profiles_private")
      .select("email, phone, preferred_contact")
      .eq("id", user.id)
      .maybeSingle();

    if (privRow) {
      writeValue("settings-email", privRow.email || "");
      writeValue("settings-phone", privRow.phone || "");

      const contactSelect = document.getElementById("settings-contact");
      if (contactSelect) {
        contactSelect.value = privRow.preferred_contact || "email";
      }
    }

    // Load local appearance settings
    const fontSize = localStorage.getItem("cc-font-size") || "medium";
    const theme = localStorage.getItem("cc-theme") || "system";
    const bgUrl = localStorage.getItem("cc-bg-url") || "";

    writeValue("settings-font-size", fontSize);
    writeValue("settings-theme", theme);
    writeValue("settings-bg-url", bgUrl);

    applyAppearance(fontSize, theme, bgUrl);

    showSection("settings-page");
  } catch (err) {
    handleActionError("settings load", err);
  }
}

// ---- SETTINGS: Save profile (top of settings) ----
async function ccSaveProfileFromSettings() {
  try {
    const user = await requireUser();

    const displayName = readValue("settings-name");
    const handle = readValue("settings-handle", { lowercase: true });
    const bio = readValue("settings-bio");
    const city = readValue("settings-city");
    const avatarUrl = readValue("settings-avatar-url");
    const email = readValue("settings-email");
    const phone = readValue("settings-phone");

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
    if (pubErr) throw pubErr;

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        email: email || null,
        phone: phone || null,
      },
      { onConflict: "id" }
    );
    if (privErr) throw privErr;

    alert("Profile saved");
  } catch (err) {
    handleActionError("profile save", err);
  }
}

// ---- SETTINGS: Save privacy & contact ----
async function ccSavePreferences() {
  try {
    const user = await requireUser();
    const privacy = readValue("settings-privacy");
    const contact = readValue("settings-contact");

    const isPrivate = privacy === "private";

    const { error: pubErr } = await sb.from("profiles_public").upsert(
      {
        id: user.id,
        is_private: isPrivate,
        is_searchable: !isPrivate,
      },
      { onConflict: "id" }
    );
    if (pubErr) throw pubErr;

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        preferred_contact: contact,
      },
      { onConflict: "id" }
    );
    if (privErr) throw privErr;

    alert("Preferences saved");
  } catch (err) {
    handleActionError("preferences save", err);
  }
}

// ---- Appearance helpers ----
function applyAppearance(fontSize, theme, bgUrl) {
  const root = document.documentElement;
  const body = document.body;

  // font size
  root.dataset.fontSize = fontSize || "medium";

  // theme
  root.dataset.theme = theme || "system";

  if (theme === "dark") {
    root.classList.add("theme-dark");
    root.classList.remove("theme-light");
  } else if (theme === "light") {
    root.classList.add("theme-light");
    root.classList.remove("theme-dark");
  } else {
    root.classList.remove("theme-light");
    root.classList.remove("theme-dark");
  }

  // background image
  if (bgUrl) {
    body.style.backgroundImage = `url(${bgUrl})`;
    body.style.backgroundSize = "cover";
    body.style.backgroundAttachment = "fixed";
  } else {
    body.style.backgroundImage = "";
  }
}

function ccSaveAppearance() {
  const fontSize = readValue("settings-font-size");
  const theme = readValue("settings-theme");
  const bgUrl = readValue("settings-bg-url");

  localStorage.setItem("cc-font-size", fontSize);
  localStorage.setItem("cc-theme", theme);
  localStorage.setItem("cc-bg-url", bgUrl);

  applyAppearance(fontSize, theme, bgUrl);
  alert("Appearance saved");
}

// ---- SETTINGS: Change password ----
async function ccSavePassword() {
  try {
    await requireUser(); // just ensure logged in
    const newPass = readValue("settings-new-password");
    const confirmPass = readValue("settings-new-password-confirm");

    if (!newPass || !confirmPass) {
      return alert("Enter and confirm your new password");
    }
    if (newPass.length < 6) {
      return alert("Password must be at least 6 characters");
    }
    if (newPass !== confirmPass) {
      return alert("Passwords do not match");
    }

    const { error } = await sb.auth.updateUser({ password: newPass });
    if (error) throw error;

    writeValue("settings-new-password", "");
    writeValue("settings-new-password-confirm", "");
    alert("Password updated");
  } catch (err) {
    handleActionError("password change", err);
  }
}

// ---- Public profile view (for your own public page) ----
async function showPublicProfileView() {
  try {
    const user = await requireUser();
    const { data: pubRow, error } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (error) throw error;
    if (!pubRow) {
      alert("No public profile yet. Fill out your profile in Settings.");
      return loadSettings();
    }

    const avatar = document.getElementById("pub-avatar");
    const displayName = document.getElementById("pub-display-name");
    const handle = document.getElementById("pub-handle");
    const city = document.getElementById("pub-city");
    const bio = document.getElementById("pub-bio");

    if (avatar) avatar.src = pubRow.avatar_url || "https://via.placeholder.com/80";
    if (displayName) displayName.textContent = pubRow.display_name || "Anonymous";
    if (handle) handle.textContent = `@${pubRow.handle}`;
    if (city) city.textContent = pubRow.city || "";
    if (bio) bio.textContent = pubRow.bio || "No bio yet.";

    showSection("public-profile");
  } catch (err) {
    handleActionError("public profile view", err);
  }
}

// ---- Debates view ----
async function showDebates() {
  try {
    const user = await requireUser();
    const { data: row } = await sb
      .from("debate_pages")
      .select("title, description")
      .eq("id", user.id)
      .maybeSingle();

    const titleEl = document.getElementById("deb-title");
    const descEl = document.getElementById("deb-desc");

    if (row) {
      if (titleEl) titleEl.textContent = row.title || "My Debates";
      if (descEl) descEl.textContent = row.description || "";
    } else {
      if (titleEl) titleEl.textContent = "My Debates";
      if (descEl) descEl.textContent = "";
    }

    showSection("debate-page");
  } catch (err) {
    handleActionError("debates load", err);
  }
}

// ---- Attach all event listeners ----
function attachEventListeners() {
  console.log("Attaching event listeners…");

  // login
  byId("btn-login").addEventListener("click", ccLogin);
  byId("go-signup").addEventListener("click", showSignup);
  byId("forgot-password-btn").addEventListener("click", showForgotPassword);

  const loginUsername = byId("login-username");
  const loginPassword = byId("login-password");
  loginUsername.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      ccLogin();
    }
  });
  loginPassword.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      ccLogin();
    }
  });

  // forgot password
  byId("btn-reset-password").addEventListener("click", ccResetPassword);
  byId("back-to-login").addEventListener("click", showLogin);

  // signup
  byId("btn-signup").addEventListener("click", ccSignup);
  byId("go-login").addEventListener("click", showLogin);

  // settings actions
  byId("settings-save-profile").addEventListener("click", ccSaveProfileFromSettings);
  byId("settings-save-preferences").addEventListener("click", ccSavePreferences);
  byId("settings-save-appearance").addEventListener("click", ccSaveAppearance);
  byId("settings-save-password").addEventListener("click", ccSavePassword);
  byId("settings-logout").addEventListener("click", ccLogout);

  // nav
  const navPrivate = document.getElementById("nav-private-profile");
  if (navPrivate) {
    navPrivate.addEventListener("click", (e) => {
      e.preventDefault();
      showSection("private-profile");
    });
  }

  const navPublic = document.getElementById("nav-public-profile");
  if (navPublic) {
    navPublic.addEventListener("click", (e) => {
      e.preventDefault();
      showPublicProfileView();
    });
  }

  const navDebates = document.getElementById("nav-debates");
  if (navDebates) {
    navDebates.addEventListener("click", (e) => {
      e.preventDefault();
      showDebates();
    });
  }

  const navSettings = document.getElementById("nav-settings");
  if (navSettings) {
    navSettings.addEventListener("click", (e) => {
      e.preventDefault();
      loadSettings();
    });
  }

  const logoutBtn = document.getElementById("logout-btn");
  if (logoutBtn) {
    logoutBtn.addEventListener("click", ccLogout);
  }

  console.log("Listeners attached.");
}

// ---- Init app ----
async function initApp() {
  console.log("=== Civic Chatter Initializing ===");
  console.log("Supabase client:", sb ? "✓ Connected" : "✗ Not connected");

  attachEventListeners();

  // If already logged in, show nav + private space
  try {
    const { data } = await sb.auth.getSession();
    if (data?.session) {
      showNav();
      showSection("private-profile");
    } else {
      hideNav();
      showLogin();
    }
  } catch {
    hideNav();
    showLogin();
  }

  console.log("App ready.");
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  initApp();
}
