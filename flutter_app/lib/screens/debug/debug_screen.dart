import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _status = 'Not tested';
  bool _isTesting = false;

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _status = 'Testing...';
    });

    final results = <String>[];

    try {
      // Test 1: Check Supabase URL
      results.add('✓ Supabase URL: ${SupabaseConfig.url}');

      // Test 2: Try to connect to Supabase
      final supabase = Supabase.instance.client;
      results.add('✓ Supabase client initialized');

      // Test 3: Try a simple query
      try {
        final response =
            await supabase.from('profiles_public').select('id').limit(1);
        results.add('✓ Database connection successful');
        results.add('  Response: ${response.length} records');
      } catch (e) {
        results.add('✗ Database query failed: ${e.toString()}');
      }

      // Test 4: Check auth status
      final user = supabase.auth.currentUser;
      if (user != null) {
        results.add('✓ User logged in: ${user.email}');
      } else {
        results.add('○ No user logged in');
      }

      setState(() {
        _status = results.join('\n');
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _status = '✗ Connection test failed:\n${e.toString()}';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Civic Chatter Debug',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isTesting ? null : _testConnection,
              child: _isTesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test Connection'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
