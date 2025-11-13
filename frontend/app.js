/* ===========================
   Civic Chatter — app.js
   =========================== */

// ---- Service Worker Registration (optional) ----
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  });
}

// ---- Supabase init ----
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

let sb = null; // Supabase client

// ---- Section IDs (must match HTML) ----
const SECTION_IDS = [
  "login-section",
  "signup-section",
  "forgot-password-section",
  "private-profile",
  "public-profile",
  "debate-page",
  "settings-page",
];

// ---- Helpers ----
const formatError = (err) => err?.message || String(err || "Unknown error");

function byId(id, { required = false } = {}) {
  const el = document.getElementById(id);
  if (!el && required) {
    console.error(`Missing required DOM element #${id}`);
  }
  return el;
}

function readValue(id, { lowercase = false } = {}) {
  const el = byId(id, { required: true });
  const value = (el?.value ?? "").trim();
  return lowercase ? value.toLowerCase() : value;
}

function writeValue(id, value) {
  const el = byId(id);
  if (el && "value" in el) {
    el.value = value ?? "";
  }
}

async function withBusyButton(buttonId, busyText, fn) {
  const btn = byId(buttonId, { required: true });
  if (!btn) return fn();

  const originalText = btn.textContent;
  const originalDisabled = btn.disabled;
  const originalAriaBusy = btn.getAttribute("aria-busy");

  btn.disabled = true;
  btn.setAttribute("aria-busy", "true");
  if (busyText) btn.textContent = busyText;

  try {
    return await fn();
  } finally {
    btn.disabled = originalDisabled;
    if (originalAriaBusy === null) btn.removeAttribute("aria-busy");
    else btn.setAttribute("aria-busy", originalAriaBusy);
    btn.textContent = originalText;
  }
}

function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
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
  const nav = byId("nav");
  if (nav) nav.classList.remove("hidden");
}

function hideNav() {
  const nav = byId("nav");
  if (nav) nav.classList.add("hidden");
}

