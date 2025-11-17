# Message Center Feature

## Overview
A message center has been added to the right side of the posts feed on screens wider than 1200px. This allows users to have direct messaging conversations without leaving the main feed.

## What Was Added

### 1. Database Schema (`/db/create_messages_table.sql`)
- **messages table**: Stores direct messages between users
  - `id`: Unique message identifier
  - `sender_id`: Reference to the user who sent the message
  - `receiver_id`: Reference to the user receiving the message
  - `content`: Message text content
  - `read`: Boolean flag indicating if message has been read
  - `created_at`: Timestamp of when message was sent

- **RLS Policies**:
  - Users can read messages where they are sender or receiver
  - Users can send messages (insert with their ID as sender)
  - Users can update received messages (mark as read)
  - Users can delete their sent messages

- **Indexes**: Optimized for fast queries on sender, receiver, conversations, and timestamps

### 2. Message Center Widget (`/flutter_app/lib/widgets/message_center.dart`)
A complete messaging interface with:

#### Features
- **Conversation List**: Shows all conversations with:
  - Partner's avatar and username
  - Last message preview
  - Time ago formatting (minutes, hours, days, or date)
  - Unread indicator (blue dot)
  - Sorted by most recent message

- **Message View**: Individual conversation interface with:
  - Back button to return to conversation list
  - Partner's avatar and username in header
  - Message bubbles (different colors for sent/received)
  - Timestamps for each message
  - Auto-scroll to bottom on load and new messages
  - Real-time updates using Supabase Realtime

- **Message Input**: Text field with:
  - Multi-line support
  - Send button
  - Enter key to send
  - Auto-clears after sending

#### Technical Details
- Uses Supabase Realtime subscriptions for instant message updates
- Marks messages as read automatically when viewing conversation
- Loads conversation partners with profile data (username, avatar)
- Handles loading states and empty states
- Proper cleanup of subscriptions on dispose

### 3. Layout Changes (`/flutter_app/lib/screens/home/home_screen.dart`)
- Modified main layout to use a `Row` instead of single column
- Posts feed is wrapped in `Expanded` widget (takes available space)
- Message center appears on right side (350px fixed width)
- Responsive behavior:
  - **< 1200px width**: Message center hidden, posts take full width
  - **> 1200px width**: Message center visible on right side
  - Maintains existing responsive behavior for posts (max 800px on large screens)

### 4. Documentation Updates
- Updated `/db/README.md` with migration instructions for messages table
- Listed all available SQL migration files in order

## How to Use

### Database Setup
1. Open your Supabase project SQL Editor
2. Copy the contents of `/db/create_messages_table.sql`
3. Run the SQL query
4. Verify the `messages` table was created with proper RLS policies

### User Interface
1. Build and deploy the Flutter app
2. On screens wider than 1200px, the message center will appear on the right
3. Click on a conversation to view messages
4. Type a message and press Enter or click Send
5. Messages update in real-time when either party sends

### Starting a Conversation
Currently, conversations appear in the message center after the first message is sent. Future enhancement could add a "Send Message" button to user profiles to initiate new conversations.

## Technical Considerations

### Performance
- Real-time subscriptions are created per conversation and cleaned up on exit
- Message queries are optimized with database indexes
- Conversation list only loads once (can be refreshed by going back from a conversation)

### Responsive Design
- Message center only shows on screens > 1200px wide
- On smaller screens (tablets, mobile), users can access messages through a dedicated messages page (future enhancement)
- Posts feed maintains its responsive behavior

### Security
- All database access is protected by RLS policies
- Users can only see and interact with their own messages
- Message content is stored as plain text (consider encryption for sensitive content)

## Future Enhancements

1. **Initiate Conversations**: Add "Send Message" button to user profiles
2. **Mobile View**: Create dedicated messages screen for smaller devices
3. **Notifications**: Add push notifications for new messages
4. **Message Actions**: Edit, delete, reply to specific messages
5. **Group Messaging**: Support for group conversations
6. **Media Sharing**: Allow sending images and files
7. **Message Search**: Search within conversations
8. **Unread Count**: Show total unread count in header
9. **Typing Indicators**: Show when other user is typing
10. **Message Reactions**: React to messages with emojis

## Testing Checklist

- [ ] Database migration runs successfully
- [ ] Message center appears on screens > 1200px
- [ ] Message center hidden on screens < 1200px
- [ ] Can send messages in a conversation
- [ ] Messages appear in real-time for both users
- [ ] Messages marked as read when viewing
- [ ] Unread indicator shows correctly
- [ ] Conversation list sorted by most recent
- [ ] Time ago formatting works correctly
- [ ] Auto-scroll to bottom works
- [ ] Back button returns to conversation list
- [ ] Send button and Enter key both work
- [ ] Loading states show correctly
- [ ] Empty states show when no messages/conversations
- [ ] RLS policies prevent unauthorized access

## Files Modified/Created

**Created:**
- `/db/create_messages_table.sql` - Database schema and RLS policies
- `/flutter_app/lib/widgets/message_center.dart` - Message center widget

**Modified:**
- `/flutter_app/lib/screens/home/home_screen.dart` - Added Row layout with message center
- `/db/README.md` - Updated migration documentation
