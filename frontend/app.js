/* ===========================
   Civic Chatter — app.js
   =========================== */

// ------------ Supabase init ------------
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

let sb = null; // Supabase client

// ------------ Helpers ------------
const SECTION_IDS = [
  "login-section",
  "signup-section",
  "private-profile",
  "public-profile",
  "debate-page",
];

function byId(id) {
  return document.getElementById(id) || null;
}

function readValue(id, { lowercase = false } = {}) {
  const el = byId(id);
  const value = (el?.value ?? "").trim();
  return lowercase ? value.toLowerCase() : value;
}

function writeValue(id, value) {
  const el = byId(id);
  if (el && "value" in el) el.value = value ?? "";
}

function showSection(id) {
  SECTION_IDS.forEach((secId) => {
    const el = byId(secId);
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

function setActiveNav(hash) {
  document.querySelectorAll("#nav a.nav-link").forEach((link) => {
    if (!link) return;
    if (link.getAttribute("href") === hash) {
      link.setAttribute("aria-current", "page");
    } else {
      link.removeAttribute("aria-current");
    }
  });
}

function formatError(err) {
  return err?.message || String(err || "Unknown error");
}

function alertActionError(action, err) {
  console.error(`${action} failed:`, err);
  alert(`${action} error: ${formatError(err)}`);
}

async function withBusy(btnId, busyText, fn) {
  const btn = byId(btnId);
  if (!btn) return fn();

  const originalText = btn.textContent;
  const originalDisabled = btn.disabled;

  btn.disabled = true;
  if (busyText) btn.textContent = busyText;

  // Safety: if the operation never completes (network hang, etc.),
  // restore the button after a timeout so UI doesn't remain blocked.
  // This does NOT cancel the operation, it only restores the button state
  // to allow the user to retry or inspect the console.
  let cleared = false;
  const TIMEOUT_MS = 15000; // 15s
  const timeoutId = setTimeout(() => {
    if (!cleared) {
      console.warn(`withBusy(${btnId}): operation timed out after ${TIMEOUT_MS}ms, restoring button state`);
      try {
        btn.disabled = originalDisabled;
        btn.textContent = originalText;
      } catch (e) {
        console.error('withBusy: failed to restore button state after timeout', e);
      }
    }
  }, TIMEOUT_MS);

  try {
    const result = await fn();
    cleared = true;
    clearTimeout(timeoutId);
    btn.disabled = originalDisabled;
    btn.textContent = originalText;
    return result;
  } catch (err) {
    // Ensure we restore UI even on errors
    cleared = true;
    clearTimeout(timeoutId);
    try {
      btn.disabled = originalDisabled;
      btn.textContent = originalText;
    } catch (e) {
      console.error('withBusy: failed to restore button state after error', e);
    }
    throw err;
  }
}

function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
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

  // PGRST116 = no row found
  if (error && error.code !== "PGRST116") throw error;
  if (data && data.id !== allowOwnerId) {
    throw new Error("Handle is already taken");
  }
}

async function createInitialRecords({ userId, handle, name, email, phone, isPrivate, address }) {
  const upsertOrThrow = async (promise, label) => {
    const { error } = await promise;
    if (error) throw new Error(`${label}: ${error.message}`);
  };

  // Public profile
  await upsertOrThrow(
    sb.from("profiles_public").upsert(
      {
        id: userId,
        handle,
        display_name: name,
        bio: null,
        city: null,
        avatar_url: null,
        is_private: isPrivate,
        is_searchable: !isPrivate,
      },
      { onConflict: "id" }
    ),
    "public profile"
  );

  // Private profile
  await upsertOrThrow(
    sb.from("profiles_private").upsert(
      {
        id: userId,
        email,
        phone: phone || null,
        address: address || null,
        preferred_contact: phone ? "sms" : "email",
      },
      { onConflict: "id" }
    ),
    "private profile"
  );

  // Debate page
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
  // If it looks like an email, use it directly
  if (identifier.includes("@")) return identifier;

  // Otherwise, treat as handle → look up email
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

// ------------ Auth actions ------------

async function handleLogin() {
  await withBusy("btn-login", "Signing in…", async () => {
    try {
      console.debug('handleLogin: start');
      const identifier = readValue("login-username");
      const password = readValue("login-password");

      console.debug('handleLogin: got identifier/password?', { identifier: !!identifier, password: !!password });

      if (!identifier || !password) {
        alert("Enter username/email and password");
        return;
      }

      console.debug('handleLogin: resolving email for', identifier);
      const email = await resolveEmailForLogin(identifier);
      console.debug("handleLogin: Resolved login email:", email);

      console.debug('handleLogin: calling sb.auth.signInWithPassword');
      const { data, error } = await sb.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        console.debug('handleLogin: signInWithPassword returned error', error);
        throw error;
      }

      console.debug("handleLogin: Login success:", data);
      showNav();

      console.debug('handleLogin: loading profile');
      await loadMyProfile();
      console.debug('handleLogin: profile loaded, routing to /profile');
      window.location.hash = "#/profile";
    } catch (err) {
      console.error('handleLogin: caught error', err);
      alertActionError("login", err);
    }
  });
}

async function handleSignup() {
  await withBusy("btn-signup", "Creating…", async () => {
    try {
      const name = readValue("signup-name");
      const handle = readValue("signup-handle", { lowercase: true });
      const email = readValue("signup-email");
      const phone = readValue("signup-phone");
      const password = readValue("signup-password");
      const address = readValue("signup-address");
      const isPrivate = !!byId("signup-private")?.checked;

      if (!name) return alert("Enter your name");
      if (!isValidHandle(handle)) {
        return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
      }
      if (!email || !password) {
        return alert("Email & password required");
      }
      if (password.length < 6) {
        return alert("Password must be at least 6 characters long");
      }

      await ensureHandleAvailable(handle);

      const { data: signData, error: signErr } = await sb.auth.signUp({
        email,
        password,
      });

      if (signErr) throw signErr;

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
        address,
      });

      alert("Account created!");
      showNav();
      await loadMyProfile();
      window.location.hash = "#/profile";
    } catch (err) {
      alertActionError("signup", err);
    }
  });
}

