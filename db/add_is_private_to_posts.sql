-- add_is_private_to_posts.sql
-- Adds is_private column to the posts table to track public vs private posts
-- Run this in the Supabase SQL editor

-- Add is_private column with default value of false (public posts)
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS is_private boolean NOT NULL DEFAULT false;

-- Create an index on is_private for better query performance
CREATE INDEX IF NOT EXISTS posts_is_private_idx ON public.posts(is_private);

-- Add comment to document the column
COMMENT ON COLUMN public.posts.is_private IS 'Indicates whether the post is private (true) or public (false). Public posts are visible to all users, while private posts are only visible to the author.';

-- Verify the column was added
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'posts'
  AND column_name = 'is_private';
