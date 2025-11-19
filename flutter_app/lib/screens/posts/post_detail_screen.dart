import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/civic_chatter_app_bar.dart';
import '../../widgets/report_block_dialog.dart';

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
  Set<String> _userReactions = {}; // user's current reactions (up to 2)
  Map<String, List<Map<String, dynamic>>> _reactionDetails =
      {}; // reactionType -> [user details]
  String? _replyingToCommentId; // Track which comment is being replied to
  String? _replyingToUsername; // Track username being replied to

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

      // Load all reactions for this post
      final reactionsResponse = await supabase
          .from('reactions')
          .select('reaction_type, custom_emoji, user_id')
          .eq('post_id', postId);

      // Get unique user IDs from reactions
      final userIds =
          reactionsResponse.map((r) => r['user_id'] as String).toSet().toList();

      // Load profiles for these users
      Map<String, Map<String, dynamic>> userProfiles = {};
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await supabase
              .from('profiles_public')
              .select('id, handle, display_name')
              .inFilter('id', userIds);

          for (var profile in profilesResponse) {
            userProfiles[profile['id']] = profile;
          }
        } catch (profileError) {
          debugPrint('Error loading user profiles: $profileError');
          // Continue without profiles - reactions will still work
        }
      }

      // Process reactions
      final Map<String, int> reactionCounts = {};
      final Set<String> userReactions = {};
      final Map<String, List<Map<String, dynamic>>> reactionDetails = {};

      for (var reaction in reactionsResponse) {
        final reactionType = reaction['reaction_type'];
        final customEmoji = reaction['custom_emoji'];
        final reactionUserId = reaction['user_id'];
        final profile = userProfiles[reactionUserId];

        // Use custom emoji as the type if it's a custom reaction
        final effectiveType = reactionType == 'custom' && customEmoji != null
            ? 'custom_$customEmoji'
            : reactionType;

        // Count reactions
        reactionCounts[effectiveType] =
            (reactionCounts[effectiveType] ?? 0) + 1;

        // Store reaction details with user info
        if (!reactionDetails.containsKey(effectiveType)) {
          reactionDetails[effectiveType] = [];
        }
        reactionDetails[effectiveType]!.add({
          'user_id': reactionUserId,
          'handle': profile?['handle'] ?? 'Unknown',
          'display_name': profile?['display_name'] ?? 'Unknown User',
        });

        // Track user's own reactions (can have up to 2)
        if (userId != null && reactionUserId == userId) {
          userReactions.add(effectiveType);
        }
      }

      if (mounted) {
        setState(() {
          _reactions = reactionCounts;
          _userReactions = userReactions;
          _reactionDetails = reactionDetails;
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

      // Check if user already has this reaction
      if (_userReactions.contains(reactionType)) {
        // Remove this specific reaction
        await supabase
            .from('reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .eq('reaction_type', reactionType);
      } else {
        // Check if user already has 2 reactions
        if (_userReactions.length >= 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You can only have up to 2 reactions per post'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // Add new reaction
        await supabase.from('reactions').insert({
          'post_id': postId,
          'user_id': userId,
          'reaction_type': reactionType,
          'custom_emoji': null,
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
        if (_replyingToCommentId != null)
          'parent_comment_id': _replyingToCommentId,
      });

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUsername = null;
      });

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
                                  // Report/Block button for post author
                                  if (widget.post['user_id'] !=
                                      Supabase
                                          .instance.client.auth.currentUser?.id)
                                    IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              ReportBlockDialog(
                                            reportedUserId:
                                                widget.post['user_id'],
                                            reportedUsername: displayName,
                                            postId: widget.post['id'],
                                            commentId: null,
                                          ),
                                        );
                                      },
                                    ),
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
                                const SizedBox(height: 8),
                                // Reply and Report/Block buttons
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.reply, size: 16),
                                      label: const Text('Reply'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        minimumSize: const Size(0, 32),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _replyingToCommentId = comment['id'];
                                          _replyingToUsername = displayName;
                                        });
                                        _commentController.text =
                                            '@$displayName ';
                                      },
                                    ),
                                    const Spacer(),
                                    if (comment['user_id'] !=
                                        Supabase.instance.client.auth
                                            .currentUser?.id)
                                      IconButton(
                                        icon: const Icon(Icons.more_vert,
                                            size: 24),
                                        padding: const EdgeInsets.all(8),
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Report or Block',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                ReportBlockDialog(
                                              reportedUserId:
                                                  comment['user_id'],
                                              reportedUsername: displayName,
                                              postId: widget.post['id'],
                                              commentId: comment['id'],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply indicator
                  if (_replyingToUsername != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Replying to $_replyingToUsername',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _replyingToCommentId = null;
                                _replyingToUsername = null;
                                _commentController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  Row(
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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

    // Calculate total reactions
    int totalReactions = 0;
    for (var count in _reactions.values) {
      totalReactions += count;
    }

    // Build display for user's reactions (can be up to 2)
    String userReactionDisplay = '👍';
    String userReactionLabel = 'React';

    if (_userReactions.isNotEmpty) {
      // Show the emojis of user's reactions
      final emojis = <String>[];
      for (var reaction in _userReactions) {
        if (reaction.startsWith('custom_')) {
          emojis.add(reaction.substring(7));
        } else {
          final selectedReaction = reactionButtons.firstWhere(
            (r) => r['type'] == reaction,
            orElse: () => {'emoji': '👍'},
          );
          emojis.add(selectedReaction['emoji'] as String);
        }
      }
      userReactionDisplay = emojis.join(' ');
      userReactionLabel = 'Reacted';
    }

    return Row(
      children: [
        // Reaction dropdown button
        PopupMenuButton<String>(
          offset: const Offset(0, -10),
          onSelected: (value) {
            if (value == 'custom') {
              _showCustomReactionPicker();
            } else if (value.startsWith('custom_')) {
              final emoji = value.substring(7);
              _toggleCustomReaction(emoji);
            } else {
              _toggleReaction(value);
            }
          },
          itemBuilder: (context) => [
            // Standard reactions
            ...reactionButtons.map((reaction) {
              final type = reaction['type'] as String;
              final emoji = reaction['emoji'] as String;
              final label = reaction['label'] as String;
              final count = _reactions[type] ?? 0;
              final isSelected = _userReactions.contains(type);

              return PopupMenuItem<String>(
                value: type,
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _showReactionUsers(type, emoji, label);
                            },
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),

            // Divider before custom reactions if any exist
            if (customReactions.isNotEmpty) const PopupMenuDivider(),

            // Custom reactions that have been used
            ...customReactions.map((emoji) {
              final customKey = 'custom_$emoji';
              final count = _reactions[customKey] ?? 0;
              final isSelected = _userReactions.contains(customKey);

              return PopupMenuItem<String>(
                value: customKey,
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Custom')),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),

            // Divider before add custom option
            const PopupMenuDivider(),

            // Add custom reaction option
            const PopupMenuItem<String>(
              value: 'custom',
              child: Row(
                children: [
                  Icon(Icons.add_reaction_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Add Custom Reaction'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _userReactions.isNotEmpty
                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                  : Theme.of(context).cardColor,
              border: Border.all(
                color: _userReactions.isNotEmpty
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).dividerColor,
                width: _userReactions.isNotEmpty ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userReactionDisplay,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 4),
                Text(
                  userReactionLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _userReactions.isNotEmpty
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: _userReactions.isNotEmpty
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),

        // Show total reaction count if there are any
        if (totalReactions > 0) ...[
          const SizedBox(width: 8),
          Text(
            '$totalReactions ${totalReactions == 1 ? 'reaction' : 'reactions'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ],
    );
  }

  void _showReactionUsers(String reactionType, String emoji, String label) {
    final isPrivatePost = widget.post['is_private'] ?? false;
    final users = _reactionDetails[reactionType] ?? [];

    if (users.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              // Use display_name for private posts, handle for public posts
              final displayText =
                  isPrivatePost ? user['display_name'] : '@${user['handle']}';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(displayText[0].toUpperCase()),
                ),
                title: Text(displayText),
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
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

      final customKey = 'custom_$emoji';

      // Check if user already has this custom reaction
      if (_userReactions.contains(customKey)) {
        // Remove this specific custom reaction
        await supabase
            .from('reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .eq('reaction_type', 'custom')
            .eq('custom_emoji', emoji);
      } else {
        // Check if user already has 2 reactions
        if (_userReactions.length >= 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You can only have up to 2 reactions per post'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // Add new custom reaction
        await supabase.from('reactions').insert({
          'post_id': postId,
          'user_id': userId,
          'reaction_type': 'custom',
          'custom_emoji': emoji,
        });
      }

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
