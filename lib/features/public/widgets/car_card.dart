import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/car_model.dart';

/// Reusable car card. Used on the public Home grid, the authenticated
/// Dashboard grid, and search results.
///
/// Content height is intentionally deterministic: the subtitle line is
/// always reserved at a fixed height whether or not the car has a trim,
/// so every card in a grid row is the same height with no leftover gap.
class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    required this.onTap,
    required this.onFavoriteTap,
    this.isFavorite = false,
  });

  final CarModel car;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15151A),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              _buildDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = car.primaryImageUrl;

    return AspectRatio(
      // Slightly shorter than before (was 16:11) so the image doesn't
      // dominate the card and crowd out the details below it.
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFF202024),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => _imageFallback(),
            )
          else
            _imageFallback(),

          // Subtle bottom gradient so badges stay legible over bright photos.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.30)],
                ),
              ),
            ),
          ),

          if (car.condition != null && car.condition!.isNotEmpty)
            Positioned(top: 10, left: 10, child: _Badge(text: car.condition!.toUpperCase()) ),

          if (car.isOnSale)
            Positioned(
              top: 10,
              left: (car.condition != null && car.condition!.isNotEmpty) ? 84 : 10,
              child: const _Badge(text: 'SALE', color: Color(0xFFDC2626)),
            ),

          Positioned(
            top: 8,
            right: 8,
            child: _FavoriteButton(isFavorite: isFavorite, onTap: onFavoriteTap),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final hasTrim = car.trim != null && car.trim!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            car.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 3),
          // Fixed-height slot regardless of whether trim exists — this is
          // what keeps every card in a row the same height.
          SizedBox(
            height: 15,
            child: hasTrim
                ? Text(
                    car.trim!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11.5),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatPrice(car.displayPrice),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5),
              ),
              if (car.isOnSale) ...[
                const SizedBox(width: 6),
                Text(
                  _formatPrice(car.price),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11.5,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (car.mileage != null) ...[
                const Icon(Icons.speed_outlined, size: 15, color: Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text(
                  '${_formatNumber(car.mileage!)} mi',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ],
              if (car.mileage != null && car.transmission != null) const SizedBox(width: 10),
              if (car.transmission != null) ...[
                const Icon(Icons.settings_applications_outlined, size: 15, color: Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    car.transmission!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFF202024),
      child: const Center(
        child: Icon(Icons.directions_car_outlined, color: Colors.white24, size: 32),
      ),
    );
  }

  String _formatPrice(double price) => '\$${_formatNumber(price.round())}';

  String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i != 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color = const Color(0xFF18181B)});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isFavorite ? const Color(0xFFDC2626) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
