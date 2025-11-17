import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/civic_chatter_app_bar.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;
  bool _isSubmitting = false;
  Map<String, int> _reactions = {}; // reactionType -> count
  String? _userReaction; // user's current reaction

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadReactions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final postId = widget.post['id'];

      // Fetch comments with user profiles
      final commentsResponse = await supabase
          .from('comments')
          .select(
              '*, profiles_public!comments_user_id_fkey(id, handle, display_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(commentsResponse);
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading comments: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadReactions() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      final postId = widget.post['id'];

      // Load all reactions for this post (including custom_emoji)
      final reactionsResponse = await supabase
          .from('reactions')
          .select('reaction_type, custom_emoji, user_id')
          .eq('post_id', postId);

      // Process reactions
      final Map<String, int> reactionCounts = {};
      String? userReaction;

      for (var reaction in reactionsResponse) {
        final reactionType = reaction['reaction_type'];
        final customEmoji = reaction['custom_emoji'];
        final reactionUserId = reaction['user_id'];

        // Use custom emoji as the type if it's a custom reaction
        final effectiveType = reactionType == 'custom' && customEmoji != null
            ? 'custom_$customEmoji'
            : reactionType;

        // Count reactions
        reactionCounts[effectiveType] =
            (reactionCounts[effectiveType] ?? 0) + 1;

        // Track user's own reaction
        if (userId != null && reactionUserId == userId) {
          userReaction = effectiveType;
        }
      }

      if (mounted) {
        setState(() {
          _reactions = reactionCounts;
          _userReaction = userReaction;
        });
      }
    } catch (e) {
      debugPrint('Error loading reactions: $e');
    }
  }

  Future<void> _toggleReaction(String reactionType) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      final postId = widget.post['id'];

      if (userId == null) return;

      if (_userReaction == reactionType) {
        // Remove reaction
        await supabase
            .from('reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else if (_userReaction != null) {
        // Update reaction
        await supabase
            .from('reactions')
            .update({'reaction_type': reactionType})
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        // Add new reaction
        await supabase.from('reactions').insert({
          'post_id': postId,
          'user_id': userId,
          'reaction_type': reactionType,
        });
      }

      // Reload reactions
      await _loadReactions();
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating reaction: $e')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('You must be logged in to comment');
      }

      final postId = widget.post['id'];

      // Insert comment into database
      await supabase.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': commentText,
      });

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });

        // Reload comments to show the new one
        await _loadComments();
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDate = dateFormat.format(localTime);
    final timezone = localTime.timeZoneName;
    return '$formattedDate $timezone';
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'];
    final displayName = profile != null
        ? (profile['display_name'] ?? profile['handle'] ?? 'Unknown User')
        : 'Unknown User';
    final createdAt = DateTime.parse(widget.post['created_at']);
    final timestamp = _formatTimestamp(createdAt);
    final isPrivate = widget.post['is_private'] ?? false;

    return Scaffold(
      appBar: const CivicChatterAppBar(
        title: 'Post Details',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original Post Card
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: profile != null &&
                                        profile['avatar_url'] != null
                                    ? NetworkImage(profile['avatar_url'])
                                    : null,
                                child: profile == null ||
                                        profile['avatar_url'] == null
                                    ? Text(displayName[0].toUpperCase())
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      timestamp,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.post['media_type'] != null)
                                    Chip(
                                      label: Text(widget.post['media_type']),
                                      padding: EdgeInsets.zero,
                                    ),
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPrivate ? Icons.lock : Icons.public,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(isPrivate ? 'Private' : 'Public'),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    backgroundColor: isPrivate
                                        ? Colors.orange[100]
                                        : Colors.green[100],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.post['content'] ?? '',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),

                          // Reaction Bar
                          _buildReactionBar(),
                        ],
                      ),
                    ),
                  ),
                  // Comments Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingComments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final profile = comment['profiles_public'];
                        final displayName = profile != null
                            ? (profile['display_name'] ??
                                profile['handle'] ??
                                'Unknown User')
                            : 'Unknown User';
                        final createdAt = DateTime.parse(comment['created_at']);
                        final timestamp = _formatTimestamp(createdAt);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: profile != null &&
                                              profile['avatar_url'] != null
                                          ? NetworkImage(profile['avatar_url'])
                                          : null,
                                      child: profile == null ||
                                              profile['avatar_url'] == null
                                          ? Text(displayName[0].toUpperCase())
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            timestamp,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['content'] ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          // Comment Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSubmitting ? null : _submitComment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF002868),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBar() {
    final reactionButtons = [
      {'type': 'like', 'emoji': '👍', 'label': 'Like'},
      {'type': 'love', 'emoji': '❤️', 'label': 'Love'},
      {'type': 'laugh', 'emoji': '😂', 'label': 'Laugh'},
      {'type': 'wow', 'emoji': '😮', 'label': 'Wow'},
      {'type': 'sad', 'emoji': '😢', 'label': 'Sad'},
      {'type': 'angry', 'emoji': '😠', 'label': 'Angry'},
    ];

    // Collect custom reactions for this post
    final customReactions = _reactions.keys
        .where((key) => key.startsWith('custom_'))
        .map((key) => key.substring(7)) // Remove 'custom_' prefix
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Standard reaction buttons
        ...reactionButtons.map((reaction) {
          final type = reaction['type'] as String;
          final emoji = reaction['emoji'] as String;
          final count = _reactions[type] ?? 0;
          final isSelected = _userReaction == type;

          return InkWell(
            onTap: () => _toggleReaction(type),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : Theme.of(context).cardColor,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),

        // Custom reaction buttons (show ones that have been used)
        ...customReactions.map((emoji) {
          final customKey = 'custom_$emoji';
          final count = _reactions[customKey] ?? 0;
          final isSelected = _userReaction == customKey;

          return InkWell(
            onTap: () => _toggleCustomReaction(emoji),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : Theme.of(context).cardColor,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),

        // Add custom reaction button
        InkWell(
          onTap: _showCustomReactionPicker,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_reaction_outlined,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Custom',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCustomReactionPicker() {
    final TextEditingController emojiController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Reaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter any emoji:'),
            const SizedBox(height: 16),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                hintText: 'Type or paste emoji (e.g., 🎉, 🔥, 💯)',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
              maxLength: 10,
            ),
            const SizedBox(height: 16),
            const Text(
              'Popular emojis:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                '🎉',
                '🔥',
                '💯',
                '✨',
                '🚀',
                '💪',
                '🙌',
                '👏',
                '🤔',
                '🎯',
                '⭐',
                '💎',
                '🌟',
                '🎊',
                '🏆',
                '❓',
                '💡',
                '🎈',
              ]
                  .map((emoji) => InkWell(
                        onTap: () {
                          emojiController.text = emoji;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final emoji = emojiController.text.trim();
              if (emoji.isNotEmpty) {
                Navigator.pop(context);
                _toggleCustomReaction(emoji);
              }
            },
            child: const Text('Add Reaction'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCustomReaction(String emoji) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      final postId = widget.post['id'];

      if (userId == null) return;

      // If user already has a reaction, remove it first
      if (_userReaction != null) {
        await supabase
            .from('reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      }

      // Add custom reaction
      await supabase.from('reactions').insert({
        'post_id': postId,
        'user_id': userId,
        'reaction_type': 'custom',
        'custom_emoji': emoji,
      });

      // Reload reactions
      await _loadReactions();
    } catch (e) {
      debugPrint('Error toggling custom reaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating reaction: $e')),
        );
      }
    }
  }
}
