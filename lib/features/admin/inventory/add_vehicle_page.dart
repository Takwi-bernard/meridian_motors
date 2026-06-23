// add_vehicle_page.dart
//
// Required packages:
//   image_picker: ^1.0.0
//   supabase_flutter: ^2.0.0
//
// Supabase:
//   Bucket : car_images
//   Tables : cars, car_images

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart'; // MM brand tokens

// ═══════════════════════════════════════════════════════════════
//  ADD VEHICLE PAGE
//  Dark luxury · Sectioned form · Full validation · Image UX (Web-Safe)
// ════════════════════════════════════

class AddVehiclePage extends StatefulWidget {
  /// Called after a vehicle is saved so the inventory list can refresh.
  final VoidCallback? onSaved;
  const AddVehiclePage({super.key, this.onSaved});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _formKey  = GlobalKey<FormState>();
  final _scroll   = ScrollController();

  // ── Section expand state
  final _expanded = [true, false, false, false, false];

  // ── Section keys for scroll-to
  final _sectionKeys = List.generate(5, (_) => GlobalKey());

  // ── Controllers — Identity
  final _vinCtrl       = TextEditingController();
  final _stockCtrl     = TextEditingController();
  final _makeCtrl      = TextEditingController();
  final _modelCtrl     = TextEditingController();
  final _trimCtrl      = TextEditingController();

  // ── Controllers — Pricing
  final _priceCtrl     = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _mileageCtrl   = TextEditingController();

  // ── Controllers — Specs
  final _engineCtrl    = TextEditingController();
  final _extColorCtrl  = TextEditingController();
  final _intColorCtrl  = TextEditingController();

  // ── Controllers — Description
  final _shortDescCtrl = TextEditingController();
  final _fullDescCtrl  = TextEditingController();

  // ── Dropdowns / selectors
  int    _year         = DateTime.now().year;
  String _fuelType     = 'Petrol';
  String _transmission = 'Automatic';
  String _bodyType     = 'Sedan';
  String _drivetrain   = 'FWD';
  String _condition    = 'Used';
  String _status       = 'available';
  int    _doors        = 4;
  int    _seats        = 5;
  bool   _featured     = false;

  // ── Images
  final List<XFile> _images  = [];
  int  _primaryIndex         = 0;
  bool _saving               = false;
  int  _uploadCurrent        = 0;
  int  _uploadTotal          = 0;

