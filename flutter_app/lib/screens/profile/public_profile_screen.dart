import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/profile_service.dart';
import '../../widgets/civic_chatter_app_bar.dart';

class PublicProfileScreen extends StatefulWidget {
  final String handle;

  const PublicProfileScreen({super.key, required this.handle});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await ProfileService.getProfileByHandle(widget.handle);
      setState(() {
        _profile = profile;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _profile = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CivicChatterAppBar(
        title: '@${widget.handle}',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Profile not found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _profile!['avatar_url'] != null
                            ? CachedNetworkImageProvider(
                                _profile!['avatar_url'])
                            : null,
                        child: _profile!['avatar_url'] == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Display name
                      Text(
                        _profile!['display_name'] ?? 'Unknown',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Handle
                      Text(
                        '@${_profile!['handle']}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                      ),

                      const SizedBox(height: 24),

                      // Bio
                      if (_profile!['bio'] != null &&
                          _profile!['bio'].toString().isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bio',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _profile!['bio'],
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // City
                      if (_profile!['city'] != null &&
                          _profile!['city'].toString().isNotEmpty) ...[
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_city),
                            title: const Text('City'),
                            subtitle: Text(_profile!['city']),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Privacy indicator
                      if (_profile!['is_private'] == true) ...[
                        Card(
                          color: Colors.orange[50],
                          child: const ListTile(
                            leading: Icon(Icons.lock, color: Colors.orange),
                            title: Text('Private Account'),
                            subtitle: Text('This profile is not searchable'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
