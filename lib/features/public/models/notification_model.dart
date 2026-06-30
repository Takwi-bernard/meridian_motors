/// Mirrors the `notifications` table. Rows are created exclusively by
/// the database triggers (reservation status change / inquiry response)
/// — the app only ever reads and marks-as-read, never inserts.
class NotificationModel {
  final String id;
  final String customerId;

  /// 'reservation_status' or 'inquiry_response'.
  final String type;
  final String title;
  final String message;
  final String? reservationId;
  final String? inquiryId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.customerId,
    required this.type,
    required this.title,
    required this.message,
    this.reservationId,
    this.inquiryId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      type: (map['type'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      reservationId: map['reservation_id'] as String?,
      inquiryId: map['inquiry_id'] as String?,
      isRead: (map['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
