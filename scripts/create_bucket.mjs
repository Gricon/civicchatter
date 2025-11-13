import { createClient } from '@supabase/supabase-js';

// Usage:
// SUPABASE_URL=https://<PROJECT_REF>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY> node scripts/create_bucket.mjs

async function main() {
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your environment.');
    process.exit(1);
  }
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  // Attempt to create the 'avatars' bucket as public so avatars are directly
  // addressable by the client. Change { public: false } to keep it private.
  const { data, error } = await supabase.storage.createBucket('avatars', { public: true });
  if (error) {
    console.error('Failed to create bucket:', error);
    process.exit(1);
  }
  console.log('Bucket created:', data);
}

main().catch((e) => { console.error(e); process.exit(1); });
