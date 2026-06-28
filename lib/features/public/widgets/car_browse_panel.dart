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
class CarBrowsePanel extends StatefulWidget {
  const CarBrowsePanel({
    super.key,
    required this.onFavoriteTap,
    this.favoriteCarIds = const {},
  });

  final void Function(CarModel car) onFavoriteTap;
  final Set<String> favoriteCarIds;

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

  /// Public so a parent (RefreshIndicator, or after a favorite action
  /// fails and needs a clean refetch) can trigger a reload.
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
            !(_selectedBodyTypes.contains(car.bodyType))) {
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

  void _openFilterSheet() {
    Set<String> tempBodyTypes = {..._selectedBodyTypes};
    RangeValues tempPrice = _priceRange;
    RangeValues tempYear = _yearRange;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempBodyTypes = {};
                              tempPrice = _priceBounds;
                              tempYear = _yearBounds;
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_availableBodyTypes.isNotEmpty) ...[
                      const Text(
                        'Body Type',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableBodyTypes.map((type) {
                          final selected = tempBodyTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  tempBodyTypes.add(type);
                                } else {
                                  tempBodyTypes.remove(type);
                                }
                              });
                            },
                            selectedColor: Colors.white,
                            backgroundColor: const Color(0xFF26262A),
                            labelStyle: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                            ),
                            checkmarkColor: Colors.black,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Price: \$${tempPrice.start.round()} - \$${tempPrice.end.round()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                    const SizedBox(height: 10),
                    Text(
                      'Year: ${tempYear.start.round()} - ${tempYear.end.round()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    RangeSlider(
                      values: tempYear,
                      min: _yearBounds.start,
                      max: _yearBounds.end > _yearBounds.start
                          ? _yearBounds.end
                          : _yearBounds.start + 1,
                      activeColor: Colors.white,
                      inactiveColor: const Color(0xFF3F3F46),
                      onChanged: (val) => setSheetState(() => tempYear = val),
                    ),
                    const SizedBox(height: 24),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSearchAndIntro()),
        if (!_loading && _availableMakes.isNotEmpty)
          SliverToBoxAdapter(child: _buildMakeChips()),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _buildBody(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSearchAndIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find Your Dream Car',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Browse quality vehicles from our dealership.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by make, model, year...',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: _allCars.isEmpty ? null : _openFilterSheet,
                  icon: const Icon(Icons.tune, color: Colors.white),
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: makes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final make = makes[index];
          final isSelected =
              (make == 'All' && _selectedMake == null) || make == _selectedMake;
          return ChoiceChip(
            label: Text(make),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedMake = make == 'All' ? null : make);
              _applyFilters();
            },
            selectedColor: Colors.white,
            backgroundColor: const Color(0xFF1A1A1D),
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
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
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white38, size: 40),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: loadCars,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, color: Colors.white38, size: 40),
                SizedBox(height: 12),
                Text('No vehicles match your search.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width > 1100 ? 4 : (width > 760 ? 3 : 2);

          // The details block under the image is a fixed pixel height
          // regardless of card width, so wider cards (more columns) need
          // a taller aspect ratio value to keep the image from looking
          // squashed relative to that fixed-height text block.
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
                final car = _filtered[index];
                return CarCard(
                  car: car,
                  isFavorite: widget.favoriteCarIds.contains(car.id),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
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