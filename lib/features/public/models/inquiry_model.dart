/// Mirrors the `inquiries` table after the migration that added
/// car_id, customer_id, status, admin_response, and responded_at.
class InquiryModel {
  final String id;
  final String? carId;
  final String? customerId;
  final String name;
  final String email;
  final String? phone;
  final String subject;
  final String message;
  final bool isRead;

  /// "pending" until the admin replies, then "responded".
  final String status;
  final String? adminResponse;
  final DateTime? respondedAt;
  final DateTime createdAt;

  final String? carTitle;

  const InquiryModel({
    required this.id,
    this.carId,
    this.customerId,
    required this.name,
    required this.email,
    this.phone,
    required this.subject,
    required this.message,
    required this.isRead,
    required this.status,
    this.adminResponse,
    this.respondedAt,
    required this.createdAt,
    this.carTitle,
  });

  factory InquiryModel.fromMap(Map<String, dynamic> map) {
    final carRaw = map['cars'] as Map<String, dynamic>?;
    String? carTitle;
    if (carRaw != null) {
      final year = carRaw['year'];
      final make = carRaw['make'];
      final model = carRaw['model'];
      carTitle = '$year $make $model'.trim();
    }

    return InquiryModel(
      id: map['id'] as String,
      carId: map['car_id'] as String?,
      customerId: map['customer_id'] as String?,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phone: map['phone'] as String?,
      subject: (map['subject'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      isRead: (map['is_read'] as bool?) ?? false,
      status: ((map['status'] as String?) ?? 'pending').toLowerCase(),
      adminResponse: map['admin_response'] as String?,
      respondedAt: map['responded_at'] != null
          ? DateTime.parse(map['responded_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      carTitle: carTitle,
    );
  }
}