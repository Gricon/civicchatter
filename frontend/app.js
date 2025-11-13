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
  "settings-page",
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
      // If a DB trigger is installed it will create the public/private
      // profile and debate page automatically. Rely on that instead of
      // making client-side upserts which can be blocked by RLS policies.
      alert("Account created! Please check your email to confirm (if required).\nYou can sign in once your email is confirmed.");
      // Optionally attempt to load profile if the trigger already ran
      try {
        showNav();
        await loadMyProfile();
      } catch (e) {
        console.debug('Profile not yet provisioned by trigger', e);
      }
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
      // Also update nav public profile link when we have the handle
      const navPub = byId('nav-public-profile');
      if (navPub) {
        if (pubRow.handle) navPub.href = `#/u/${pubRow.handle.toLowerCase()}`;
        else navPub.href = '#/u/';
      }
    }

    const { data: privRow } = await sb
      .from("profiles_private")
      .select("email, phone, site_settings")
      .eq("id", user.id)
      .maybeSingle();

    if (privRow) {
      writeValue("pr-email", privRow.email || "");
      writeValue("pr-phone", privRow.phone || "");

      // If the user has site settings stored server-side, apply them and
      // persist locally so they take effect across devices.
      if (privRow.site_settings) {
        try {
          localStorage.setItem('siteSettings', JSON.stringify(privRow.site_settings));
          applySettings(privRow.site_settings);
          // update the settings form inputs if visible
          loadSettingsIntoForm();
        } catch (e) {
          console.warn('Failed to apply site settings from DB', e);
        }
      }
    }
    // Also populate the settings-page profile summary inputs (if present)
    try {
      const spAvatar = byId('sp-avatar');
      const spName = byId('sp-display-name');
      const spHandle = byId('sp-handle');
      const spEmail = byId('sp-email');
      const spAvatarInput = byId('sp-avatar-input');
      const spNameInput = byId('sp-display-name-input');
      const spHandleInput = byId('sp-handle-input');
      const spEmailInput = byId('sp-email-input');
      const spPhoneInput = byId('sp-phone-input');

      if (spAvatar && pubRow?.avatar_url) spAvatar.src = pubRow.avatar_url;
      if (spName) spName.textContent = pubRow?.display_name || pubRow?.handle || '—';
      if (spHandle) spHandle.textContent = pubRow?.handle ? `@${pubRow.handle}` : '';
      if (spEmail) spEmail.textContent = privRow?.email || '';

      if (spAvatarInput) spAvatarInput.value = pubRow?.avatar_url || '';
      if (spNameInput) spNameInput.value = pubRow?.display_name || '';
      if (spHandleInput) spHandleInput.value = pubRow?.handle || '';
      if (spEmailInput) spEmailInput.value = privRow?.email || '';
      if (spPhoneInput) spPhoneInput.value = privRow?.phone || '';
    } catch (e) {
      // non-fatal — not all pages show settings profile
    }
    // populate small header name/avatar for private profile
    try {
      const myNameEl = byId('my-real-name');
      const myHandleEl = byId('my-handle-small');
      const myAvatarSmall = byId('my-avatar-small');
      if (myNameEl) myNameEl.textContent = pubRow?.display_name || pubRow?.handle || 'Your Name';
      if (myHandleEl) myHandleEl.textContent = pubRow?.handle ? `@${pubRow.handle}` : '';
      if (myAvatarSmall) myAvatarSmall.src = pubRow?.avatar_url || 'https://via.placeholder.com/48';
    } catch (e) {}

    // load user's posts into posts-list
    try {
      loadMyPosts();
    } catch (e) {
      console.warn('Failed to load posts', e);
    }
  } catch (err) {
    alertActionError("profile load", err);
  }
}

