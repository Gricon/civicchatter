// auth-callback.js
// Handles Supabase email confirmation / magic link / PKCE redirect

const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

// Where to send the user after confirming
const REDIRECT_AFTER = "/#/profile";
const REDIRECT_FALLBACK = "/#/login";

function setMsg(text) {
  const el = document.getElementById("msg");
  if (el) el.textContent = text;
}

async function runAuthCallback() {
  try {
    if (!window.supabase) {
      setMsg("Supabase SDK not loaded.");
      // Let CSP errors surface in console if something else is wrong
      return;
    }

    const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const url = new URL(window.location.href);

    // Support both hash (#access_token=...) and query (?code=...) formats
    const hash = url.hash.startsWith("#") ? url.hash.slice(1) : "";
    const h = new URLSearchParams(hash);
    const q = url.searchParams;

    const access_token = h.get("access_token");
    const refresh_token = h.get("refresh_token");
    const code = q.get("code"); // PKCE code

    // Case A: magic-link tokens in hash
    if (access_token && refresh_token) {
      setMsg("Setting session from magic link…");
      await sb.auth.setSession({ access_token, refresh_token });
      window.location.replace(REDIRECT_AFTER);
      return;
    }

    // Case B: PKCE (authorization code in query string)
    if (code) {
      setMsg("Exchanging authorization code…");
      await sb.auth.exchangeCodeForSession({ authCode: code });
      window.location.replace(REDIRECT_AFTER);
      return;
    }

    // Case C: maybe session is already set
    const { data: { session } } = await sb.auth.getSession();
    window.location.replace(session ? REDIRECT_AFTER : REDIRECT_FALLBACK);
  } catch (err) {
    console.error("auth-callback error:", err);
    setMsg("Error completing sign-in: " + (err?.message || err));
    setTimeout(() => window.location.replace(REDIRECT_FALLBACK), 1500);
  }
}

// Run when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", runAuthCallback);
} else {
  runAuthCallback();
}
