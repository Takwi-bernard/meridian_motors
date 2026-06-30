import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';
import '../services/favorite_service.dart';
import '../auth/customer_login_page.dart';
import 'widgets/reservation_form_sheet.dart';
import 'widgets/inquiry_form_sheet.dart';

// ─────────────────────────────────────────────────────────
//  MERIDIAN MOTORS — Car Detail Page
//  Layout inspired by Carea UI Kit (dark luxury version)
//  Sections: Image hero · Thumbnails · Tabs (About/Specs/Gallery)
// ─────────────────────────────────────────────────────────

// ── Colour tokens
class _C {
  static const bg        = Color(0xFF0F0F11);
  static const card      = Color(0xFF15151A);
  static const surface   = Color(0xFF1C1C24);
  static const blue      = Color(0xFF1E56D6);
  static const blueLight = Color(0xFF3B72F0);
  static const green     = Color(0xFF22C55E);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const border    = Color(0xFF22222E);
  static const sub       = Color(0xFF8A8A9A);
  static const muted     = Color(0xFF3D3D50);
  // hero image area — slightly lighter so car "floats"
  static const heroFrame = Color(0xFF1E1E28);
}

class CarDetailPage extends StatefulWidget {
  const CarDetailPage({super.key, required this.car});
  final CarModel car;

  @override
  State<CarDetailPage> createState() => _CarDetailPageState();
}

