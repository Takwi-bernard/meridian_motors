/// Mirrors the `reservations` table. [carTitle] is only populated when
/// the row was fetched with the `cars` foreign table joined in.
class ReservationModel {
  final String id;
  final String carId;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final DateTime reservationDate;

  /// One of: pending, approved, completed, rejected.
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final String? carTitle;

  const ReservationModel({
    required this.id,
    required this.carId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.reservationDate,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.carTitle,
  });

  factory ReservationModel.fromMap(Map<String, dynamic> map) {
    final carRaw = map['cars'] as Map<String, dynamic>?;
    String? carTitle;
    if (carRaw != null) {
      final year = carRaw['year'];
      final make = carRaw['make'];
      final model = carRaw['model'];
      carTitle = '$year $make $model'.trim();
    }

    return ReservationModel(
      id: map['id'] as String,
      carId: map['car_id'] as String,
      customerId: map['customer_id'] as String,
      customerName: (map['customer_name'] as String?) ?? '',
      customerEmail: (map['customer_email'] as String?) ?? '',
      customerPhone: map['customer_phone'] as String?,
      reservationDate: DateTime.parse(map['reservation_date'] as String),
      status: ((map['status'] as String?) ?? 'pending').toLowerCase(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      carTitle: carTitle,
    );
  }
}