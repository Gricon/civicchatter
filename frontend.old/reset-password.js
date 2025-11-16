/* ===========================
   Reset Password Page Logic
   =========================== */

const SUPABASE_URL = "https://uoehxenaabrmuqzhxjdi.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZWh4ZW5hYWJybXVxemh4amRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDgwOTAsImV4cCI6MjA3NzgyNDA5MH0._-2yNMgwTjfZ_yBupor_DMrOmYx_vqiS_aWYICA0GjU";

let sb;

function showStatus(message, isError = false) {
  const statusEl = document.getElementById("status-message");
  statusEl.textContent = message;
  statusEl.style.display = "block";
  statusEl.style.color = isError ? "#bf0a30" : "#002868";
}

function hideStatus() {
  const statusEl = document.getElementById("status-message");
  statusEl.style.display = "none";
}

async function updatePassword() {
  try {
    hideStatus();

    const newPassword = document.getElementById("new-password").value.trim();
    const confirmPassword = document.getElementById("confirm-password").value.trim();

    // Validation
    if (!newPassword || !confirmPassword) {
      return showStatus("Please enter and confirm your new password", true);
    }

    if (newPassword.length < 6) {
      return showStatus("Password must be at least 6 characters long", true);
    }

    if (newPassword !== confirmPassword) {
      return showStatus("Passwords do not match", true);
    }

    // Check if user is authenticated
    const { data: sessionData } = await sb.auth.getSession();
    if (!sessionData?.session) {
      return showStatus("Session expired. Please request a new password reset link.", true);
    }

    // Update the password
    showStatus("Updating password...");
    const { error } = await sb.auth.updateUser({
      password: newPassword,
    });

    if (error) throw error;

    showStatus("Password updated successfully! Redirecting to login...");
    
    // Clear inputs
    document.getElementById("new-password").value = "";
    document.getElementById("confirm-password").value = "";

    // Sign out and redirect
    setTimeout(async () => {
      await sb.auth.signOut();
      window.location.href = "/";
    }, 2000);

  } catch (error) {
    console.error("Password update error:", error);
    showStatus(`Error: ${error.message}`, true);
  }
}

function cancel() {
  if (confirm("Cancel password reset and return to login?")) {
    window.location.href = "/";
  }
}

async function initResetPage() {
  if (!window.supabase) {
    showStatus("Error: Supabase SDK not loaded. Please refresh the page.", true);
    return;
  }

  sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Verify user is authenticated (from the email link)
  const { data: sessionData } = await sb.auth.getSession();
  if (!sessionData?.session) {
    showStatus("No active session. Please click the reset link from your email again.", true);
    setTimeout(() => {
      window.location.href = "/";
    }, 3000);
    return;
  }

  // Attach event listeners
  document.getElementById("btn-update-password").addEventListener("click", updatePassword);
  document.getElementById("btn-cancel").addEventListener("click", cancel);

  // Allow Enter key to submit
  const inputs = document.querySelectorAll("input[type='password']");
  inputs.forEach(input => {
    input.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        updatePassword();
      }
    });
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => {
    setTimeout(initResetPage, 100);
  });
} else {
  setTimeout(initResetPage, 100);
}