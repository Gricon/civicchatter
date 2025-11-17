import 'package:flutter/material.dart';
import '../services/moderation_service.dart';

class ReportBlockDialog extends StatefulWidget {
  final String reportedUserId;
  final String reportedUsername;
  final String? postId;
  final String? commentId;

  const ReportBlockDialog({
    super.key,
    required this.reportedUserId,
    required this.reportedUsername,
    this.postId,
    this.commentId,
  });

  @override
  State<ReportBlockDialog> createState() => _ReportBlockDialogState();
}

class _ReportBlockDialogState extends State<ReportBlockDialog> {
  String _selectedAction = 'block';
  String _threatType = 'physical';
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    try {
      if (_selectedAction == 'block') {
        await ModerationService.blockUser(
          blockedUserId: widget.reportedUserId,
          reason: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Blocked ${widget.reportedUsername}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (_selectedAction == 'report') {
        if (_descriptionController.text.isEmpty) {
          throw Exception('Please provide a description of the threat');
        }
        await ModerationService.reportThreat(
          reportedUserId: widget.reportedUserId,
          postId: widget.postId,
          commentId: widget.commentId,
          threatType: _threatType,
          description: _descriptionController.text,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Report submitted. Law enforcement will be notified for physical threats.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report or Block ${widget.reportedUsername}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action selection
            RadioListTile<String>(
              title: const Text('Block User'),
              subtitle: const Text('Hide all content from this user'),
              value: 'block',
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value!),
            ),
            RadioListTile<String>(
              title: const Text('Report Threat'),
              subtitle: const Text('Report to law enforcement'),
              value: 'report',
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value!),
            ),
            const SizedBox(height: 16),

            // Threat type (only for reports)
            if (_selectedAction == 'report') ...[
              const Text(
                'Threat Type:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _threatType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'physical', child: Text('Physical Threat')),
                  DropdownMenuItem(
                      value: 'harassment', child: Text('Harassment')),
                  DropdownMenuItem(
                      value: 'hate_speech', child: Text('Hate Speech')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _threatType = value!),
              ),
              const SizedBox(height: 16),
            ],

            // Description
            Text(
              _selectedAction == 'report'
                  ? 'Description (required):'
                  : 'Reason (optional):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _selectedAction == 'report'
                    ? 'Describe the threat in detail...'
                    : 'Optional reason for blocking...',
              ),
              maxLines: 4,
            ),

            if (_selectedAction == 'report') ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ Physical threats will be reported to law enforcement via email.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _selectedAction == 'report' ? Colors.red : Colors.orange,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_selectedAction == 'report' ? 'Report' : 'Block'),
        ),
      ],
    );
  }
}
