/* ===========================
   Civic Chatter — app.js
   (minimal, noisy version)
   =========================== */

alert("Civic Chatter JS loaded"); // remove later once it's working

// ---- Supabase init ----
const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

if (!window.supabase) {
  alert("Supabase SDK missing (window.supabase is undefined)");
  throw new Error("Supabase SDK missing");
}

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
console.log("Supabase client created:", sb);

// ---- helpers ----
function isValidHandle(h) {
  return /^[a-z0-9_-]{3,}$/.test((h || "").toLowerCase());
}

function showSection(id) {
  const ids = ["login-section", "signup-section", "private-profile", "public-profile", "debate-page"];
  ids.forEach(secId => {
    const el = document.getElementById(secId);
    if (!el) return;
    if (secId === id) el.classList.remove("hidden");
    else el.classList.add("hidden");
  });
}

// simple navigation helpers for buttons
function showSignup() { showSection("signup-section"); }
function showLogin()  { showSection("login-section"); }

// expose globally (used by HTML onclick)
window.showSignup = showSignup;
window.showLogin  = showLogin;

// ---- SIGNUP ----
async function ccSignup() {
  console.log("ccSignup clicked");
  try {
    const name   = document.getElementById("signup-name").value.trim();
    const handle = document.getElementById("signup-handle").value.trim().toLowerCase();
    const email  = document.getElementById("signup-email").value.trim();
    const phone  = document.getElementById("signup-phone").value.trim();
    const passwd = document.getElementById("signup-password").value;
    const addr   = document.getElementById("signup-address").value.trim();
    const isPriv = document.getElementById("signup-private").checked;

    console.log("Signup form data:", { name, handle, email, phone, addr, isPriv });

    if (!name)  return alert("Enter your name");
    if (!isValidHandle(handle)) return alert("Handle must be 3+ chars: a–z, 0–9, _ or -");
    if (!email || !passwd) return alert("Email & password required");

    // check handle availability
    const { data: existing, error: handleErr } = await sb
      .from("profiles_public")
      .select("id")
      .eq("handle", handle)
      .maybeSingle();

    if (handleErr && handleErr.code !== "PGRST116") {
      console.error("Handle check error:", handleErr);
      alert("Error checking handle: " + handleErr.message);
      return;
    }

    if (existing) {
      return alert("Handle is already taken");
    }

    console.log("Calling auth.signUp...");
    const { data: signData, error: signError } = await sb.auth.signUp({
      email,
      password: passwd,
      // if you re-enable confirmations later, you can add:
      // options: { emailRedirectTo: "https://civicchatter.netlify.app/auth-callback.html" },
    });

    console.log("signUp result:", { signData, signError });

    if (signError) {
      alert("Signup error: " + signError.message);
      return;
    }

    // email confirmations OFF → we should have a session now
    const user = signData.user;
    if (!user) {
      alert("Signup succeeded but no user returned. Check Supabase Auth settings.");
      return;
    }

    alert("Auth user created! Now writing profile rows…");
    console.log("New user id:", user.id);

    const userId = user.id;

    // --- Public profile ---
    const { error: pubErr } = await sb.from("profiles_public").upsert(
      {
        id: userId,
        handle,
        display_name: name,
        is_private: isPriv,
        is_searchable: !isPriv
      },
      { onConflict: "id" }
    );
    console.log("profiles_public upsert error:", pubErr);
    if (pubErr) {
      alert("Error creating public profile: " + pubErr.message);
      return;
    }

    // --- Private profile ---
    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: userId,
        email,
        phone: phone || null,
        preferred_contact: phone ? "sms" : "email",
        // NOTE: I'm NOT inserting "address" here in case your table
        // doesn't have that column yet. We can add it later once schema matches.
      },
      { onConflict: "id" }
    );
    console.log("profiles_private upsert error:", privErr);
    if (privErr) {
      alert("Error creating private profile: " + privErr.message);
      return;
    }

    // --- Debate page ---
    const { error: debErr } = await sb.from("debate_pages").upsert(
      {
        id: userId,
        handle,
        title: `${name || handle}'s Debates`,
        description: "Debate topics and positions.",
      },
      { onConflict: "id" }
    );
    console.log("debate_pages upsert error:", debErr);
    if (debErr) {
      alert("Error creating debate page: " + debErr.message);
      return;
    }

    alert("Account and pages created successfully!");
    // Optionally jump to profile:
    showSection("private-profile");
  } catch (err) {
    console.error("ccSignup error:", err);
    alert("Unexpected signup error: " + (err?.message || err));
  }
}
window.ccSignup = ccSignup; // make global