// Posts: create, upload media, list
async function handleCreatePost() {
  try {
    const user = await requireUser();
    const text = readValue('post-text');
    const link = readValue('post-link');
    const fileEl = byId('post-file');
    const status = byId('post-status');
    if (status) status.textContent = 'Posting…';

    // Preflight: check that posts table exists so we can fail fast with a clear message
    try {
      const { error: tableErr } = await sb.from('posts').select('id').limit(1);
      if (tableErr) {
        console.warn('posts table check error', tableErr);
        if (status) status.textContent = 'Error: posts table not found (run DB migration)';
        throw tableErr;
      }
    } catch (e) {
      // rethrow so outer catch shows a helpful message
      throw e;
    }

    let media_url = null;
    let media_type = null;
    if (fileEl && fileEl.files && fileEl.files[0]) {
      const f = fileEl.files[0];
      // Store full MIME type (e.g. "image/png" or "application/pdf")
      media_type = f.type || null;
      // upload to 'posts' bucket with filename userId/timestamp_originalname
      const { data: userData } = await sb.auth.getUser();
      const userId = userData?.user?.id;
      const filename = `${userId}/${Date.now()}_${f.name}`;
      // use simple storage upload (sdk) which may not provide progress here
      const { error: upErr } = await sb.storage.from('posts').upload(filename, f, { upsert: false });
      if (upErr) {
        console.error('storage upload error', upErr);
        if (status) status.textContent = `Upload failed: ${upErr.message || JSON.stringify(upErr)}`;
        throw upErr;
      }
      const { data } = sb.storage.from('posts').getPublicUrl(filename);
      media_url = (data && (data.publicUrl || data.public_url)) || null;
      if (!media_url) {
        console.warn('getPublicUrl returned no url', data);
      }
    }

    // insert post row (will fail if table not created)
    const insertRow = {
      user_id: user.id,
      content: text || null,
      media_url: media_url,
      media_type: media_type,
      link: link || null,
    };
    const { error: insErr } = await sb.from('posts').insert(insertRow);
    if (insErr) {
      console.error('insert post error', insErr);
      if (status) status.textContent = `Failed to save post: ${insErr.message || JSON.stringify(insErr)}`;
      throw insErr;
    }

    if (status) status.textContent = 'Posted';
    writeValue('post-text', '');
    writeValue('post-link', '');
    if (fileEl) fileEl.value = '';
    // refresh posts
    await loadMyPosts();
  } catch (err) {
    console.error('handleCreatePost failed', err);
    // Show helpful error to the user in the UI
    const statusEl = byId('post-status');
    if (statusEl) {
      statusEl.textContent = err?.message || (err?.error && err.error.message) || 'Failed to create post';
    } else {
      alertActionError('create post', err);
    }
  }
}

async function loadMyPosts() {
  try {
    const { data: userData } = await sb.auth.getUser();
    const user = userData?.user;
    if (!user) return;
    const { data: rows, error } = await sb.from('posts').select('id, content, media_url, media_type, link, created_at').eq('user_id', user.id).order('created_at', { ascending: false }).limit(50);
    if (error) {
      // if posts table doesn't exist, don't bother
      console.debug('loadMyPosts: error', error);
      return;
    }
    const list = byId('posts-list');
    if (!list) return;
    list.innerHTML = '';
    if (!rows || rows.length === 0) {
      list.innerHTML = '<p class="hint">No posts yet.</p>';
      return;
    }
    rows.forEach((r) => {
      const item = document.createElement('div');
      item.className = 'card mt-1';
      const created = new Date(r.created_at).toLocaleString();
      let html = `<div style="display:flex; justify-content:space-between;"><div style="font-weight:600;">${r.content ? escapeHtml(r.content).slice(0,100) : ''}</div><div class="hint">${created}</div></div>`;
      if (r.link) html += `<div><a href="${escapeHtml(r.link)}" target="_blank" rel="noopener">${escapeHtml(r.link)}</a></div>`;
      if (r.media_url) {
        // media_type stores the MIME type (e.g. image/png, video/mp4, application/pdf)
        if (r.media_type && r.media_type.startsWith && r.media_type.startsWith('video/')) {
          html += `<div class="mt-1"><video controls src="${escapeHtml(r.media_url)}" style="max-width:100%;"></video></div>`;
        } else if (r.media_type && r.media_type.startsWith && r.media_type.startsWith('image/')) {
          html += `<div class="mt-1"><img src="${escapeHtml(r.media_url)}" style="max-width:100%;"/></div>`;
        } else if (r.media_type === 'application/pdf') {
          // Embed PDF inline for preview (falls back to browser download if unsupported)
          html += `<div class="mt-1"><embed src="${escapeHtml(r.media_url)}" type="application/pdf" width="100%" height="600px" /></div>`;
        } else {
          // Generic file: show a download link
          const filename = (r.media_url || '').split('/').pop();
          html += `<div class="mt-1"><a href="${escapeHtml(r.media_url)}" target="_blank" rel="noopener">Download ${escapeHtml(filename || 'file')}</a></div>`;
        }
      }
      item.innerHTML = html;
      list.appendChild(item);
    });
  } catch (err) {
    console.warn('loadMyPosts error', err);
  }
}

