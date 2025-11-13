Database migration helpers

This folder contains SQL scripts to ensure every Auth user has the three
records you expect: a public profile (`profiles_public`), a private
profile (`profiles_private`), and a debate page (`debate_pages`).

Files
- create_auth_trigger.sql
  Creates a Postgres function and trigger on `auth.users` that inserts
  one row into each of the three tables whenever a new auth user is
  created. Run this once in the Supabase SQL editor.

- backfill_profiles.sql
  Inserts missing profiles and debate pages for existing users. Safe to
  run multiple times; checks for existing rows before inserting.

How to apply (Supabase SQL editor)
1. Open your Supabase project.
2. Go to "SQL Editor" → New query.
3. Paste the contents of `create_auth_trigger.sql` and run it. You should
   see confirmation that the function and trigger were created.
4. Optionally, run `backfill_profiles.sql` to populate existing users.

Notes and considerations
- The trigger generates a simple handle based on display name or email
  localpart. It strips characters not in `[a-z0-9_-]` and appends a small
  suffix if needed to keep handles unique. Adjust this logic to match
  your desired handle policy.

- The trigger is marked `security definer` so it can run with the
  privileges of the SQL user that created it. Create it from the
  Supabase SQL editor (which runs as an admin/service role) so it has
  the required permissions.

- If you already have some users with public profiles but missing
  private profiles (or vice versa), run `backfill_profiles.sql` to add
  missing rows.

- Keep your client-side `handleSignup` behavior as-is (its useful for
  immediate feedback), but the DB trigger guarantees profiles are
  created even for signups that occur outside your client (dashboard,
  CLI, or external auth provider callbacks).

Security/Permissions
- Creating triggers on `auth.users` requires admin/service_role access.
- Do not commit or expose your Supabase service_role key in code or
  public repositories.

If you'd like, I can also:
- Change the handle generation schema (more friendly names or UID-based).
- Add an HTTP endpoint (or Supabase Function) to repair/normalize handles.
- Add a small migration to add missing unique indexes or constraints.

Tell me which option you prefer and I can apply follow-up changes or
walk you through running these scripts in your Supabase project.