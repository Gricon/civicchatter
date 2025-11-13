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
const SECTION_IDS = ["login-section", "signup-section", "forgot-password-section", "private-profile", "public-profile", "debate-page", "settings-page"];

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

function showNav() {
  const nav = document.getElementById("nav");
  if (nav) nav.classList.remove("hidden");
}

function hideNav() {
  const nav = document.getElementById("nav");
  if (nav) nav.classList.add("hidden");
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
    userMessage = "Invalid credentials. Please check:\n\n" +
                  "• Are you using the correct email or handle?\n" +
                  "• Is your password correct?\n" +
                  "• Did you create an account yet?\n\n" +
                  "TIP: Try logging in with your EMAIL address instead of your handle.";
  } else if (err?.message?.includes("Handle is already taken")) {
    userMessage = "This handle is already taken. Please choose a different one.";
  } else if (err?.message?.includes("Handle not found")) {
    userMessage = "Handle not found. Please:\n\n" +
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
  console.log("Resolving email for identifier:", identifier);
  
  if (identifier.includes("@")) {
    console.log("Identifier is an email, using directly");
    return identifier;
  }

  console.log("Identifier appears to be a handle, looking up in database...");
  const handle = identifier.toLowerCase();
  
  const { data: pubRow, error: pubErr } = await sb
    .from("profiles_public")
    .select("id")
    .eq("handle", handle)
    .maybeSingle();

  if (pubErr) {
    console.error("Error querying profiles_public:", pubErr);
    throw pubErr;
  }
  
  if (!pubRow?.id) {
    console.error("No profile found for handle:", handle);
    throw new Error("Handle not found");
  }
  
  console.log("Found profile with ID:", pubRow.id);

  const { data: privRow, error: privErr } = await sb
    .from("profiles_private")
    .select("email")
    .eq("id", pubRow.id)
    .maybeSingle();

  if (privErr) {
    console.error("Error querying profiles_private:", privErr);
    throw privErr;
  }
  
  if (!privRow?.email) {
    console.error("No email found for user ID:", pubRow.id);
    throw new Error("No email on file for this user");
  }

  console.log("Resolved email successfully:", privRow.email);
  return privRow.email;
}

// ---- Navigation helpers ----
function showSignup() { 
  showSection("signup-section");
  hideNav();
}

function showLogin() { 
  showSection("login-section");
  hideNav();
}

function showForgotPassword() {
  showSection("forgot-password-section");
  hideNav();
}

// ---- LOGOUT ----
async function ccLogout() {
  try {
    const { error } = await sb.auth.signOut();
    if (error) throw error;
    
    alert("Logged out successfully");
    hideNav();
    showSection("login-section");
  } catch (err) {
    handleActionError("logout", err);
  }
}

