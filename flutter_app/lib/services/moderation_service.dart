import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationService {
  static final _supabase = Supabase.instance.client;

  // Block a user
  static Future<void> blockUser({
    required String blockedUserId,
    String? reason,
  }) async {
    await _supabase.from('blocked_users').insert({
      'blocker_id': _supabase.auth.currentUser!.id,
      'blocked_id': blockedUserId,
      'reason': reason,
    });
  }

  // Unblock a user
  static Future<void> unblockUser(String blockedUserId) async {
    await _supabase
        .from('blocked_users')
        .delete()
        .eq('blocker_id', _supabase.auth.currentUser!.id)
        .eq('blocked_id', blockedUserId);
  }

  // Check if user is blocked
  static Future<bool> isUserBlocked(String userId) async {
    final result = await _supabase
        .from('blocked_users')
        .select('id')
        .eq('blocker_id', _supabase.auth.currentUser!.id)
        .eq('blocked_id', userId)
        .maybeSingle();
    return result != null;
  }

  // Report a threat to law enforcement
  static Future<void> reportThreat({
    required String reportedUserId,
    String? postId,
    String? commentId,
    required String
        threatType, // 'physical', 'harassment', 'hate_speech', 'other'
    required String description,
  }) async {
    if (postId == null && commentId == null) {
      throw Exception('Either postId or commentId must be provided');
    }

    await _supabase.from('threat_reports').insert({
      'reporter_id': _supabase.auth.currentUser!.id,
      'reported_user_id': reportedUserId,
      'post_id': postId,
      'comment_id': commentId,
      'threat_type': threatType,
      'description': description,
    });

    // Note: In production, trigger an Edge Function to send email to law enforcement.
    // For now, admins can query the threat_reports table.
  }

  // Get list of blocked users
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final result = await _supabase
        .from('blocked_users')
        .select(
            'blocked_id, profiles_public!blocked_users_blocked_id_fkey(id, handle, display_name, avatar_url)')
        .eq('blocker_id', _supabase.auth.currentUser!.id);
    return List<Map<String, dynamic>>.from(result);
  }
}
