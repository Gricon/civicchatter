-- fix_posts_profiles_relationship.sql
-- Adds foreign key relationship between posts and profiles_public tables
-- Also adds username column as an alias for handle to fix compatibility issues
-- Run this in the Supabase SQL editor

-- Step 1: Add foreign key relationship from posts to profiles_public
-- First, let's make sure the posts table references profiles_public instead of just auth.users
-- We need to drop the existing foreign key and add a new one

-- Check if there are any posts with user_ids that don't have profiles
-- This query will help identify orphaned records
DO $$
BEGIN
  -- Check for orphaned posts
  IF EXISTS (
    SELECT 1 FROM public.posts p
    LEFT JOIN public.profiles_public pp ON p.user_id = pp.id
    WHERE pp.id IS NULL
  ) THEN
    RAISE NOTICE 'Warning: Some posts have user_ids without corresponding profiles. Consider running backfill_profiles.sql first.';
  END IF;
END $$;

-- Add foreign key constraint from posts to profiles_public
-- This creates the relationship that Supabase PostgREST can use for joins
ALTER TABLE public.posts
DROP CONSTRAINT IF EXISTS posts_user_id_fkey;

ALTER TABLE public.posts
ADD CONSTRAINT posts_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES public.profiles_public(id) 
ON DELETE CASCADE;

-- Step 2: Add username column to profiles_public as an alias/copy of handle
-- This fixes the "column profiles_public.username does not exist" error
-- We'll add it as a generated column that always matches handle

-- First check if username column already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles_public' 
    AND column_name = 'username'
  ) THEN
    -- Add username column as a copy of handle (for backwards compatibility)
    ALTER TABLE public.profiles_public ADD COLUMN username text;
    
    -- Create an index on username for performance
    CREATE INDEX IF NOT EXISTS profiles_public_username_idx ON public.profiles_public(username);
    
    -- Update existing rows to copy handle to username
    UPDATE public.profiles_public SET username = handle WHERE username IS NULL;
    
    -- Create a trigger to keep username in sync with handle
    CREATE OR REPLACE FUNCTION sync_username_with_handle()
    RETURNS TRIGGER AS $func$
    BEGIN
      NEW.username := NEW.handle;
      RETURN NEW;
    END;
    $func$ LANGUAGE plpgsql;
    
    DROP TRIGGER IF EXISTS sync_username_trigger ON public.profiles_public;
    CREATE TRIGGER sync_username_trigger
      BEFORE INSERT OR UPDATE OF handle ON public.profiles_public
      FOR EACH ROW
      EXECUTE FUNCTION sync_username_with_handle();
      
    RAISE NOTICE 'Added username column and sync trigger to profiles_public table';
  ELSE
    RAISE NOTICE 'username column already exists in profiles_public table';
  END IF;
END $$;

-- Step 3: Verify the changes
-- Check that foreign key exists
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name, 
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'posts'
  AND tc.table_schema = 'public';

-- Check that username column exists
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'profiles_public'
  AND column_name IN ('handle', 'username');

-- End of fix_posts_profiles_relationship.sql
