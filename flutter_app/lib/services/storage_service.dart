import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class StorageService {
  static final _supabase = Supabase.instance.client;

  static Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final fileExt = file.path.split('.').last;
    final fileName = '$userId.$fileExt';
    final filePath = 'avatars/$fileName';

    await _supabase.storage.from(SupabaseConfig.storageBucket).upload(
          filePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _supabase.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl(filePath);

    return publicUrl;
  }

  static Future<void> deleteAvatar(String userId) async {
    // Delete all possible avatar file extensions
    final extensions = ['jpg', 'jpeg', 'png', 'gif'];

    for (final ext in extensions) {
      try {
        await _supabase.storage
            .from(SupabaseConfig.storageBucket)
            .remove(['avatars/$userId.$ext']);
      } catch (e) {
        // Ignore errors - file might not exist
      }
    }
  }
}