// ---- FORGOT PASSWORD ----
async function ccResetPassword() {
  await withBusyButton("btn-reset-password", "Sending...", async () => {
    try {
      const email = readValue("forgot-email");
      
      if (!email) {
        return alert("Please enter your email address");
      }
      
      if (!email.includes("@")) {
        return alert("Please enter a valid email address");
      }
      
      console.log("Sending password reset to:", email);
      
      const { error } = await sb.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password.html`
      });
      
      if (error) {
        console.error("Password reset error:", error);
        throw error;
      }
      
      alert("Password reset email sent! Check your inbox (and spam folder).");
      showLogin();
      
      // Clear the email field
      writeValue("forgot-email", "");
    } catch (err) {
      handleActionError("password reset", err);
    }
  });
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
      showNav();
      showSection("private-profile");
      await loadMyProfile();
    } catch (err) {
      handleActionError("signup", err);
    }
  });
}

// ---- LOGIN ----
async function ccLogin() {
  console.log("Login attempt started...");
  
  try {
    const uname = readValue("login-username");
    const passwd = byId("login-password").value;

    console.log("Username/email:", uname);
    console.log("Password length:", passwd.length);

    if (!uname || !passwd) {
      console.log("Missing credentials");
      return alert("Enter username/email and password");
    }

    console.log("Resolving email for login...");
    const email = await resolveEmailForLogin(uname);
    console.log("Resolved email:", email);

    console.log("Attempting sign in...");
    const { data, error } = await sb.auth.signInWithPassword({ email, password: passwd });

    if (error) {
      console.error("Supabase auth error:", error);
      throw error;
    }

    console.log("Sign in successful!", data);
    alert("Login OK!");
    showNav();
    showSection("private-profile");
    await loadMyProfile();
  } catch (err) {
    console.error("Login error:", err);
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

// ---- SHOW PUBLIC PROFILE VIEW ----
async function showPublicProfileView() {
  try {
    const user = await requireUser();
    
    const { data: pubRow, error: pubErr } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (pubErr) throw pubErr;
    
    if (pubRow) {
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
    }
    
    showSection("public-profile");
  } catch (err) {
    handleActionError("public profile view", err);
  }
}

// ---- LOAD SETTINGS ----
async function loadSettings() {
  try {
    const user = await requireUser();

    const { data: pubRow, error: pubErr } = await sb
      .from("profiles_public")
      .select("is_private")
      .eq("id", user.id)
      .maybeSingle();

    if (!pubErr && pubRow) {
      const privacySelect = document.getElementById("settings-privacy");
      if (privacySelect) {
        privacySelect.value = pubRow.is_private ? "private" : "public";
      }
    }

    const { data: privRow, error: privErr } = await sb
      .from("profiles_private")
      .select("preferred_contact")
      .eq("id", user.id)
      .maybeSingle();

    if (!privErr && privRow) {
      const contactSelect = document.getElementById("settings-contact");
      if (contactSelect) {
        contactSelect.value = privRow.preferred_contact || "email";
      }
    }

    showSection("settings-page");
  } catch (err) {
    handleActionError("settings load", err);
  }
}

// ---- SAVE SETTINGS ----
async function ccSaveSettings() {
  try {
    const user = await requireUser();

    const privacy = document.getElementById("settings-privacy").value;
    const contact = document.getElementById("settings-contact").value;

    const isPrivate = privacy === "private";

    const { error: pubErr } = await sb.from("profiles_public").upsert(
      {
        id: user.id,
        is_private: isPrivate,
        is_searchable: !isPrivate,
      },
      { onConflict: "id" }
    );
    if (pubErr) {
      throw new Error("Error saving privacy settings: " + pubErr.message);
    }

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        preferred_contact: contact,
      },
      { onConflict: "id" }
    );
    if (privErr) {
      throw new Error("Error saving contact preference: " + privErr.message);
    }

    alert("Settings saved successfully");
  } catch (err) {
    handleActionError("settings save", err);
  }
}

// ---- SHOW DEBATES ----
async function showDebates() {
  try {
    const user = await requireUser();
    
    const { data: debateRow, error: debErr } = await sb
      .from("debate_pages")
      .select("title, description")
      .eq("id", user.id)
      .maybeSingle();

    if (!debErr && debateRow) {
      const title = document.getElementById("deb-title");
      const desc = document.getElementById("deb-desc");
      
      if (title) title.textContent = debateRow.title || "My Debates";
      if (desc) desc.textContent = debateRow.description || "";
    }
    
    showSection("debate-page");
  } catch (err) {
    handleActionError("debates load", err);
  }
}

// ---- Event Listener Attachments ----
function attachEventListeners() {
  console.log("Attaching event listeners...");
  
  // Login page buttons
  try {
    const loginBtn = byId("btn-login");
    loginBtn.addEventListener("click", ccLogin);
    console.log("✓ Login button listener attached");
    
    // Add Enter key support for login fields
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
    console.log("✓ Enter key listeners attached to login fields");
  } catch (err) {
    console.error("Failed to attach login button:", err);
  }
  
  try {
    const signupLinkBtn = byId("go-signup");
    signupLinkBtn.addEventListener("click", showSignup);
    console.log("✓ Go to signup button listener attached");
  } catch (err) {
    console.error("Failed to attach go-signup button:", err);
  }

  // Forgot password link
  try {
    const forgotPasswordBtn = document.getElementById("forgot-password-btn");
    if (forgotPasswordBtn) {
      forgotPasswordBtn.addEventListener("click", (e) => {
        e.preventDefault();
        showForgotPassword();
      });
      console.log("✓ Forgot password button listener attached");
    }
  } catch (err) {
    console.error("Failed to attach forgot password button:", err);
  }

  // Forgot password page buttons
  try {
    const resetPasswordBtn = byId("btn-reset-password");
    resetPasswordBtn.addEventListener("click", ccResetPassword);
    console.log("✓ Reset password button listener attached");
  } catch (err) {
    console.error("Failed to attach reset password button:", err);
  }

  try {
    const backToLoginBtn = byId("back-to-login");
    backToLoginBtn.addEventListener("click", showLogin);
    console.log("✓ Back to login button listener attached");
  } catch (err) {
    console.error("Failed to attach back to login button:", err);
  }

  // Signup page buttons
  try {
    const signupBtn = byId("btn-signup");
    signupBtn.addEventListener("click", ccSignup);
    console.log("✓ Signup button listener attached");
  } catch (err) {
    console.error("Failed to attach signup button:", err);
  }
  
  try {
    const loginLinkBtn = byId("go-login");
    loginLinkBtn.addEventListener("click", showLogin);
    console.log("✓ Back to login button listener attached");
  } catch (err) {
    console.error("Failed to attach go-login button:", err);
  }

  // Profile page button
  try {
    const saveProfileBtn = byId("save-profile");
    saveProfileBtn.addEventListener("click", ccSaveProfile);
    console.log("✓ Save profile button listener attached");
  } catch (err) {
    console.error("Failed to attach save profile button:", err);
  }

  // Navigation links
  const navPrivateProfile = document.getElementById("nav-private-profile");
  if (navPrivateProfile) {
    navPrivateProfile.addEventListener("click", (e) => {
      e.preventDefault();
      console.log("Navigating to private profile");
      showSection("private-profile");
      loadMyProfile();
    });
    console.log("✓ Private profile nav listener attached");
  }

  const navPublicProfile = document.getElementById("nav-public-profile");
  if (navPublicProfile) {
    navPublicProfile.addEventListener("click", (e) => {
      e.preventDefault();
      console.log("Navigating to public profile");
      showPublicProfileView();
    });
    console.log("✓ Public profile nav listener attached");
  }

  const navDebates = document.getElementById("nav-debates");
  if (navDebates) {
    navDebates.addEventListener("click", (e) => {
      e.preventDefault();
      console.log("Navigating to debates");
      showDebates();
    });
    console.log("✓ Debates nav listener attached");
  }

  const navSettings = document.getElementById("nav-settings");
  if (navSettings) {
    navSettings.addEventListener("click", (e) => {
      e.preventDefault();
      console.log("Navigating to settings");
      loadSettings();
    });
    console.log("✓ Settings nav listener attached");
  }

  // Logout buttons (both in nav and in settings)
  const logoutBtn = document.getElementById("logout-btn");
  if (logoutBtn) {
    logoutBtn.addEventListener("click", ccLogout);
    console.log("✓ Logout button (nav) listener attached");
  }

  const settingsLogout = document.getElementById("settings-logout");
  if (settingsLogout) {
    settingsLogout.addEventListener("click", ccLogout);
    console.log("✓ Logout button (settings) listener attached");
  }

  // Settings save button
  const settingsSave = document.getElementById("settings-save");
  if (settingsSave) {
    settingsSave.addEventListener("click", ccSaveSettings);
    console.log("✓ Settings save button listener attached");
  }

  console.log("All event listeners attached successfully!");
}

// ---- Initialize app when DOM is ready ----
function initApp() {
  console.log("=== Civic Chatter Initializing ===");
  console.log("Supabase client:", sb ? "✓ Connected" : "✗ Not connected");
  
  attachEventListeners();
  showSection("login-section");
  console.log("App JS fully loaded and ready!");
  console.log("=================================");
}

// Wait for DOM to be ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  // DOM is already ready
  initApp();
}