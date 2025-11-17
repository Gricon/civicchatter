# Database Setup Instructions for Civic Chatter

This guide explains how to properly set up your Supabase database for the Civic Chatter application.

## Required SQL Scripts (Run in Order)

Open your Supabase SQL Editor and run these scripts in the following order:

### 1. Create Posts Table
Run: `create_posts_table.sql`
- Creates the `posts` table for storing user posts
- Includes fields: id, user_id, content, media_url, media_type, created_at

### 2. Enable RLS on Posts
Run: `posts_rls_policies.sql`
- Enables Row Level Security on the posts table
- Allows users to insert their own posts
- Allows everyone to read all posts
- Allows users to update/delete only their own posts

### 3. Create Auth Trigger
Run: `create_auth_trigger.sql`
- Creates a trigger that automatically creates profiles when a new user signs up
- Creates entries in: `profiles_public`, `profiles_private`, and `debate_pages`
- Generates unique handles based on user's name or email

### 4. Backfill Existing Users (if needed)
Run: `backfill_profiles.sql`
- Creates profiles for any existing users who don't have them yet
- Only needed if you have users who signed up before the trigger was created

### 5. Enable Profile RLS
Run: `rls_policies.sql`
- Enables Row Level Security on profile tables
- Allows users to manage their own profiles

## Verify Setup

After running all scripts, verify:

1. **Check if trigger exists:**
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'auth_user_created';
   ```

2. **Check if profiles exist for your users:**
   ```sql
   SELECT u.id, u.email, p.handle, p.display_name 
   FROM auth.users u
   LEFT JOIN public.profiles_public p ON p.id = u.id;
   ```

3. **Check RLS policies:**
   ```sql
   SELECT tablename, policyname FROM pg_policies 
   WHERE schemaname = 'public' AND tablename IN ('posts', 'profiles_public');
   ```

## Troubleshooting

### "Unknown User" showing in posts
- Run `backfill_profiles.sql` to create profiles for existing users
- Verify the auth trigger is working for new signups

### Posts not saving
- Run `posts_rls_policies.sql` to enable RLS policies
- Check that users are authenticated when posting

### Profile not loading
- The app uses the `handle` field (not `username`) from `profiles_public` table
- Check if the profile exists: `SELECT * FROM profiles_public WHERE id = 'user-id-here';`

## Database Schema Overview

- **auth.users** - Supabase authentication users
- **profiles_public** - Public user profile info (handle, display_name, bio, etc.)
- **profiles_private** - Private user info (email, phone, address)
- **posts** - User posts (content, media_url, media_type)
- **debate_pages** - User debate pages

All tables should have RLS enabled with appropriate policies.