class _CarDetailPageState extends State<CarDetailPage>
    with SingleTickerProviderStateMixin {
  final FavoriteService _favoriteService = FavoriteService();
  final PageController  _pageController  = PageController();

  late final TabController _tabController;

  bool get _isAuthenticated =>
      Supabase.instance.client.auth.currentUser != null;

  bool _isFavorite       = false;
  bool _checkingFavorite = true;
  int  _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (_isAuthenticated) {
      _loadFavoriteStatus();
    } else {
      _checkingFavorite = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final ids = await _favoriteService.fetchFavoriteCarIds();
      if (mounted) {
        setState(() {
          _isFavorite        = ids.contains(widget.car.id);
          _checkingFavorite  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingFavorite = false);
    }
  }

  void _goToAuth() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerAuthPage()),
      );

  Future<void> _toggleFavorite() async {
    if (!_isAuthenticated) { _goToAuth(); return; }
    final was = _isFavorite;
    setState(() => _isFavorite = !was);
    try {
      await _favoriteService.toggleFavorite(
          widget.car.id, isCurrentlyFavorite: was);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavorite = was);
      _toast('Could not update favourite. Try again.');
    }
  }

  void _handleReserve() {
    if (!_isAuthenticated) { _goToAuth(); return; }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ReservationFormSheet(car: widget.car),
    );
  }

  void _handleInquire() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => InquiryFormSheet(car: widget.car),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final car = widget.car;

    return Scaffold(
      backgroundColor: _C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── App bar
          SliverAppBar(
            backgroundColor: _C.bg,
            elevation: 0,
            pinned: true,
            centerTitle: true,
            leading: _circleBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            title: const Text(
              'Car Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              _circleBtn(
                icon: Icons.share_outlined,
                onTap: () => _toast('Share coming soon.'),
              ),
              _circleBtn(
                icon: _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _isFavorite ? _C.red : Colors.white,
                loading: _checkingFavorite,
                onTap: _checkingFavorite ? null : _toggleFavorite,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Hero image frame
          SliverToBoxAdapter(child: _buildHero(car)),

          // ── Thumbnail strip
          if (car.imageUrls.length > 1)
            SliverToBoxAdapter(child: _buildThumbnails(car)),

          // ── Title + category + rating row
          SliverToBoxAdapter(child: _buildTitleRow(car)),

          // ── Tab bar (About / Specs / Gallery)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: _C.blue,
                unselectedLabelColor: _C.sub,
                indicatorColor: _C.blue,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Specs'),
                  Tab(text: 'Gallery'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAboutTab(car),
            _buildSpecsTab(car),
            _buildGalleryTab(car),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HERO IMAGE FRAME
  //  White/light inner panel so the car floats — dark border frame
  // ════════════════════════════════════════════════════════
  Widget _buildHero(CarModel car) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          // Slightly lighter panel — makes car appear to "float"
          color: _C.heroFrame,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: car.imageUrls.isEmpty
              ? _noImagePlaceholder()
              : Stack(
                  children: [
                    // Main image swiper
                    PageView.builder(
                      controller: _pageController,
                      itemCount: car.imageUrls.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Image.network(
                          car.imageUrls[i],
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, prog) {
                            if (prog == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _C.blue,
                                value: prog.expectedTotalBytes != null
                                    ? prog.cumulativeBytesLoaded /
                                        prog.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _noImagePlaceholder(),
                        ),
                      ),
                    ),

                    // Counter pill — top right
                    if (car.imageUrls.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined,
                                  color: Colors.white70, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '+${car.imageUrls.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Featured badge — top left
                    if (car.featured == true)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _C.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Featured',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),

                    // Dot indicators — bottom center
                    if (car.imageUrls.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            car.imageUrls.length > 5
                                ? 5
                                : car.imageUrls.length,
                            (i) {
                              final active = i == _currentImageIndex;
                              return AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                width: active ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? _C.blue
                                      : Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  THUMBNAIL STRIP  (below hero, matches reference image)
  // ════════════════════════════════════════════════════════
  Widget _buildThumbnails(CarModel car) {
    final total  = car.imageUrls.length;
    final show   = total > 5 ? 4 : total; // show max 4, last one gets +N
    final extras = total - show;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          ...List.generate(show, (i) {
            final isActive = i == _currentImageIndex;
            final isLast   = i == show - 1 && extras > 0;
            return GestureDetector(
              onTap: () => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 64,
                height: 52,
                decoration: BoxDecoration(
                  color: _C.heroFrame,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? _C.blue : _C.border,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.network(
                          car.imageUrls[i],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car,
                              color: Colors.white24,
                              size: 24),
                        ),
                      ),
                      // Last thumbnail overlay showing remaining count
                      if (isLast)
                        Container(
                          color: Colors.black.withOpacity(0.65),
                          child: Center(
                            child: Text(
                              '+$extras',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  TITLE ROW — body type chip · rating · name · price
  // ════════════════════════════════════════════════════════
  Widget _buildTitleRow(CarModel car) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Body type chip + rating
          Row(
            children: [
              if (car.bodyType != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _C.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    car.bodyType!.toUpperCase(),
                    style: const TextStyle(
                      color: _C.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              const Spacer(),
              // Static rating (can be made dynamic later)
              const Icon(Icons.star_rounded,
                  color: _C.amber, size: 16),
              const SizedBox(width: 4),
              const Text('4.9',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),

          const SizedBox(height: 10),

          // Car name + price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  car.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${_fmt(car.displayPrice.round())}',
                    style: const TextStyle(
                      color: _C.green,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (car.isOnSale)
                    Text(
                      '\$${_fmt(car.price.round())}',
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _C.muted,
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (car.trim != null && car.trim!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(car.trim!,
                style: const TextStyle(
                    color: _C.sub, fontSize: 13)),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  TAB: ABOUT
  // ════════════════════════════════════════════════════════
  Widget _buildAboutTab(CarModel car) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        // Quick spec chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (car.condition != null)
              _specChip(Icons.verified_rounded, car.condition!),
            if (car.mileage != null)
              _specChip(Icons.speed_rounded,
                  '${_fmt(car.mileage!)} mi'),
            if (car.transmission != null)
              _specChip(Icons.settings_input_component_rounded,
                  car.transmission!),
            if (car.fuelType != null)
              _specChip(Icons.local_gas_station_rounded,
                  car.fuelType!),
            if (car.drivetrain != null)
              _specChip(Icons.rotate_right_rounded,
                  car.drivetrain!),
          ],
        ),

        const SizedBox(height: 24),

        // Dealership / contact row — matches "Rent Partner" in reference
        _buildDealerCard(),

        const SizedBox(height: 24),

        // About / description
        _sectionLabel('About'),
        const SizedBox(height: 10),
        _ExpandableText(
          text: car.fullDescription?.isNotEmpty == true
              ? car.fullDescription!
              : car.shortDescription?.isNotEmpty == true
                  ? car.shortDescription!
                  : 'No description available for this vehicle.',
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  TAB: SPECS
  // ════════════════════════════════════════════════════════
  Widget _buildSpecsTab(CarModel car) {
    final rows = <_SpecRow>[
      _SpecRow(Icons.calendar_today_rounded, 'Year',
          car.year.toString()),
      _SpecRow(Icons.directions_car_rounded, 'Make', car.make),
      _SpecRow(Icons.drive_eta_rounded, 'Model', car.model),
      if (car.condition != null)
        _SpecRow(Icons.verified_rounded, 'Condition',
            car.condition!),
      if (car.mileage != null)
        _SpecRow(Icons.speed_rounded, 'Mileage',
            '${_fmt(car.mileage!)} mi'),
      if (car.fuelType != null)
        _SpecRow(Icons.local_gas_station_rounded, 'Fuel Type',
            car.fuelType!),
      if (car.transmission != null)
        _SpecRow(Icons.settings_input_component_rounded,
            'Transmission', car.transmission!),
      if (car.bodyType != null)
        _SpecRow(Icons.directions_car_filled_rounded, 'Body Type',
            car.bodyType!),
      if (car.drivetrain != null)
        _SpecRow(Icons.rotate_right_rounded, 'Drivetrain',
            car.drivetrain!),
      if (car.engine != null)
        _SpecRow(Icons.engineering_rounded, 'Engine', car.engine!),
      if (car.exteriorColor != null)
        _SpecRow(Icons.palette_rounded, 'Exterior',
            car.exteriorColor!),
      if (car.interiorColor != null)
        _SpecRow(Icons.chair_rounded, 'Interior',
            car.interiorColor!),
      if (car.doors != null)
        _SpecRow(Icons.sensor_door_rounded, 'Doors',
            car.doors.toString()),
      if (car.seats != null)
        _SpecRow(
            Icons.airline_seat_recline_normal_rounded,
            'Seats',
            car.seats.toString()),
      if (car.stockNumber != null)
        _SpecRow(Icons.tag_rounded, 'Stock #', car.stockNumber!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: List.generate(rows.length, (i) {
              final r      = rows[i];
              final isLast = i == rows.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _C.blue.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(9),
                          ),
                          child: Icon(r.icon,
                              color: _C.blue, size: 17),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(r.label,
                              style: const TextStyle(
                                  color: _C.sub,
                                  fontSize: 13)),
                        ),
                        Text(r.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                        color: _C.border,
                        height: 1,
                        indent: 16,
                        endIndent: 16),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  TAB: GALLERY
  // ════════════════════════════════════════════════════════
  Widget _buildGalleryTab(CarModel car) {
    if (car.imageUrls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                color: _C.muted, size: 48),
            const SizedBox(height: 12),
            Text('No photos available.',
                style: TextStyle(color: _C.sub, fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: car.imageUrls.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () {
          // Jump to hero + scroll to top
          _tabController.animateTo(0);
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: _C.heroFrame,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.network(
                car.imageUrls[i],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white24,
                    size: 36),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  DEALER CARD  (matches "Rent Partner" in reference)
  // ════════════════════════════════════════════════════════
  Widget _buildDealerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // Dealer avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _C.blue.withOpacity(0.3)),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: _C.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meridian Motors',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('Official Dealership',
                    style: TextStyle(
                        color: _C.sub, fontSize: 12)),
              ],
            ),
          ),
          // Chat button
          GestureDetector(
            onTap: _handleInquire,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _C.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _C.blue.withOpacity(0.3)),
              ),
              child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _C.blue,
                  size: 18),
            ),
          ),
          // Call button
          GestureDetector(
            onTap: () => _toast('Call feature coming soon.'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _C.blue.withOpacity(0.3)),
              ),
              child: const Icon(Icons.phone_outlined,
                  color: _C.blue, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  BOTTOM ACTION BAR
  // ════════════════════════════════════════════════════════
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: _C.bg,
        border: Border(
            top: BorderSide(color: _C.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Price pill
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price',
                    style:
                        TextStyle(color: _C.sub, fontSize: 11)),
                Text(
                  '\$${_fmt(widget.car.displayPrice.round())}',
                  style: const TextStyle(
                    color: _C.green,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Inquire button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleInquire,
                icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17),
                label: const Text('Inquire'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: _C.border),
                  padding:
                      const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Reserve / Book Now button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _handleReserve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ════════════════════════════════════════════════════════
  Widget _noImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_rounded,
              color: _C.muted, size: 56),
          const SizedBox(height: 8),
          Text('No photos',
              style: TextStyle(color: _C.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800));
  }

  Widget _specChip(IconData icon, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _C.sub),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _circleBtn({
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
            padding: const EdgeInsets.all(9),
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color))
                : Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }

  String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

// ════════════════════════════════════════════════════════
//  Expandable description text
// ════════════════════════════════════════════════════════
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            widget.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                height: 1.6),
          ),
          secondChild: Text(
            widget.text,
            style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                height: 1.6),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (widget.text.length > 180) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                  color: _C.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
//  Spec row model
// ════════════════════════════════════════════════════════
class _SpecRow {
  final IconData icon;
  final String   label;
  final String   value;
  const _SpecRow(this.icon, this.label, this.value);
}

// ════════════════════════════════════════════════════════
//  SliverPersistentHeader delegate for TabBar
// ════════════════════════════════════════════════════════
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0F0F11),
      child: Column(
        children: [
          tabBar,
          Divider(
              color: Colors.white.withOpacity(0.06),
              height: 1),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}