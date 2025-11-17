import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
  XFile? _selectedFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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
    final content = _contentController.text.trim();

    if (_selectedPostType == 'Text Post' && content.isEmpty) {
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

    String message = 'Posting $_selectedPostType';
    if (_selectedFile != null) {
      message += ' (${_selectedFile!.name})';
    }
    message += ' as ${_showPrivatePosts ? "Private" : "Public"}...';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    setState(() {
      _contentController.clear();
      _selectedFile = null;
    });
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
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: CivicChatterAppBar(
        title: 'Home',
        showBackButton: false,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _handleLogout,
                tooltip: 'Logout',
              ),
              // Public/Private Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Public',
                      style: TextStyle(
                        fontSize: 12,
                        color: !_showPrivatePosts
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: !_showPrivatePosts
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _showPrivatePosts,
                        onChanged: (value) {
                          setState(() {
                            _showPrivatePosts = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Private',
                      style: TextStyle(
                        fontSize: 12,
                        color: _showPrivatePosts
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _showPrivatePosts
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: constrain max width on large screens (web/tablet)
          final isLargeScreen = constraints.maxWidth > 900;
          final maxWidth = isLargeScreen ? 800.0 : double.infinity;
          final horizontalPadding = isLargeScreen ? 24.0 : 16.0;

          return SingleChildScrollView(
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
                    Text(
                      _showPrivatePosts ? 'Private Posts' : 'Public Posts',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                              color: _showPrivatePosts
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _contentController,
                              maxLines: 4,
                              minLines: 2,
                              decoration: InputDecoration(
                                hintText: 'What\'s on your mind?',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedFile != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getPostTypeIcon(_selectedPostType),
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
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedFile = null;
                                        });
                                      },
                                      tooltip: 'Remove',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedFile != null)
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
                                                BorderRadius.circular(8),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                          ),
                                          prefixIcon: Icon(
                                            _getPostTypeIcon(_selectedPostType),
                                            size: 20,
                                          ),
                                        ),
                                        items: _buildDropdownItems(),
                                        onChanged: _handlePostTypeChange,
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed: _submitPost,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            foregroundColor: Colors.white,
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Submit',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
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
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedPostType,
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
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
                                          onChanged: _handlePostTypeChange,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: ElevatedButton(
                                          onPressed: _submitPost,
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            foregroundColor: Colors.white,
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Submit',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
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
            ),
          );
        },
      ),
    );
  }
}
