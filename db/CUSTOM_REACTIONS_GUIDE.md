# Custom Reactions Setup Guide

## Overview
Users can now create their own custom emoji reactions in addition to the 6 standard reactions! 🎉

### Standard Reactions:
- 👍 Like
- ❤️ Love
- 😂 Laugh
- 😮 Wow
- 😢 Sad
- 😠 Angry

### Custom Reactions:
- **Any emoji you want!** 🔥 💯 🚀 ✨ 🎯 💪 and more!

## Database Migration Required

Before the custom reactions feature will work, you need to update your database:

### Step 1: Run the SQL Migration

1. Go to your Supabase dashboard: https://supabase.com/dashboard
2. Open the SQL Editor
3. Copy and paste the contents of `add_custom_reactions.sql`
4. Click "Run" to execute

This will:
- Add a `custom_emoji` column to the reactions table
- Update constraints to allow custom reactions
- Add indexes for better performance

### Step 2: Verify the Migration

In your Supabase Table Editor, check that the `reactions` table now has:
- All the original columns (id, post_id, user_id, reaction_type, created_at)
- New column: `custom_emoji` (TEXT, nullable)

## Features

### How to Add a Custom Reaction:

1. **Find the "Custom" button** - It appears after the 6 standard reactions on every post
2. **Click "Custom"** - A dialog will open
3. **Choose your emoji** in one of two ways:
   - Type or paste any emoji in the text field
   - Click one of the 18 popular emoji suggestions
4. **Click "Add Reaction"** - Your custom emoji will be added to the post!

### Popular Emoji Suggestions:
The custom reaction picker includes quick-select buttons for:
- 🎉 Party
- 🔥 Fire
- 💯 100
- ✨ Sparkles
- 🚀 Rocket
- 💪 Muscle
- 🙌 Raised Hands
- 👏 Clapping
- 🤔 Thinking
- 🎯 Target
- ⭐ Star
- 💎 Gem
- 🌟 Glowing Star
- 🎊 Confetti
- 🏆 Trophy
- ❓ Question
- 💡 Lightbulb
- 🎈 Balloon

### Custom Reaction Behavior:

- **Persistent** - Once someone uses a custom emoji on a post, it appears as a button for everyone
- **Counted** - Custom reactions show a count just like standard reactions
- **Highlighted** - Your selected reaction is highlighted (whether standard or custom)
- **One per user** - Each user can only have one active reaction per post
- **Switch reactions** - Click a different emoji (standard or custom) to change your reaction
- **Remove reaction** - Click the same emoji again to remove your reaction

### Where Custom Reactions Appear:

- ✅ Home feed - Below each post
- ✅ Post detail view - Below the post content
- ✅ Both locations stay in sync

## Technical Details

### Database Schema:
```sql
reactions table:
  - reaction_type: TEXT (like/love/laugh/wow/sad/angry/custom)
  - custom_emoji: TEXT (nullable, stores the emoji when reaction_type='custom')
  - Constraint: If reaction_type='custom', custom_emoji must not be null
```

### UI Implementation:
- Standard reactions show first (6 buttons)
- Custom reactions that have been used appear next (dynamic)
- "Custom" button appears last (always visible)

### Data Format:
- Standard reactions: stored as `reaction_type` (e.g., "like")
- Custom reactions: stored as `reaction_type='custom'` + `custom_emoji='🔥'`
- Internally tracked as: `custom_🔥`, `custom_💯`, etc.

## Testing

After running the migration:
1. Refresh your web app
2. Find or create a post
3. Click the "Custom" button at the end of the reactions
4. Try adding a custom emoji (e.g., 🔥 or 💯)
5. Verify the emoji appears as a button with a count
6. Click it again to remove the reaction
7. Try using a different custom emoji
8. Open the post detail view - custom reactions should appear there too

## Troubleshooting

**Custom button doesn't appear:**
- Clear browser cache and refresh
- Check that the web build deployed successfully

**Can't add custom reactions:**
- Verify the SQL migration ran successfully
- Check that `custom_emoji` column exists in reactions table
- Ensure you're logged in

**Custom emojis don't show up:**
- Check browser console for errors
- Verify the reaction was saved in Supabase
- Try refreshing the page

**Emoji looks different on different devices:**
- This is normal! Emoji rendering varies by platform
- iOS, Android, Windows, and Web may display emojis slightly differently

## Future Enhancements

Potential improvements:
- Save frequently used custom emojis per user
- Trending custom reactions
- Emoji search/picker
- Animated emoji reactions
- Reaction combos (e.g., "🔥 x5!")
