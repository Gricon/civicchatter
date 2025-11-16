import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _supabase = Supabase.instance.client;

  static Future<void> createInitialRecords({
    required String userId,
    required String handle,
    required String name,
    required String email,
    String? phone,
    String? address,
    bool isPrivate = false,
  }) async {
    // Create public profile
    await _supabase.from('profiles_public').upsert({
      'id': userId,
      'handle': handle,
      'display_name': name,
      'bio': null,
      'city': null,
      'avatar_url': null,
      'is_private': isPrivate,
      'is_searchable': !isPrivate,
    }, onConflict: 'id');

    // Create private profile
    await _supabase.from('profiles_private').upsert({
      'id': userId,
      'email': email,
      'phone': phone,
      'address': address,
      'preferred_contact': phone != null ? 'sms' : 'email',
    }, onConflict: 'id');

    // Create debate page
    await _supabase.from('debate_pages').upsert({
      'id': userId,
      'title': '$name\'s Debate Page',
      'description': 'Welcome to my debate page',
    }, onConflict: 'id');
  }

  static Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final response = await _supabase
        .from('profiles_public')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  static Future<Map<String, dynamic>> getPrivateProfile(String userId) async {
    final response = await _supabase
        .from('profiles_private')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  static Future<Map<String, dynamic>> getProfileByHandle(String handle) async {
    final response = await _supabase
        .from('profiles_public')
        .select()
        .eq('handle', handle.toLowerCase())
        .single();
    return response;
  }

  static Future<void> updatePublicProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? city,
    String? avatarUrl,
    bool? isPrivate,
  }) async {
    final updates = <String, dynamic>{};

    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isPrivate != null) {
      updates['is_private'] = isPrivate;
      updates['is_searchable'] = !isPrivate;
    }

    await _supabase.from('profiles_public').update(updates).eq('id', userId);
  }

  static Future<void> updatePrivateProfile({
    required String userId,
    String? email,
    String? phone,
    String? address,
    String? preferredContact,
  }) async {
    final updates = <String, dynamic>{};

    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (preferredContact != null) {
      updates['preferred_contact'] = preferredContact;
    }

    await _supabase.from('profiles_private').update(updates).eq('id', userId);
  }
}
