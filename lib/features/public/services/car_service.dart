import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';

/// All Supabase access for cars lives here. Widgets should never call
/// Supabase directly — they go through this service, so if the schema
/// changes (column rename, new status values, etc.) there's exactly
/// one place to fix it.
class CarService {
  CarService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// NOTE: adjust this if the admin module uses a different string
  /// for "visible to customers" (e.g. "active" / "published").
  static const String availableStatus = 'available';

  /// Fetches every car visible to the public, each with its ordered
  /// image list attached via the car_images foreign table.
  Future<List<CarModel>> fetchAvailableCars() async {
    final response = await _client
        .from('cars')
        .select('*, car_images(image_url, is_primary, display_order)')
        .eq('status', availableStatus)
        .order('featured', ascending: false)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => CarModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}