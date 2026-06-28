import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inquiry_model.dart';

class InquiryService {
  InquiryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Creates an inquiry. carId is optional (a general question doesn't
  /// have to be about a specific car) and customer_id is left null for
  /// guests, since the inquiry form doesn't require authentication.
  Future<void> createInquiry({
    String? carId,
    required String name,
    required String email,
    String? phone,
    required String subject,
    required String message,
  }) async {
    await _client.from('inquiries').insert({
      'car_id': carId,
      'customer_id': _userId,
      'name': name,
      'email': email,
      'phone': phone,
      'subject': subject,
      'message': message,
      'is_read': false,
      'status': 'pending',
    });
  }

  /// All inquiries submitted by the signed-in customer, most recent
  /// first. Guest inquiries (customer_id null) aren't retrievable here
  /// since there's no account to attach them to.
  Future<List<InquiryModel>> fetchMyInquiries() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('inquiries')
        .select('*, cars(make, model, year)')
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => InquiryModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}