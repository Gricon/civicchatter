-- create_posts_table.sql
-- Creates a simple posts table for user posts with optional media and links.
-- Run this in the Supabase SQL editor (requires admin/service role to create tables).

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text,
  media_url text,
  media_type text,
  link text,
  created_at timestamptz not null default now()
);

create index if not exists posts_user_id_idx on public.posts(user_id);
create index if not exists posts_created_idx on public.posts(created_at desc);

-- Note: Consider adding RLS policies to allow users to insert/select their own posts.
