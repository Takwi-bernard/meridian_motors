// car_detail_page.dart
//
// Displays full details of a single vehicle.
// Navigates to EditVehiclePage on edit tap.
// Supabase tables: cars, car_images

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';
import 'edit_vehicle_page.dart';

// ═══════════════════════════════════════════════════════════
//  CAR DETAIL PAGE
// ═══════════════════════════════════════════════════════════

class CarDetailPage extends StatefulWidget {
  final String carId;
  final VoidCallback? onUpdated; // notify inventory to refresh

  const CarDetailPage({
    super.key,
    required this.carId,
    this.onUpdated,
  });

  @override
  State<CarDetailPage> createState() => _CarDetailPageState();
}

class _CarDetailPageState extends State<CarDetailPage> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _car;
  List<String> _imageUrls = [];
  int _activeImage = 0;
  bool _isLoading = true;
  bool _hasError  = false;

  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final results = await Future.wait([
        _supabase.from('cars').select().eq('id', widget.carId).single(),
        _supabase
            .from('car_images')
            .select('image_url, is_primary, display_order')
            .eq('car_id', widget.carId)
            .order('display_order'),
      ]);

      final car    = results[0] as Map<String, dynamic>;
      final images = results[1] as List;

      // Sort: primary first
      images.sort((a, b) {
        if (a['is_primary'] == true) return -1;
        if (b['is_primary'] == true) return  1;
        return (a['display_order'] ?? 0)
            .compareTo(b['display_order'] ?? 0);
      });

      if (!mounted) return;
      setState(() {
        _car       = car;
        _imageUrls = images
            .map((e) => e['image_url']?.toString() ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('CarDetail load error: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── Quick status update directly from detail page
  Future<void> _updateStatus(String status) async {
    try {
      await _supabase
          .from('cars')
          .update({'status': status})
          .eq('id', widget.carId);
      setState(() => _car!['status'] = status);
      widget.onUpdated?.call();
      _toast('Status updated to ${MM.statusLabel(status)}.');
    } catch (_) {
      _toast('Failed to update status.', isError: true);
    }
  }

  Future<void> _toggleFeatured() async {
    final newVal = !(_car!['featured'] == true);
    try {
      await _supabase
          .from('cars')
          .update({'featured': newVal})
          .eq('id', widget.carId);
      setState(() => _car!['featured'] = newVal);
      widget.onUpdated?.call();
      _toast(newVal
          ? 'Added to featured listings.'
          : 'Removed from featured listings.');
    } catch (_) {
      _toast('Failed to update featured status.', isError: true);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MM.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete vehicle?',
            style: TextStyle(
                color: MM.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          '${_car!['year'] ?? ''} ${_car!['make'] ?? ''} ${_car!['model'] ?? ''} '
          'will be permanently removed. This cannot be undone.',
          style: const TextStyle(
              color: MM.textSub, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: MM.textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MM.accentRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supabase.from('cars').delete().eq('id', widget.carId);
      widget.onUpdated?.call();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _toast('Failed to delete vehicle.', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? MM.accentRed : MM.accentGreen,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: MM.bgDeep),
      child: Scaffold(
        backgroundColor: MM.bgDeep,
        body: _isLoading
            ? _loader()
            : _hasError
                ? _error()
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: isDesktop
              ? _desktopLayout()
              : _mobileLayout(),
        ),
      ],
    );
  }

  // ── Top bar
  Widget _buildTopBar() {
    final car    = _car!;
    final label  =
        '${car['year'] ?? ''} ${car['make'] ?? ''} ${car['model'] ?? ''}'
            .trim();
    final status = car['status']?.toString() ?? '';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: MM.bgCard,
        border: Border(bottom: BorderSide(color: MM.border)),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: MM.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MM.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: MM.textSub, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          // Breadcrumb
          Text('Inventory',
              style: TextStyle(color: MM.textSub, fontSize: 13)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right_rounded,
                color: MM.textMuted, size: 16),
          ),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          // Status badge
          _StatusBadge(status),
          const SizedBox(width: 12),
          // Featured toggle
          GestureDetector(
            onTap: _toggleFeatured,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: car['featured'] == true
                    ? MM.accentAmber.withOpacity(0.12)
                    : MM.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: car['featured'] == true
                      ? MM.accentAmber.withOpacity(0.4)
                      : MM.border,
                ),
              ),
              child: Row(children: [
                Icon(
                  car['featured'] == true
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: car['featured'] == true
                      ? MM.accentAmber : MM.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text('Featured',
                    style: TextStyle(
                        color: car['featured'] == true
                            ? MM.accentAmber : MM.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          // Edit button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditVehiclePage(
                  carId: widget.carId,
                  onSaved: () {
                    _load();
                    widget.onUpdated?.call();
                  },
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: MM.brandBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.edit_rounded,
                    color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Edit',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // More menu
          _moreMenu(),
        ],
      ),
    );
  }

  Widget _moreMenu() {
    return Theme(
      data: ThemeData.dark().copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: MM.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: MM.border),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MM.border),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: MM.textSub, size: 20),
        ),
        onSelected: (v) async {
          switch (v) {
            case 'available': await _updateStatus('available'); break;
            case 'reserved':  await _updateStatus('reserved');  break;
            case 'sold':      await _updateStatus('sold');       break;
            case 'delete':    await _confirmDelete();            break;
            case 'copy_id':
              await Clipboard.setData(
                  ClipboardData(text: widget.carId));
              _toast('Car ID copied to clipboard.');
              break;
          }
        },
        itemBuilder: (_) => [
          _mi('available', 'Mark Available',
              Icons.check_circle_outline, MM.accentGreen),
          _mi('reserved',  'Mark Reserved',
              Icons.event_outlined,        MM.accentAmber),
          _mi('sold',      'Mark Sold',
              Icons.sell_outlined,          MM.accentRed),
          const PopupMenuDivider(),
          _mi('copy_id',  'Copy Car ID',
              Icons.copy_rounded,           MM.textSub),
          const PopupMenuDivider(),
          _mi('delete',   'Delete Vehicle',
              Icons.delete_outline_rounded, MM.accentRed),
        ],
      ),
    );
  }

  PopupMenuItem<String> _mi(
      String val, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color == MM.textSub
                    ? MM.textPrimary : color,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── Mobile layout
  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _imageGallery(),
          const SizedBox(height: 20),
          _titleBlock(),
          const SizedBox(height: 20),
          _pricingBlock(),
          const SizedBox(height: 20),
          _specsBlock(),
          const SizedBox(height: 20),
          _descriptionBlock(),
          const SizedBox(height: 20),
          _metaBlock(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Desktop layout
  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left — images + description
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _imageGallery(),
                const SizedBox(height: 24),
                _descriptionBlock(),
                const SizedBox(height: 24),
                _metaBlock(),
              ],
            ),
          ),
        ),
        // Right — title, pricing, specs
        Container(
          width: 360,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: MM.border)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleBlock(),
                const SizedBox(height: 20),
                _pricingBlock(),
                const SizedBox(height: 20),
                _specsBlock(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  SECTIONS
  // ════════════════════════════════════════════════════════

  // ── Image gallery with thumbnail strip
  Widget _imageGallery() {
    if (_imageUrls.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: MM.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MM.border),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_rounded,
                  color: MM.textMuted, size: 52),
              SizedBox(height: 10),
              Text('No photos uploaded',
                  style: TextStyle(
                      color: MM.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Main image
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) =>
                  setState(() => _activeImage = i),
              itemCount: _imageUrls.length,
              itemBuilder: (_, i) => Image.network(
                _imageUrls[i],
                fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) {
                  if (prog == null) return child;
                  return Container(
                    color: MM.bgCard,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: prog.expectedTotalBytes != null
                            ? prog.cumulativeBytesLoaded /
                                prog.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation(
                            MM.brandBlue),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: MM.bgCard,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: MM.textMuted, size: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Dot indicator
        if (_imageUrls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_imageUrls.length, (i) {
              return GestureDetector(
                onTap: () {
                  _pageCtrl.animateToPage(i,
                      duration:
                          const Duration(milliseconds: 300),
                      curve: Curves.easeOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 3),
                  width: _activeImage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _activeImage == i
                        ? MM.brandBlue
                        : MM.textMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          // Thumbnail strip
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length,
              itemBuilder: (_, i) {
                final active = i == _activeImage;
                return GestureDetector(
                  onTap: () {
                    _pageCtrl.animateToPage(i,
                        duration:
                            const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? MM.brandBlue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        _imageUrls[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MM.bgCard,
                          child: const Icon(
                              Icons.broken_image_rounded,
                              color: MM.textMuted, size: 20),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Title block
  Widget _titleBlock() {
    final car = _car!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (car['condition'] != null)
            _chip(car['condition'].toString(), MM.brandBlue),
          if (car['featured'] == true) ...[
            const SizedBox(width: 6),
            _chip('Featured', MM.accentAmber,
                icon: Icons.star_rounded),
          ],
        ]),
        const SizedBox(height: 10),
        Text(
          '${car['year'] ?? ''} ${car['make'] ?? ''} ${car['model'] ?? ''}',
          style: const TextStyle(
            color: MM.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        if (car['trim'] != null) ...[
          const SizedBox(height: 4),
          Text(car['trim'].toString(),
              style: const TextStyle(
                  color: MM.textSub, fontSize: 14)),
        ],
        if (car['stock_number'] != null) ...[
          const SizedBox(height: 6),
          Text('Stock #${car['stock_number']}',
              style: const TextStyle(
                  color: MM.textMuted, fontSize: 12)),
        ],
      ],
    );
  }

  // ── Pricing block
  Widget _pricingBlock() {
    final car = _car!;
    final price     = car['price'];
    final salePrice = car['sale_price'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Pricing', Icons.attach_money_rounded,
              MM.accentGreen),
          const SizedBox(height: 14),
          if (salePrice != null) ...[
            Text('\$${_fmt(salePrice)}',
                style: const TextStyle(
                    color: MM.accentGreen,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
            const SizedBox(height: 4),
            Row(children: [
              Text('Was \$${_fmt(price)}',
                  style: const TextStyle(
                      color: MM.textSub,
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 10),
              _chip('On Sale', MM.accentGreen),
            ]),
          ] else
            Text(
              price != null ? '\$${_fmt(price)}' : 'Price not set',
              style: TextStyle(
                color: price != null
                    ? MM.accentGreen : MM.textMuted,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          if (car['mileage'] != null) ...[
            const SizedBox(height: 12),
            Divider(color: MM.border),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.speed_rounded,
                  color: MM.textSub, size: 16),
              const SizedBox(width: 8),
              Text('${_fmt(car['mileage'])} miles',
                  style: const TextStyle(
                      color: MM.textSub, fontSize: 14)),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Specs block
  Widget _specsBlock() {
    final car = _car!;
    final specs = <_SpecRow>[
      if (car['fuel_type']    != null)
        _SpecRow(Icons.local_gas_station_rounded,
            'Fuel Type',     car['fuel_type'].toString()),
      if (car['transmission'] != null)
        _SpecRow(Icons.settings_input_component_rounded,
            'Transmission',  car['transmission'].toString()),
      if (car['body_type']    != null)
        _SpecRow(Icons.directions_car_filled_rounded,
            'Body Type',     car['body_type'].toString()),
      if (car['drivetrain']   != null)
        _SpecRow(Icons.rotate_right_rounded,
            'Drivetrain',    car['drivetrain'].toString()),
      if (car['engine']       != null)
        _SpecRow(Icons.engineering_rounded,
            'Engine',        car['engine'].toString()),
      if (car['exterior_color'] != null)
        _SpecRow(Icons.palette_rounded,
            'Exterior',      car['exterior_color'].toString()),
      if (car['interior_color'] != null)
        _SpecRow(Icons.chair_rounded,
            'Interior',      car['interior_color'].toString()),
      if (car['doors']        != null)
        _SpecRow(Icons.sensor_door_rounded,
            'Doors',         '${car['doors']}'),
      if (car['seats']        != null)
        _SpecRow(Icons.airline_seat_recline_normal_rounded,
            'Seats',         '${car['seats']}'),
    ];

    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Specifications',
              Icons.settings_rounded, MM.accentAmber),
          const SizedBox(height: 14),
          ...specs.map((s) => _specRow(s)),
        ],
      ),
    );
  }

  Widget _specRow(_SpecRow s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: MM.bgSurface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(s.icon, color: MM.textSub, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.label,
                style: const TextStyle(
                    color: MM.textSub, fontSize: 13)),
          ),
          Text(s.value,
              style: const TextStyle(
                  color: MM.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Description block
  Widget _descriptionBlock() {
    final car = _car!;
    final short = car['short_description']?.toString();
    final full  = car['full_description']?.toString();

    if (short == null && full == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Description',
              Icons.description_rounded, MM.accentPurple),
          const SizedBox(height: 14),
          if (short != null) ...[
            Text(short,
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5)),
            if (full != null) const SizedBox(height: 12),
          ],
          if (full != null)
            Text(full,
                style: const TextStyle(
                    color: MM.textSub,
                    fontSize: 14,
                    height: 1.7)),
        ],
      ),
    );
  }

  // ── Meta / admin info block
  Widget _metaBlock() {
    final car = _car!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Record Info',
              Icons.info_outline_rounded, MM.textSub),
          const SizedBox(height: 14),
          _metaRow('Car ID',      widget.carId),
          if (car['vin'] != null)
            _metaRow('VIN',       car['vin'].toString()),
          if (car['stock_number'] != null)
            _metaRow('Stock #',   car['stock_number'].toString()),
          if (car['created_at'] != null)
            _metaRow('Added',     _fmtDate(car['created_at'].toString())),
          if (car['updated_at'] != null)
            _metaRow('Updated',   _fmtDate(car['updated_at'].toString())),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: MM.textMuted, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await Clipboard.setData(
                    ClipboardData(text: value));
                _toast('Copied to clipboard.');
              },
              child: Text(value,
                  style: const TextStyle(
                      color: MM.textSub,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════
  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: MM.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _fmt(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000)
      return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000)
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return n.toStringAsFixed(0);
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final m  = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return raw; }
  }

  // ── States
  Widget _loader() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34, height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(MM.brandBlue),
              ),
            ),
            SizedBox(height: 16),
            Text('Loading vehicle…',
                style: TextStyle(
                    color: MM.textSub, fontSize: 14)),
          ],
        ),
      );

  Widget _error() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: MM.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('Could not load vehicle.',
                style: TextStyle(
                    color: MM.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: MM.brandBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Try again',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _SpecRow {
  final IconData icon;
  final String label, value;
  const _SpecRow(this.icon, this.label, this.value);
}

// ── Status badge
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = MM.statusColor(status);
    final label = MM.statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}