function escapeHtml(s) {
  if (!s) return '';
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

async function handleSaveSettingsProfile() {
  try {
    const user = await requireUser();
    const handle = readValue('sp-handle-input', { lowercase: true });
    const displayName = readValue('sp-display-name-input');
    const avatarUrl = readValue('sp-avatar-input');
    const email = readValue('sp-email-input');
    const phone = readValue('sp-phone-input');

    if (!isValidHandle(handle)) return alert('Handle must be 3+ chars: a–z, 0–9, _ or -');
    await ensureHandleAvailable(handle, { allowOwnerId: user.id });

    const { error: pubErr } = await sb.from('profiles_public').upsert(
      { id: user.id, handle, display_name: displayName || null, avatar_url: avatarUrl || null },
      { onConflict: 'id' }
    );
    if (pubErr) throw pubErr;

    const { error: privErr } = await sb.from('profiles_private').upsert(
      { id: user.id, email: email || null, phone: phone || null },
      { onConflict: 'id' }
    );
    if (privErr) throw privErr;

    alert('Profile saved');
    // refresh local UI
    await loadMyProfile();
    // hide edit form
    byId('settings-profile-edit')?.classList.add('hidden');
  } catch (err) {
    alertActionError('save profile (settings)', err);
  }
}

async function handleChangePassword() {
  try {
    const newPwd = readValue('security-new-password');
    const confirm = readValue('security-confirm-password');
    if (!newPwd || newPwd.length < 6) return alert('New password must be at least 6 characters');
    if (newPwd !== confirm) return alert('Passwords do not match');

    const { data, error } = await sb.auth.updateUser({ password: newPwd });
    if (error) throw error;
    alert('Password changed successfully');
    // clear inputs
    writeValue('security-new-password', '');
    writeValue('security-confirm-password', '');
  } catch (err) {
    alertActionError('change password', err);
  }
}

// Danger zone helpers
async function handleExportData() {
  try {
    const user = await requireUser();
    // Fetch the user's rows
    const [{ data: pub }, { data: priv }, { data: deb }] = await Promise.all([
      sb.from('profiles_public').select('*').eq('id', user.id).maybeSingle(),
      sb.from('profiles_private').select('*').eq('id', user.id).maybeSingle(),
      sb.from('debate_pages').select('*').eq('id', user.id).maybeSingle(),
    ]);

    const exportObj = {
      exported_at: new Date().toISOString(),
      user_id: user.id,
      profiles_public: pub || null,
      profiles_private: priv || null,
      debate_page: deb || null,
    };

    const blob = new Blob([JSON.stringify(exportObj, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `civicchatter-backup-${user.id}.json`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  } catch (err) {
    alertActionError('export data', err);
  }
}

async function handleDeleteData() {
  try {
    if (!confirm('This will permanently delete your public & private profile and your debate page. This cannot be undone. Are you sure?')) return;
    const user = await requireUser();

    // Delete user's debate page and profiles (best-effort). RLS may block if misconfigured.
    const res1 = await sb.from('debate_pages').delete().eq('id', user.id);
    if (res1.error) throw res1.error;
    const res2 = await sb.from('profiles_public').delete().eq('id', user.id);
    if (res2.error) throw res2.error;
    const res3 = await sb.from('profiles_private').delete().eq('id', user.id);
    if (res3.error) throw res3.error;

    alert('Your data was deleted from the database for this project. You will be signed out.');
    await handleLogout();
  } catch (err) {
    alertActionError('delete data', err);
  }
}

async function handleDeleteAccount() {
  try {
    if (!confirm('Delete your account? This attempts to delete your data and sign you out. It does NOT remove the Auth user record in Supabase (that requires admin credentials). Continue?')) return;
    // First remove user data
    await handleDeleteData();
    // Attempt to sign out (delete of Auth user needs service role)
    try {
      await sb.auth.signOut();
    } catch (e) {
      // ignore
    }
    // Inform the user about final step
    alert('Account data removed locally. To fully remove your Auth account from Supabase the project admin must delete the auth.user record (service_role). Contact the admin if you want complete account removal.');
  } catch (err) {
    alertActionError('delete account', err);
  }
}

// ----- Client-side cartoonize (OpenCV) + upload to Supabase Storage -----
function ensureCvReady() {
  return new Promise((resolve) => {
    if (window.cv && (window.cv.ready || window.cv.onRuntimeInitialized)) return resolve();
    // opencv.js sets onRuntimeInitialized when loaded
    const wait = () => {
      if (window.cv && (window.cv.ready || window.cv.onRuntimeInitialized)) return resolve();
      setTimeout(wait, 100);
    };
    wait();
  });
}

function loadImageFromFile(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = URL.createObjectURL(file);
  });
}

async function cartoonizeFile(file, { maxDim = 800 } = {}) {
  await ensureCvReady();
  const img = await loadImageFromFile(file);

  const w = img.width;
  const h = img.height;
  let scale = 1;
  if (Math.max(w, h) > maxDim) scale = maxDim / Math.max(w, h);
  const cw = Math.round(w * scale);
  const ch = Math.round(h * scale);

  const canvas = document.createElement('canvas');
  canvas.width = cw;
  canvas.height = ch;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0, cw, ch);

  let src = cv.imread(canvas);
  let srcRgb = new cv.Mat();
  cv.cvtColor(src, srcRgb, cv.COLOR_RGBA2RGB);

  // Color smoothing
  let color = new cv.Mat();
  cv.pyrMeanShiftFiltering(srcRgb, color, 20, 40, 1);

  // Edges
  let gray = new cv.Mat();
  cv.cvtColor(srcRgb, gray, cv.COLOR_RGB2GRAY);
  let blurred = new cv.Mat();
  cv.medianBlur(gray, blurred, 7);
  let edges = new cv.Mat();
  cv.adaptiveThreshold(blurred, edges, 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, 9, 2);

  let edgesColor = new cv.Mat();
  cv.cvtColor(edges, edgesColor, cv.COLOR_GRAY2RGB);
  let dst = new cv.Mat();
  cv.bitwise_and(color, edgesColor, dst);

  const outCanvas = document.createElement('canvas');
  outCanvas.width = cw;
  outCanvas.height = ch;
  cv.imshow(outCanvas, dst);

  // cleanup
  src.delete(); srcRgb.delete(); color.delete();
  gray.delete(); blurred.delete(); edges.delete(); edgesColor.delete(); dst.delete();

  return outCanvas.toDataURL('image/png');
}

function dataURLToBlob(dataURL) {
  const parts = dataURL.split(',');
  const mime = parts[0].match(/:(.*?);/)[1];
  const bstr = atob(parts[1]);
  let n = bstr.length;
  const u8arr = new Uint8Array(n);
  while (n--) u8arr[n] = bstr.charCodeAt(n);
  return new Blob([u8arr], { type: mime });
}

async function uploadAvatarBlob(blob, filename) {
  // Upload to Supabase Storage 'avatars' bucket. Bucket must exist and allow uploads by anon role.
  const path = `${filename}`;
  const { error: upErr } = await sb.storage.from('avatars').upload(path, blob, { upsert: true });
  if (upErr) throw upErr;
  const { data } = sb.storage.from('avatars').getPublicUrl(path);
  return data?.publicUrl || null;
}

async function handleCartoonizeAndUploadAvatar() {
  const fileEl = byId('sp-avatar-file');
  const status = byId('sp-cartoon-status');
  const preview = byId('sp-avatar-preview');
  const progressWrap = byId('sp-cartoon-progress');
  const progressBar = byId('sp-cartoon-progress-bar');
  const progressText = byId('sp-cartoon-progress-text');
  if (!fileEl || !fileEl.files || !fileEl.files[0]) return alert('Choose an image file first');
  const file = fileEl.files[0];
  try {
    if (status) { status.textContent = 'Processing…'; }
    if (progressWrap) progressWrap.classList.remove('hidden');
    if (progressBar) progressBar.style.width = '0%';
    if (progressText) progressText.textContent = 'Starting…';
    byId('sp-cartoonize')?.setAttribute('disabled', 'disabled');
    // Use Web Worker cartoonizer if available for responsive processing
    let processedBlob = null;
    if (window.Worker) {
      processedBlob = await new Promise((resolve, reject) => {
        const worker = new Worker('cartoon_worker.js');
        const id = Math.random().toString(36).slice(2);
        worker.postMessage({ id, file, maxDim: 800 });
        worker.onmessage = (ev) => {
          const msg = ev.data || {};
          if (msg.id && msg.id !== id) return;
          if (msg.type === 'progress') {
            const pct = Math.min(80, msg.pct || 0);
            if (progressBar) progressBar.style.width = `${Math.round(pct * 0.8)}%`;
            if (progressText) progressText.textContent = msg.text || '';
          }
          if (msg.type === 'result') {
            resolve(msg.blob);
            worker.terminate();
          }
          if (msg.type === 'error') {
            reject(new Error(msg.message || 'Worker error'));
            worker.terminate();
          }
        };
        worker.onerror = (err) => { reject(err); worker.terminate(); };
      });
    } else {
      // fallback to main-thread OpenCV processing
      const dataUrl = await cartoonizeFile(file, { maxDim: 800 });
      if (preview) { preview.src = dataUrl; preview.style.display = 'block'; }
      processedBlob = dataURLToBlob(dataUrl);
    }

    if (!processedBlob) throw new Error('Processing failed');
    // show preview
    const previewUrl = URL.createObjectURL(processedBlob);
    if (preview) { preview.src = previewUrl; preview.style.display = 'block'; }
    // upload to storage
    const { data: userData } = await sb.auth.getUser();
    const user = userData?.user;
    if (!user) throw new Error('Not signed in');
    const filename = `${user.id}.png`;
    if (progressBar) progressBar.style.width = '90%';
    if (progressText) progressText.textContent = 'Uploading…';
    // Use XHR PUT to storage endpoint so we can get upload progress events
    const publicUrl = await uploadAvatarBlobXHR(processedBlob, filename, (uploadedPct) => {
      // map uploadedPct (0-100) into 90..100 overall range
      const overall = 90 + Math.round(uploadedPct * 0.1);
      if (progressBar) progressBar.style.width = overall + '%';
      if (progressText) progressText.textContent = `Uploading ${uploadedPct}%`;
    });
    if (!publicUrl) throw new Error('Failed to get public URL from storage');
    // set avatar input (so saving profile will persist it too)
    writeValue('sp-avatar-input', publicUrl);
    if (status) status.textContent = 'Uploaded';
    if (progressBar) progressBar.style.width = '100%';
    if (progressText) progressText.textContent = 'Done';
    // auto-save the profile avatar URL (upsert private/public rows as needed)
    // we only update the public profile avatar_url here
    const { error: pubErr } = await sb.from('profiles_public').upsert({ id: user.id, avatar_url: publicUrl }, { onConflict: 'id' });
    if (pubErr) console.warn('Failed to save avatar url to profiles_public:', pubErr);
    // refresh UI
    await loadMyProfile();
  } catch (err) {
    alertActionError('cartoonize upload', err);
    if (status) status.textContent = '';
    if (progressText) progressText.textContent = '';
    if (progressBar) progressBar.style.width = '0%';
    if (progressWrap) progressWrap.classList.add('hidden');
  } finally {
    byId('sp-cartoonize')?.removeAttribute('disabled');
  }
}

// Upload using XHR to allow progress events. Uses Supabase Storage REST endpoint.
async function uploadAvatarBlobXHR(blob, filename, onProgress) {
  return new Promise(async (resolve, reject) => {
    try {
      const bucket = 'avatars';
      const path = encodeURIComponent(filename);
      const url = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/${bucket}/${path}`;

      const xhr = new XMLHttpRequest();
      xhr.open('PUT', url, true);
      // Supabase needs the anon key in Authorization
      xhr.setRequestHeader('Authorization', `Bearer ${SUPABASE_ANON_KEY}`);
      // Optional: tell Supabase to upsert
      xhr.setRequestHeader('x-upsert', 'true');
      xhr.upload.onprogress = function (e) {
        if (e.lengthComputable && typeof onProgress === 'function') {
          const pct = Math.round((e.loaded / e.total) * 100);
          onProgress(pct);
        }
      };
      xhr.onload = function () {
        if (xhr.status >= 200 && xhr.status < 300) {
          // Construct public URL (depends on bucket public settings)
          const publicUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/${bucket}/${path}`;
          resolve(publicUrl);
        } else {
          reject(new Error(`Upload failed: ${xhr.status} ${xhr.statusText} ${xhr.responseText || ''}`));
        }
      };
      xhr.onerror = function (e) { reject(new Error('Network error during upload')); };
      xhr.send(blob);
    } catch (err) { reject(err); }
  });
}

