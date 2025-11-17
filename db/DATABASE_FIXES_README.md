# Database and UI Fixes for Civic Chatter

## Issues Fixed

### 1. Database Schema Issues
- ✅ Missing foreign key relationship between `posts` and `profiles_public` tables
- ✅ Missing `username` column in `profiles_public` table

### 2. UI Issues
- ✅ RenderFlex overflow in debates screen

---

## How to Apply the Fixes

### Step 1: Run the Database Migration Script

1. Open your Supabase SQL Editor
2. Run the new migration script: **`db/fix_posts_profiles_relationship.sql`**

This script will:
- Add a foreign key constraint from `posts.user_id` to `profiles_public.id`
  - This allows Supabase PostgREST to automatically join these tables
- Add a `username` column to `profiles_public` that syncs with the `handle` column
  - Fixes the "column profiles_public.username does not exist" error
  - Creates a trigger to keep `username` and `handle` in sync
  - Adds an index for performance

### Step 2: Hot Reload Your Flutter App

After running the SQL script, the app should automatically work correctly. The hot reload has already been triggered.

---

## What Changed

### Database Changes

**New file created:** `db/fix_posts_profiles_relationship.sql`

This comprehensive migration:
1. Adds foreign key: `posts.user_id` → `profiles_public.id`
2. Adds `username` column to match `handle`
3. Creates sync trigger to keep both columns aligned
4. Includes verification queries

### Flutter Code Changes

**Modified:** `flutter_app/lib/screens/debates/debates_screen.dart`
- Wrapped the Column in a `SingleChildScrollView` to fix overflow
- Content can now scroll when screen size is too small

---

## Verification

After running the SQL script, verify with these queries:

```sql
-- Check foreign key relationship
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name, 
  ccu.table_name AS foreign_table_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'posts';

-- Check username column
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'profiles_public'
  AND column_name IN ('handle', 'username');
```

---

## Expected Results

After applying these fixes:

1. ✅ No more "Could not find a relationship between 'posts' and 'profiles'" errors
2. ✅ No more "column profiles_public.username does not exist" errors
3. ✅ No more RenderFlex overflow in the Debates screen
4. ✅ Posts will load with their associated profiles correctly
5. ✅ UI will be scrollable on smaller screens

---

## Notes

- The `username` column is kept in sync with `handle` automatically via a trigger
- You can use either `username` or `handle` in your queries - they contain the same value
- The foreign key enables Supabase to support join queries like:
  ```dart
  .from('posts')
  .select('*, profiles_public!inner(handle, display_name)')
  ```
- Your current code (manual profile fetching) will continue to work as well
