# Reactions Table Setup Instructions

## Overview
The reaction system allows users to react to posts with 6 different emoji reactions:
- 👍 Like
- ❤️ Love
- 😂 Laugh
- 😮 Wow
- 😢 Sad
- 😠 Angry

## Database Setup

1. **Go to your Supabase project dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your CivicChatter project

2. **Open the SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New query"

3. **Run the SQL migration**
   - Copy the contents of `create_reactions_table.sql`
   - Paste into the SQL editor
   - Click "Run" to execute

4. **Verify the table was created**
   - Go to "Table Editor" in the left sidebar
   - You should see a new `reactions` table with columns:
     - id (UUID)
     - post_id (UUID, references posts)
     - user_id (UUID, references auth.users)
     - reaction_type (TEXT)
     - created_at (TIMESTAMPTZ)

## Features

### In the Home Feed
- Each post displays 6 reaction buttons below the content
- Reaction buttons show emoji + count
- Your selected reaction is highlighted
- Click to add/change/remove reactions
- Reactions update in real-time

### In Post Detail View
- Same reaction bar appears below the post content
- Reactions are loaded when viewing the post
- All reaction changes are synced with the database

### Security (RLS Policies)
- ✅ Users can view reactions on public posts
- ✅ Users can view reactions on their own posts
- ✅ Users can view reactions on private posts they have access to
- ✅ Authenticated users can add reactions
- ✅ Users can only delete/update their own reactions
- ✅ One reaction per user per post (enforced by unique constraint)

## Usage

1. **React to a post**: Click any reaction emoji button
2. **Change reaction**: Click a different emoji button
3. **Remove reaction**: Click the same emoji button again
4. **View reaction counts**: Numbers appear next to emojis when reactions exist

## Testing

After running the SQL migration:
1. Refresh your web app
2. Create or view a post
3. Try clicking the reaction buttons
4. Open the post detail view to see reactions there too
5. Reactions should persist and sync across views

## Troubleshooting

If reactions don't appear or errors occur:
1. Check browser console for errors
2. Verify the `reactions` table exists in Supabase
3. Check RLS policies are enabled
4. Ensure you're logged in (reactions require authentication)
5. Try refreshing the page

## Next Steps

Future enhancements could include:
- Reaction notifications
- Filtering posts by most reacted
- Reaction analytics
- Custom reactions
- Reaction animations
