import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<NotificationModel>> fetchMyNotifications() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => NotificationModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final userId = _userId;
    if (userId == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('customer_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  Future<void> markAsRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('customer_id', userId)
        .eq('is_read', false);
  }
}
