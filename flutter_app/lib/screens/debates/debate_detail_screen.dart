import 'package:flutter/material.dart';
import '../../widgets/civic_chatter_app_bar.dart';

class DebateDetailScreen extends StatelessWidget {
  final String debateId;

  const DebateDetailScreen({super.key, required this.debateId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CivicChatterAppBar(
        title: 'Debate #$debateId',
        showBackButton: true,
      ),
      body: Center(
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
                'Debate #$debateId',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Debate details coming soon!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
