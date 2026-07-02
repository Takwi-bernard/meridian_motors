import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/company_info.dart';

/// Shown immediately after a reservation is successfully submitted.
///
/// Designed to feel like a milestone moment — the customer just reserved
/// a car, which deserves a proper celebration. The dialog:
///   • Animates in with a scale+fade entrance
///   • Shows an animated checkmark with a pulsing green ring
///   • Displays the full price breakdown (car price → 5% → fee)
///   • Lets the customer copy the email with one tap
///   • Explains what happens next so there's no ambiguity
///   • Only closes when the customer taps Done — never auto-dismisses
class ReservationPaymentNoticeDialog extends StatefulWidget {
  const ReservationPaymentNoticeDialog({
    super.key,
    required this.carTitle,
    required this.carPrice,
    required this.onDone,
  });

  final String carTitle;
  final double carPrice;
  final VoidCallback onDone;

  @override
  State<ReservationPaymentNoticeDialog> createState() =>
      _ReservationPaymentNoticeDialogState();
}

class _ReservationPaymentNoticeDialogState
    extends State<ReservationPaymentNoticeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  bool _emailCopied = false;

  double get _feeAmount =>
      widget.carPrice * CompanyInfo.reservationFeeRate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(
        ClipboardData(text: CompanyInfo.contactEmail));
    setState(() => _emailCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _emailCopied = false);
  }

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
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF15151A),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSuccessHeader(),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Success Header ────────────────────────────────────────────────────────

  Widget _buildSuccessHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF16A34A).withOpacity(0.12),
            Colors.transparent,
          ],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Pulsing green ring around checkmark
          _PulsingCheckmark(),
          const SizedBox(height: 16),
          const Text(
            'Reservation Submitted!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.carTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: [
          _buildFeeBreakdown(),
          const SizedBox(height: 16),
          _buildNextStepsCard(),
          const SizedBox(height: 16),
          _buildEmailCard(),
          const SizedBox(height: 20),
          _buildDoneButton(),
          const SizedBox(height: 12),
          const Text(
            'Track your reservation in the Reservations tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          // Car price row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vehicle price',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 13)),
              Text(
                _formatCurrency(widget.carPrice),
                style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rate row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Reservation fee rate',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 13)),
              Text('5%',
                  style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
                color: Colors.white.withOpacity(0.07), height: 1),
          ),
          // Fee amount — the important number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount due now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatCurrency(_feeAmount),
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1410),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFCA8A04).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFCA8A04), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your reservation is pending until we receive your payment. '
              'Email us to arrange the fee — once confirmed, we\'ll approve your reservation.',
              style: TextStyle(
                color: Color(0xFFCA8A04),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailCard() {
    return GestureDetector(
      onTap: _copyEmail,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _emailCopied
              ? const Color(0xFF16A34A).withOpacity(0.10)
              : const Color(0xFF1A1A1D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _emailCopied
                ? const Color(0xFF16A34A).withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emailCopied
                    ? const Color(0xFF16A34A).withOpacity(0.15)
                    : const Color(0xFF2563EB).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _emailCopied
                    ? Icons.check_rounded
                    : Icons.email_outlined,
                size: 16,
                color: _emailCopied
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _emailCopied ? 'Email copied!' : 'Contact us at',
                    style: TextStyle(
                      color: _emailCopied
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CompanyInfo.contactEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _emailCopied
                    ? Icons.check_circle_rounded
                    : Icons.copy_rounded,
                key: ValueKey(_emailCopied),
                size: 16,
                color: _emailCopied
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: widget.onDone,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Got it, Done',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

// ── Animated pulsing checkmark ────────────────────────────────────────────

class _PulsingCheckmark extends StatefulWidget {
  @override
  State<_PulsingCheckmark> createState() => _PulsingCheckmarkState();
}

class _PulsingCheckmarkState extends State<_PulsingCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _ringScale = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: _ringScale.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF16A34A)
                        .withOpacity(_ringOpacity.value),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          // Static green circle with check icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF16A34A).withOpacity(0.4),
                  width: 1.5),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF16A34A),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}