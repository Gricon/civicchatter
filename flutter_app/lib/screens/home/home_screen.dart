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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.forum,
                size: 100,
                color: Color(0xFF002868),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Civic Chatter!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (user != null) ...[
                Text(
                  'Logged in as: ${user.email}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('My Profile'),
                          subtitle: const Text('Edit your profile details'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => context.go('/profile'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.public),
                          title: const Text('Public Profile'),
                          subtitle: const Text('View how others see you'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // TODO: Get user's handle and navigate
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loading your public profile...'),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.forum),
                          title: const Text('Debates'),
                          subtitle: const Text('View and manage debates'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => context.go('/debates'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Settings'),
                          subtitle: const Text('Customize your experience'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => context.go('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
