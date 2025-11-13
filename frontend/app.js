/* ===========================
   Civic Chatter — app.js
   =========================== */

// ---- Service Worker (optional, safe no-op if missing) ----
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

// ---- DOM helper utilities ----
const SECTION_IDS = [
  "login-section",
  "signup-section",
  "private-page",
  "public-page",
  "settings-page",
];

function byId(id) {
  const el = document.getElementById(id);
  if (!el) {
    console.warn("Missing DOM element #", id);
  }
  return el;
}

function showSection(id) {
  SECTION_IDS.forEach((secId) => {
    const el = byId(secId);
    if (!el) return;
    if (secId === id) el.classList.remove("hidden");
    else el.classList.add("hidden");
  });
}

function showNav(visible) {
  const nav = byId("nav");
  if (!nav) return;
  if (visible) nav.classList.remove("hidden");
  else nav.classList.add("hidden");
}

function readValue(id, { lowercase = false } = {}) {
  const el = byId(id);
  if (!el) return "";
  const v = (el.value ?? "").trim();
  return lowercase ? v.toLowerCase() : v;
}

function writeValue(id, value) {
  const el = byId(id);
  if (!el) return;
  if ("value" in el) el.value = value ?? "";
}

// Simple handle validation
function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
}

function handleError(action, err) {
  console.error(`${action} failed:`, err);
  alert(`${action} error: ${err?.message || err || "Unknown error"}`);
}

// Busy button wrapper
async function withBusyButton(btn, label, fn) {
  if (!btn) return fn();
  const orig = btn.textContent;
  btn.disabled = true;
  btn.textContent = label;
  try {
    return await fn();
  } finally {
    btn.disabled = false;
    btn.textContent = orig;
  }
}

