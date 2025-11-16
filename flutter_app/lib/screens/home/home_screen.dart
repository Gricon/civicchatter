import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/civic_chatter_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showPrivatePosts = false;
  String _selectedPostType = 'Text Post';
  final TextEditingController _contentController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: CivicChatterAppBar(
        title: 'Home',
        showBackButton: false,
        actions: [
          // Private/Public Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Public',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: _showPrivatePosts
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: _showPrivatePosts
                            ? Theme.of(context).textTheme.bodyMedium?.color
                            : Theme.of(context).colorScheme.primary,
                      ),
                ),
                Switch(
                  value: _showPrivatePosts,
                  onChanged: (value) {
                    setState(() {
                      _showPrivatePosts = value;
                    });
                  },
                ),
                Text(
                  'Private',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: _showPrivatePosts
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _showPrivatePosts
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              _showPrivatePosts ? 'Private Posts' : 'Public Posts',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (user != null)
              Text(
                _showPrivatePosts
                    ? 'Posts visible only to your friends'
                    : 'Posts visible to everyone',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _showPrivatePosts ? Colors.orange : Colors.green,
                    ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            // Create Post Box
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Content Input
                    TextField(
                      controller: _contentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dropdown and Submit Button Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedPostType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              prefixIcon: Icon(
                                _getPostTypeIcon(_selectedPostType),
                                size: 20,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Text Post',
                                child: Text('Text Post'),
                              ),
                              DropdownMenuItem(
                                value: 'Video',
                                child: Text('Video'),
                              ),
                              DropdownMenuItem(
                                value: 'Livestream',
                                child: Text('Livestream'),
                              ),
                              DropdownMenuItem(
                                value: 'Photo',
                                child: Text('Photo'),
                              ),
                              DropdownMenuItem(
                                value: 'File',
                                child: Text('File'),
                              ),
                              DropdownMenuItem(
                                value: 'Document',
                                child: Text('Document'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPostType = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_contentController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter some content'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Posting $_selectedPostType as ${_showPrivatePosts ? "Private" : "Public"}...',
                                  ),
                                ),
                              );
                              _contentController.clear();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Posts Feed Placeholder
            Text(
              'Recent Posts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first post to get started!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
}
