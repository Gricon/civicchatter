import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MessageCenter extends StatefulWidget {
  const MessageCenter({super.key});

  @override
  State<MessageCenter> createState() => _MessageCenterState();
}

class _MessageCenterState extends State<MessageCenter> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _selectedConversation;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  RealtimeChannel? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoadingConversations = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all messages for this user with sender/receiver profiles
      final response = await _supabase
          .from('messages')
          .select('''
          *,
          sender:profiles_public!sender_id(id, username, avatar_url),
          receiver:profiles_public!receiver_id(id, username, avatar_url)
        ''')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      // Group by conversation partner
      final conversationMap = <String, Map<String, dynamic>>{};
      for (final message in response) {
        final isSender = message['sender_id'] == userId;
        final partnerId =
            isSender ? message['receiver_id'] : message['sender_id'];
        final partner = isSender ? message['receiver'] : message['sender'];

        if (!conversationMap.containsKey(partnerId)) {
          conversationMap[partnerId] = {
            'partner_id': partnerId,
            'partner': partner,
            'last_message': message['content'],
            'last_message_time': message['created_at'],
            'unread': !isSender && !(message['read'] ?? false),
          };
        } else {
          // Update unread count
          if (!isSender && !(message['read'] ?? false)) {
            conversationMap[partnerId]!['unread'] = true;
          }
        }
      }

      setState(() {
        _conversations = conversationMap.values.toList()
          ..sort((a, b) => (b['last_message_time'] as String)
              .compareTo(a['last_message_time'] as String));
        _isLoadingConversations = false;
      });
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      setState(() => _isLoadingConversations = false);
    }
  }

  Future<void> _loadMessages(String partnerId) async {
    setState(() => _isLoadingMessages = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('messages')
          .select('''
          *,
          sender:profiles_public!sender_id(id, username, avatar_url)
        ''')
          .or('and(sender_id.eq.$userId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$userId)')
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoadingMessages = false;
      });

      // Mark messages as read
      await _supabase
          .from('messages')
          .update({'read': true})
          .eq('receiver_id', userId)
          .eq('sender_id', partnerId);

      // Subscribe to new messages
      _messagesSubscription?.unsubscribe();
      _messagesSubscription = _supabase
          .channel('messages:$partnerId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newMessage = payload.newRecord;
              if ((newMessage['sender_id'] == partnerId &&
                      newMessage['receiver_id'] == userId) ||
                  (newMessage['sender_id'] == userId &&
                      newMessage['receiver_id'] == partnerId)) {
                _loadMessages(partnerId);
              }
            },
          )
          .subscribe();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedConversation == null) {
      return;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final content = _messageController.text.trim();
      _messageController.clear();

      await _supabase.from('messages').insert({
        'sender_id': userId,
        'receiver_id': _selectedConversation!['partner_id'],
        'content': content,
      });

      await _loadMessages(_selectedConversation!['partner_id']);
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _selectConversation(Map<String, dynamic> conversation) {
    setState(() {
      _selectedConversation = conversation;
    });
    _loadMessages(conversation['partner_id']);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.message,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _selectedConversation == null
                ? _buildConversationsList()
                : _buildMessagesView(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a conversation by visiting a user\'s profile',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final partner = conversation['partner'];
        final lastMessageTime =
            DateTime.parse(conversation['last_message_time']);
        final timeAgo = _formatTimeAgo(lastMessageTime);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: partner['avatar_url'] != null
                ? NetworkImage(partner['avatar_url'])
                : null,
            child: partner['avatar_url'] == null
                ? Text(partner['username'][0].toUpperCase())
                : null,
          ),
          title: Text(
            partner['username'],
            style: TextStyle(
              fontWeight: conversation['unread'] == true
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            conversation['last_message'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeAgo,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (conversation['unread'] == true)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          onTap: () => _selectConversation(conversation),
        );
      },
    );
  }

  Widget _buildMessagesView() {
    return Column(
      children: [
        // Conversation header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedConversation = null;
                    _messages = [];
                  });
                  _messagesSubscription?.unsubscribe();
                  _loadConversations();
                },
              ),
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    _selectedConversation!['partner']['avatar_url'] != null
                        ? NetworkImage(
                            _selectedConversation!['partner']['avatar_url'])
                        : null,
                child: _selectedConversation!['partner']['avatar_url'] == null
                    ? Text(
                        _selectedConversation!['partner']['username'][0]
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                _selectedConversation!['partner']['username'],
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        // Messages list
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final userId = _supabase.auth.currentUser?.id;
                        final isMe = message['sender_id'] == userId;
                        final timestamp = DateTime.parse(message['created_at']);

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: const BoxConstraints(maxWidth: 250),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['content'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('h:mm a').format(timestamp),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Message input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
