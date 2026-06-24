// edit_vehicle_page.dart
//
// Loads existing car data, lets admin edit all fields,
// uploads new images and removes deleted ones,
// then saves everything to Supabase immediately on tap.
//
// Supabase tables: cars, car_images
// Supabase bucket: car_images

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';

// ═══════════════════════════════════════════════════════════
//  EDIT VEHICLE PAGE
// ═══════════════════════════════════════════════════════════

class EditVehiclePage extends StatefulWidget {
  final String carId;
  final VoidCallback? onSaved;

  const EditVehiclePage({
    super.key,
    required this.carId,
    this.onSaved,
  });

  @override
  State<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  final _supabase = Supabase.instance.client;
  final _formKey  = GlobalKey<FormState>();
  final _scroll   = ScrollController();

  // ── Section expand state
  final _expanded = [true, false, false, false, false];
  final _sectionKeys = List.generate(5, (_) => GlobalKey());

  // ── Controllers
  final _vinCtrl       = TextEditingController();
  final _stockCtrl     = TextEditingController();
  final _makeCtrl      = TextEditingController();
  final _modelCtrl     = TextEditingController();
  final _trimCtrl      = TextEditingController();
  final _priceCtrl     = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _mileageCtrl   = TextEditingController();
  final _engineCtrl    = TextEditingController();
  final _extColorCtrl  = TextEditingController();
  final _intColorCtrl  = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _fullDescCtrl  = TextEditingController();

  // ── Dropdowns
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
  // Existing images from DB
  List<_ExistingImage> _existingImages = [];
  // New images picked locally
  final List<XFile> _newImages = [];
  int  _primaryIndex  = 0; // index across combined [existing + new]
  bool _isLoading     = true;
  bool _isSaving      = false;
  int  _uploadCurrent = 0;
  int  _uploadTotal   = 0;

  // ── Options
  static const _fuelTypes     = ['Petrol','Diesel','Electric','Hybrid','Plug-in Hybrid'];
  static const _transmissions = ['Automatic','Manual','CVT','Semi-Automatic'];
  static const _bodyTypes     = ['Sedan','SUV','Truck','Coupe','Convertible',
                                  'Hatchback','Wagon','Van','Minivan'];
  static const _drivetrains   = ['FWD','RWD','AWD','4WD'];
  static const _conditions    = ['New','Used','Certified Pre-Owned'];
  static const _statuses      = ['available','reserved','sold'];

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _loadCar();
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

