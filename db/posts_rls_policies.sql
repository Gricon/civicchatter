-- posts_rls_policies.sql
-- RLS policies for the posts table
-- Run this in the Supabase SQL editor

-- Enable RLS on posts table
alter table if exists public.posts enable row level security;

-- Allow authenticated users to insert their own posts
drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Allow everyone to read all posts (for now - you can restrict this later)
drop policy if exists "posts_select_all" on public.posts;
create policy "posts_select_all" on public.posts
  for select
  to authenticated
  using (true);

-- Allow users to update their own posts
drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own" on public.posts
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Allow users to delete their own posts
drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts
  for delete
  to authenticated
  using (auth.uid() = user_id);
