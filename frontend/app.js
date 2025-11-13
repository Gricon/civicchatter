/* ===========================
   Civic Chatter — app.js
   =========================== */

// ---- Supabase init ----
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

let sb = null;

// Sections in the SPA
const SECTION_IDS = [
  "login-section",
  "signup-section",
  "forgot-password-section",
  "private-profile",
  "public-profile",
  "debate-page",
  "settings-page",
];

// ---------- small helpers ----------
function byId(id) {
  const el = document.getElementById(id);
  if (!el) {
    console.error("Missing DOM element #", id);
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

function showNav(show) {
  const nav = byId("nav");
  if (!nav) return;
  if (show) nav.classList.remove("hidden");
  else nav.classList.add("hidden");
}

function readVal(id, lower = false) {
  const el = byId(id);
  const v = (el?.value ?? "").trim();
  return lower ? v.toLowerCase() : v;
}

function writeVal(id, v) {
  const el = byId(id);
  if (el && "value" in el) el.value = v ?? "";
}

function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
}

async function requireUser() {
  const { data, error } = await sb.auth.getUser();
  if (error) throw error;
  if (!data?.user) throw new Error("Not signed in");
  return data.user;
}

// ---------- Supabase record helpers ----------
async function ensureHandleAvailable(handle, { allowOwnerId = null } = {}) {
  const { data, error } = await sb
    .from("profiles_public")
    .select("id")
    .eq("handle", handle)
    .maybeSingle();

  // PGRST116 = "No rows"
  if (error && error.code !== "PGRST116") throw error;

  if (data && data.id !== allowOwnerId) {
    throw new Error("Handle is already taken");
  }
}

async function createInitialRecords({ userId, handle, name, email, phone, isPrivate }) {
  const upsert = async (promise, label) => {
    const { error } = await promise;
    if (error) throw new Error(`${label}: ${error.message}`);
  };

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

// ---------- AUTH: login, signup, logout ----------
async function handleLoginClick() {
  const btn = byId("btn-login");
  if (!btn) return;

  const originalText = btn.textContent;
  btn.disabled = true;
  btn.textContent = "Signing in…";

  try {
    const identifier = readVal("login-username");
    const password = readVal("login-password");

    if (!identifier || !password) {
      alert("Enter username/email and password");
      return;
    }

    // For now: treat the identifier as EMAIL ONLY to keep this simple & test
    const email = identifier;

    console.log("Login with email:", email);

    const { data, error } = await sb.auth.signInWithPassword({
      email,
      password,
    });

    console.log("signInWithPassword result:", data, error);

    if (error) {
      alert("Login failed: " + error.message);
      return;
    }

    alert("Login OK!");
    showNav(true);
    showSection("private-profile");
    await loadMyProfile();
  } catch (err) {
    console.error("Login error:", err);
    alert("Login error: " + (err?.message || err));
  } finally {
    btn.disabled = false;
    btn.textContent = originalText;
  }
}

async function handleSignupClick() {
  const btn = byId("btn-signup");
  if (!btn) return;

  const originalText = btn.textContent;
  btn.disabled = true;
  btn.textContent = "Creating…";

  try {
    const name = readVal("signup-name");
    const handle = readVal("signup-handle", true);
    const email = readVal("signup-email");
    const phone = readVal("signup-phone");
    const password = readVal("signup-password");
    const isPrivate = byId("signup-private")?.checked ?? false;

    if (!name) {
      alert("Enter your name");
      return;
    }
    if (!isValidHandle(handle)) {
      alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
      return;
    }
    if (!email || !password) {
      alert("Email & password required");
      return;
    }
    if (password.length < 6) {
      alert("Password must be at least 6 characters");
      return;
    }

    await ensureHandleAvailable(handle);

    console.log("Signing up:", { email, handle });

    const { data, error } = await sb.auth.signUp({
      email,
      password,
    });

    console.log("signUp result:", data, error);

    if (error) {
      alert("Signup failed: " + error.message);
      return;
    }

    const user = data.user;
    if (!user) {
      alert("Signup succeeded but no user returned (check Supabase email settings).");
      return;
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
    showNav(true);
    showSection("private-profile");
    await loadMyProfile();
  } catch (err) {
    console.error("Signup error:", err);
    alert("Signup error: " + (err?.message || err));
  } finally {
    btn.disabled = false;
    btn.textContent = originalText;
  }
}

async function handleLogoutClick() {
  try {
    await sb.auth.signOut();
  } catch (err) {
    console.error("Logout error:", err);
  }
  showNav(false);
  showSection("login-section");
}

// ---------- PROFILE + SETTINGS ----------
async function loadMyProfile() {
  try {
    const user = await requireUser();

    const { data: pub, error: pubErr } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url, is_private, is_searchable")
      .eq("id", user.id)
      .maybeSingle();

    if (pubErr) console.error("public profile error:", pubErr);

    writeVal("pp-handle", pub?.handle || "");
    writeVal("pp-display-name", pub?.display_name || "");
    writeVal("pp-bio", pub?.bio || "");
    writeVal("pp-city", pub?.city || "");
    writeVal("pp-avatar-url", pub?.avatar_url || "");

    const publicLink = byId("public-link");
    if (publicLink && pub?.handle) {
      publicLink.href = `#/u/${pub.handle.toLowerCase()}`;
    }

    const { data: priv, error: privErr } = await sb
      .from("profiles_private")
      .select("email, phone, preferred_contact")
      .eq("id", user.id)
      .maybeSingle();

    if (privErr) console.error("private profile error:", privErr);

    writeVal("pr-email", priv?.email || "");
    writeVal("pr-phone", priv?.phone || "");

    // Settings page: privacy + preferred contact
    const settingsPrivacy = byId("settings-privacy");
    if (settingsPrivacy && pub) {
      settingsPrivacy.value = pub.is_private ? "private" : "public";
    }

    const settingsContact = byId("settings-contact");
    if (settingsContact && priv) {
      settingsContact.value = priv.preferred_contact || "email";
    }
  } catch (err) {
    console.error("loadMyProfile error:", err);
  }
}

async function handleSaveProfileClick() {
  try {
    const user = await requireUser();

    const handle = readVal("pp-handle", true);
    const displayName = readVal("pp-display-name");
    const bio = readVal("pp-bio");
    const city = readVal("pp-city");
    const avatarUrl = readVal("pp-avatar-url");
    const email = readVal("pr-email");
    const phone = readVal("pr-phone");

    if (!isValidHandle(handle)) {
      alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
      return;
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
    console.error("Save profile error:", err);
    alert("Save profile error: " + (err?.message || err));
  }
}

async function handleSettingsSaveClick() {
  try {
    const user = await requireUser();

    const privacy = byId("settings-privacy")?.value || "public";
    const contact = byId("settings-contact")?.value || "email";
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

    alert("Settings saved");
  } catch (err) {
    console.error("Settings save error:", err);
    alert("Settings save error: " + (err?.message || err));
  }
}

// ---------- Public profile view + debates ----------
async function showPublicProfileView() {
  try {
    const user = await requireUser();

    const { data: pub, error } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (error) throw error;
    if (!pub) {
      alert("No public profile yet");
      return;
    }

    const avatar = byId("pub-avatar");
    const disp = byId("pub-display-name");
    const handle = byId("pub-handle");
    const city = byId("pub-city");
    const bio = byId("pub-bio");

    if (avatar) avatar.src = pub.avatar_url || "https://via.placeholder.com/80";
    if (disp) disp.textContent = pub.display_name || "Anonymous";
    if (handle) handle.textContent = `@${pub.handle}`;
    if (city) city.textContent = pub.city || "";
    if (bio) bio.textContent = pub.bio || "";

    showSection("public-profile");
  } catch (err) {
    console.error("Show public profile error:", err);
    alert("Could not load public profile: " + (err?.message || err));
  }
}

async function showDebates() {
  try {
    const user = await requireUser();
    const { data: deb, error } = await sb
      .from("debate_pages")
      .select("title, description")
      .eq("id", user.id)
      .maybeSingle();

    if (error) throw error;

    const titleEl = byId("deb-title");
    const descEl = byId("deb-desc");

    if (titleEl) titleEl.textContent = deb?.title || "My Debates";
    if (descEl) descEl.textContent = deb?.description || "Debate topics and positions.";

    showSection("debate-page");
  } catch (err) {
    console.error("Show debates error:", err);
    alert("Could not load debates: " + (err?.message || err));
  }
}

// ---------- Forgot password ----------
async function handleResetPasswordClick() {
  const btn = byId("btn-reset-password");
  if (!btn) return;

  const original = btn.textContent;
  btn.disabled = true;
  btn.textContent = "Sending…";

  try {
    const email = readVal("forgot-email");
    if (!email) {
      alert("Enter your email address");
      return;
    }

    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password.html`,
    });

    if (error) throw error;
    alert("Password reset email sent. Check your inbox and spam folder.");
    showSection("login-section");
  } catch (err) {
    console.error("Reset password error:", err);
    alert("Reset password error: " + (err?.message || err));
  } finally {
    btn.disabled = false;
    btn.textContent = original;
  }
}

// ---------- Attach events & init ----------

function attachEvents() {
  // Auth
  byId("btn-login")?.addEventListener("click", handleLoginClick);
  byId("btn-signup")?.addEventListener("click", handleSignupClick);
  byId("logout-btn")?.addEventListener("click", handleLogoutClick);
  byId("go-signup")?.addEventListener("click", () => showSection("signup-section"));
  byId("go-login")?.addEventListener("click", () => showSection("login-section"));

  // Forgot password
  byId("forgot-password-btn")?.addEventListener("click", () =>
    showSection("forgot-password-section")
  );
  byId("btn-reset-password")?.addEventListener("click", handleResetPasswordClick);
  byId("back-to-login")?.addEventListener("click", () => showSection("login-section"));

  // Profile & settings
  byId("save-profile")?.addEventListener("click", handleSaveProfileClick);
  byId("settings-save")?.addEventListener("click", handleSettingsSaveClick);
  byId("settings-logout")?.addEventListener("click", handleLogoutClick);

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
    loadMyProfile(); // to populate settings fields
    showSection("settings-page");
  });

  // Enter key for login
  byId("login-password")?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleLoginClick();
    }
  });
}

function initApp() {
  console.log("Civic Chatter app starting…");

  if (!window.supabase) {
    console.error("Supabase SDK not found on window");
    alert("Supabase SDK failed to load.");
    return;
  }

  sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  console.log("Supabase client created:", !!sb);

  attachEvents();
  showNav(false);
  showSection("login-section");
  console.log("App initialized.");
}

// DOM ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  initApp();
}
