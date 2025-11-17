# Message Center Visual Guide

## Layout Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CivicChatter Header                                │
├──────────────────────────────────────┬──────────────────────────────────────┤
│                                      │  ┌──────────────────────────────┐   │
│   Post Creation Form                 │  │  📧 Messages                 │   │
│   [Text Editor]                      │  ├──────────────────────────────┤   │
│   [Submit Button]                    │  │  👤 User1          2h        │   │
│                                      │  │  Last message preview...  •  │   │
│   ─────────────────────              │  │                              │   │
│                                      │  │  👤 User2          1d        │   │
│   Filter Buttons                     │  │  Another message...          │   │
│   [Privacy] [Type] [Sort]            │  │                              │   │
│                                      │  │  👤 User3          3d        │   │
│   ─────────────────────              │  │  Older conversation          │   │
│                                      │  │                              │   │
│   📝 Post 1                          │  │                              │   │
│   [Content]                          │  │                              │   │
│   [Reactions] [Comments]             │  │                              │   │
│                                      │  │                              │   │
│   📝 Post 2                          │  │                              │   │
│   [Content]                          │  │                              │   │
│   [Reactions] [Comments]             │  └──────────────────────────────┘   │
│                                      │        350px fixed width             │
│   📝 Post 3                          │                                      │
│   [Content]                          │                                      │
│   [Reactions] [Comments]             │                                      │
│                                      │                                      │
│   ... more posts ...                 │                                      │
│                                      │                                      │
└──────────────────────────────────────┴──────────────────────────────────────┘
    Scrollable (Expanded width)               Message Center (350px)
```

## Conversation View

When you click on a conversation, it switches to the message view:

```
┌──────────────────────────────────┐
│  ← 👤 User1                      │
├──────────────────────────────────┤
│                                  │
│  ┌────────────────────┐          │
│  │ Hey there!         │ 2:30 PM  │
│  │                    │          │
│  └────────────────────┘          │
│                                  │
│           ┌──────────────────┐   │
│   3:45 PM │ Hi! How are you? │   │
│           │                  │   │
│           └──────────────────┘   │
│                                  │
│  ┌────────────────────┐          │
│  │ Doing great!       │ 4:15 PM  │
│  └────────────────────┘          │
│                                  │
│                                  │
├──────────────────────────────────┤
│ [Type a message...        ] 📤   │
└──────────────────────────────────┘
```

## Responsive Behavior

### Large Screen (> 1200px width)
```
┌─────────────────────────────────────────────────────────────┐
│                     Header                                   │
├──────────────────────────────┬──────────────────────────────┤
│                              │                              │
│     Posts Feed               │    Message Center            │
│     (Expanded)               │    (350px)                   │
│                              │                              │
└──────────────────────────────┴──────────────────────────────┘
```

### Medium/Small Screen (< 1200px width)
```
┌─────────────────────────────────────────────────────────────┐
│                     Header                                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│               Posts Feed (Full Width)                        │
│         (Message Center Hidden)                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Color Scheme

- **Your messages**: Primary container color (light purple/blue)
- **Their messages**: Surface variant color (light gray)
- **Unread indicator**: Primary color dot
- **Header**: Primary container background
- **Borders**: Divider color

## Features At a Glance

### Conversation List
✓ Shows all your conversations
✓ Avatar + username
✓ Last message preview (truncated)
✓ Time ago (minutes, hours, days, or date)
✓ Unread indicator (blue dot)
✓ Click to open conversation

### Message View
✓ Back button to conversation list
✓ Partner info in header
✓ Bubble-style messages
✓ Different colors for sent/received
✓ Timestamps on each message
✓ Auto-scroll to bottom
✓ Real-time updates
✓ Text input with send button
✓ Enter key to send

### Empty States
✓ "No messages yet" when no conversations
✓ Helpful hint about starting conversations
✓ "No messages yet" in empty conversations

## Database Schema

```sql
messages
├── id (UUID, primary key)
├── sender_id (UUID, foreign key → profiles.user_id)
├── receiver_id (UUID, foreign key → profiles.user_id)
├── content (TEXT)
├── read (BOOLEAN, default false)
└── created_at (TIMESTAMP)
```

## Next Steps

1. **Run the migration**: Copy `/db/create_messages_table.sql` to Supabase SQL Editor
2. **Deploy the app**: The frontend files are already built and copied
3. **Test on large screen**: Open on a screen > 1200px to see the message center
4. **Start conversations**: Visit user profiles to send messages (or insert test data)

## Tips

- The message center automatically marks messages as read when viewing
- Real-time updates mean both users see new messages instantly
- Conversations are sorted by most recent message
- The message center stays visible while scrolling through posts
- Type long messages - the input expands to multiple lines
