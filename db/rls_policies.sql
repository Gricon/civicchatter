-- rls_policies.sql
--
-- Recommended Row-Level Security (RLS) policies for profile & debate tables.
-- Run these in the Supabase SQL editor (they require admin/service_role privileges
-- to create policies and enable RLS). These policies allow authenticated users
-- to insert/update/delete their own rows (where auth.uid() = id) but not others'.

-- Enable RLS on the tables (no-op if already enabled)
alter table if exists public.profiles_public enable row level security;
alter table if exists public.profiles_private enable row level security;
alter table if exists public.debate_pages enable row level security;

drop policy if exists "profiles_public_insert_own" on public.profiles_public;
create policy "profiles_public_insert_own" on public.profiles_public
  for insert
  to authenticated
  -- allow insert when the user is the owner OR when the DB role is postgres
  with check (auth.uid() = id OR current_user = 'postgres');

-- Allow updates and deletes only for the owner
drop policy if exists "profiles_public_update_own" on public.profiles_public;
create policy "profiles_public_update_own" on public.profiles_public
  for update
  to authenticated
  using (auth.uid() = id OR current_user = 'postgres')
  with check (auth.uid() = id OR current_user = 'postgres');

drop policy if exists "profiles_public_delete_own" on public.profiles_public;
create policy "profiles_public_delete_own" on public.profiles_public
  for delete
  to authenticated
  using (auth.uid() = id OR current_user = 'postgres');

-- Profiles private: allow users to insert/update their own private profile
drop policy if exists "profiles_private_insert_own" on public.profiles_private;
create policy "profiles_private_insert_own" on public.profiles_private
  for insert
  to authenticated
  with check (auth.uid() = id OR current_user = 'postgres');

drop policy if exists "profiles_private_update_own" on public.profiles_private;
create policy "profiles_private_update_own" on public.profiles_private
  for update
  to authenticated
  using (auth.uid() = id OR current_user = 'postgres')
  with check (auth.uid() = id OR current_user = 'postgres');

drop policy if exists "profiles_private_delete_own" on public.profiles_private;
create policy "profiles_private_delete_own" on public.profiles_private
  for delete
  to authenticated
  using (auth.uid() = id OR current_user = 'postgres');

-- Debate pages: same pattern
drop policy if exists "debate_pages_insert_own" on public.debate_pages;
create policy "debate_pages_insert_own" on public.debate_pages
  for insert
  to authenticated
  with check (auth.uid() = id OR current_user = 'postgres');

drop policy if exists "debate_pages_update_own" on public.debate_pages;
create policy "debate_pages_update_own" on public.debate_pages
  for update
  to authenticated
  using (auth.uid() = id OR current_user = 'postgres')
  with check (auth.uid() = id OR current_user = 'postgres');

drop policy if exists "debate_pages_delete_own" on public.debate_pages;
create policy "debate_pages_delete_own" on public.debate_pages
  for delete
  to authenticated
  using (auth.uid() = id OR current_user = 'postgres');

-- Notes:
-- 1) These policies assume your client uses the anon/public key and the
--    authenticated role is mapped to logged-in users (default Supabase setup).
-- 2) If you need server-side services to modify these tables, keep using
--    service_role credentials server-side or create additional policies for
--    a trusted role.
-- 3) If your tables have other constraints (unique handle), ensure your
--    client checks for collisions before attempting to insert.

-- End of rls_policies.sql
