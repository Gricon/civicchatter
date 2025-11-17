import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/civic_chatter_app_bar.dart';
import '../../widgets/custom_background.dart';
import '../../widgets/message_center.dart';
import '../../widgets/notifications_panel.dart';
import '../posts/post_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedPostType = 'Text Post';
  bool _isPrivatePost = false; // Privacy toggle for new posts
  QuillController? _quillController;
  XFile? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingPosts = false;
  Map<String, Map<String, int>> _postReactions =
      {}; // postId -> {reactionType -> count}
  Map<String, Set<String>> _userReactions =
      {}; // postId -> Set of reaction keys (up to 2)

  // Filter and sort options
  String _sortBy = 'newest'; // newest, oldest, popular
  String _filterBy = 'all'; // all, public, private
  String _postTypeFilter = 'all'; // all, Text Post, Photo, Video, Link, Poll

  // Message center resizing
  double _messageCenterWidth = 300.0;
  bool _isResizing = false;

  // Notifications panel resizing
  double _notificationsPanelWidth = 280.0;
  bool _isResizingNotifications = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _loadPosts();
  }

  void _initializeController() {
    try {
      _quillController = QuillController.basic();
    } catch (e) {
      debugPrint('Error initializing QuillController: $e');
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Build query based on filter
      var query = supabase.from('posts').select('*');

      // Apply privacy filter
      if (_filterBy == 'public') {
        query = query.eq('is_private', false);
      } else if (_filterBy == 'private') {
        query = query.eq('is_private', true);
      }

      // Apply post type filter
      if (_postTypeFilter != 'all') {
        query = query.eq('media_type', _postTypeFilter);
      }

      // Apply sort and execute
      List<dynamic> postsResponse;
      if (_sortBy == 'newest') {
        postsResponse =
            await query.order('created_at', ascending: false).limit(50);
      } else if (_sortBy == 'oldest') {
        postsResponse =
            await query.order('created_at', ascending: true).limit(50);
      } else {
        // popular - TODO: Add like/comment count sorting when those features are added
        postsResponse =
            await query.order('created_at', ascending: false).limit(50);
      }

      // Fetch all unique user IDs from posts
      final userIds = <String>{};
      for (var post in postsResponse) {
        if (post['user_id'] != null) {
          userIds.add(post['user_id']);
        }
      }

      // Fetch profiles for those users
      Map<String, dynamic> profilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await supabase
              .from('profiles_public')
              .select('id, handle, display_name, avatar_url')
              .inFilter('id', userIds.toList());

          for (var profile in profilesResponse) {
            profilesMap[profile['id']] = profile;
          }
        } catch (e) {
          debugPrint('Error loading profiles: $e');
        }
      }

      // Merge posts with their profiles
      final postsWithProfiles = postsResponse.map((post) {
        final postMap = Map<String, dynamic>.from(post);
        final userId = post['user_id'];
        final profile = profilesMap[userId];

        // If no profile exists, create a basic one with user ID
        if (profile == null) {
          postMap['profiles'] = {
            'id': userId,
            'handle': 'User ${userId?.substring(0, 8) ?? 'Unknown'}',
            'display_name': null,
          };
        } else {
          postMap['profiles'] = profile;
        }
        return postMap;
      }).toList();

      if (mounted) {
        setState(() {
          _posts = postsWithProfiles;
          _isLoadingPosts = false;
        });
        // Load reactions for all posts
        _loadReactionsForPosts();
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _loadReactionsForPosts() async {
    if (_posts.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      final postIds = _posts.map((p) => p['id']).toList();

      // Load all reactions for these posts (including custom_emoji)
      final reactionsResponse = await supabase
          .from('reactions')
          .select('post_id, reaction_type, custom_emoji, user_id')
          .inFilter('post_id', postIds);

      // Process reactions
      final Map<String, Map<String, int>> reactionCounts = {};
      final Map<String, Set<String>> userReactions = {};

      for (var reaction in reactionsResponse) {
        final postId = reaction['post_id'];
        final reactionType = reaction['reaction_type'];
        final customEmoji = reaction['custom_emoji'];
        final reactionUserId = reaction['user_id'];

        // Use custom emoji as the type if it's a custom reaction
        final effectiveType = reactionType == 'custom' && customEmoji != null
            ? 'custom_$customEmoji'
            : reactionType;

        // Count reactions
        if (!reactionCounts.containsKey(postId)) {
          reactionCounts[postId] = {};
        }
        reactionCounts[postId]![effectiveType] =
            (reactionCounts[postId]![effectiveType] ?? 0) + 1;

        // Track user's own reactions (can have up to 2)
        if (userId != null && reactionUserId == userId) {
          if (!userReactions.containsKey(postId)) {
            userReactions[postId] = {};
          }
          userReactions[postId]!.add(effectiveType);
        }
      }

      if (mounted) {
        setState(() {
          _postReactions = reactionCounts;
          _userReactions = userReactions;
        });
      }
    } catch (e) {
      debugPrint('Error loading reactions: $e');
    }
  }

  Future<void> _toggleReaction(String postId, String reactionType) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final userReactions = _userReactions[postId] ?? {};

      // Check if user already has this reaction
      if (userReactions.contains(reactionType)) {
        // Remove this specific reaction
        await supabase
            .from('reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .eq('reaction_type', reactionType);
      } else {
        // Check if user already has 2 reactions
        if (userReactions.length >= 2) {
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
      await _loadReactionsForPosts();
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating reaction: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  Future<void> _handlePostAction(
      String action, Map<String, dynamic> post) async {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    switch (action) {
      case 'share':
        // Use the share_plus package
        final postUrl = 'https://civicchatter.netlify.app/#/post/${post['id']}';
        try {
          await Share.share(
            'Check out this post on Civic Chatter: ${post['content']?.substring(0, 100) ?? ''}\n\n$postUrl',
            subject: 'Civic Chatter Post',
          );
        } catch (e) {
          debugPrint('Error sharing: $e');
        }
        break;

      case 'copy_link':
        final postUrl = 'https://civicchatter.netlify.app/#/post/${post['id']}';
        await Clipboard.setData(ClipboardData(text: postUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;

      case 'report':
        if (mounted) {
          _showReportDialog(post);
        }
        break;

      case 'edit':
        if (post['user_id'] == currentUserId) {
          if (mounted) {
            _showEditDialog(post);
          }
        }
        break;

      case 'delete':
        if (post['user_id'] == currentUserId) {
          if (mounted) {
            _showDeleteConfirmation(post);
          }
        }
        break;
    }
  }

  void _showReportDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Spam'),
              onTap: () {
                Navigator.pop(context);
                _submitReport(post['id'], 'spam');
              },
            ),
            ListTile(
              title: const Text('Harassment'),
              onTap: () {
                Navigator.pop(context);
                _submitReport(post['id'], 'harassment');
              },
            ),
            ListTile(
              title: const Text('Misinformation'),
              onTap: () {
                Navigator.pop(context);
                _submitReport(post['id'], 'misinformation');
              },
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () {
                Navigator.pop(context);
                _submitReport(post['id'], 'other');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(String postId, String reason) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('reports').insert({
        'post_id': postId,
        'user_id': supabase.auth.currentUser?.id,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Report submitted. Thank you for helping keep our community safe.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> post) {
    final controller = TextEditingController(text: post['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit your post...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updatePost(post['id'], controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePost(String postId, String newContent) async {
    if (newContent.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post content cannot be empty')),
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('posts')
          .update({'content': newContent.trim()}).eq('id', postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
      }

      await _loadPosts();
    } catch (e) {
      debugPrint('Error updating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(post['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      final supabase = Supabase.instance.client;

      // Delete reactions first
      await supabase.from('reactions').delete().eq('post_id', postId);

      // Delete comments
      await supabase.from('comments').delete().eq('post_id', postId);

      // Delete the post
      await supabase.from('posts').delete().eq('id', postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }

      await _loadPosts();
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedFile = image;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected: ${image.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      if (video != null) {
        setState(() {
          _selectedFile = video;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected: ${video.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePostTypeChange(String? value) {
    if (value == null) return;

    setState(() {
      _selectedPostType = value;
      _selectedFile = null;
    });

    switch (value) {
      case 'Photo':
        _pickImage();
        break;
      case 'Video':
        _pickVideo();
        break;
      case 'Livestream':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livestream feature coming soon!'),
            backgroundColor: Colors.purple,
          ),
        );
        break;
      case 'File':
      case 'Document':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$value upload coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
    }
  }

  Future<void> _submitPost() async {
    if (_quillController == null) return;

    final plainText = _quillController!.document.toPlainText().trim();

    if (_selectedPostType == 'Text Post' && plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some content'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if ((_selectedPostType == 'Photo' || _selectedPostType == 'Video') &&
        _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a ${_selectedPostType.toLowerCase()}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;

      if (user == null) {
        throw Exception('You must be logged in to post');
      }

      // Get the Supabase client
      final supabase = Supabase.instance.client;

      debugPrint('Attempting to insert post for user: ${user.id}');
      debugPrint('Content length: ${plainText.length}');
      debugPrint('Post type: $_selectedPostType');

      // Insert post into database
      final response = await supabase.from('posts').insert({
        'user_id': user.id,
        'content': plainText,
        'media_url': _selectedFile?.path,
        'media_type': _selectedPostType,
        'is_private': _isPrivatePost,
      }).select();

      debugPrint('Insert response: $response');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_isPrivatePost ? "Private" : "Public"} post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _quillController?.clear();
        _selectedFile = null;
        _isPrivatePost = false; // Reset privacy toggle after posting
      });

      // Reload posts to show the new one
      await _loadPosts();
    } catch (e, stackTrace) {
      debugPrint('Error posting: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    return [
      const DropdownMenuItem(
        value: 'Text Post',
        child: Row(
          children: [
            Icon(Icons.text_fields, size: 20),
            SizedBox(width: 8),
            Text('Text Post'),
          ],
        ),
      ),
      const DropdownMenuItem(
        value: 'Video',
        child: Row(
          children: [
            Icon(Icons.video_library, size: 20),
            SizedBox(width: 8),
            Text('Video'),
          ],
        ),
      ),
      const DropdownMenuItem(
        value: 'Livestream',
        child: Row(
          children: [
            Icon(Icons.videocam, size: 20),
            SizedBox(width: 8),
            Text('Livestream'),
          ],
        ),
      ),
      const DropdownMenuItem(
        value: 'Photo',
        child: Row(
          children: [
            Icon(Icons.photo_library, size: 20),
            SizedBox(width: 8),
            Text('Photo'),
          ],
        ),
      ),
      const DropdownMenuItem(
        value: 'File',
        child: Row(
          children: [
            Icon(Icons.insert_drive_file, size: 20),
            SizedBox(width: 8),
            Text('File'),
          ],
        ),
      ),
      const DropdownMenuItem(
        value: 'Document',
        child: Row(
          children: [
            Icon(Icons.description, size: 20),
            SizedBox(width: 8),
            Text('Document'),
          ],
        ),
      ),
    ];
  }

  Widget _buildToolbarButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  IconData _getPostTypeIcon(String postType) {
    switch (postType) {
      case 'Text Post':
        return Icons.text_fields;
      case 'Video':
        return Icons.video_library;
      case 'Livestream':
        return Icons.videocam;
      case 'Photo':
        return Icons.photo_library;
      case 'File':
        return Icons.insert_drive_file;
      case 'Document':
        return Icons.description;
      default:
        return Icons.post_add;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: CivicChatterAppBar(
          title: 'Home',
          showBackButton: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive: constrain max width on large screens (web/tablet)
            final isLargeScreen = constraints.maxWidth > 900;
            final showMessageCenter = constraints.maxWidth > 1000;
            final showNotifications = constraints.maxWidth > 1200;
            final maxWidth = isLargeScreen ? 800.0 : double.infinity;
            final horizontalPadding = isLargeScreen ? 24.0 : 16.0;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notifications panel
                if (showNotifications) ...[
                  SizedBox(
                    width: _notificationsPanelWidth,
                    child: const NotificationsPanel(),
                  ),
                  // Draggable divider for notifications
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) {
                        setState(() => _isResizingNotifications = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _notificationsPanelWidth =
                              (_notificationsPanelWidth + details.delta.dx)
                                  .clamp(200.0, 400.0);
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        setState(() => _isResizingNotifications = false);
                      },
                      child: Container(
                        width: 8,
                        color: _isResizingNotifications
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5)
                            : Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 2,
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // Posts feed
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Rich Text Editor Toolbar (Custom)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          _buildToolbarButton(
                                              Icons.format_bold, 'Bold', () {
                                            _quillController?.formatSelection(
                                                Attribute.bold);
                                          }),
                                          _buildToolbarButton(
                                              Icons.format_italic, 'Italic',
                                              () {
                                            _quillController?.formatSelection(
                                                Attribute.italic);
                                          }),
                                          _buildToolbarButton(
                                              Icons.format_underlined,
                                              'Underline', () {
                                            _quillController?.formatSelection(
                                                Attribute.underline);
                                          }),
                                          _buildToolbarButton(
                                              Icons.format_strikethrough,
                                              'Strike', () {
                                            _quillController?.formatSelection(
                                                Attribute.strikeThrough);
                                          }),
                                          const VerticalDivider(),
                                          _buildToolbarButton(
                                              Icons.format_align_left, 'Left',
                                              () {
                                            _quillController?.formatSelection(
                                                Attribute.leftAlignment);
                                          }),
                                          _buildToolbarButton(
                                              Icons.format_align_center,
                                              'Center', () {
                                            _quillController?.formatSelection(
                                                Attribute.centerAlignment);
                                          }),
                                          _buildToolbarButton(
                                              Icons.format_align_right, 'Right',
                                              () {
                                            _quillController?.formatSelection(
                                                Attribute.rightAlignment);
                                          }),
                                          const VerticalDivider(),
                                          _buildToolbarButton(
                                              Icons.format_list_bulleted,
                                              'Bullets', () {
                                            _quillController
                                                ?.formatSelection(Attribute.ul);
                                          }),
                                          _buildToolbarButton(
                                              Icons.format_list_numbered,
                                              'Numbers', () {
                                            _quillController
                                                ?.formatSelection(Attribute.ol);
                                          }),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Rich Text Editor
                                    if (_quillController != null)
                                      Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                Theme.of(context).dividerColor,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: QuillEditor.basic(
                                          controller: _quillController!,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    if (_selectedFile != null)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border:
                                              Border.all(color: Colors.green),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getPostTypeIcon(
                                                  _selectedPostType),
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Selected: ${_selectedFile!.name}',
                                                style: const TextStyle(
                                                    color: Colors.green),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _selectedFile = null;
                                                });
                                              },
                                              tooltip: 'Remove',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_selectedFile != null)
                                      const SizedBox(height: 12),
                                    // Privacy Toggle
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isPrivatePost
                                                ? Icons.lock
                                                : Icons.public,
                                            size: 20,
                                            color: _isPrivatePost
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _isPrivatePost
                                                  ? 'Private Post'
                                                  : 'Public Post',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                          Switch(
                                            value: _isPrivatePost,
                                            onChanged: (value) {
                                              setState(() {
                                                _isPrivatePost = value;
                                              });
                                            },
                                            activeColor: Colors.orange,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Responsive button layout
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isSmallScreen =
                                            constraints.maxWidth < 500;

                                        if (isSmallScreen) {
                                          // Stack vertically on mobile
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              DropdownButtonFormField<String>(
                                                value: _selectedPostType,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                                  prefixIcon: Icon(
                                                    _getPostTypeIcon(
                                                        _selectedPostType),
                                                    size: 20,
                                                  ),
                                                ),
                                                items: _buildDropdownItems(),
                                                onChanged:
                                                    _handlePostTypeChange,
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 48,
                                                child: ElevatedButton(
                                                  onPressed: _submitPost,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Theme.of(
                                                                    context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? const Color(
                                                            0xFF3B82F6)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 4,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Submit',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          // Row layout on larger screens
                                          return Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: DropdownButtonFormField<
                                                    String>(
                                                  value: _selectedPostType,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 12,
                                                      vertical: 14,
                                                    ),
                                                    prefixIcon: Icon(
                                                      _getPostTypeIcon(
                                                          _selectedPostType),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  items: _buildDropdownItems(),
                                                  onChanged:
                                                      _handlePostTypeChange,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                flex: 1,
                                                child: ElevatedButton(
                                                  onPressed: _submitPost,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 16),
                                                    backgroundColor: Theme.of(
                                                                    context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? const Color(
                                                            0xFF3B82F6)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 4,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Submit',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Filter and Sort Bar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Privacy Filter Button
                                  Expanded(
                                    child: PopupMenuButton<String>(
                                      initialValue: _filterBy,
                                      onSelected: (value) {
                                        setState(() {
                                          _filterBy = value;
                                        });
                                        _loadPosts();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                Theme.of(context).dividerColor,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.visibility,
                                                size: 18),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '${_filterBy == 'all' ? 'All' : _filterBy == 'public' ? 'Public' : 'Private'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'all',
                                          child: Row(
                                            children: [
                                              Icon(Icons.public),
                                              SizedBox(width: 8),
                                              Text('All Posts'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'public',
                                          child: Row(
                                            children: [
                                              Icon(Icons.public),
                                              SizedBox(width: 8),
                                              Text('Public Only'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'private',
                                          child: Row(
                                            children: [
                                              Icon(Icons.lock),
                                              SizedBox(width: 8),
                                              Text('Private Only'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Post Type Filter Button
                                  Expanded(
                                    child: PopupMenuButton<String>(
                                      initialValue: _postTypeFilter,
                                      onSelected: (value) {
                                        setState(() {
                                          _postTypeFilter = value;
                                        });
                                        _loadPosts();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                Theme.of(context).dividerColor,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                _getPostTypeIcon(
                                                    _postTypeFilter),
                                                size: 18),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                _postTypeFilter == 'all'
                                                    ? 'Type'
                                                    : _postTypeFilter
                                                        .replaceAll(
                                                            ' Post', ''),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'all',
                                          child: Row(
                                            children: [
                                              Icon(Icons.all_inclusive),
                                              SizedBox(width: 8),
                                              Text('All Types'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Text Post',
                                          child: Row(
                                            children: [
                                              Icon(Icons.text_fields),
                                              SizedBox(width: 8),
                                              Text('Text Posts'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Photo',
                                          child: Row(
                                            children: [
                                              Icon(Icons.photo),
                                              SizedBox(width: 8),
                                              Text('Photos'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Video',
                                          child: Row(
                                            children: [
                                              Icon(Icons.videocam),
                                              SizedBox(width: 8),
                                              Text('Videos'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Link',
                                          child: Row(
                                            children: [
                                              Icon(Icons.link),
                                              SizedBox(width: 8),
                                              Text('Links'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Poll',
                                          child: Row(
                                            children: [
                                              Icon(Icons.poll),
                                              SizedBox(width: 8),
                                              Text('Polls'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Sort Button
                                  Expanded(
                                    child: PopupMenuButton<String>(
                                      initialValue: _sortBy,
                                      onSelected: (value) {
                                        setState(() {
                                          _sortBy = value;
                                        });
                                        _loadPosts();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                Theme.of(context).dividerColor,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.sort, size: 18),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '${_sortBy == 'newest' ? 'Newest' : _sortBy == 'oldest' ? 'Oldest' : 'Popular'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'newest',
                                          child: Row(
                                            children: [
                                              Icon(Icons.new_releases),
                                              SizedBox(width: 8),
                                              Text('Newest First'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'oldest',
                                          child: Row(
                                            children: [
                                              Icon(Icons.history),
                                              SizedBox(width: 8),
                                              Text('Oldest First'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'popular',
                                          child: Row(
                                            children: [
                                              Icon(Icons.trending_up),
                                              SizedBox(width: 8),
                                              Text('Most Popular'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Posts List
                            if (_isLoadingPosts)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_posts.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.feed,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No posts yet',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Create your first post to get started!',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey[600],
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
                                itemCount: _posts.length,
                                itemBuilder: (context, index) {
                                  final post = _posts[index];
                                  final profile = post['profiles'];
                                  final displayName = profile != null
                                      ? (profile['display_name'] ??
                                          profile['handle'] ??
                                          'Unknown User')
                                      : 'Unknown User';
                                  final createdAt =
                                      DateTime.parse(post['created_at']);
                                  final timestamp = _formatTimestamp(createdAt);
                                  final isPrivate = post['is_private'] ?? false;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PostDetailScreen(post: post),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: profile !=
                                                              null &&
                                                          profile['avatar_url'] !=
                                                              null
                                                      ? NetworkImage(
                                                          profile['avatar_url'])
                                                      : null,
                                                  child: profile == null ||
                                                          profile['avatar_url'] ==
                                                              null
                                                      ? Text(displayName[0]
                                                          .toUpperCase())
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        displayName,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                      Text(
                                                        timestamp,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    if (post['media_type'] !=
                                                        null)
                                                      Chip(
                                                        label: Text(
                                                            post['media_type']),
                                                        padding:
                                                            EdgeInsets.zero,
                                                      ),
                                                    const SizedBox(height: 4),
                                                    Chip(
                                                      label: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            isPrivate
                                                                ? Icons.lock
                                                                : Icons.public,
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(isPrivate
                                                              ? 'Private'
                                                              : 'Public'),
                                                        ],
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
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
                                              post['content'] ?? '',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                            const SizedBox(height: 12),

                                            // Reaction Bar
                                            _buildReactionBar(post['id']),

                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.comment_outlined,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'View comments',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                const Spacer(),
                                                PopupMenuButton<String>(
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey[600],
                                                    size: 20,
                                                  ),
                                                  onSelected: (value) =>
                                                      _handlePostAction(
                                                          value, post),
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'share',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.share),
                                                          SizedBox(width: 12),
                                                          Text('Share'),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'copy_link',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.link),
                                                          SizedBox(width: 12),
                                                          Text('Copy Link'),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'report',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.flag),
                                                          SizedBox(width: 12),
                                                          Text('Report'),
                                                        ],
                                                      ),
                                                    ),
                                                    if (post['user_id'] ==
                                                        Supabase
                                                            .instance
                                                            .client
                                                            .auth
                                                            .currentUser
                                                            ?.id) ...[
                                                      const PopupMenuDivider(),
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.edit),
                                                            SizedBox(width: 12),
                                                            Text('Edit'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.delete,
                                                                color:
                                                                    Colors.red),
                                                            SizedBox(width: 12),
                                                            Text('Delete',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (showMessageCenter) ...[
                  // Draggable divider
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) {
                        setState(() => _isResizing = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _messageCenterWidth =
                              (_messageCenterWidth - details.delta.dx)
                                  .clamp(200.0, 600.0);
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        setState(() => _isResizing = false);
                      },
                      child: Container(
                        width: 8,
                        color: _isResizing
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5)
                            : Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 2,
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Message center with dynamic width
                  SizedBox(
                    width: _messageCenterWidth,
                    child: const MessageCenter(),
                  ),
                ],
              ],
            );
          },
        ),
      ), // Close CustomBackground
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    // Convert to local time
    final localTime = dateTime.toLocal();

    // Format: "2025-11-17 14:30:45 PST" (24-hour format with timezone)
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDate = dateFormat.format(localTime);

    // Get timezone abbreviation
    final timezone = localTime.timeZoneName;

    return '$formattedDate $timezone';
  }

  Widget _buildReactionBar(String postId) {
    final reactions = _postReactions[postId] ?? {};
    final userReactions = _userReactions[postId] ?? {};

    final reactionButtons = [
      {'type': 'like', 'emoji': '👍', 'label': 'Like'},
      {'type': 'love', 'emoji': '❤️', 'label': 'Love'},
      {'type': 'laugh', 'emoji': '😂', 'label': 'Laugh'},
      {'type': 'wow', 'emoji': '😮', 'label': 'Wow'},
      {'type': 'sad', 'emoji': '😢', 'label': 'Sad'},
      {'type': 'angry', 'emoji': '😠', 'label': 'Angry'},
    ];

    // Collect custom reactions for this post
    final customReactions = reactions.keys
        .where((key) => key.startsWith('custom_'))
        .map((key) => key.substring(7)) // Remove 'custom_' prefix
        .toList();

    // Calculate total reactions
    int totalReactions = 0;
    for (var count in reactions.values) {
      totalReactions += count;
    }

    // Build display for user's reactions (can be up to 2)
    String userReactionDisplay = '👍';
    String userReactionLabel = 'React';

    if (userReactions.isNotEmpty) {
      // Show the emojis of user's reactions
      final emojis = <String>[];
      for (var reaction in userReactions) {
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
              _showCustomReactionPicker(postId);
            } else if (value.startsWith('custom_')) {
              final emoji = value.substring(7);
              _toggleCustomReaction(postId, emoji);
            } else {
              _toggleReaction(postId, value);
            }
          },
          itemBuilder: (context) => [
            // Standard reactions
            ...reactionButtons.map((reaction) {
              final type = reaction['type'] as String;
              final emoji = reaction['emoji'] as String;
              final label = reaction['label'] as String;
              final count = reactions[type] ?? 0;
              final isSelected = userReactions.contains(type);

              return PopupMenuItem<String>(
                value: type,
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
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

            // Divider before custom reactions if any exist
            if (customReactions.isNotEmpty) const PopupMenuDivider(),

            // Custom reactions that have been used
            ...customReactions.map((emoji) {
              final customKey = 'custom_$emoji';
              final count = reactions[customKey] ?? 0;
              final isSelected = userReactions.contains(customKey);

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
              color: userReactions.isNotEmpty
                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                  : Theme.of(context).cardColor,
              border: Border.all(
                color: userReactions.isNotEmpty
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).dividerColor,
                width: userReactions.isNotEmpty ? 2 : 1,
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
                        color: userReactions.isNotEmpty
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: userReactions.isNotEmpty
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

  void _showCustomReactionPicker(String postId) {
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
                _toggleCustomReaction(postId, emoji);
              }
            },
            child: const Text('Add Reaction'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCustomReaction(String postId, String emoji) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final userReactions = _userReactions[postId] ?? {};
      final customKey = 'custom_$emoji';

      // Check if user already has this custom reaction
      if (userReactions.contains(customKey)) {
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
        if (userReactions.length >= 2) {
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
      await _loadReactionsForPosts();
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
