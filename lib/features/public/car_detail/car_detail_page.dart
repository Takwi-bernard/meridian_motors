import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';
import '../services/favorite_service.dart';
import '../auth/customer_login_page.dart';
import 'widgets/reservation_form_sheet.dart';
import 'widgets/inquiry_form_sheet.dart';

/// Car detail screen. Reachable by anyone (public Home or Dashboard).
/// Favoriting and reserving require authentication and route to
/// [CustomerAuthPage] if the visitor isn't signed in. Inquiring does
/// not require authentication, per spec.
class CarDetailPage extends StatefulWidget {
  const CarDetailPage({super.key, required this.car});

  final CarModel car;

  @override
  State<CarDetailPage> createState() => _CarDetailPageState();
}

class _CarDetailPageState extends State<CarDetailPage> {
  final FavoriteService _favoriteService = FavoriteService();
  final PageController _pageController = PageController();

  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  bool _isFavorite = false;
  bool _checkingFavorite = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_isAuthenticated) {
      _loadFavoriteStatus();
    } else {
      _checkingFavorite = false;
    }
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final ids = await _favoriteService.fetchFavoriteCarIds();
      if (mounted) {
        setState(() {
          _isFavorite = ids.contains(widget.car.id);
          _checkingFavorite = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingFavorite = false);
    }
  }

  void _goToAuth() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerAuthPage()));
  }

  Future<void> _toggleFavorite() async {
    if (!_isAuthenticated) {
      _goToAuth();
      return;
    }

    final wasFavorite = _isFavorite;
    setState(() => _isFavorite = !wasFavorite);

    try {
      await _favoriteService.toggleFavorite(widget.car.id, isCurrentlyFavorite: wasFavorite);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavorite = wasFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorite. Please try again.')),
      );
    }
  }

  void _handleReserve() {
    if (!_isAuthenticated) {
      _goToAuth();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ReservationFormSheet(car: widget.car),
    );
  }

  void _handleInquire() {
    // No auth gate — inquiries are open to guests, per spec.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => InquiryFormSheet(car: widget.car),
    );
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0F0F11),
            elevation: 0,
            pinned: true,
            leading: _circleIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            title: Text(car.model, style: TextStyle(fontSize: 30,color: Colors.white24),),
            actions: [
              _circleIconButton(
                icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? const Color(0xFFDC2626) : Colors.white,
                loading: _checkingFavorite,
                onTap: _checkingFavorite ? null : _toggleFavorite,
              ),
              const SizedBox(width: 12),
            ],
          ),
          SliverToBoxAdapter(child: _buildGalleryCard(car)),
          SliverToBoxAdapter(child: _buildDetails(car)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildActionBar(),
    );
  }

  /// Wraps the gallery in margin + rounded corners + a faint border, so
  /// images read as sitting "inside a frame" instead of running flush
  /// to the edges of the screen.
  Widget _buildGalleryCard(CarModel car) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 300,
          
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: _buildGallery(car),
        ),
      ),
    );
  }

  Widget _buildGallery(CarModel car) {
    if (car.imageUrls.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A1D),
        child: const Center(child: Icon(Icons.directions_car, color: Colors.white24, size: 64)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: car.imageUrls.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (context, index) => Image.network(
            car.imageUrls[index],
            
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1A1A1D),
              child: const Icon(Icons.directions_car, color: Colors.white24, size: 64),
            ),
          ),
        ),
        if (car.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(car.imageUrls.length, (i) {
                final isActive = i == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildDetails(CarModel car) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  car.title,
                  style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${_formatNumber(car.displayPrice.round())}',
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  if (car.isOnSale)
                    Text(
                      '\$${_formatNumber(car.price.round())}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (car.trim != null && car.trim!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(car.trim!, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (car.condition != null) _specChip(Icons.verified, car.condition!),
              if (car.mileage != null) _specChip(Icons.speed, '${_formatNumber(car.mileage!)} mi'),
              if (car.transmission != null) _specChip(Icons.settings, car.transmission!),
              if (car.fuelType != null) _specChip(Icons.local_gas_station, car.fuelType!),
              if (car.bodyType != null) _specChip(Icons.directions_car, car.bodyType!),
              if (car.drivetrain != null) _specChip(Icons.toll, car.drivetrain!),
            ],
          ),
          const SizedBox(height: 24),
          if (car.fullDescription != null && car.fullDescription!.isNotEmpty) ...[
            _sectionLabel('Description'),
            const SizedBox(height: 8),
            Text(
              car.fullDescription!,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
          _sectionLabel('Specifications'),
          const SizedBox(height: 12),
          _specCard(car),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800));
  }

  Widget _specChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1D), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  /// Specs grouped in one bordered card with thin dividers between rows,
  /// instead of a bare list directly on the page background — keeps the
  /// section visually contained and the row spacing exact rather than
  /// padded out with extra whitespace.
  Widget _specCard(CarModel car) {
    final rows = <List<String>>[
      ['Year', car.year.toString()],
      ['Make', car.make],
      ['Model', car.model],
      if (car.exteriorColor != null) ['Exterior', car.exteriorColor!],
      if (car.interiorColor != null) ['Interior', car.interiorColor!],
      if (car.doors != null) ['Doors', car.doors.toString()],
      if (car.seats != null) ['Seats', car.seats.toString()],
      if (car.engine != null) ['Engine', car.engine!],
      if (car.stockNumber != null) ['Stock #', car.stockNumber!],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          final isLast = i == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row[0], style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5)),
                    Text(
                      row[1],
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(color: Colors.white.withOpacity(0.06), height: 1),
            ],
          );
        }),
      ),
    );
  }

  String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i != 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color color = Colors.white,
    bool loading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.white.withOpacity(0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleInquire,
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text('Inquire', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _handleReserve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Reserve This Car', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}