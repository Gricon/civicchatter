import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'image_processing_service.dart';

class StorageService {
  static final _supabase = Supabase.instance.client;

  static Future<String> uploadAvatar({
    required String userId,
    required File file,
    bool cartoonize = true,
  }) async {
    File fileToUpload = file;

    // Cartoonize the image if requested
    if (cartoonize) {
      try {
        fileToUpload = await ImageProcessingService.cartoonizeImage(file);
      } catch (e) {
        // If cartoonization fails, use original image
        print('Cartoonization failed, using original image: $e');
      }
    }

    final fileExt = 'png'; // Always use PNG for processed images
    final fileName = '$userId.$fileExt';
    final filePath = 'avatars/$fileName';

    await _supabase.storage.from(SupabaseConfig.storageBucket).upload(
          filePath,
          fileToUpload,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _supabase.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl(filePath);

    // Clean up temp file if it was created
    if (cartoonize && fileToUpload.path != file.path) {
      try {
        await fileToUpload.delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    }

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
