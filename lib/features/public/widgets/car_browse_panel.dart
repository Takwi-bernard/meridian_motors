import 'package:flutter/material.dart';
import '../models/car_model.dart';
import '../services/car_service.dart';
import 'car_card.dart';
import '../car_detail/car_detail_page.dart';

/// Search + filter + responsive grid of available cars.
///
/// Used by both the public Home page and the authenticated Dashboard.
/// The only thing that differs between those two contexts is what a tap
/// on the favorite icon should do — redirect to auth (Home) or actually
/// toggle a favorite (Dashboard) — so that decision is left entirely to
/// [onFavoriteTap].
///
/// [showIntroHeader] controls whether the "Find Your Dream Car" headline
/// and subtitle are rendered at the top. Home suppresses this (the page
/// header already sets the scene); Dashboard shows it since the panel
/// is the only content in view.
class CarBrowsePanel extends StatefulWidget {
  const CarBrowsePanel({
    super.key,
    required this.onFavoriteTap,
    this.favoriteCarIds = const {},
    this.showIntroHeader = true,
  });

  final void Function(CarModel car) onFavoriteTap;
  final Set<String> favoriteCarIds;
  final bool showIntroHeader;

  @override
  State<CarBrowsePanel> createState() => CarBrowsePanelState();
}

class CarBrowsePanelState extends State<CarBrowsePanel> {
  final CarService _service = CarService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;

  List<CarModel> _allCars = [];
  List<CarModel> _filtered = [];

  String? _selectedMake;
  Set<String> _selectedBodyTypes = {};

  RangeValues _priceBounds = const RangeValues(0, 100000);
  RangeValues _yearBounds = const RangeValues(2000, 2026);
  RangeValues _priceRange = const RangeValues(0, 100000);
  RangeValues _yearRange = const RangeValues(2000, 2026);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    loadCars();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadCars() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cars = await _service.fetchAvailableCars();

      final prices = cars.map((c) => c.displayPrice).toList();
      final years = cars.map((c) => c.year.toDouble()).toList();

      final priceBounds = prices.isEmpty
          ? const RangeValues(0, 100000)
          : RangeValues(
              prices.reduce((a, b) => a < b ? a : b),
              prices.reduce((a, b) => a > b ? a : b),
            );

      final yearBounds = years.isEmpty
          ? const RangeValues(2000, 2026)
          : RangeValues(
              years.reduce((a, b) => a < b ? a : b),
              years.reduce((a, b) => a > b ? a : b),
            );