// ---- LOGIN ----
async function ccLogin() {
  console.log("ccLogin clicked");
  try {
    const uname = document.getElementById("login-username").value.trim();
    const passwd = document.getElementById("login-password").value;

    if (!uname || !passwd) {
      return alert("Enter username/email and password");
    }

    let email = null;
    if (uname.includes("@")) {
      email = uname;
    } else {
      // treat uname as handle
      const { data: pubRow, error: pubErr } = await sb
        .from("profiles_public")
        .select("id")
        .eq("handle", uname.toLowerCase())
        .maybeSingle();

      console.log("Lookup handle result:", { pubRow, pubErr });

      if (pubErr) {
        alert("Error looking up handle: " + pubErr.message);
        return;
      }
      if (!pubRow?.id) {
        alert("Handle not found");
        return;
      }

      const { data: privRow, error: privErr } = await sb
        .from("profiles_private")
        .select("email")
        .eq("id", pubRow.id)
        .maybeSingle();

      console.log("Resolve email result:", { privRow, privErr });

      if (privErr) {
        alert("Error resolving email: " + privErr.message);
        return;
      }
      if (!privRow?.email) {
        alert("No email on file for this user");
        return;
      }
      email = privRow.email;
    }

    console.log("Signing in with email:", email);
    const { data, error } = await sb.auth.signInWithPassword({ email, password: passwd });
    console.log("signIn result:", { data, error });

    if (error) {
      alert("Login error: " + error.message);
      return;
    }

    alert("Login OK!");
    showSection("private-profile");
    await loadMyProfile();
  } catch (err) {
    console.error("ccLogin error:", err);
    alert("Unexpected login error: " + (err?.message || err));
  }
}
window.ccLogin = ccLogin;

// ---- LOAD MY PROFILE ----
async function loadMyProfile() {
  try {
    const { data: { user } } = await sb.auth.getUser();
    console.log("loadMyProfile user:", user);
    if (!user) {
      alert("No logged-in user");
      return;
    }

    const { data: pubRow, error: pubErr } = await sb
      .from("profiles_public")
      .select("handle, display_name, bio, city, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    console.log("Public profile row:", { pubRow, pubErr });

    if (!pubErr && pubRow) {
      document.getElementById("pp-handle").value        = pubRow.handle || "";
      document.getElementById("pp-display-name").value  = pubRow.display_name || "";
      document.getElementById("pp-bio").value           = pubRow.bio || "";
      document.getElementById("pp-city").value          = pubRow.city || "";
      document.getElementById("pp-avatar-url").value    = pubRow.avatar_url || "";

      const link = document.getElementById("public-link");
      if (link && pubRow.handle) link.href = `#/u/${pubRow.handle.toLowerCase()}`;
    }

    const { data: privRow, error: privErr } = await sb
      .from("profiles_private")
      .select("email, phone")
      .eq("id", user.id)
      .maybeSingle();

    console.log("Private profile row:", { privRow, privErr });

    if (!privErr && privRow) {
      document.getElementById("pr-email").value = privRow.email || "";
      document.getElementById("pr-phone").value = privRow.phone || "";
    }
  } catch (err) {
    console.error("loadMyProfile error:", err);
  }
}

// ---- SAVE PROFILE (optional; can be expanded later) ----
async function ccSaveProfile() {
  console.log("ccSaveProfile clicked");
  try {
    const { data: { user } } = await sb.auth.getUser();
    if (!user) {
      alert("Not signed in");
      return;
    }

    const handle      = document.getElementById("pp-handle").value.trim().toLowerCase();
    const displayName = document.getElementById("pp-display-name").value.trim();
    const bio         = document.getElementById("pp-bio").value.trim();
    const city        = document.getElementById("pp-city").value.trim();
    const avatarUrl   = document.getElementById("pp-avatar-url").value.trim();
    const email       = document.getElementById("pr-email").value.trim();
    const phone       = document.getElementById("pr-phone").value.trim();

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
    console.log("profiles_public save error:", pubErr);
    if (pubErr) {
      alert("Error saving public profile: " + pubErr.message);
      return;
    }

    const { error: privErr } = await sb.from("profiles_private").upsert(
      {
        id: user.id,
        email: email || null,
        phone: phone || null,
      },
      { onConflict: "id" }
    );
    console.log("profiles_private save error:", privErr);
    if (privErr) {
      alert("Error saving private profile: " + privErr.message);
      return;
    }

    alert("Profile saved");
  } catch (err) {
    console.error("ccSaveProfile error:", err);
    alert("Unexpected save error: " + (err?.message || err));
  }
}
window.ccSaveProfile = ccSaveProfile;

// ---- Initial view ----
showSection("login-section");
console.log("App JS fully loaded");
