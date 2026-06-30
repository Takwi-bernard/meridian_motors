import 'package:flutter/material.dart';
import '../../constants/company_info.dart';

/// Shown immediately after a reservation is successfully submitted.
/// Since the dealership isn't taking payment in-app yet, this dialog
/// tells the customer exactly how much to pay (5% of the car's price)
/// and where to send it — by emailing the dealership directly. The
/// dialog only closes when the customer taps "Done", never on its own,
/// so the instructions can't be missed.
class ReservationPaymentNoticeDialog extends StatelessWidget {
  const ReservationPaymentNoticeDialog({
    super.key,
    required this.carTitle,
    required this.carPrice,
    required this.onDone,
  });

  final String carTitle;
  final double carPrice;

  /// Called when the customer taps Done — the caller decides what
  /// happens next (e.g. closing the reservation form sheet too).
  final VoidCallback onDone;

  double get _feeAmount => carPrice * CompanyInfo.reservationFeeRate;

  String _formatCurrency(double value) {
    final rounded = value.round();
    final raw = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i != 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reservation Submitted',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your request for $carTitle is pending. To complete your reservation, a fee is required before processing can begin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF26262A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'RESERVATION FEE (5%)',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(_feeAmount),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Please contact our team by email to arrange payment before your reservation can proceed:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      CompanyInfo.contactEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}