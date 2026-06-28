import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Signs up a new customer and creates their profile row.
  ///
  /// The role is always written explicitly as 'customer' here — this
  /// screen is customer-only. Admin accounts are created through the
  /// admin module, never through this flow.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;

    if (user == null) {
      throw Exception('Sign up did not return a user. Please try again.');
    }

    await _client.from('profiles').insert({
      'id': user.id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': 'customer',
      'is_active': true,
    });
  }
}