function handleActionError(action, err) {
  console.error(`${action} failed:`, err);
  let msg = formatError(err);

  if (msg.includes("Password should be at least")) {
    msg = "Password must be at least 6 characters long.";
  } else if (msg.includes("Email signups are disabled")) {
    msg = "Email signups are currently disabled in Supabase settings.";
  } else if (msg.includes("User already registered")) {
    msg = "This email is already registered. Try logging in instead.";
  } else if (msg.includes("Invalid login credentials")) {
    msg =
      "Invalid login credentials.\n\n" +
      "• Check your email/handle\n" +
      "• Check your password\n" +
      "• Make sure you created an account\n\n" +
      "Tip: Try using your email instead of handle.";
  } else if (msg.includes("Handle is already taken")) {
    msg = "That handle is already taken. Please choose another.";
  } else if (msg.includes("Handle not found")) {
    msg =
      "Handle not found.\n\n" +
      "• Check the spelling\n" +
      "• Or log in using your email\n" +
      "• Make sure you created an account";
  }

  alert(`${action} error: ${msg}`);
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
  const upsert = async (promise, label) => {
    const { error } = await promise;
    if (error) throw new Error(`${label}: ${error.message}`);
  };

  // public profile
  await upsert(
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

  // private profile
  await upsert(
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

  // debate page
  await upsert(
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
  // if user typed email, just use it
  if (identifier.includes("@")) return identifier;

  // otherwise treat as handle → look up in DB
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
function goToSignup() {
  hideNav();
  showSection("signup-section");
}

function goToLogin() {
  hideNav();
  showSection("login-section");
}

function goToForgotPassword() {
  hideNav();
  showSection("forgot-password-section");
}

// ---- Auth: Logout ----
async function handleLogout() {
  try {
    const { error } = await sb.auth.signOut();
    if (error) throw error;
    hideNav();
    showSection("login-section");
  } catch (err) {
    handleActionError("logout", err);
  }
}

// ---- Auth: Reset password ----
async function handleResetPassword() {
  await withBusyButton("btn-reset-password", "Sending…", async () => {
    try {
      const email = readValue("forgot-email");
      if (!email || !email.includes("@")) {
        return alert("Please enter a valid email address");
      }

      const { error } = await sb.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password.html`,
      });

      if (error) throw error;

      alert("Password reset email sent. Check your inbox (and spam).");
      writeValue("forgot-email", "");
      goToLogin();
    } catch (err) {
      handleActionError("password reset", err);
    }
  });
}

// ---- Auth: Signup ----
async function handleSignup() {
  await withBusyButton("btn-signup", "Creating…", async () => {
    try {
      const name = readValue("signup-name");
      const handle = readValue("signup-handle", { lowercase: true });
      const email = readValue("signup-email");
      const phone = readValue("signup-phone");
      const password = byId("signup-password", { required: true }).value;
      const isPrivate = !!byId("signup-private").checked;

      if (!name) return alert("Enter your name");
      if (!isValidHandle(handle)) {
        return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
      }
      if (!email || !password) {
        return alert("Email & password are required");
      }
      if (password.length < 6) {
        return alert("Password must be at least 6 characters long");
      }

      await ensureHandleAvailable(handle);

      const { data, error } = await sb.auth.signUp({
        email,
        password,
      });

      if (error) throw error;

      const user = data.user;
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

      alert("Account created!");
      showNav();
      showSection("private-profile");
      await loadMyProfile();
    } catch (err) {
      handleActionError("signup", err);
    }
  });
}

// ---- Auth: Login ----
async function handleLogin() {
  await withBusyButton("btn-login", "Signing in…", async () => {
    try {
      const identifier = readValue("login-username");
      const password = byId("login-password", { required: true }).value;

      if (!identifier || !password) {
        return alert("Enter username/email and password");
      }

      const email = await resolveEmailForLogin(identifier);

      const { error } = await sb.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;

      alert("Login OK!");
      showNav();
      showSection("private-profile");
      await loadMyProfile();
    } catch (err) {
      handleActionError("login", err);
    }
  });
}

// ---- Load My Profile ----
async function loadMyProfile() {
  try {
    const user = await requireUser();

    const { data: pubRow } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (pubRow) {
      writeValue("pp-handle", pubRow.handle || "");
      writeValue("pp-display-name", pubRow.display_name || "");
      writeValue("pp-bio", pubRow.bio || "");
      writeValue("pp-city", pubRow.city || "");
      writeValue("pp-avatar-url", pubRow.avatar_url || "");

      const link = byId("public-link");
      if (link && pubRow.handle) {
        link.href = `#/u/${pubRow.handle.toLowerCase()}`;
      }
    }

    const { data: privRow } = await sb
      .from("profiles_private")
      .select("email, phone")
      .eq("id", user.id)
      .maybeSingle();

    if (privRow) {
      writeValue("pr-email", privRow.email || "");
      writeValue("pr-phone", privRow.phone || "");
    }
  } catch (err) {
    handleActionError("profile load", err);
  }
}

// ---- Save Profile ----
async function handleSaveProfile() {
  try {
    const user = await requireUser();

    const handle = readValue("pp-handle", { lowercase: true });
    const displayName = readValue("pp-display-name");
    const bio = readValue("pp-bio");
    const city = readValue("pp-city");
    const avatarUrl = readValue("pp-avatar-url");
    const email = readValue("pr-email");
    const phone = readValue("pr-phone");

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
    if (pubErr) throw new Error(pubErr.message);

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        email: email || null,
        phone: phone || null,
      },
      { onConflict: "id" }
    );
    if (privErr) throw new Error(privErr.message);

    alert("Profile saved");
  } catch (err) {
    handleActionError("profile save", err);
  }
}

// ---- Public Profile (view) ----
async function showPublicProfileView() {
  try {
    const user = await requireUser();

    const { data: pubRow, error } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (error) throw error;

    if (pubRow) {
      const avatar = byId("pub-avatar");
      const displayName = byId("pub-display-name");
      const handle = byId("pub-handle");
      const city = byId("pub-city");
      const bio = byId("pub-bio");

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

// ---- Settings (load + save) ----
async function loadSettings() {
  try {
    const user = await requireUser();

    const { data: pubRow } = await sb
      .from("profiles_public")
      .select("is_private")
      .eq("id", user.id)
      .maybeSingle();

    if (pubRow) {
      const privacySelect = byId("settings-privacy");
      if (privacySelect) {
        privacySelect.value = pubRow.is_private ? "private" : "public";
      }
    }

    const { data: privRow } = await sb
      .from("profiles_private")
      .select("preferred_contact")
      .eq("id", user.id)
      .maybeSingle();

    if (privRow) {
      const contactSelect = byId("settings-contact");
      if (contactSelect) {
        contactSelect.value = privRow.preferred_contact || "email";
      }
    }

    showSection("settings-page");
  } catch (err) {
    handleActionError("settings load", err);
  }
}

async function handleSettingsSave() {
  try {
    const user = await requireUser();

    const privacySelect = byId("settings-privacy");
    const contactSelect = byId("settings-contact");

    const privacy = privacySelect?.value || "public";
    const contact = contactSelect?.value || "email";

    const isPrivate = privacy === "private";

    const { error: pubErr } = await sb.from("profiles_public").upsert(
      {
        id: user.id,
        is_private: isPrivate,
        is_searchable: !isPrivate,
      },
      { onConflict: "id" }
    );
    if (pubErr) throw new Error(pubErr.message);

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        preferred_contact: contact,
      },
      { onConflict: "id" }
    );
    if (privErr) throw new Error(privErr.message);

    alert("Settings saved");
  } catch (err) {
    handleActionError("settings save", err);
  }
}

// ---- Debates ----
async function showDebates() {
  try {
    const user = await requireUser();

    const { data: debateRow, error } = await sb
      .from("debate_pages")
      .select("title, description")
      .eq("id", user.id)
      .maybeSingle();

    if (error) throw error;

    const titleEl = byId("deb-title");
    const descEl = byId("deb-desc");

    if (titleEl) titleEl.textContent = debateRow?.title || "My Debates";
    if (descEl) descEl.textContent = debateRow?.description || "";

    showSection("debate-page");
  } catch (err) {
    handleActionError("debates load", err);
  }
}

// ---- Attach event listeners ----
function attachEventListeners() {
  console.log("Attaching event listeners…");

  // Auth
  byId("btn-login", { required: true })?.addEventListener("click", handleLogin);
  byId("btn-signup", { required: true })?.addEventListener("click", handleSignup);
  byId("go-signup")?.addEventListener("click", goToSignup);
  byId("go-login")?.addEventListener("click", goToLogin);

  // Enter key for login
  const loginPassword = byId("login-password");
  loginPassword?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleLogin();
    }
  });

  // Forgot password
  byId("forgot-password-btn")?.addEventListener("click", goToForgotPassword);
  byId("btn-reset-password")?.addEventListener("click", handleResetPassword);
  byId("back-to-login")?.addEventListener("click", goToLogin);

  // Profile / settings / debates
  byId("save-profile")?.addEventListener("click", handleSaveProfile);
  byId("settings-save")?.addEventListener("click", handleSettingsSave);
  byId("settings-logout")?.addEventListener("click", handleLogout);

  // Nav links
  byId("nav-private-profile")?.addEventListener("click", (e) => {
    e.preventDefault();
    showSection("private-profile");
    loadMyProfile();
  });

  byId("nav-public-profile")?.addEventListener("click", (e) => {
    e.preventDefault();
    showPublicProfileView();
  });

  byId("nav-debates")?.addEventListener("click", (e) => {
    e.preventDefault();
    showDebates();
  });

  byId("nav-settings")?.addEventListener("click", (e) => {
    e.preventDefault();
    loadMyProfile();
    loadSettings();
  });

  // Logout (nav)
  byId("logout-btn")?.addEventListener("click", handleLogout);
}

// ---- Init ----
function initApp() {
  console.log("=== Civic Chatter app starting ===");

  if (!window.supabase) {
    console.error("Supabase SDK missing (window.supabase undefined)");
    alert("Supabase SDK failed to load");
    return;
  }

  sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  console.log("Supabase client created:", !!sb);

  attachEventListeners();
  hideNav();
  showSection("login-section");
  console.log("App ready.");
}

// Run once DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  initApp();
}
