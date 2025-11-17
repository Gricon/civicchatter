-- fix_posts_privacy.sql
-- Fixes RLS policies to properly hide private posts from other users

-- Enable RLS on posts table
ALTER TABLE IF EXISTS public.posts ENABLE ROW LEVEL SECURITY;

-- Drop old policy
DROP POLICY IF EXISTS "posts_select_all" ON public.posts;

-- Create new policy that respects privacy settings
-- Users can see:
-- 1. Their own posts (public or private)
-- 2. Public posts from other users
-- 3. Private posts from other users ONLY if they follow them (future feature)
CREATE POLICY "posts_select_with_privacy" ON public.posts
  FOR SELECT
  TO authenticated
  USING (
    -- User's own posts (can see both public and private)
    auth.uid() = user_id
    OR
    -- Public posts from other users
    is_private = false
  );

-- Keep other policies unchanged
DROP POLICY IF EXISTS "posts_insert_own" ON public.posts;
CREATE POLICY "posts_insert_own" ON public.posts
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "posts_update_own" ON public.posts;
CREATE POLICY "posts_update_own" ON public.posts
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "posts_delete_own" ON public.posts;
CREATE POLICY "posts_delete_own" ON public.posts
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- End of fix_posts_privacy.sql
