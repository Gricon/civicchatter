-- fix_profiles_public_select.sql
--
-- Add SELECT policy for profiles_public table so that users can view other users' profiles
-- This is needed for reactions "who reacted" feature and other social features

-- Drop existing select policy if it exists
DROP POLICY IF EXISTS "profiles_public_select_all" ON public.profiles_public;

-- Create policy to allow authenticated users to read all public profiles
CREATE POLICY "profiles_public_select_all" ON public.profiles_public
  FOR SELECT
  TO authenticated
  USING (true);

-- Also allow anonymous users to read public profiles (optional - uncomment if needed)
-- DROP POLICY IF EXISTS "profiles_public_select_anon" ON public.profiles_public;
-- CREATE POLICY "profiles_public_select_anon" ON public.profiles_public
--   FOR SELECT
--   TO anon
--   USING (true);