async function handleLogout() {
  try {
    const { error } = await sb.auth.signOut();
    if (error) throw error;
    hideNav();
    showSection("login-section");
    window.location.hash = "#/login";
  } catch (err) {
    alertActionError("logout", err);
  }
}

// ------------ Profile loading/saving ------------

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

      const publicLink = byId("public-link");
      if (publicLink && pubRow.handle) {
        publicLink.href = `#/u/${pubRow.handle.toLowerCase()}`;
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
    alertActionError("profile load", err);
  }
}

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
    alertActionError("profile save", err);
  }
}

// ------------ Public profile view ------------

async function showPublicProfileFromHash(handle) {
  try {
    showSection("public-profile");

    if (!handle) {
      byId("pub-display-name").textContent = "Profile not found";
      byId("pub-handle").textContent = "";
      byId("pub-bio").textContent = "";
      byId("pub-city").textContent = "";
      return;
    }

    const { data: row, error } = await sb
      .from("profiles_public")
      .select("display_name, handle, bio, city, avatar_url")
      .eq("handle", handle.toLowerCase())
      .maybeSingle();

    if (error || !row) {
      byId("pub-display-name").textContent = "Profile not found";
      byId("pub-handle").textContent = "";
      byId("pub-bio").textContent = "";
      byId("pub-city").textContent = "";
      return;
    }

    const avatar = byId("pub-avatar");
    if (avatar) {
      avatar.src = row.avatar_url || "https://via.placeholder.com/80";
    }

    byId("pub-display-name").textContent = row.display_name || row.handle;
    byId("pub-handle").textContent = `@${row.handle}`;
    byId("pub-city").textContent = row.city || "";
    byId("pub-bio").textContent = row.bio || "No bio yet.";
  } catch (err) {
    alertActionError("public profile view", err);
  }
}

// ------------ Debates page ------------

