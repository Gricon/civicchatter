import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'image_processing_service.dart';

class StorageService {
  static final _supabase = Supabase.instance.client;

  static Future<String> uploadAvatar({
    required String userId,
    required XFile file,
    bool cartoonize = true,
  }) async {
    Uint8List fileBytes = await file.readAsBytes();

    // Cartoonize the image if requested
    if (cartoonize) {
      try {
        fileBytes = await ImageProcessingService.cartoonizeImage(fileBytes);
      } catch (e) {
        // If cartoonization fails, use original image
        debugPrint('Cartoonization failed, using original image: $e');
        fileBytes = await file.readAsBytes();
      }
    }

    const fileExt = 'png'; // Always use PNG for processed images
    final fileName = '$userId.$fileExt';
    final filePath = 'avatars/$fileName';

    await _supabase.storage.from(SupabaseConfig.storageBucket).uploadBinary(
          filePath,
          fileBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
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