      setState(() {
        _allCars = cars;
        _priceBounds = priceBounds;
        _yearBounds = yearBounds;
        _priceRange = priceBounds;
        _yearRange = yearBounds;
        _selectedMake = null;
        _selectedBodyTypes = {};
        _loading = false;
      });
      _applyFilters();
    } catch (_) {
      setState(() {
        _error = 'Could not load vehicles. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  List<String> get _availableMakes {
    final set = <String>{};
    for (final car in _allCars) {
      if (car.make.isNotEmpty) set.add(car.make);
    }
    return set.toList()..sort();
  }

  List<String> get _availableBodyTypes {
    final set = <String>{};
    for (final car in _allCars) {
      if (car.bodyType != null && car.bodyType!.isNotEmpty) {
        set.add(car.bodyType!);
      }
    }
    return set.toList()..sort();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filtered = _allCars.where((car) {
        if (_selectedMake != null && car.make != _selectedMake) return false;
        if (_selectedBodyTypes.isNotEmpty &&
            !_selectedBodyTypes.contains(car.bodyType)) {
          return false;
        }
        if (car.displayPrice < _priceRange.start ||
            car.displayPrice > _priceRange.end) {
          return false;
        }
        if (car.year < _yearRange.start || car.year > _yearRange.end) {
          return false;
        }
        if (query.isNotEmpty) {
          final haystack =
              '${car.make} ${car.model} ${car.trim ?? ''} ${car.year} ${car.bodyType ?? ''}'
                  .toLowerCase();
          if (!haystack.contains(query)) return false;
        }
        return true;
      }).toList();
    });
  }

  bool get _hasActiveFilters =>
      _selectedBodyTypes.isNotEmpty ||
      _priceRange != _priceBounds ||
      _yearRange != _yearBounds;

  void _openFilterSheet() {
    Set<String> tempBodyTypes = {..._selectedBodyTypes};
    RangeValues tempPrice = _priceRange;
    RangeValues tempYear = _yearRange;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Vehicles',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            tempBodyTypes = {};
                            tempPrice = _priceBounds;
                            tempYear = _yearBounds;
                          }),
                          child: const Text(
                            'Reset All',
                            style: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_availableBodyTypes.isNotEmpty) ...[
                      _filterLabel('Body Type'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableBodyTypes.map((type) {
                          final selected = tempBodyTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: (val) => setSheetState(() {
                              if (val) {
                                tempBodyTypes.add(type);
                              } else {
                                tempBodyTypes.remove(type);
                              }
                            }),
                            selectedColor: Colors.white,
                            backgroundColor: const Color(0xFF26262A),
                            labelStyle: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontSize: 13,
                            ),
                            checkmarkColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _filterLabel(
                      'Price: \$${_formatNumber(tempPrice.start.round())} — \$${_formatNumber(tempPrice.end.round())}',
                    ),
                    RangeSlider(
                      values: tempPrice,
                      min: _priceBounds.start,
                      max: _priceBounds.end > _priceBounds.start
                          ? _priceBounds.end
                          : _priceBounds.start + 1,
                      activeColor: Colors.white,
                      inactiveColor: const Color(0xFF3F3F46),
                      onChanged: (val) => setSheetState(() => tempPrice = val),
                    ),
                    const SizedBox(height: 8),
                    _filterLabel(
                      'Year: ${tempYear.start.round()} — ${tempYear.end.round()}',
                    ),
                    RangeSlider(
                      values: tempYear,
                      min: _yearBounds.start,
                      max: _yearBounds.end > _yearBounds.start
                          ? _yearBounds.end
                          : _yearBounds.start + 1,
                      divisions: (_yearBounds.end - _yearBounds.start).round().clamp(1, 100),
                      activeColor: Colors.white,
                      inactiveColor: const Color(0xFF3F3F46),
                      onChanged: (val) => setSheetState(() => tempYear = val),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedBodyTypes = tempBodyTypes;
                            _priceRange = tempPrice;
                            _yearRange = tempYear;
                          });
                          _applyFilters();
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Apply Filters',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (widget.showIntroHeader)
          SliverToBoxAdapter(child: _buildIntroHeader()),
        SliverToBoxAdapter(child: _buildSearchBar()),
        if (!_loading && _availableMakes.isNotEmpty)
          SliverToBoxAdapter(child: _buildMakeChips()),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _buildBody(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildIntroHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find Your Dream Car',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Browse quality vehicles from our dealership.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, widget.showIntroHeader ? 0 : 14, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search make, model, year...',
                hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14.5),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                filled: true,
                fillColor: const Color(0xFF1A1A1D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter button — shows a dot indicator when filters are active
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: _hasActiveFilters
                    ? Colors.white
                    : const Color(0xFF1A1A1D),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _allCars.isEmpty ? null : _openFilterSheet,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilters
                          ? Colors.black
                          : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMakeChips() {
    final makes = ['All', ..._availableMakes];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: makes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final make = makes[index];
          final isSelected =
              (make == 'All' && _selectedMake == null) ||
              make == _selectedMake;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: ChoiceChip(
              label: Text(make),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedMake = make == 'All' ? null : make);
                _applyFilters();
              },
              selectedColor: Colors.white,
              backgroundColor: const Color(0xFF1A1A1D),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.white12,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: loadCars,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded,
                    color: Colors.white24, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No vehicles found',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try adjusting your search or filters.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedMake = null;
                        _selectedBodyTypes = {};
                        _priceRange = _priceBounds;
                        _yearRange = _yearBounds;
                      });
                      _applyFilters();
                    },
                    child: const Text(
                      'Clear all filters',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width > 1100 ? 4 : (width > 760 ? 3 : 2);
          final aspectRatio =
              columns >= 4 ? 0.82 : (columns == 3 ? 0.78 : 0.70);

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: aspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final car = _filtered[index];
                return CarCard(
                  car: car,
                  isFavorite: widget.favoriteCarIds.contains(car.id),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CarDetailPage(car: car)),
                  ),
                  onFavoriteTap: () => widget.onFavoriteTap(car),
                );
              },
              childCount: _filtered.length,
            ),
          );
        },
      ),
    );
  }
}
