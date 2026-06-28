/// Typed representation of a row in `cars`, joined with its images
/// from `car_images`. Keeping this typed (instead of passing raw
/// Map<String, dynamic> around the widget tree) means typos in column
/// names fail at the service layer, not deep inside some random widget.
class CarModel {
  final String id;
  final String? vin;
  final String? stockNumber;
  final String make;
  final String model;
  final int year;
  final String? trim;
  final String? condition; // e.g. "new" / "used"
  final double price;
  final double? salePrice;
  final int? mileage;
  final String? fuelType;
  final String? transmission;
  final String? bodyType;
  final String? drivetrain;
  final String? engine;
  final String? exteriorColor;
  final String? interiorColor;
  final int? doors;
  final int? seats;
  final String? shortDescription;
  final String? fullDescription;
  final String status;
  final bool featured;
  final String? brand;
  final String? category;

  /// Ordered: primary image first, then by display_order.
  final List<String> imageUrls;

  const CarModel({
    required this.id,
    this.vin,
    this.stockNumber,
    required this.make,
    required this.model,
    required this.year,
    this.trim,
    this.condition,
    required this.price,
    this.salePrice,
    this.mileage,
    this.fuelType,
    this.transmission,
    this.bodyType,
    this.drivetrain,
    this.engine,
    this.exteriorColor,
    this.interiorColor,
    this.doors,
    this.seats,
    this.shortDescription,
    this.fullDescription,
    required this.status,
    required this.featured,
    this.brand,
    this.category,
    this.imageUrls = const [],
  });

  String get title => '$year $make $model'.trim();

  /// Price to actually display: sale price if one is set and lower
  /// than list price, otherwise the regular price.
  double get displayPrice =>
      (salePrice != null && salePrice! > 0 && salePrice! < price)
          ? salePrice!
          : price;

  bool get isOnSale =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  String? get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  factory CarModel.fromMap(Map<String, dynamic> map) {
    final rawImages = (map['car_images'] as List<dynamic>?) ?? const [];
    final images = rawImages
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    images.sort((a, b) {
      final aPrimary = (a['is_primary'] == true) ? 0 : 1;
      final bPrimary = (b['is_primary'] == true) ? 0 : 1;
      if (aPrimary != bPrimary) return aPrimary - bPrimary;
      final aOrder = (a['display_order'] as int?) ?? 0;
      final bOrder = (b['display_order'] as int?) ?? 0;
      return aOrder.compareTo(bOrder);
    });

    return CarModel(
      id: map['id'] as String,
      vin: map['vin'] as String?,
      stockNumber: map['stock_number'] as String?,
      make: (map['make'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      year: (map['year'] as int?) ?? 0,
      trim: map['trim'] as String?,
      condition: map['condition'] as String?,
      price: ((map['price'] as num?) ?? 0).toDouble(),
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      mileage: map['mileage'] as int?,
      fuelType: map['fuel_type'] as String?,
      transmission: map['transmission'] as String?,
      bodyType: map['body_type'] as String?,
      drivetrain: map['drivetrain'] as String?,
      engine: map['engine'] as String?,
      exteriorColor: map['exterior_color'] as String?,
      interiorColor: map['interior_color'] as String?,
      doors: map['doors'] as int?,
      seats: map['seats'] as int?,
      shortDescription: map['short_description'] as String?,
      fullDescription: map['full_description'] as String?,
      status: (map['status'] as String?) ?? 'unknown',
      featured: (map['featured'] as bool?) ?? false,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      imageUrls: images
          .map((e) => e['image_url'] as String?)
          .whereType<String>()
          .toList(),
    );
  }
}