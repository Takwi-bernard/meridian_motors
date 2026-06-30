/// Centralized company contact details. Update here if these ever
/// change — referenced by the reservation payment-instructions dialog
/// and can be reused anywhere else the dealership's contact info is
/// needed (Company Policies, Settings, etc).
class CompanyInfo {
  CompanyInfo._();

  static const String name = 'Meridian Motors';
  static const String contactEmail = 'meridianmotors100@gmail.com';

  /// Reservation fee as a fraction of the car's price (5%).
  static const double reservationFeeRate = 0.05;
}