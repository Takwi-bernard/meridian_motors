import 'package:flutter/material.dart';
import '../../models/car_model.dart';
import '../../services/favorite_service.dart';
import '../../widgets/car_card.dart';
import '../../car_detail/car_detail_page.dart';

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

  Future<void> load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cars = await _favoriteService.fetchFavoriteCars();
      setState(() { _favorites = cars; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your saved cars.'; _loading = false; });
    }
  }

  Future<void> _removeFavorite(CarModel car) async {
    final index = _favorites.indexOf(car);
    setState(() => _favorites.remove(car));
    try {
      await _favoriteService.removeFavorite(car.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorites.insert(index.clamp(0, _favorites.length), car));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    if (_favorites.isEmpty) return _emptyState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.crossAxisExtent;
                final cols = w > 1100 ? 4 : (w > 760 ? 3 : 2);
                final ratio = cols >= 4 ? 0.82 : (cols == 3 ? 0.78 : 0.70);
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: ratio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final car = _favorites[i];
                      return CarCard(
                        car: car,
                        isFavorite: true,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => CarDetailPage(car: car))),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFDC2626), size: 22),
              const SizedBox(width: 10),
              const Text(
                'My Favorites',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_favorites.length} saved ${_favorites.length == 1 ? 'car' : 'cars'}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _loadingState() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Loading your saved cars...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      );

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(Icons.favorite_border_rounded, color: Colors.white38, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'No saved cars yet',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap the heart icon on any car card\nto save it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.directions_car_filled, size: 16),
              label: const Text('Browse Cars'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 32),
            ),
            const SizedBox(height: 20),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
