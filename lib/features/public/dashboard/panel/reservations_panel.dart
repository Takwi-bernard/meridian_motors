import 'package:flutter/material.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';

/// Lists the signed-in customer's reservations with their current
/// status. Status colors/labels assume the admin module writes one of:
/// pending, approved, completed, rejected.
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reservations = await _service.fetchMyReservations();
      setState(() {
        _reservations = reservations;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load your reservations.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) return _errorState();
    if (_reservations.isEmpty) return _emptyState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _reservations.length,
        itemBuilder: (context, index) => _reservationCard(_reservations[index]),
      ),
    );
  }

  Widget _reservationCard(ReservationModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1D), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.carTitle ?? 'Vehicle',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              _statusBadge(r.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(_formatDate(r.reservationDate), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            ],
          ),
          if (r.notes != null && r.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.notes!, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = const Color(0xFF16A34A);
        break;
      case 'completed':
        color = const Color(0xFF2563EB);
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        break;
      default:
        color = const Color(0xFFCA8A04); // pending
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.event_available, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text('No reservations yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Reserve a car from its detail page to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}