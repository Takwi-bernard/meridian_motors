import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reservation_model.dart';

class ReservationService {
  ReservationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Creates a new reservation, always as "pending" — approval happens
  /// on the admin side, never client-side.
  Future<void> createReservation({
    required String carId,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    required DateTime reservationDate,
    String? notes,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Must be signed in to reserve a car.');
    }

    await _client.from('reservations').insert({
      'car_id': carId,
      'customer_id': userId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
      'reservation_date': reservationDate.toIso8601String(),
      'status': 'pending',
      'notes': notes,
    });
  }

  /// All reservations for the signed-in customer, most recent first,
  /// with the related car's make/model/year joined in for display.
  Future<List<ReservationModel>> fetchMyReservations() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('reservations')
        .select('*, cars(make, model, year)')
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => ReservationModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Whether the current user already has a pending or approved
  /// reservation on this car, so the Car Detail page can avoid letting
  /// someone submit duplicate requests for the same vehicle.
  Future<bool> hasActiveReservation(String carId) async {
    final userId = _userId;
    if (userId == null) return false;

    final response = await _client
        .from('reservations')
        .select('id')
        .eq('customer_id', userId)
        .eq('car_id', carId)
        .inFilter('status', ['pending', 'approved'])
        .limit(1);

    return (response as List).isNotEmpty;
  }
}