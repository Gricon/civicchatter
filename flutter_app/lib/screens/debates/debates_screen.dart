import 'package:flutter/material.dart';
import '../../widgets/civic_chatter_app_bar.dart';
import '../../widgets/custom_background.dart';
import '../../widgets/app_drawer.dart';

class DebatesScreen extends StatefulWidget {
  const DebatesScreen({super.key});

  @override
  State<DebatesScreen> createState() => _DebatesScreenState();
}

class _DebatesScreenState extends State<DebatesScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CivicChatterAppBar(
          title: 'Debates',
          showBackButton: false,
        ),
        drawer: isMobile ? const AppDrawer() : null,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.forum,
                    size: 80,
                    color: Color(0xFF002868),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Debates',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Debate features coming soon!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'This section will include:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.list),
                            title: Text('Your debates list'),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.add),
                            title: Text('Create new debates'),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.message),
                            title: Text('Post and comment'),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.people),
                            title: Text('Invite participants'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Create debate feature coming soon!'),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