async function showDebatePageFromHash(handleOrMe) {
  try {
    showSection("debate-page");

    let handle = handleOrMe;
    if (!handle || handle === "me") {
      const user = await requireUser();
      const { data: pubRow } = await sb
        .from("profiles_public")
        .select("handle")
        .eq("id", user.id)
        .maybeSingle();
      handle = pubRow?.handle;
    }

    if (!handle) {
      byId("deb-title").textContent = "Debates";
      byId("deb-desc").textContent = "No debate page found.";
      byId("deb-content").innerHTML = "";
      return;
    }

    const { data: deb, error } = await sb
      .from("debate_pages")
      .select("title, description, handle")
      .eq("handle", handle.toLowerCase())
      .maybeSingle();

    if (error || !deb) {
      byId("deb-title").textContent = "Debate page not found";
      byId("deb-desc").textContent = "";
      byId("deb-content").innerHTML = "";
      return;
    }

    byId("deb-title").textContent = deb.title || `@${deb.handle} · Debates`;
    byId("deb-desc").textContent =
      deb.description || "Debate topics and positions.";
    byId("deb-content").innerHTML =
      '<p class="hint">Debate threads coming soon.</p>';
  } catch (err) {
    alertActionError("debate page", err);
  }
}

// ------------ Router ------------

async function router() {
  // Keep nav visibility in sync with auth session
  const { data: sessionData } = await sb.auth.getSession();
  const isAuthed = !!sessionData?.session;
  if (isAuthed) showNav();
  else hideNav();

  let hash = window.location.hash;
  if (!hash) {
    window.location.hash = isAuthed ? "#/profile" : "#/login";
    return;
  }

  if (isAuthed && hash === "#/login") {
    window.location.hash = "#/profile";
    return;
  }

  const requiresAuth = hash.startsWith("#/profile") || hash.startsWith("#/d/");
  if (!isAuthed && requiresAuth) {
    window.location.hash = "#/login";
    return;
  }

  setActiveNav(hash);

  if (hash.startsWith("#/signup")) {
    showSection("signup-section");
    return;
  }

  if (hash.startsWith("#/login")) {
    showSection("login-section");
    return;
  }

  if (hash.startsWith("#/profile")) {
    await loadMyProfile();
    showSection("private-profile");
    return;
  }

  if (hash.startsWith("#/u/")) {
    const handle = hash.slice("#/u/".length);
    await showPublicProfileFromHash(handle);
    return;
  }

  if (hash.startsWith("#/d/")) {
    const handleOrMe = hash.slice("#/d/".length);
    await showDebatePageFromHash(handleOrMe);
    return;
  }

  // default route fallback – snap to the appropriate landing page
  window.location.hash = isAuthed ? "#/profile" : "#/login";
  return;
}

// ------------ Wire up event listeners ------------

function attachEventListeners() {
  // Auth buttons
  byId("btn-login")?.addEventListener("click", handleLogin);
  byId("btn-signup")?.addEventListener("click", handleSignup);
  byId("go-signup")?.addEventListener("click", () => {
    window.location.hash = "#/signup";
  });
  byId("go-login")?.addEventListener("click", () => {
    window.location.hash = "#/login";
  });

  // Enter key on login password
  byId("login-password")?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleLogin();
    }
  });

  // Save profile
  byId("save-profile")?.addEventListener("click", handleSaveProfile);

  // Nav + logout
  byId("logout-link")?.addEventListener("click", (e) => {
    e.preventDefault();
    handleLogout();
  });

  byId("nav")?.querySelector('a[href="#/profile"]')?.addEventListener("click", (e) => {
    e.preventDefault();
    window.location.hash = "#/profile";
  });

  byId("nav")?.querySelector('a[href="#/d/me"]')?.addEventListener("click", (e) => {
    e.preventDefault();
    window.location.hash = "#/d/me";
  });

  // Hash routing
  window.addEventListener("hashchange", () => {
    router().catch((err) => console.error("router error", err));
  });
}

// ------------ Init ------------

function initApp() {
  console.log("Civic Chatter init…");

  if (!window.supabase) {
    console.error("Supabase SDK missing (window.supabase is undefined)");
    alert("Supabase SDK failed to load");
    return;
  }

  sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  console.log("Supabase client created:", !!sb);

  // Global handler to surface otherwise-silent promise rejections
  window.addEventListener('unhandledrejection', (ev) => {
    console.error('Unhandled promise rejection:', ev.reason);
    // Show a non-blocking notice for debugging
    const msg = ev.reason?.message || String(ev.reason || 'Unhandled rejection');
    // Keep short and non-annoying — don't alert blindly in production.
    // Uncomment the alert during active debugging if desired.
    // alert(`Unhandled error: ${msg}`);
  });

  attachEventListeners();

  // Initial route
  router().catch((err) => console.error("Initial router error", err));
}

// DOM ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  initApp();
}
