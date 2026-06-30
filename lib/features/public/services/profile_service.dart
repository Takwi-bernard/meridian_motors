import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> fetchProfile() async {
    final userId = _userId;
    if (userId == null) return null;
    return await _client.from('profiles').select().eq('id', userId).maybeSingle();
  }

  Future<void> updateProfile({required String fullName, String? phone}) async {
    final userId = _userId;
    if (userId == null) throw Exception('Must be signed in.');

    await _client.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Uploads [bytes] to the profile-images bucket under a path scoped to
  /// the current user (so the storage RLS policy `(storage.foldername
  /// (name))[1] = auth.uid()::text` accepts it), then saves the
  /// resulting public URL on the profile row.
  ///
  /// Assumes the bucket is marked public in Supabase. If you make it
  /// private instead, swap getPublicUrl for createSignedUrl.
  Future<String> uploadAvatar(Uint8List bytes, String fileExtension) async {
    final userId = _userId;
    if (userId == null) throw Exception('Must be signed in.');

    final path = '$userId/avatar.$fileExtension';

    await _client.storage.from('profile-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from('profile-images').getPublicUrl(path);

    await _client.from('profiles').update({
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    return publicUrl;
  }

  /// Lightweight counts for the activity row on the Profile page.
  Future<Map<String, int>> fetchActivityCounts() async {
    final userId = _userId;
    if (userId == null) return {'favorites': 0, 'reservations': 0, 'inquiries': 0};

    final favorites = await _client.from('favorites').select('id').eq('user_id', userId);
    final reservations = await _client.from('reservations').select('id').eq('customer_id', userId);
    final inquiries = await _client.from('inquiries').select('id').eq('customer_id', userId);

    return {
      'favorites': (favorites as List).length,
      'reservations': (reservations as List).length,
      'inquiries': (inquiries as List).length,
    };
  }
}