// ---- Auth + profiles helpers ----
async function requireUser() {
  const { data, error } = await sb.auth.getUser();
  if (error) throw error;
  if (!data?.user) throw new Error("Not signed in");
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

async function resolveEmailForLogin(identifier) {
  if (identifier.includes("@")) return identifier; // email

  // Treat as handle
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

async function createInitialRecords({ userId, handle, name, email, phone, isPrivate }) {
  const doUpsert = async (promise, label) => {
    const { error } = await promise;
    if (error) throw new Error(`${label}: ${error.message}`);
  };

  await doUpsert(
    sb
      .from("profiles_public")
      .upsert(
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

  await doUpsert(
    sb
      .from("profiles_private")
      .upsert(
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

  await doUpsert(
    sb
      .from("debate_pages")
      .upsert(
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

// ---- Theme helpers (localStorage) ----
function applyThemeFromSettings(settings) {
  const root = document.documentElement;
  const { fontSize, colorScheme, backgroundUrl } = settings;

  // Font size
  if (fontSize === "small") root.style.fontSize = "14px";
  else if (fontSize === "large") root.style.fontSize = "18px";
  else root.style.fontSize = ""; // normal

  // Color scheme (basic)
  if (colorScheme === "light") {
    root.dataset.theme = "light";
  } else if (colorScheme === "dark") {
    root.dataset.theme = "dark";
  } else {
    root.dataset.theme = "";
  }

  // Background
  if (backgroundUrl) {
    document.body.style.backgroundImage = `url("${backgroundUrl}")`;
    document.body.style.backgroundSize = "cover";
    document.body.style.backgroundAttachment = "fixed";
  } else {
    document.body.style.backgroundImage = "";
  }
}

function loadThemeSettings() {
  try {
    return JSON.parse(localStorage.getItem("cc_theme") || "{}");
  } catch {
    return {};
  }
}

function saveThemeSettings(settings) {
  localStorage.setItem("cc_theme", JSON.stringify(settings));
}

// ---- AUTH: Login / Signup / Logout ----
async function handleLogin() {
  const btn = byId("btn-login");
  await withBusyButton(btn, "Signing in…", async () => {
    try {
      const ident = readValue("login-username");
      const password = readValue("login-password");
      if (!ident || !password) {
        alert("Enter username/email and password");
        return;
      }

      const email = await resolveEmailForLogin(ident);
      const { error } = await sb.auth.signInWithPassword({ email, password });
      if (error) throw error;

      // Logged in → show private page & nav
      showNav(true);
      showSection("private-page");
      await loadSettingsIntoForm(); // so settings is ready if they click it
    } catch (err) {
      handleError("Login", err);
    }
  });
}

async function handleSignup() {
  const btn = byId("btn-signup");
  await withBusyButton(btn, "Creating…", async () => {
    try {
      const name = readValue("signup-name");
      const handle = readValue("signup-handle", { lowercase: true });
      const email = readValue("signup-email");
      const phone = readValue("signup-phone");
      const password = readValue("signup-password");
      const address = readValue("signup-address"); // stored in private if you want later
      const isPrivate = byId("signup-private")?.checked || false;

      if (!name) return alert("Enter your name");
      if (!isValidHandle(handle)) return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
      if (!email || !password) return alert("Email & password required");
      if (password.length < 6) return alert("Password must be at least 6 characters");

      await ensureHandleAvailable(handle);

      const { data, error } = await sb.auth.signUp({
        email,
        password,
      });
      if (error) throw error;

      const user = data.user;
      if (!user) throw new Error("Signup succeeded but no user returned (check Supabase Auth).");

      await createInitialRecords({
        userId: user.id,
        handle,
        name,
        email,
        phone,
        isPrivate,
      });

      alert("Account created! You are now signed in.");
      showNav(true);
      showSection("private-page");
      await loadSettingsIntoForm();
    } catch (err) {
      handleError("Signup", err);
    }
  });
}

async function handleLogout() {
  try {
    const { error } = await sb.auth.signOut();
    if (error) throw error;
    showNav(false);
    showSection("login-section");
  } catch (err) {
    handleError("Logout", err);
  }
}

// ---- SETTINGS: load/save profile + theme ----
async function loadSettingsIntoForm() {
  try {
    const user = await requireUser();

    // Public profile
    const { data: pubRow } = await sb
      .from("profiles_public")
      .select("handle, display_name, city, avatar_url, is_private")
      .eq("id", user.id)
      .maybeSingle();

    if (pubRow) {
      writeValue("settings-handle", pubRow.handle || "");
      writeValue("settings-display-name", pubRow.display_name || "");
      writeValue("settings-city", pubRow.city || "");
      writeValue("settings-avatar-url", pubRow.avatar_url || "");
      const privacySel = byId("settings-privacy");
      if (privacySel) privacySel.value = pubRow.is_private ? "private" : "public";
    }

    // Private profile
    const { data: privRow } = await sb
      .from("profiles_private")
      .select("email, phone, preferred_contact")
      .eq("id", user.id)
      .maybeSingle();

    if (privRow) {
      writeValue("settings-email", privRow.email || "");
      writeValue("settings-phone", privRow.phone || "");
      const contactSel = byId("settings-contact");
      if (contactSel) contactSel.value = privRow.preferred_contact || "email";
    }

    // Theme from localStorage
    const theme = loadThemeSettings();
    const fontSel = byId("settings-font-size");
    const colorSel = byId("settings-color-scheme");
    writeValue("settings-background-url", theme.backgroundUrl || "");
    if (fontSel && theme.fontSize) fontSel.value = theme.fontSize;
    if (colorSel && theme.colorScheme) colorSel.value = theme.colorScheme;

    applyThemeFromSettings({
      fontSize: theme.fontSize || "normal",
      colorScheme: theme.colorScheme || "system",
      backgroundUrl: theme.backgroundUrl || "",
    });
  } catch (err) {
    handleError("Load settings", err);
  }
}

async function handleSaveSettings() {
  const btn = byId("btn-save-settings");
  await withBusyButton(btn, "Saving…", async () => {
    try {
      const user = await requireUser();

      // Profile fields
      const handle = readValue("settings-handle", { lowercase: true });
      const displayName = readValue("settings-display-name");
      const email = readValue("settings-email");
      const phone = readValue("settings-phone");
      const city = readValue("settings-city");
      const avatarUrl = readValue("settings-avatar-url");
      const privacy = readValue("settings-privacy");
      const contact = readValue("settings-contact");

      if (!isValidHandle(handle)) {
        alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
        return;
      }

      await ensureHandleAvailable(handle, { allowOwnerId: user.id });

      const isPrivate = privacy === "private";

      // Public
      const { error: pubErr } = await sb
        .from("profiles_public")
        .upsert(
          {
            id: user.id,
            handle,
            display_name: displayName || null,
            city: city || null,
            avatar_url: avatarUrl || null,
            is_private: isPrivate,
            is_searchable: !isPrivate,
          },
          { onConflict: "id" }
        );
      if (pubErr) throw pubErr;

      // Private
      const { error: privErr } = await sb
        .from("profiles_private")
        .upsert(
          {
            id: user.id,
            email: email || null,
            phone: phone || null,
            preferred_contact: contact || "email",
          },
          { onConflict: "id" }
        );
      if (privErr) throw privErr;

      // Theme
      const fontSize = readValue("settings-font-size") || "normal";
      const colorScheme = readValue("settings-color-scheme") || "system";
      const backgroundUrl = readValue("settings-background-url");

      const theme = { fontSize, colorScheme, backgroundUrl };
      saveThemeSettings(theme);
      applyThemeFromSettings(theme);

      alert("Settings saved");
    } catch (err) {
      handleError("Save settings", err);
    }
  });
}

async function handleChangePassword() {
  const btn = byId("btn-change-password");
  await withBusyButton(btn, "Updating…", async () => {
    try {
      const newPass = readValue("settings-new-password");
      const confirm = readValue("settings-new-password-confirm");

      if (!newPass || !confirm) {
        alert("Enter and confirm your new password");
        return;
      }
      if (newPass !== confirm) {
        alert("Passwords do not match");
        return;
      }
      if (newPass.length < 6) {
        alert("Password must be at least 6 characters");
        return;
      }

      const { error } = await sb.auth.updateUser({ password: newPass });
      if (error) throw error;

      writeValue("settings-new-password", "");
      writeValue("settings-new-password-confirm", "");
      alert("Password updated");
    } catch (err) {
      handleError("Change password", err);
    }
  });
}

// ---- Navigation buttons ----
function attachNavListeners() {
  byId("nav-private")?.addEventListener("click", async () => {
    showSection("private-page");
  });

  byId("nav-public")?.addEventListener("click", async () => {
    showSection("public-page");
  });

  byId("nav-settings")?.addEventListener("click", async () => {
    showSection("settings-page");
    await loadSettingsIntoForm();
  });

  byId("nav-logout")?.addEventListener("click", handleLogout);
}

// ---- Auth form listeners ----
function attachAuthListeners() {
  byId("btn-login")?.addEventListener("click", handleLogin);
  byId("btn-signup")?.addEventListener("click", handleSignup);

  byId("go-signup")?.addEventListener("click", () => {
    showNav(false);
    showSection("signup-section");
  });

  byId("go-login")?.addEventListener("click", () => {
    showNav(false);
    showSection("login-section");
  });

  const loginPassword = byId("login-password");
  loginPassword?.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleLogin();
    }
  });
}

// ---- Settings listeners ----
function attachSettingsListeners() {
  byId("btn-save-settings")?.addEventListener("click", handleSaveSettings);
  byId("btn-change-password")?.addEventListener("click", handleChangePassword);
}

// ---- Initial app boot ----
async function boot() {
  console.log("Civic Chatter app booting…");

  attachAuthListeners();
  attachNavListeners();
  attachSettingsListeners();

  // See if user already has a session
  try {
    const { data } = await sb.auth.getSession();
    if (data?.session) {
      showNav(true);
      showSection("private-page");
      await loadSettingsIntoForm();
    } else {
      showNav(false);
      showSection("login-section");
    }
  } catch (err) {
    console.error("Error checking session:", err);
    showNav(false);
    showSection("login-section");
  }

  console.log("Civic Chatter ready");
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot);
} else {
  boot();
}