// UI helper: set progress (0-100) and optional text
function setCartoonProgress(pct, text) {
  const wrap = byId('sp-cartoon-progress');
  const bar = byId('sp-cartoon-progress-bar');
  const txt = byId('sp-cartoon-progress-text');
  if (!wrap || !bar) return;
  wrap.classList.remove('hidden');
  bar.style.width = `${pct}%`;
  if (txt) txt.textContent = text || '';
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
      // Render a listing of debate rooms
      const { data: rows, error: rowsErr } = await sb.from('debate_pages').select('id, title, description, handle').order('title', { ascending: true });
      if (rowsErr) throw rowsErr;
      byId('deb-title').textContent = 'Debates';
      byId('deb-desc').textContent = 'Join a live debate room below.';
      const container = byId('deb-content');
      container.innerHTML = '';
      if (!rows || rows.length === 0) {
        container.innerHTML = '<p class="hint">No debates yet.</p>';
        return;
      }
      rows.forEach((d) => {
        const card = document.createElement('div');
        card.className = 'card';
        card.style.display = 'flex';
        card.style.justifyContent = 'space-between';
        card.style.alignItems = 'center';
        card.style.gap = '1rem';
        card.innerHTML = `
          <div>
            <div style="font-weight:600">${escapeHtml(d.title || `@${d.handle}`)}</div>
            <div class="hint">${escapeHtml(d.description || '')}</div>
          </div>
          <div>
            <button class="button--primary debate-join" data-room="${escapeHtml('civicchatter-' + (d.handle || d.title).replace(/[^a-zA-Z0-9_-]/g, ''))}">Join</button>
          </div>
        `;
        container.appendChild(card);
      });
      // bind join buttons
      container.querySelectorAll('.debate-join').forEach((btn) => {
        btn.addEventListener('click', (e) => {
          const room = e.currentTarget?.getAttribute('data-room');
          openDebateRoom(room);
        });
      });
      return;
    }

    const { data: deb, error } = await sb
      .from("debate_pages")
      .select("title, description, handle")
      .eq("handle", handle.toLowerCase())
      .maybeSingle();

      if (error || !deb) return showDebatePageNotFound();

    byId('deb-title').textContent = deb.title || `@${deb.handle} · Debates`;
    byId('deb-desc').textContent =
      deb.description || "Debate topics and positions.";
    // Render a single-room card with Join button
    const roomName = `civicchatter-${(deb.handle || deb.title || 'room').replace(/[^a-zA-Z0-9_-]/g, '')}`;
    byId('deb-content').innerHTML = `
      <div class="card">
        <div style="font-weight:600">${escapeHtml(deb.title || `@${deb.handle} · Debates`)}</div>
        <div class="hint">${escapeHtml(deb.description || '')}</div>
        <div style="margin-top:1rem; text-align:right;"><button class="button--primary" id="deb-join-btn" data-room="${escapeHtml(roomName)}">Join Live Debate</button></div>
      </div>
    `;
    byId('deb-join-btn')?.addEventListener('click', (e) => {
      const room = e.currentTarget?.getAttribute('data-room');
      if (room) openDebateRoom(room, deb.title || deb.handle);
    });

    // Bind join button
    byId('deb-join-btn')?.addEventListener('click', (e) => {
      const room = e.currentTarget?.getAttribute('data-room');
      if (room) openDebateRoom(room, deb.title || deb.handle);
    });
  } catch (err) {
    alertActionError("debate page", err);
  }
}

  function showDebatePageNotFound() {
    byId("deb-title").textContent = "Debate page not found";
    byId("deb-desc").textContent = "";
    byId("deb-content").innerHTML = "";
  }

  function openDebateRoom(roomName, title) {
    try {
      const modal = byId('debate-modal');
      const body = byId('debate-modal-body');
      if (!modal || !body) return;
      // Clear old iframe
      body.innerHTML = '';
      // Build Jitsi Meet iframe URL (public meet.jit.si)
      const url = `https://meet.jit.si/${encodeURIComponent(roomName)}`;
      const iframe = document.createElement('iframe');
      iframe.src = url;
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.frameBorder = '0';
      body.appendChild(iframe);
      modal.classList.remove('hidden');
      // close handler
      byId('debate-modal-close')?.addEventListener('click', closeDebateRoom);
    } catch (e) {
      console.error('openDebateRoom error', e);
      alert('Failed to open live debate room');
    }
  }

  function closeDebateRoom() {
    const modal = byId('debate-modal');
    const body = byId('debate-modal-body');
    if (modal) modal.classList.add('hidden');
    if (body) body.innerHTML = '';
  }

  // Jitsi API integration
  let _jitsiApi = null;
  let _jitsiRoom = null;

  async function loadJitsiAPI() {
    if (window.JitsiMeetExternalAPI) return window.JitsiMeetExternalAPI;
    // Dynamically load the external API script from meet.jit.si
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = 'https://meet.jit.si/external_api.js';
      s.onload = () => resolve(window.JitsiMeetExternalAPI);
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  async function openDebateRoom(roomName, title) {
    try {
      if (!roomName) {
        alert('No room specified');
        return;
      }
      const modal = byId('debate-modal');
      const body = byId('debate-modal-body');
      const titleEl = byId('debate-modal-title');
      const countEl = byId('debate-modal-count');
      const muteBtn = byId('debate-mute-toggle');
      if (!modal || !body) return;
      // Ensure API is loaded
      await loadJitsiAPI();
      // Clear any previous instance
      if (_jitsiApi) {
        try { _jitsiApi.dispose(); } catch (e) { console.warn('dispose previous jitsi', e); }
        _jitsiApi = null;
        _jitsiRoom = null;
      }
      body.innerHTML = '';
      const parent = document.createElement('div');
      parent.style.width = '100%';
      parent.style.height = '100%';
      body.appendChild(parent);

      const domain = 'meet.jit.si';
      const options = {
        roomName: roomName,
        parentNode: parent,
        configOverwrite: { enableWelcomePage: false },
        interfaceConfigOverwrite: { TOOLBAR_BUTTONS: [] },
      };
      _jitsiApi = new window.JitsiMeetExternalAPI(domain, options);
      _jitsiRoom = roomName;
      if (titleEl) titleEl.textContent = title || roomName;
      // participant count
      const updateCount = async () => {
        try {
          const participants = await _jitsiApi.getNumberOfParticipants?.();
          if (countEl) countEl.textContent = `${participants || 1} participant${(participants && participants>1)?'s':''}`;
        } catch (e) { /* ignore */ }
      };
      // initial set a small timeout to allow join
      setTimeout(updateCount, 1500);
      // events
      _jitsiApi.addEventListener('participantJoined', updateCount);
      _jitsiApi.addEventListener('participantLeft', updateCount);
      _jitsiApi.addEventListener('videoConferenceJoined', updateCount);
      _jitsiApi.addEventListener('videoConferenceLeft', () => { closeDebateRoom(); });

      // mute toggle
      if (muteBtn) {
        muteBtn.textContent = 'Mute';
        muteBtn.onclick = async () => {
          try {
            const isMuted = await _jitsiApi.isAudioMuted?.();
            if (isMuted) {
              _jitsiApi.executeCommand('toggleAudio');
              muteBtn.textContent = 'Mute';
            } else {
              _jitsiApi.executeCommand('toggleAudio');
              muteBtn.textContent = 'Unmute';
            }
          } catch (e) { console.warn('mute toggle error', e); }
        };
      }

      modal.classList.remove('hidden');
      // wire close
      byId('debate-modal-close')?.addEventListener('click', closeDebateRoom);
    } catch (e) {
      console.error('openDebateRoom error', e);
      alert('Failed to open live debate room');
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

  const requiresAuth = hash.startsWith("#/profile") || hash.startsWith("#/d/") || hash.startsWith("#/settings");
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

  if (hash.startsWith("#/settings")) {
    // ensure profile + settings are loaded
    await loadMyProfile();
    showSection("settings-page");
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
  byId('post-create')?.addEventListener('click', handleCreatePost);

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

  // Ensure debates nav is wired even if the href selector doesn't match
  byId('nav-debates')?.addEventListener('click', (e) => {
    e.preventDefault();
    window.location.hash = '#/d/me';
  });

  // Hash routing
  window.addEventListener("hashchange", () => {
    router().catch((err) => console.error("router error", err));
  });

  // Settings page handlers
  byId('nav-settings')?.addEventListener('click', (e) => {
    e.preventDefault();
    window.location.hash = '#/settings';
  });
  byId('settings-save')?.addEventListener('click', handleSaveSettings);
  byId('settings-reset')?.addEventListener('click', handleResetSettings);
  // settings profile inline edit handlers
  byId('settings-edit-profile')?.addEventListener('click', (e) => {
    e.preventDefault();
    const form = byId('settings-profile-edit');
    if (!form) return;
    form.classList.toggle('hidden');
  });
  byId('settings-cancel-profile')?.addEventListener('click', (e) => {
    e.preventDefault();
    const form = byId('settings-profile-edit');
    if (form) form.classList.add('hidden');
  });
  byId('settings-save-profile')?.addEventListener('click', (e) => {
    e.preventDefault();
    handleSaveSettingsProfile();
  });
  // avatar cartoonize upload handlers
  byId('sp-avatar-file')?.addEventListener('change', (e) => {
    const img = byId('sp-avatar-preview');
    const file = e.target.files && e.target.files[0];
    if (file && img) {
      img.src = URL.createObjectURL(file);
      img.style.display = 'block';
    }
  });
  byId('sp-cartoonize')?.addEventListener('click', (e) => {
    e.preventDefault();
    handleCartoonizeAndUploadAvatar();
  });
  byId('security-change-password')?.addEventListener('click', (e) => {
    e.preventDefault();
    handleChangePassword();
  });
  byId('security-signout')?.addEventListener('click', (e) => {
    e.preventDefault();
    handleLogout();
  });
  // Danger zone handlers
  byId('danger-export')?.addEventListener('click', (e) => { e.preventDefault(); handleExportData(); });
  byId('danger-delete-data')?.addEventListener('click', (e) => { e.preventDefault(); handleDeleteData(); });
  byId('danger-delete-account')?.addEventListener('click', (e) => { e.preventDefault(); handleDeleteAccount(); });
  // live preview controls
  const fontRange = byId('settings-font-size');
  const fontVal = byId('settings-font-size-val');
  fontRange?.addEventListener('input', (e) => {
    const v = e.target.value;
    if (fontVal) fontVal.textContent = v;
    applySettings({ fontSize: Number(v) });
  });
  byId('settings-writing-mode')?.addEventListener('change', (e) => {
    applySettings({ writingMode: e.target.value });
  });
  byId('settings-font-italic')?.addEventListener('change', (e) => {
    applySettings({ italic: e.target.checked });
  });
  byId('bgtype-color')?.addEventListener('change', toggleBgInputs);
  byId('bgtype-image')?.addEventListener('change', toggleBgInputs);
  byId('settings-bg-color')?.addEventListener('input', (e) => applySettings({ bgColor: e.target.value }));
  byId('settings-bg-image')?.addEventListener('input', (e) => applySettings({ bgImage: e.target.value }));
}

// Settings: apply, load, save
function applySettings(partial = {}) {
  // read existing
  const cur = JSON.parse(localStorage.getItem('siteSettings') || '{}');
  const s = Object.assign({}, cur, partial);
  if (s.fontSize) document.documentElement.style.setProperty('--base-font-size', s.fontSize + 'px');
  if (s.writingMode) document.documentElement.style.setProperty('--site-writing-mode', s.writingMode);
  if (typeof s.italic !== 'undefined') document.documentElement.style.setProperty('--site-font-style', s.italic ? 'italic' : 'normal');
  if (s.bgColor) document.documentElement.style.setProperty('--site-bg-color', s.bgColor);
  if (s.bgImage) document.documentElement.style.setProperty('--site-bg-image', s.bgImage ? 'url(' + s.bgImage + ')' : 'none');
  // update preview if present
  const preview = byId('settings-preview');
  if (preview) {
    preview.style.fontSize = (s.fontSize ? s.fontSize + 'px' : getComputedStyle(document.documentElement).getPropertyValue('--base-font-size'));
    preview.style.fontStyle = s.italic ? 'italic' : 'normal';
  }
  // persist merged
  localStorage.setItem('siteSettings', JSON.stringify(s));
}

function loadSettingsIntoForm() {
  const s = JSON.parse(localStorage.getItem('siteSettings') || '{}');
  if (s.fontSize) {
    const r = byId('settings-font-size');
    const v = byId('settings-font-size-val');
    if (r) r.value = s.fontSize;
    if (v) v.textContent = s.fontSize;
  }
  if (s.writingMode) {
    const w = byId('settings-writing-mode');
    if (w) w.value = s.writingMode;
  }
  if (typeof s.italic !== 'undefined') {
    const i = byId('settings-font-italic');
    if (i) i.checked = s.italic;
  }
  if (s.bgColor) {
    const c = byId('settings-bg-color');
    if (c) c.value = s.bgColor;
  }
  if (s.bgImage) {
    const img = byId('settings-bg-image');
    if (img) img.value = s.bgImage;
  }
  // show/hide inputs
  toggleBgInputs();
  applySettings(s);
}

async function handleSaveSettings(e) {
  e.preventDefault();
  const fontSize = Number(readValue('settings-font-size')) || 16;
  const writingMode = readValue('settings-writing-mode') || 'horizontal-tb';
  const italic = !!byId('settings-font-italic')?.checked;
  const bgColor = readValue('settings-bg-color') || getComputedStyle(document.documentElement).getPropertyValue('--site-bg-color').trim();
  const bgImage = readValue('settings-bg-image');
  const payload = { fontSize, writingMode, italic, bgColor, bgImage };

  // Persist locally first so changes are immediate
  localStorage.setItem('siteSettings', JSON.stringify(payload));
  applySettings(payload);

  // If the user is authenticated, persist to the DB for cross-device sync.
  try {
    const { data: userData } = await sb.auth.getUser();
    const user = userData?.user;
    if (user && user.id) {
      const { error } = await sb.from('profiles_private').upsert(
        { id: user.id, site_settings: payload },
        { onConflict: 'id' }
      );
      if (error) console.warn('Failed to save settings to DB:', error);
    }
  } catch (err) {
    console.warn('Error saving settings to DB (user may be unauthenticated):', err);
  }

  alert('Settings saved (in your browser)');
}

function handleResetSettings(e) {
  e.preventDefault();
  localStorage.removeItem('siteSettings');
  // restore defaults
  document.documentElement.style.removeProperty('--base-font-size');
  document.documentElement.style.removeProperty('--site-writing-mode');
  document.documentElement.style.removeProperty('--site-font-style');
  document.documentElement.style.removeProperty('--site-bg-color');
  document.documentElement.style.removeProperty('--site-bg-image');
  // reset UI
  const r = byId('settings-font-size'); if (r) r.value = 16; const v = byId('settings-font-size-val'); if (v) v.textContent = '16';
  const w = byId('settings-writing-mode'); if (w) w.value = 'horizontal-tb';
  const i = byId('settings-font-italic'); if (i) i.checked = false;
  const c = byId('settings-bg-color'); if (c) c.value = '#f5f5f5';
  const img = byId('settings-bg-image'); if (img) img.value = '';
  toggleBgInputs();
}

function toggleBgInputs() {
  const isImage = !!byId('bgtype-image')?.checked;
  const colorLabel = byId('bg-color-label');
  const imageLabel = byId('bg-image-label');
  if (isImage) {
    if (colorLabel) colorLabel.classList.add('hidden');
    if (imageLabel) imageLabel.classList.remove('hidden');
  } else {
    if (colorLabel) colorLabel.classList.remove('hidden');
    if (imageLabel) imageLabel.classList.add('hidden');
  }
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

  // Apply user settings from localStorage
  try {
    loadSettingsIntoForm();
  } catch (e) {
    console.warn('Failed to load settings into form', e);
  }

  // Initial route
  router().catch((err) => console.error("Initial router error", err));
}

// DOM ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initApp);
} else {
  initApp();
}
