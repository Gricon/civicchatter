/* ===========================
   Auth Callback Handler
   For email verification & password resets
   =========================== */

const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

async function handleAuthCallback() {
  const msgEl = document.getElementById("msg");
  
  if (!window.supabase) {
    msgEl.textContent = "Error: Supabase SDK not loaded. Please refresh the page.";
    return;
  }

  const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  try {
    // Check URL for hash params (from email link)
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const type = hashParams.get("type");
    const accessToken = hashParams.get("access_token");
    const refreshToken = hashParams.get("refresh_token");

    if (!type) {
      msgEl.textContent = "No authentication type found in URL. Redirecting...";
      setTimeout(() => {
        window.location.href = "/";
      }, 2000);
      return;
    }

    // Handle different auth types
    if (type === "recovery") {
      // Password reset flow
      msgEl.textContent = "Email verified! Setting up password reset...";
      
      if (accessToken) {
        // Set the session with the tokens from the URL
        const { error: sessionError } = await sb.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });

        if (sessionError) throw sessionError;

        msgEl.textContent = "Verified! Redirecting to password reset page...";
        setTimeout(() => {
          window.location.href = "/reset-password.html";
        }, 1500);
      } else {
        throw new Error("No access token found");
      }
    } else if (type === "signup" || type === "email") {
      // Email confirmation flow
      msgEl.textContent = "Email verified successfully!";
      
      if (accessToken) {
        const { error: sessionError } = await sb.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });

        if (sessionError) throw sessionError;
      }

      msgEl.textContent = "Success! Redirecting to your profile...";
      setTimeout(() => {
        window.location.href = "/";
      }, 1500);
    } else {
      msgEl.textContent = `Unknown authentication type: ${type}. Redirecting...`;
      setTimeout(() => {
        window.location.href = "/";
      }, 2000);
    }
  } catch (error) {
    console.error("Auth callback error:", error);
    msgEl.textContent = `Error: ${error.message}\n\nRedirecting to home page...`;
    setTimeout(() => {
      window.location.href = "/";
    }, 3000);
  }
}

// Wait for Supabase SDK to load, then run
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => {
    // Give SDK a moment to initialize
    setTimeout(handleAuthCallback, 100);
  });
} else {
  setTimeout(handleAuthCallback, 100);
}