  // ════════════════════════════════════════════════════════
  //  LOAD EXISTING DATA
  // ════════════════════════════════════════════════════════
  Future<void> _loadCar() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.from('cars').select().eq('id', widget.carId).single(),
        _supabase
            .from('car_images')
            .select('id, image_url, is_primary, display_order')
            .eq('car_id', widget.carId)
            .order('display_order'),
      ]);

      final car    = results[0] as Map<String, dynamic>;
      final images = results[1] as List;

      // Populate controllers
      _vinCtrl.text       = car['vin']               ?? '';
      _stockCtrl.text     = car['stock_number']      ?? '';
      _makeCtrl.text      = car['make']              ?? '';
      _modelCtrl.text     = car['model']             ?? '';
      _trimCtrl.text      = car['trim']              ?? '';
      _priceCtrl.text     = car['price']?.toString() ?? '';
      _salePriceCtrl.text = car['sale_price']?.toString() ?? '';
      _mileageCtrl.text   = car['mileage']?.toString() ?? '';
      _engineCtrl.text    = car['engine']            ?? '';
      _extColorCtrl.text  = car['exterior_color']    ?? '';
      _intColorCtrl.text  = car['interior_color']    ?? '';
      _shortDescCtrl.text = car['short_description'] ?? '';
      _fullDescCtrl.text  = car['full_description']  ?? '';

      // Dropdowns — safe fallback if DB value not in list
      _year         = car['year']         ?? DateTime.now().year;
      _fuelType     = _safe(_fuelTypes,     car['fuel_type'],    'Petrol');
      _transmission = _safe(_transmissions, car['transmission'], 'Automatic');
      _bodyType     = _safe(_bodyTypes,     car['body_type'],    'Sedan');
      _drivetrain   = _safe(_drivetrains,   car['drivetrain'],   'FWD');
      _condition    = _safe(_conditions,    car['condition'],    'Used');
      _status       = _safe(_statuses,      car['status'],       'available');
      _doors        = car['doors']    ?? 4;
      _seats        = car['seats']    ?? 5;
      _featured     = car['featured'] == true;

      // Images — sort primary first
      final sorted = List<Map<String, dynamic>>.from(images);
      sorted.sort((a, b) {
        if (a['is_primary'] == true) return -1;
        if (b['is_primary'] == true) return  1;
        return (a['display_order'] ?? 0)
            .compareTo(b['display_order'] ?? 0);
      });

      _existingImages = sorted.map((e) => _ExistingImage(
        id:        e['id'].toString(),
        url:       e['image_url'].toString(),
        isPrimary: e['is_primary'] == true,
      )).toList();

      // Set primary index to the existing primary
      final primaryIdx = _existingImages
          .indexWhere((e) => e.isPrimary);
      _primaryIndex = primaryIdx >= 0 ? primaryIdx : 0;

      _isDirty = false; // reset after initial load
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('EditVehicle load error: $e');
      if (mounted) {
        _toast('Failed to load vehicle data.', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  String _safe(List<String> list, dynamic val, String fallback) {
    if (val == null) return fallback;
    return list.contains(val.toString()) ? val.toString() : fallback;
  }

  // ════════════════════════════════════════════════════════
  //  IMAGE MANAGEMENT
  // ════════════════════════════════════════════════════════
  int get _totalImageCount =>
      _existingImages.where((e) => !e.markedForDelete).length +
      _newImages.length;

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      _newImages.addAll(picked);
      _isDirty = true;
    });
  }

  void _removeExisting(int index) {
    setState(() {
      _existingImages[index].markedForDelete = true;
      _isDirty = true;
      // Re-adjust primary if needed
      if (_primaryIndex == index) _primaryIndex = 0;
    });
  }

  void _removeNew(int index) {
    setState(() {
      _newImages.removeAt(index);
      _isDirty = true;
    });
  }

  // ════════════════════════════════════════════════════════
  //  SAVE — updates DB immediately
  // ════════════════════════════════════════════════════════
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _toast('Please fix the errors before saving.', isError: true);
      return;
    }

    setState(() {
      _isSaving      = true;
      _uploadCurrent = 0;
      _uploadTotal   = _newImages.length;
    });

    try {
      // ── 1. Update car record (With Lowercase Conversions to Match Database Constraints)
await _supabase.from('cars').update({
  'vin':               _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
  'stock_number':      _stockCtrl.text.trim().isEmpty ? null : _stockCtrl.text.trim(),
  'make':              _makeCtrl.text.trim(),
  'model':             _modelCtrl.text.trim(),
  'year':              _year,
  'trim':              _trimCtrl.text.trim().isEmpty ? null : _trimCtrl.text.trim(),
  
  // Lowercase conversions applied to align perfectly with add_vehicle_page behavior
  'condition':         _condition.toLowerCase(),
  'fuel_type':         _fuelType.toLowerCase(),
  'transmission':      _transmission.toLowerCase(),
  'body_type':         _bodyType.toLowerCase(),
  'drivetrain':        _drivetrain.toLowerCase(),
  
  'price':             double.tryParse(_priceCtrl.text.trim()) ?? 0,
  'sale_price':        _salePriceCtrl.text.trim().isEmpty
                         ? null
                         : double.tryParse(_salePriceCtrl.text.trim()),
  'mileage':           int.tryParse(_mileageCtrl.text.trim()),
  'engine':            _engineCtrl.text.trim().isEmpty ? null : _engineCtrl.text.trim(),
  'exterior_color':    _extColorCtrl.text.trim().isEmpty ? null : _extColorCtrl.text.trim(),
  'interior_color':    _intColorCtrl.text.trim().isEmpty ? null : _intColorCtrl.text.trim(),
  'doors':             _doors,
  'seats':             _seats,
  'short_description': _shortDescCtrl.text.trim().isEmpty ? null : _shortDescCtrl.text.trim(),
  'full_description':  _fullDescCtrl.text.trim().isEmpty ? null : _fullDescCtrl.text.trim(),
  'status':            _status.toLowerCase(),
  'featured':          _featured,
  'updated_at':        DateTime.now().toIso8601String(),
}).eq('id', widget.carId);
      // ── 2. Delete images marked for removal
      for (final img in _existingImages.where((e) => e.markedForDelete)) {
        await _supabase
            .from('car_images')
            .delete()
            .eq('id', img.id);
        // Also remove from storage if you want (optional)
        // final fileName = img.url.split('/').last;
        // await _supabase.storage.from('car_images').remove([fileName]);
      }

      // ── 3. Upload new images
      int displayOrder = _existingImages
          .where((e) => !e.markedForDelete)
          .length;

      for (int i = 0; i < _newImages.length; i++) {
        setState(() => _uploadCurrent = i + 1);

        final file     = File(_newImages[i].path);
        final ext      = _newImages[i].path.split('.').last.toLowerCase();
        final fileName =
            '${widget.carId}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        await _supabase.storage
            .from('car_images')
            .upload(fileName, file);

        final url = _supabase.storage
            .from('car_images')
            .getPublicUrl(fileName);

        await _supabase.from('car_images').insert({
          'car_id':        widget.carId,
          'image_url':     url,
          'is_primary':    false, // primary handled below
          'display_order': displayOrder + i,
        });
      }

      // ── 4. Update primary image flag
      // Clear all is_primary first
      await _supabase
          .from('car_images')
          .update({'is_primary': false})
          .eq('car_id', widget.carId);

      // Set the correct primary
      final activeExisting = _existingImages
          .where((e) => !e.markedForDelete)
          .toList();

      if (_primaryIndex < activeExisting.length) {
        // Primary is an existing image
        await _supabase
            .from('car_images')
            .update({'is_primary': true})
            .eq('id', activeExisting[_primaryIndex].id);
      }
      // (If primary is a new image, it was uploaded without is_primary=true
      // because we don't have its DB id yet — update by position)
      else {
        final newIdx = _primaryIndex - activeExisting.length;
        if (newIdx >= 0 && newIdx < _newImages.length) {
          // Get the newly inserted image id by querying last inserted
          final rows = await _supabase
              .from('car_images')
              .select('id, display_order')
              .eq('car_id', widget.carId)
              .order('display_order', ascending: false)
              .limit(_newImages.length);

          if (rows.isNotEmpty) {
            // The primary new image has display_order = activeExisting.length + newIdx
            final targetOrder = activeExisting.length + newIdx;
            final match = (rows as List).firstWhere(
              (r) => r['display_order'] == targetOrder,
              orElse: () => rows.first,
            );
            await _supabase
                .from('car_images')
                .update({'is_primary': true})
                .eq('id', match['id']);
          }
        }
      }

      if (!mounted) return;

      _toast('Vehicle updated successfully.');
      _isDirty = false;
      widget.onSaved?.call();

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint('EditVehicle save error: $e');
      if (mounted) _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('duplicate') || raw.contains('unique'))
      return 'A vehicle with this VIN or stock number already exists.';
    if (raw.contains('network') || raw.contains('socket'))
      return 'No internet connection. Please try again.';
    if (raw.contains('storage'))
      return 'Image upload failed. Check storage bucket permissions.';
    return 'Something went wrong. Please try again.';
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
        duration: Duration(seconds: isError ? 4 : 2),
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
  //  NAVIGATION GUARD
  // ════════════════════════════════════════════════════════
  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
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
            'Your unsaved edits will be lost.',
            style: TextStyle(
                color: MM.textSub, fontSize: 14, height: 1.5)),
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

  void _toggleSection(int i) {
    setState(() => _expanded[i] = !_expanded[i]);
    if (_expanded[i]) {
      Future.delayed(const Duration(milliseconds: 200), () {
        final ctx = _sectionKeys[i].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut);
        }
      });
    }
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Theme(
        data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: MM.bgDeep),
        child: Scaffold(
          backgroundColor: MM.bgDeep,
          body: _isLoading
              ? _loader()
              : Column(
                  children: [
                    _buildTopBar(),
                    if (_isSaving) _buildProgressBanner(),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                              20, 20, 20, 120),
                          child: Column(
                            children: [
                              _section(0, Icons.badge_rounded,
                                  'Vehicle Identity',
                                  'VIN, make, model, year',
                                  MM.brandBlue,
                                  _identitySection()),
                              _section(1, Icons.attach_money_rounded,
                                  'Pricing & Mileage',
                                  'Price, sale price, mileage',
                                  MM.accentGreen,
                                  _pricingSection()),
                              _section(2, Icons.settings_rounded,
                                  'Specifications',
                                  'Engine, fuel, transmission, colors',
                                  MM.accentAmber,
                                  _specsSection()),
                              _section(3, Icons.description_rounded,
                                  'Description',
                                  'Short and full description',
                                  MM.accentPurple,
                                  _descSection()),
                              _section(4, Icons.photo_library_rounded,
                                  'Photos',
                                  '$_totalImageCount image${_totalImageCount == 1 ? '' : 's'}',
                                  MM.accentRed,
                                  _mediaSection()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: _isLoading ? null : _saveBar(),
        ),
      ),
    );
  }

  // ── Top bar
  Widget _buildTopBar() {
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
          const SizedBox(width: 14),
          Text('Vehicle Details',
              style: TextStyle(color: MM.textSub, fontSize: 13)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right_rounded,
                color: MM.textMuted, size: 16),
          ),
          const Text('Edit',
              style: TextStyle(
                  color: MM.textPrimary,
                  fontSize: 13,
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
              child: Row(children: [
                Icon(
                  _featured
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color:
                      _featured ? MM.accentAmber : MM.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text('Featured',
                    style: TextStyle(
                        color: _featured
                            ? MM.accentAmber : MM.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBanner() {
    final pct = _uploadTotal == 0
        ? 0.0 : _uploadCurrent / _uploadTotal;
    return Container(
      color: MM.brandNavy,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      child: Row(children: [
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
              ? 'Saving changes…'
              : 'Uploading image $_uploadCurrent of $_uploadTotal…',
          style: const TextStyle(
              color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text('${(pct * 100).toInt()}%',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  // ── Collapsible section wrapper
  Widget _section(
    int index,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    Widget child,
  ) {
    final open = _expanded[index];
    return Container(
      key: _sectionKeys[index],
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: open ? color.withOpacity(0.3) : MM.border),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => _toggleSection(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
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
            ]),
          ),
        ),
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
      ]),
    );
  }

  // ── Save bar
  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: MM.bgCard,
        border: Border(top: BorderSide(color: MM.border)),
      ),
      child: Row(children: [
        // Status selector
        Expanded(
          child: _dropdown<String>(
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
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: MM.brandBlue,
                disabledBackgroundColor:
                    MM.brandBlue.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            Colors.white),
                      ))
                  : const Text('Save Changes',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SECTION CONTENTS  (same structure as AddVehiclePage)
  // ════════════════════════════════════════════════════════

  Widget _identitySection() {
    final years = List.generate(40, (i) => DateTime.now().year - i);
    return Column(children: [
      _row([
        _field('Make',  _makeCtrl, icon: Icons.directions_car_rounded, required: true),
        _field('Model', _modelCtrl, icon: Icons.drive_eta_rounded, required: true),
      ]),
      const SizedBox(height: 12),
      _row([
        _dropdown<int>(
          value: _year,
          icon: Icons.calendar_today_rounded,
          items: years,
          label: (y) => y.toString(),
          onChanged: (v) => setState(() { _year = v!; _isDirty = true; }),
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
      _dropdown<String>(
        value: _condition,
        icon: Icons.verified_rounded,
        items: _conditions,
        label: (c) => c,
        onChanged: (v) => setState(() { _condition = v!; _isDirty = true; }),
        fullWidth: true,
        labelText: 'Condition',
      ),
    ]);
  }

  Widget _pricingSection() => Column(children: [
    _field('Price (USD)', _priceCtrl,
        icon: Icons.attach_money_rounded,
        required: true,
        keyboard: TextInputType.number,
        hint: 'e.g. 29999',
        validator: (v) {
          if (v == null || v.isEmpty) return 'Price is required.';
          if (double.tryParse(v) == null) return 'Enter a valid number.';
          if (double.parse(v) <= 0) return 'Price must be greater than 0.';
          return null;
        }),
    const SizedBox(height: 12),
    _field('Sale Price (USD)', _salePriceCtrl,
        icon: Icons.local_offer_rounded,
        keyboard: TextInputType.number,
        hint: 'Optional — leave blank if no sale',
        validator: (v) {
          if (v == null || v.isEmpty) return null;
          if (double.tryParse(v) == null) return 'Enter a valid number.';
          final p = double.tryParse(_priceCtrl.text) ?? 0;
          final s = double.tryParse(v) ?? 0;
          if (s >= p) return 'Sale price must be less than regular price.';
          return null;
        }),
    const SizedBox(height: 12),
    _field('Mileage (miles)', _mileageCtrl,
        icon: Icons.speed_rounded,
        keyboard: TextInputType.number,
        hint: 'e.g. 45000',
        validator: (v) {
          if (v == null || v.isEmpty) return null;
          if (int.tryParse(v) == null) return 'Enter a whole number.';
          return null;
        }),
  ]);

  Widget _specsSection() => Column(children: [
    _row([
      _dropdown<String>(
        value: _fuelType,
        icon: Icons.local_gas_station_rounded,
        items: _fuelTypes, label: (s) => s,
        onChanged: (v) => setState(() { _fuelType = v!; _isDirty = true; }),
        labelText: 'Fuel Type',
      ),
      _dropdown<String>(
        value: _transmission,
        icon: Icons.settings_input_component_rounded,
        items: _transmissions, label: (s) => s,
        onChanged: (v) => setState(() { _transmission = v!; _isDirty = true; }),
        labelText: 'Transmission',
      ),
    ]),
    const SizedBox(height: 12),
    _row([
      _dropdown<String>(
        value: _bodyType,
        icon: Icons.directions_car_filled_rounded,
        items: _bodyTypes, label: (s) => s,
        onChanged: (v) => setState(() { _bodyType = v!; _isDirty = true; }),
        labelText: 'Body Type',
      ),
      _dropdown<String>(
        value: _drivetrain,
        icon: Icons.rotate_right_rounded,
        items: _drivetrains, label: (s) => s,
        onChanged: (v) => setState(() { _drivetrain = v!; _isDirty = true; }),
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
          icon: Icons.palette_rounded, hint: 'e.g. Pearl White'),
      _field('Interior Color', _intColorCtrl,
          icon: Icons.chair_rounded, hint: 'e.g. Black Leather'),
    ]),
    const SizedBox(height: 12),
    _row([
      _stepper(label: 'Doors', icon: Icons.sensor_door_rounded,
          value: _doors, min: 2, max: 6,
          onChanged: (v) => setState(() { _doors = v; _isDirty = true; })),
      _stepper(label: 'Seats',
          icon: Icons.airline_seat_recline_normal_rounded,
          value: _seats, min: 2, max: 9,
          onChanged: (v) => setState(() { _seats = v; _isDirty = true; })),
    ]),
  ]);

  Widget _descSection() => Column(children: [
    _field('Short Description', _shortDescCtrl,
        icon: Icons.short_text_rounded,
        hint: 'One sentence summary shown on listing cards',
        maxLines: 2),
    const SizedBox(height: 12),
    _field('Full Description', _fullDescCtrl,
        icon: Icons.notes_rounded,
        hint: 'Detailed vehicle description',
        maxLines: 5),
  ]);

  // ── Media section — existing + new images
  Widget _mediaSection() {
    final activeExisting = _existingImages
        .where((e) => !e.markedForDelete)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add more photos button
        GestureDetector(
          onTap: _isSaving ? null : _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: MM.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MM.brandBlue.withOpacity(0.4)),
            ),
            child: Column(children: [
              const Icon(Icons.add_photo_alternate_rounded,
                  color: MM.brandBlue, size: 28),
              const SizedBox(height: 6),
              const Text('Add more photos',
                  style: TextStyle(
                      color: MM.brandBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                '$_totalImageCount image${_totalImageCount == 1 ? '' : 's'} total',
                style: const TextStyle(
                    color: MM.textSub, fontSize: 11),
              ),
            ]),
          ),
        ),

        if (_totalImageCount > 0) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: MM.textMuted, size: 13),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Tap image to set as primary · Tap ✕ to remove',
                style: TextStyle(color: MM.textMuted, fontSize: 11),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // ── Existing images
          if (activeExisting.isNotEmpty) ...[
            const Text('Current Photos',
                style: TextStyle(
                    color: MM.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeExisting.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                final img       = activeExisting[i];
                final isPrimary = _primaryIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _primaryIndex = i),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        img.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: MM.bgCard,
                          child: const Icon(
                              Icons.broken_image_rounded,
                              color: MM.textMuted),
                        ),
                      ),
                    ),
                    if (isPrimary)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: MM.accentAmber, width: 2.5),
                          ),
                        ),
                      ),
                    if (isPrimary)
                      Positioned(top: 5, left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MM.accentAmber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.white, size: 9),
                              SizedBox(width: 2),
                              Text('Primary',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(top: 5, right: 5,
                      child: GestureDetector(
                        onTap: () => _removeExisting(
                            _existingImages.indexOf(img)),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ],

          // ── New images
          if (_newImages.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('New Photos',
                style: TextStyle(
                    color: MM.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _newImages.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                final globalIdx = activeExisting.length + i;
                final isPrimary = _primaryIndex == globalIdx;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _primaryIndex = globalIdx),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_newImages[i].path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    if (isPrimary)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: MM.accentAmber, width: 2.5),
                          ),
                        ),
                      ),
                    if (isPrimary)
                      Positioned(top: 5, left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MM.accentAmber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.white, size: 9),
                              SizedBox(width: 2),
                              Text('New · Primary',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(top: 5, right: 5,
                      child: GestureDetector(
                        onTap: () => _removeNew(i),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                    // "New" badge
                    Positioned(bottom: 5, left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: MM.brandBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('NEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  REUSABLE FORM WIDGETS
  // ════════════════════════════════════════════════════════
  Widget _row(List<Widget> children) => Row(
    children: children
        .map((c) => Expanded(child: c))
        .toList()
        .expand((c) => [c, const SizedBox(width: 12)])
        .toList()
      ..removeLast(),
  );

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
        labelStyle: const TextStyle(color: MM.textSub, fontSize: 13),
        hintStyle: const TextStyle(color: MM.textMuted, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: MM.textMuted, size: 18)
            : null,
        filled: true,
        fillColor: MM.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MM.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: MM.brandBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: MM.accentRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: MM.accentRed, width: 1.8),
        ),
        errorStyle: const TextStyle(
            color: MM.accentRed, fontSize: 11),
      ),
    );
  }

  Widget _dropdown<T>({
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
              ? color.withOpacity(0.4) : MM.border,
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
                  ? FontWeight.w600 : FontWeight.w400),
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
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Row(children: [
              Icon(icon, color: MM.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(label(item),
                  style: const TextStyle(
                      color: MM.textPrimary, fontSize: 14)),
            ]),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _stepper({
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
      child: Row(children: [
        Icon(icon, color: MM.textMuted, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: MM.textSub, fontSize: 13)),
        const Spacer(),
        GestureDetector(
          onTap: value > min ? () => onChanged(value - 1) : null,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: value > min
                  ? MM.brandBlue.withOpacity(0.12) : MM.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MM.border),
            ),
            child: Icon(Icons.remove_rounded,
                color: value > min ? MM.brandBlue : MM.textMuted,
                size: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$value',
              style: const TextStyle(
                  color: MM.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + 1) : null,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: value < max
                  ? MM.brandBlue.withOpacity(0.12) : MM.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MM.border),
            ),
            child: Icon(Icons.add_rounded,
                color: value < max ? MM.brandBlue : MM.textMuted,
                size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _loader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 34, height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(MM.brandBlue),
          ),
        ),
        SizedBox(height: 16),
        Text('Loading vehicle data…',
            style: TextStyle(color: MM.textSub, fontSize: 14)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  Existing image model
// ═══════════════════════════════════════════════════════════
class _ExistingImage {
  final String id;
  final String url;
  final bool isPrimary;
  bool markedForDelete;

  _ExistingImage({
    required this.id,
    required this.url,
    required this.isPrimary,
    this.markedForDelete = false,
  });
}