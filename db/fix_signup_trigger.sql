-- fix_signup_trigger.sql
-- This fixes the signup issue by recreating the auth trigger properly

-- First, make sure the tables exist with correct schema
CREATE TABLE IF NOT EXISTS public.profiles_public (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    handle TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    city TEXT,
    avatar_url TEXT,
    is_private BOOLEAN DEFAULT false,
    is_searchable BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.profiles_private (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    preferred_contact TEXT DEFAULT 'email',
    site_settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.debate_pages (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    handle TEXT,
    title TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on tables
ALTER TABLE public.profiles_public ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debate_pages ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.profiles_public TO postgres, service_role;
GRANT ALL ON public.profiles_private TO postgres, service_role;
GRANT ALL ON public.debate_pages TO postgres, service_role;

-- Recreate the trigger function with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  u_email TEXT := new.email;
  display_name TEXT := NULL;
  handle_base TEXT;
  new_handle TEXT;
  suffix INT := 0;
  user_phone TEXT;
  user_address TEXT;
  user_is_private BOOLEAN;
BEGIN
  -- Get display name and other data from metadata
  BEGIN
    display_name := (new.raw_user_meta_data->>'full_name')::TEXT;
    user_phone := (new.raw_user_meta_data->>'phone')::TEXT;
    user_address := (new.raw_user_meta_data->>'address')::TEXT;
    user_is_private := COALESCE((new.raw_user_meta_data->>'is_private')::BOOLEAN, false);
  EXCEPTION WHEN OTHERS THEN
    display_name := NULL;
    user_phone := NULL;
    user_address := NULL;
    user_is_private := false;
  END;

  -- Build handle base
  IF display_name IS NOT NULL AND LENGTH(TRIM(display_name)) > 0 THEN
    handle_base := LOWER(REGEXP_REPLACE(display_name, '[^a-z0-9_-]', '', 'g'));
  ELSIF u_email IS NOT NULL THEN
    handle_base := LOWER(REGEXP_REPLACE(SPLIT_PART(u_email, '@', 1), '[^a-z0-9_-]', '', 'g'));
  ELSE
    handle_base := 'user';
  END IF;

  IF handle_base = '' THEN
    handle_base := 'user';
  END IF;

  -- Ensure handle uniqueness
  new_handle := handle_base;
  WHILE EXISTS (SELECT 1 FROM public.profiles_public WHERE handle = new_handle) LOOP
    suffix := suffix + 1;
    new_handle := handle_base || '_' || suffix;
  END LOOP;

  -- Insert public profile
  BEGIN
    INSERT INTO public.profiles_public (
      id, handle, display_name, bio, city, avatar_url, is_private, is_searchable
    ) VALUES (
      new.id, 
      new_handle, 
      COALESCE(display_name, new.email), 
      NULL, 
      NULL, 
      NULL, 
      user_is_private,
      NOT user_is_private
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to insert profiles_public: %', SQLERRM;
  END;

  -- Insert private profile
  BEGIN
    INSERT INTO public.profiles_private (
      id, email, phone, address, preferred_contact, site_settings
    ) VALUES (
      new.id, 
      new.email, 
      user_phone,
      user_address,
      CASE WHEN user_phone IS NOT NULL THEN 'sms' ELSE 'email' END,
      '{}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to insert profiles_private: %', SQLERRM;
  END;

  -- Insert debate page
  BEGIN
    INSERT INTO public.debate_pages (
      id, handle, title, description
    ) VALUES (
      new.id, 
      new_handle, 
      COALESCE(display_name, new_handle) || '''s Debates', 
      'Debate topics and positions.'
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to insert debate_pages: %', SQLERRM;
  END;

  RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS auth_user_created ON auth.users;
CREATE TRIGGER auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

-- Create RLS policies that allow the trigger to work
DROP POLICY IF EXISTS "Users can read own public profile" ON public.profiles_public;
CREATE POLICY "Users can read own public profile" 
  ON public.profiles_public FOR SELECT 
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Service role can insert public profiles" ON public.profiles_public;
CREATE POLICY "Service role can insert public profiles" 
  ON public.profiles_public FOR INSERT 
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can read own private profile" ON public.profiles_private;
CREATE POLICY "Users can read own private profile" 
  ON public.profiles_private FOR SELECT 
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Service role can insert private profiles" ON public.profiles_private;
CREATE POLICY "Service role can insert private profiles" 
  ON public.profiles_private FOR INSERT 
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can read own debate page" ON public.debate_pages;
CREATE POLICY "Users can read own debate page" 
  ON public.debate_pages FOR SELECT 
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Service role can insert debate pages" ON public.debate_pages;
CREATE POLICY "Service role can insert debate pages" 
  ON public.debate_pages FOR INSERT 
  WITH CHECK (true);

-- End of fix_signup_trigger.sql
