import 'package:flutter/material.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';
import '../../constants/company_info.dart';

class ReservationsPanel extends StatefulWidget {
  const ReservationsPanel({super.key});

  @override
  State<ReservationsPanel> createState() => _ReservationsPanelState();
}

class _ReservationsPanelState extends State<ReservationsPanel> {
  final ReservationService _service = ReservationService();

  bool _loading = true;
  String? _error;
  List<ReservationModel> _reservations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _service.fetchMyReservations();
      setState(() { _reservations = r; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your reservations.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    if (_reservations.isEmpty) return _emptyState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _reservationCard(_reservations[i]),
                childCount: _reservations.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: Colors.white70, size: 22),
              const SizedBox(width: 10),
              const Text('My Reservations',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_reservations.length} ${_reservations.length == 1 ? 'reservation' : 'reservations'}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _reservationCard(ReservationModel r) {
    final statusInfo = _statusInfo(r.status);
    final fee = r.notes != null ? null : (r.carTitle != null ? null : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusInfo.icon, size: 20, color: statusInfo.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.carTitle ?? 'Vehicle',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Submitted ${_formatDate(r.createdAt)}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _statusBadge(r.status, statusInfo.color),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          // ── Card details ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow(Icons.event_outlined, 'Preferred date', _formatDateTime(r.reservationDate)),
                if (r.notes != null && r.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.notes_outlined, 'Notes', r.notes!),
                ],
              ],
            ),
          ),
          // ── Fee reminder for pending reservations ────────────────────
          if (r.status == 'pending') ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A10),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFCA8A04)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'To confirm this reservation, contact us at ${CompanyInfo.contactEmail} to arrange payment.',
                      style: const TextStyle(color: Color(0xFFCA8A04), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'approved':
        return _StatusInfo(Icons.check_circle_outline, const Color(0xFF16A34A));
      case 'completed':
        return _StatusInfo(Icons.verified_outlined, const Color(0xFF2563EB));
      case 'rejected':
        return _StatusInfo(Icons.cancel_outlined, const Color(0xFFDC2626));
      default:
        return _StatusInfo(Icons.hourglass_empty_rounded, const Color(0xFFCA8A04));
    }
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $hour:$min $period';
  }

  Widget _loadingState() => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading reservations...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ]),
      );

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(Icons.event_available_outlined, color: Colors.white38, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('No reservations yet',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text(
              'Find a car you love and tap\n"Reserve This Car" to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF1A1A1D), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 32),
          ),
          const SizedBox(height: 20),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatusInfo {
  const _StatusInfo(this.icon, this.color);
  final IconData icon;
  final Color color;
}
