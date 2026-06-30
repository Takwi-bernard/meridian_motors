import 'package:flutter/material.dart';
import '../../models/car_model.dart';
import '../../services/favorite_service.dart';
import '../../widgets/car_card.dart';
import '../../car_detail/car_detail_page.dart';

/// Grid of the signed-in customer's favorited cars — same CarCard used
/// everywhere else in the app, so it carries the same image, price,
/// badges, and spec row a user already sees on Home/Dashboard. Tapping
/// a card opens the real detail page; tapping the heart un-favorites
/// and removes the card from the grid immediately.
class FavoritesPanel extends StatefulWidget {
  const FavoritesPanel({super.key});

  @override
  State<FavoritesPanel> createState() => FavoritesPanelState();
}

class FavoritesPanelState extends State<FavoritesPanel> {
  final FavoriteService _favoriteService = FavoriteService();

  bool _loading = true;
  String? _error;
  List<CarModel> _favorites = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  /// Public so the Dashboard shell can refresh this tab after a
  /// favorite is toggled from somewhere else (e.g. Car Detail).
  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cars = await _favoriteService.fetchFavoriteCars();
      setState(() {
        _favorites = cars;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load your favorites.';
        _loading = false;
      });
    }
  }

  Future<void> _removeFavorite(CarModel car) async {
    // Optimistic removal — card disappears immediately, restored if the
    // delete fails so the grid never silently disagrees with the DB.
    final removed = car;
    final index = _favorites.indexOf(car);
    setState(() => _favorites.remove(car));

    try {
      await _favoriteService.removeFavorite(car.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorites.insert(index.clamp(0, _favorites.length), removed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove favorite. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) return _errorState();
    if (_favorites.isEmpty) return _emptyState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: load,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'My Favorites',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width > 1100 ? 4 : (width > 760 ? 3 : 2);
                final aspectRatio = columns >= 4 ? 0.82 : (columns == 3 ? 0.78 : 0.70);

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: aspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final car = _favorites[index];
                      return CarCard(
                        car: car,
                        isFavorite: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
                        ),
                        onFavoriteTap: () => _removeFavorite(car),
                      );
                    },
                    childCount: _favorites.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.favorite_border, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text('No favorites yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Tap the heart icon on any car to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: load, child: const Text('Retry')),
        ],
      ),
    );
  }
}