  // ── Options
  static const _fuelTypes     = ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'Plug-in Hybrid'];
  static const _transmissions = ['Automatic', 'Manual', 'CVT', 'Semi-Automatic'];
  static const _bodyTypes     = ['Sedan', 'SUV', 'Truck', 'Coupe', 'Convertible',
                                  'Hatchback', 'Wagon', 'Van', 'Minivan'];
  static const _drivetrains   = ['FWD', 'RWD', 'AWD', '4WD'];
  static const _conditions    = ['New', 'Used', 'Certified Pre-Owned'];
  static const _statuses      = ['available', 'reserved', 'sold'];

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    // Mark dirty whenever any controller changes
    for (final c in _allControllers) {
      c.addListener(() => _isDirty = true);
    }
  }

  List<TextEditingController> get _allControllers => [
    _vinCtrl, _stockCtrl, _makeCtrl, _modelCtrl, _trimCtrl,
    _priceCtrl, _salePriceCtrl, _mileageCtrl,
    _engineCtrl, _extColorCtrl, _intColorCtrl,
    _shortDescCtrl, _fullDescCtrl,
  ];

  @override
  void dispose() {
    for (final c in _allControllers) c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  Navigation guard
  // ════════════════════════════════════════════════════════════
  Future<bool> _onWillPop() async {
    if (!_isDirty && _images.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MM.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?',
            style: TextStyle(
                color: MM.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
            'All entered data and selected images will be lost.',
            style: TextStyle(color: MM.textSub, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing',
                style: TextStyle(color: MM.brandBlue,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MM.accentRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Discard',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // ════════════════════════════════════════════════════════════
  //  Image picking
  // ════════════════════════════════════════════════════════════
  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked); // append, not replace
      _isDirty = true;
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_primaryIndex >= _images.length) {
        _primaryIndex = _images.isEmpty ? 0 : _images.length - 1;
      }
      if (_primaryIndex == index && _images.isNotEmpty) {
        _primaryIndex = 0;
      }
    });
  }

  void _setPrimary(int index) => setState(() => _primaryIndex = index);

  // Helper widget to load XFile image bytes safely on both Web and Mobile
  Widget _buildImagePreview(int index) {
    return FutureBuilder<Uint8List>(
      future: _images[index].readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return Container(
          color: MM.bgSurface,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  Save
  // ════════════════════════════════════════════════════════════
  Future<void> _saveVehicle() async {
    // Validate all sections first — expand any with errors
    bool valid = _formKey.currentState!.validate();
    if (!valid) {
      _showToast('Please fix the errors before saving.', isError: true);
      return;
    }

    setState(() {
      _saving       = true;
      _uploadCurrent = 0;
      _uploadTotal   = _images.length;
    });

    try {
      // 1. Insert car record
      // Fixed: Converting conditional constraints and enums to lowerCase before matching Supabase definitions
      final car = await _supabase.from('cars').insert({
        'vin':               _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
        'stock_number':      _stockCtrl.text.trim().isEmpty ? null : _stockCtrl.text.trim(),
        'make':              _makeCtrl.text.trim(),
        'model':             _modelCtrl.text.trim(),
        'year':              _year,
        'trim':              _trimCtrl.text.trim().isEmpty ? null : _trimCtrl.text.trim(),
        'condition':         _condition.toLowerCase(),
        'price':             double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'sale_price':        _salePriceCtrl.text.trim().isEmpty
                               ? null
                               : double.tryParse(_salePriceCtrl.text.trim()),
        'mileage':           int.tryParse(_mileageCtrl.text.trim()),
        'fuel_type':         _fuelType.toLowerCase(),
        'transmission':      _transmission.toLowerCase(),
        'body_type':         _bodyType.toLowerCase(),
        'drivetrain':        _drivetrain.toLowerCase(),
        'engine':            _engineCtrl.text.trim().isEmpty ? null : _engineCtrl.text.trim(),
        'exterior_color':    _extColorCtrl.text.trim().isEmpty ? null : _extColorCtrl.text.trim(),
        'interior_color':    _intColorCtrl.text.trim().isEmpty ? null : _intColorCtrl.text.trim(),
        'doors':             _doors,
        'seats':             _seats,
        'short_description': _shortDescCtrl.text.trim().isEmpty ? null : _shortDescCtrl.text.trim(),
        'full_description':  _fullDescCtrl.text.trim().isEmpty ? null : _fullDescCtrl.text.trim(),
        'status':            _status.toLowerCase(),
        'featured':          _featured,
      }).select().single();

      final carId = car['id'];

      // 2. Upload images sequentially with progress
      for (int i = 0; i < _images.length; i++) {
        setState(() => _uploadCurrent = i + 1);

        // Web-Safe adjustment: Read raw bytes directly from the XFile
        final bytes    = await _images[i].readAsBytes();
        final ext      = _images[i].path.split('.').last.toLowerCase();
        final fileName = '${carId}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        // Web-Safe adjustment: Use uploadBinary instead of targetting local File paths
        await _supabase.storage.from('car_images').uploadBinary(fileName, bytes);
        final url = _supabase.storage.from('car_images').getPublicUrl(fileName);

        await _supabase.from('car_images').insert({
          'car_id':        carId,
          'image_url':     url,
          'is_primary':    i == _primaryIndex,
          'display_order': i,
        });
      }

      if (!mounted) return;

      _showToast('Vehicle added to inventory successfully.');
      _isDirty = false;

      // Notify inventory to refresh
      widget.onSaved?.call();

      // Brief pause so user sees success toast
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        _showToast(_friendlyError(e.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('duplicate') || raw.contains('unique'))
      return 'A vehicle with this VIN or stock number already exists.';
    if (raw.contains('network') || raw.contains('socket'))
      return 'No internet connection. Please check and try again.';
    if (raw.contains('storage'))
      return 'Image upload failed. Check your storage bucket permissions.';
    if (raw.contains('permission') || raw.contains('policy'))
      return 'Permission denied. Make sure you are logged in as admin.';
    return 'Something went wrong. Please try again.';
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? MM.accentRed : MM.accentGreen,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: Duration(seconds: isError ? 4 : 2),
        content: Row(
          children: [
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
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  Section toggle
  // ════════════════════════════════════════════════════════════
  void _toggleSection(int i) {
    setState(() => _expanded[i] = !_expanded[i]);
    if (_expanded[i]) {
      Future.delayed(const Duration(milliseconds: 200), () {
        final ctx = _sectionKeys[i].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              alignment: 0.0);
        }
      });
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: MM.bgDeep,
          cardColor: MM.bgCard,
        ),
        child: Scaffold(
          backgroundColor: MM.bgDeep,
          body: Column(
            children: [
              _buildTopBar(isDesktop),
              if (_saving) _buildProgressBanner(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main form
                    Expanded(
                      flex: isDesktop ? 7 : 1,
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                              isDesktop ? 28 : 16, 20,
                              isDesktop ? 28 : 16, 120),
                          child: Column(
                            children: [
                              _buildSection(
                                index: 0,
                                icon: Icons.badge_rounded,
                                title: 'Vehicle Identity',
                                subtitle: 'VIN, make, model, year',
                                color: MM.brandBlue,
                                child: _buildIdentitySection(),
                              ),
                              _buildSection(
                                index: 1,
                                icon: Icons.attach_money_rounded,
                                title: 'Pricing & Mileage',
                                subtitle: 'Price, sale price, mileage',
                                color: MM.accentGreen,
                                child: _buildPricingSection(),
                              ),
                              _buildSection(
                                index: 2,
                                icon: Icons.settings_rounded,
                                title: 'Specifications',
                                subtitle: 'Engine, fuel, transmission, colors',
                                color: MM.accentAmber,
                                child: _buildSpecsSection(),
                              ),
                              _buildSection(
                                index: 3,
                                icon: Icons.description_rounded,
                                title: 'Description',
                                subtitle: 'Short and full description',
                                color: MM.accentPurple,
                                child: _buildDescriptionSection(),
                              ),
                              _buildSection(
                                index: 4,
                                icon: Icons.photo_library_rounded,
                                title: 'Photos',
                                subtitle:
                                    '${_images.length} image${_images.length == 1 ? '' : 's'} selected',
                                color: MM.accentRed,
                                child: _buildMediaSection(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Desktop summary sidebar
                    if (isDesktop) _buildSidebar(),
                  ],
                ),
              ),
            ],
          ),
          // Sticky save bar
          bottomNavigationBar: _buildSaveBar(),
        ),
      ),
    );
  }

  // ── Top bar
  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: MM.bgCard,
        border: Border(bottom: BorderSide(color: MM.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (await _onWillPop()) Navigator.pop(context);
            },
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
          const SizedBox(width: 16),
          // Breadcrumb
          Text('Inventory',
              style: TextStyle(color: MM.textSub, fontSize: 13)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right_rounded,
                color: MM.textMuted, size: 16),
          ),
          const Text('Add Vehicle',
              style: TextStyle(
                  color: MM.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          // Featured quick toggle
          GestureDetector(
            onTap: () => setState(() {
              _featured = !_featured;
              _isDirty  = true;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _featured
                    ? MM.accentAmber.withOpacity(0.12)
                    : MM.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _featured
                      ? MM.accentAmber.withOpacity(0.4)
                      : MM.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _featured
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color:
                        _featured ? MM.accentAmber : MM.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Featured',
                    style: TextStyle(
                      color: _featured
                          ? MM.accentAmber : MM.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upload progress banner
  Widget _buildProgressBanner() {
    final pct = _uploadTotal == 0
        ? 0.0
        : _uploadCurrent / _uploadTotal;
    return Container(
      color: MM.brandNavy,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              value: _uploadTotal > 0 ? pct : null,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _uploadTotal == 0
                ? 'Saving vehicle…'
                : 'Uploading image $_uploadCurrent of $_uploadTotal…',
            style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text('${(pct * 100).toInt()}%',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Collapsible section wrapper
  Widget _buildSection({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
  }) {
    final open = _expanded[index];
    return Container(
      key: _sectionKeys[index],
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: open ? color.withOpacity(0.3) : MM.border,
        ),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => _toggleSection(index),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: MM.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                color: MM.textSub, fontSize: 12)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: open ? color : MM.textMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: open
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ── Desktop sidebar summary
  Widget _buildSidebar() {
    return Container(
      width: 280,
      margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MM.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MM.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.preview_rounded,
                      color: MM.brandBlue, size: 16),
                  const SizedBox(width: 8),
                  const Text('Preview',
                      style: TextStyle(
                          color: MM.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
                Divider(color: MM.border, height: 20),
                // Primary image preview
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: MM.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MM.border),
                  ),
                  child: _images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          // Web-Safe adjustment here
                          child: _buildImagePreview(_primaryIndex),
                        )
                      : const Center(
                          child: Icon(Icons.directions_car_rounded,
                              color: MM.textMuted, size: 40),
                        ),
                ),
                const SizedBox(height: 14),
                // Vehicle name
                _previewLine(
                  '${_makeCtrl.text.isEmpty ? 'Make' : _makeCtrl.text} '
                  '${_modelCtrl.text.isEmpty ? 'Model' : _modelCtrl.text}',
                  isBold: true,
                ),
                _previewLine(
                  _year.toString(),
                  color: MM.textSub,
                ),
                const SizedBox(height: 8),
                _previewLine(
                  _priceCtrl.text.isEmpty
                      ? 'Price —'
                      : '\$${_priceCtrl.text}',
                  color: MM.accentGreen,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    _chip(_fuelType, MM.brandBlue),
                    _chip(_transmission, MM.accentAmber),
                    _chip(_bodyType,  MM.accentPurple),
                  ],
                ),
                if (_featured) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MM.accentAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: MM.accentAmber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: MM.accentAmber, size: 12),
                        SizedBox(width: 4),
                        Text('Featured',
                            style: TextStyle(
                                color: MM.accentAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Checklist
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MM.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MM.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.checklist_rounded,
                      color: MM.accentGreen, size: 16),
                  const SizedBox(width: 8),
                  const Text('Checklist',
                      style: TextStyle(
                          color: MM.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
                Divider(color: MM.border, height: 20),
                _checkRow('Make & Model',
                    _makeCtrl.text.isNotEmpty && _modelCtrl.text.isNotEmpty),
                _checkRow('Price set',
                    _priceCtrl.text.isNotEmpty),
                _checkRow('Mileage entered',
                    _mileageCtrl.text.isNotEmpty),
                _checkRow('Photos added',
                    _images.isNotEmpty),
                _checkRow('Description added',
                    _shortDescCtrl.text.isNotEmpty),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewLine(String text,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(text,
          style: TextStyle(
              color: color ?? MM.textPrimary,
              fontSize: isBold ? 15 : 13,
              fontWeight:
                  isBold ? FontWeight.w700 : FontWeight.w400)),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _checkRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? MM.accentGreen : MM.textMuted,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: done ? MM.textPrimary : MM.textSub,
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ── Sticky save bar
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: MM.bgCard,
        border: Border(top: BorderSide(color: MM.border)),
      ),
      child: Row(
        children: [
          // Status selector
          Expanded(
            child: _buildDropdown<String>(
              value: _status,
              icon: Icons.toggle_on_rounded,
              items: _statuses,
              label: (s) => s[0].toUpperCase() + s.substring(1),
              onChanged: (v) => setState(() {
                _status  = v!;
                _isDirty = true;
              }),
              color: MM.statusColor(_status),
            ),
          ),
          const SizedBox(width: 12),
          // Save button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MM.brandBlue,
                  disabledBackgroundColor:
                      MM.brandBlue.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              Colors.white),
                        ),
                      )
                    : const Text('Save Vehicle',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SECTION CONTENTS
  // ════════════════════════════════════════════════════════════

  // ── 1. Identity
  Widget _buildIdentitySection() {
    final years = List.generate(40, (i) => DateTime.now().year - i);
    return Column(
      children: [
        _row([
          _field('Make', _makeCtrl,
              icon: Icons.directions_car_rounded,
              required: true),
          _field('Model', _modelCtrl,
              icon: Icons.drive_eta_rounded,
              required: true),
        ]),
        const SizedBox(height: 12),
        _row([
          _buildDropdown<int>(
            value: _year,
            icon: Icons.calendar_today_rounded,
            items: years,
            label: (y) => y.toString(),
            onChanged: (v) => setState(() {
              _year    = v!;
              _isDirty = true;
            }),
          ),
          _field('Trim / Edition', _trimCtrl,
              icon: Icons.layers_rounded),
        ]),
        const SizedBox(height: 12),
        _row([
          _field('VIN', _vinCtrl,
              icon: Icons.fingerprint_rounded,
              hint: 'e.g. 1HGCM82633A123456'),
          _field('Stock Number', _stockCtrl,
              icon: Icons.tag_rounded),
        ]),
        const SizedBox(height: 12),
        _buildDropdown<String>(
          value: _condition,
          icon: Icons.verified_rounded,
          items: _conditions,
          label: (c) => c,
          onChanged: (v) => setState(() {
            _condition = v!;
            _isDirty   = true;
          }),
          fullWidth: true,
          labelText: 'Condition',
        ),
      ],
    );
  }

  // ── 2. Pricing
  Widget _buildPricingSection() {
    return Column(
      children: [
        _field('Price (USD)', _priceCtrl,
            icon: Icons.attach_money_rounded,
            required: true,
            keyboard: TextInputType.number,
            hint: 'e.g. 29999',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Price is required.';
              if (double.tryParse(v) == null)
                return 'Enter a valid number.';
              if (double.parse(v) <= 0)
                return 'Price must be greater than 0.';
              return null;
            }),
        const SizedBox(height: 12),
        _field('Sale Price (USD)', _salePriceCtrl,
            icon: Icons.local_offer_rounded,
            keyboard: TextInputType.number,
            hint: 'Optional — leave blank if no sale',
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (double.tryParse(v) == null)
                return 'Enter a valid number.';
              final price =
                  double.tryParse(_priceCtrl.text) ?? 0;
              final sale  = double.tryParse(v) ?? 0;
              if (sale >= price)
                return 'Sale price must be less than regular price.';
              return null;
            }),
        const SizedBox(height: 12),
        _field('Mileage (miles)', _mileageCtrl,
            icon: Icons.speed_rounded,
            keyboard: TextInputType.number,
            hint: 'e.g. 45000',
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (int.tryParse(v) == null)
                return 'Enter a whole number.';
              return null;
            }),
      ],
    );
  }

  // ── 3. Specs
  Widget _buildSpecsSection() {
    return Column(
      children: [
        _row([
          _buildDropdown<String>(
            value: _fuelType,
            icon: Icons.local_gas_station_rounded,
            items: _fuelTypes,
            label: (s) => s,
            onChanged: (v) => setState(() {
              _fuelType = v!;
              _isDirty  = true;
            }),
            labelText: 'Fuel Type',
          ),
          _buildDropdown<String>(
            value: _transmission,
            icon: Icons.settings_input_component_rounded,
            items: _transmissions,
            label: (s) => s,
            onChanged: (v) => setState(() {
              _transmission = v!;
              _isDirty      = true;
            }),
            labelText: 'Transmission',
          ),
        ]),
        const SizedBox(height: 12),
        _row([
          _buildDropdown<String>(
            value: _bodyType,
            icon: Icons.directions_car_filled_rounded,
            items: _bodyTypes,
            label: (s) => s,
            onChanged: (v) => setState(() {
              _bodyType = v!;
              _isDirty  = true;
            }),
            labelText: 'Body Type',
          ),
          _buildDropdown<String>(
            value: _drivetrain,
            icon: Icons.rotate_right_rounded,
            items: _drivetrains,
            label: (s) => s,
            onChanged: (v) => setState(() {
              _drivetrain = v!;
              _isDirty    = true;
            }),
            labelText: 'Drivetrain',
          ),
        ]),
        const SizedBox(height: 12),
        _field('Engine', _engineCtrl,
            icon: Icons.engineering_rounded,
            hint: 'e.g. 2.0L Turbocharged I4'),
        const SizedBox(height: 12),
        _row([
          _field('Exterior Color', _extColorCtrl,
              icon: Icons.palette_rounded,
              hint: 'e.g. Pearl White'),
          _field('Interior Color', _intColorCtrl,
              icon: Icons.chair_rounded,
              hint: 'e.g. Black Leather'),
        ]),
        const SizedBox(height: 12),
        // Doors stepper
        _row([
          _stepperField(
            label: 'Doors',
            icon: Icons.sensor_door_rounded,
            value: _doors,
            min: 2, max: 6,
            onChanged: (v) => setState(() {
              _doors   = v;
              _isDirty = true;
            }),
          ),
          _stepperField(
            label: 'Seats',
            icon: Icons.airline_seat_recline_normal_rounded,
            value: _seats,
            min: 2, max: 9,
            onChanged: (v) => setState(() {
              _seats   = v;
              _isDirty = true;
            }),
          ),
        ]),
      ],
    );
  }

  // ── 4. Description
  Widget _buildDescriptionSection() {
    return Column(
      children: [
        _field('Short Description', _shortDescCtrl,
            icon: Icons.short_text_rounded,
            hint: 'One sentence summary shown on listing cards',
            maxLines: 2),
        const SizedBox(height: 12),
        _field('Full Description', _fullDescCtrl,
            icon: Icons.notes_rounded,
            hint: 'Detailed vehicle description for the full listing page',
            maxLines: 5),
      ],
    );
  }

  // ── 5. Media
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload button
        GestureDetector(
          onTap: _saving ? null : _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: MM.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MM.brandBlue.withOpacity(0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  color: MM.brandBlue, size: 32,
                ),
                const SizedBox(height: 8),
                const Text('Tap to add photos',
                    style: TextStyle(
                        color: MM.brandBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _images.isEmpty
                      ? 'JPG, PNG — multiple supported'
                      : '${_images.length} selected · tap to add more',
                  style: const TextStyle(
                      color: MM.textSub, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: MM.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Tap image to set as primary · Tap ✕ to remove',
                style: TextStyle(
                    color: MM.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, i) {
              final isPrimary = i == _primaryIndex;
              return GestureDetector(
                onTap: () => _setPrimary(i),
                child: Stack(
                  children: [
                    // Web-Safe Image rendering
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImagePreview(i),
                    ),
                    // Primary border overlay
                    if (isPrimary)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: MM.accentAmber,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    // Primary badge
                    if (isPrimary)
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: MM.accentAmber,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.white,
                                  size: 10),
                              SizedBox(width: 3),
                              Text('Primary',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    // Remove button
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  Reusable form widgets
  // ════════════════════════════════════════════════════════════

  // Two-column row
  Widget _row(List<Widget> children) {
    return Row(
      children: children
          .map((c) => Expanded(child: c))
          .toList()
          .expand((c) => [c, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  // Text field
  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    bool required = false,
    int maxLines  = 1,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      style: const TextStyle(color: MM.textPrimary, fontSize: 14),
      cursorColor: MM.brandBlue,
      validator: validator ??
          (required
              ? (v) {
                  if (v == null || v.trim().isEmpty)
                    return '$label is required.';
                  return null;
                }
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
            color: MM.textSub, fontSize: 13),
        hintStyle: const TextStyle(
            color: MM.textMuted, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: MM.textMuted, size: 18)
            : null,
        filled: true,
        fillColor: MM.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: MM.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: MM.brandBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: MM.accentRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: MM.accentRed, width: 1.8),
        ),
        errorStyle: const TextStyle(
            color: MM.accentRed, fontSize: 11),
      ),
    );
  }

  // Dropdown
  Widget _buildDropdown<T>({
    required T value,
    required IconData icon,
    required List<T> items,
    required String Function(T) label,
    required void Function(T?) onChanged,
    bool fullWidth = false,
    String? labelText,
    Color? color,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: MM.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color != null
              ? color.withOpacity(0.4)
              : MM.border,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: MM.bgSurface,
          style: TextStyle(
              color: color ?? MM.textPrimary,
              fontSize: 14,
              fontWeight: color != null
                  ? FontWeight.w600
                  : FontWeight.w400),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: color ?? MM.textMuted, size: 20),
          hint: labelText != null
              ? Row(children: [
                  Icon(icon, color: MM.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(labelText,
                      style: const TextStyle(
                          color: MM.textSub, fontSize: 13)),
                ])
              : null,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: MM.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(label(item),
                      style: const TextStyle(
                          color: MM.textPrimary,
                          fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Stepper (doors / seats)
  Widget _stepperField({
    required String label,
    required IconData icon,
    required int value,
    required int min,
    required int max,
    required void Function(int) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MM.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MM.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: MM.textMuted, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: MM.textSub, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: value > min
                ? () => onChanged(value - 1)
                : null,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: value > min
                    ? MM.brandBlue.withOpacity(0.12)
                    : MM.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MM.border),
              ),
              child: Icon(Icons.remove_rounded,
                  color: value > min
                      ? MM.brandBlue : MM.textMuted,
                  size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12),
            child: Text('$value',
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: value < max
                ? () => onChanged(value + 1)
                : null,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: value < max
                    ? MM.brandBlue.withOpacity(0.12)
                    : MM.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MM.border),
              ),
              child: Icon(Icons.add_rounded,
                  color: value < max
                      ? MM.brandBlue : MM.textMuted,
                  size: 16),
            ),
          ),
        ],
      ),
    );
  }
}