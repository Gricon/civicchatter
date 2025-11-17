import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  RealtimeChannel? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationsSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get comments on user's posts
      final response = await _supabase
          .from('comments')
          .select('''
            id,
            content,
            created_at,
            post_id,
            user_id,
            commenter:profiles_public!user_id(id, username, avatar_url),
            post:posts!post_id(id, content, user_id)
          ''')
          .eq('posts.user_id', userId)
          .neq('user_id', userId) // Don't show own comments
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationsSubscription = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            _loadNotifications();
          },
        )
        .subscribe();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _truncateContent(String content, int maxLength) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
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
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          // Notifications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No notifications',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You\'ll see notifications when someone comments on your posts',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final commenter = notification['commenter'];
                          final post = notification['post'];
                          final createdAt =
                              DateTime.parse(notification['created_at']);
                          final timeAgo = _formatTimeAgo(createdAt);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: InkWell(
                              onTap: () {
                                // Navigate to post
                                // You can implement navigation here
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Commenter info
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage:
                                              commenter['avatar_url'] != null
                                                  ? NetworkImage(
                                                      commenter['avatar_url'])
                                                  : null,
                                          child: commenter['avatar_url'] == null
                                              ? Text(
                                                  commenter['username'][0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '@${commenter['username']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Text(
                                                'commented on your post',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Comment preview
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _truncateContent(
                                            notification['content'], 100),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Post preview and time
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'on: ${_truncateContent(post['content'] ?? 'your post', 40)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          timeAgo,
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
