import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';

/// All Supabase access for favorites lives here, mirroring the pattern
/// used by CarService — widgets never talk to Supabase directly.
class FavoriteService {
  FavoriteService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Returns the set of car IDs the current user has favorited.
  /// Returns an empty set if nobody is signed in.
  Future<Set<String>> fetchFavoriteCarIds() async {
    final userId = _userId;
    if (userId == null) return {};

    final response =
        await _client.from('favorites').select('car_id').eq('user_id', userId);

    return (response as List<dynamic>)
        .map((row) => row['car_id'] as String)
        .toSet();
  }

  Future<void> addFavorite(String carId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Must be signed in to favorite a car.');
    }
    await _client.from('favorites').insert({
      'user_id': userId,
      'car_id': carId,
    });
  }

  Future<void> removeFavorite(String carId) async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('car_id', carId);
  }

  Future<void> toggleFavorite(String carId, {required bool isCurrentlyFavorite}) {
    return isCurrentlyFavorite ? removeFavorite(carId) : addFavorite(carId);
  }

  /// Full car details (with images) for everything the current user has
  /// favorited — used by the Favorites panel, which needs more than just
  /// the bare IDs that [fetchFavoriteCarIds] returns.
  Future<List<CarModel>> fetchFavoriteCars() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('favorites')
        .select('car_id, cars(*, car_images(image_url, is_primary, display_order))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final rows = response as List<dynamic>;
    final cars = <CarModel>[];

    for (final row in rows) {
      final carData = (row as Map<String, dynamic>)['cars'];
      // A favorited car may have since been deleted by the admin —
      // skip those rather than crashing on a null join.
      if (carData == null) continue;
      cars.add(CarModel.fromMap(carData as Map<String, dynamic>));
    }

    return cars;
  }
}
