// reservations_page.dart
//
// Lives inside AdminShell — no Scaffold/AppBar needed.
// Supabase tables: reservations, cars, profiles
// Realtime: listens for new INSERT on reservations table

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';
import 'reservation_details_page.dart';

// ═══════════════════════════════════════════════════════════
//  RESERVATIONS PAGE
// ═══════════════════════════════════════════════════════════

class ReservationsPage extends StatefulWidget {
  /// Called when badge counts change so AdminShell
  /// can update the sidebar pending badge.
  final void Function(int pendingCount)? onBadgeUpdate;

  const ReservationsPage({super.key, this.onBadgeUpdate});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final _supabase       = Supabase.instance.client;
  final _searchCtrl     = TextEditingController();
  RealtimeChannel? _channel;

  List<Map<String, dynamic>> _reservations         = [];
  List<Map<String, dynamic>> _filteredReservations = [];

  bool   _isLoading      = true;
  bool   _hasError       = false;
  String _selectedStatus = 'All';
  String _sortBy         = 'newest';

  // ── Counts
  int get _total     => _reservations.length;
  int get _pending   => _reservations.where((e) => e['status'] == 'pending').length;
  int get _approved  => _reservations.where((e) => e['status'] == 'approved').length;
  int get _completed => _reservations.where((e) => e['status'] == 'completed').length;
  int get _rejected  => _reservations.where((e) => e['status'] == 'rejected').length;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
    _load();
    
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  //  REALTIME SUBSCRIPTION
  //  Listens for new reservations inserted by customers
  //  and shows an in-app notification banner instantly.
  // ════════════════════════════════════════════════════════
  void _subscribeRealtime() {
    _channel = _supabase
        .channel('admin_reservations_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reservations',
          callback: (payload) {
            if (!mounted) return;
            // Refresh the list
            _load(silent: true);
            // Show in-app notification banner
            _showNewReservationBanner(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _showNewReservationBanner(Map<String, dynamic> record) {
    final customerName =
        record['customer_name']?.toString() ?? 'A customer';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MM.brandNavy,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(20),
        content: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: MM.brandBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('New Reservation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text('$customerName just made a reservation.',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // Scroll to top to see new reservation
              setState(() => _selectedStatus = 'All');
              _applyFilters();
            },
            child: const Text('View',
                style: TextStyle(
                    color: MM.brandBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  DATA
  // ════════════════════════════════════════════════════════
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      if (mounted) setState(() { _isLoading = true; _hasError = false; });
    }

    try {
      final data = await _supabase
          .from('reservations')
          .select('''
            *,
            cars(id, make, model, year, trim, price,
                 status, exterior_color, fuel_type,
                 transmission, mileage),
            profiles!customer_id(
              id, full_name, email, phone, avatar_url
            )
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      _reservations = List<Map<String, dynamic>>.from(data);
      _applyFilters();

      // Update shell badge
      widget.onBadgeUpdate?.call(_pending);

    } catch (e) {
      debugPrint('Reservations load error: $e');
      if (mounted && !silent) setState(() => _hasError = true);
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();

    var list = _reservations.where((r) {
      // Search across reservation fields AND joined profile
      final profile = r['profiles'] as Map? ?? {};
      final name  = [
        r['customer_name'],
        profile['full_name'],
      ].whereType<String>().join(' ').toLowerCase();
      final email = [
        r['customer_email'],
        profile['email'],
      ].whereType<String>().join(' ').toLowerCase();
      final phone = [
        r['customer_phone'],
        profile['phone'],
      ].whereType<String>().join(' ').toLowerCase();
      final car   = r['cars'] as Map? ?? {};
      final carStr =
          '${car['make'] ?? ''} ${car['model'] ?? ''} ${car['year'] ?? ''}'
              .toLowerCase();

      final matchSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          carStr.contains(q);

      final matchStatus = _selectedStatus == 'All' ||
          (r['status'] ?? '').toString().toLowerCase() ==
              _selectedStatus.toLowerCase();

      return matchSearch && matchStatus;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'newest':
        list.sort((a, b) => (b['created_at'] ?? '')
            .compareTo(a['created_at'] ?? ''));
        break;
      case 'oldest':
        list.sort((a, b) => (a['created_at'] ?? '')
            .compareTo(b['created_at'] ?? ''));
        break;
      case 'date':
        list.sort((a, b) => (b['reservation_date'] ?? '')
            .compareTo(a['reservation_date'] ?? ''));
        break;
      case 'name':
        list.sort((a, b) {
          final an = (a['customer_name'] ?? '').toString();
          final bn = (b['customer_name'] ?? '').toString();
          return an.compareTo(bn);
        });
        break;
    }

    setState(() => _filteredReservations = list);
  }

  // ── Status update with confirmation
  Future<void> _updateStatus(
      String id, String status, String customerName) async {
    final confirm = await _confirmDialog(
      title: 'Mark as ${_label(status)}?',
      message:
          '$customerName\'s reservation will be updated to "${_label(status)}".',
      confirmLabel: _label(status),
      confirmColor: MM.statusColor(status),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('reservations').update({
        'status':     status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // If completed → mark car as sold
      if (status == 'completed') {
        final res = _reservations.firstWhere(
            (r) => r['id'].toString() == id,
            orElse: () => {});
        final carId = res['car_id'];
        if (carId != null) {
          await _supabase
              .from('cars')
              .update({'status': 'sold'})
              .eq('id', carId);
        }
      }

      await _load(silent: true);
      _toast('Reservation marked as ${_label(status)}.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    }
  }

  Future<void> _delete(String id, String customerName) async {
    final confirm = await _confirmDialog(
      title: 'Delete reservation?',
      message:
          '$customerName\'s reservation will be permanently deleted.',
      confirmLabel: 'Delete',
      confirmColor: MM.accentRed,
    );
    if (confirm != true) return;

    try {
      await _supabase.from('reservations').delete().eq('id', id);
      await _load(silent: true);
      _toast('Reservation deleted.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    }
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _loader();
    if (_hasError)  return _error();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return RefreshIndicator(
      onRefresh: _load,
      color: MM.brandBlue,
      backgroundColor: MM.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 28 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDesktop),
            const SizedBox(height: 24),
            _buildStatRow(isDesktop),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildList(),
          ],
        ),
      ),
    );
  }

  // ── Header
  Widget _buildHeader(bool isDesktop) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reservations',
                style: TextStyle(
                    color: MM.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('$_total reservations total · $_pending pending',
                style: const TextStyle(
                    color: MM.textSub, fontSize: 13)),
          ],
        ),
      ),
      // Sort menu
      _sortMenu(),
      const SizedBox(width: 10),
      // Refresh
      GestureDetector(
        onTap: _load,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: MM.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MM.border),
          ),
          child: const Row(children: [
            Icon(Icons.refresh_rounded,
                color: MM.brandBlue, size: 16),
            SizedBox(width: 8),
            Text('Refresh',
                style: TextStyle(
                    color: MM.brandBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _sortMenu() {
    final options = {
      'newest': 'Newest first',
      'oldest': 'Oldest first',
      'date':   'By reservation date',
      'name':   'By customer name',
    };
    return Theme(
      data: ThemeData.dark().copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: MM.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: MM.border),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          setState(() => _sortBy = v);
          _applyFilters();
        },
        icon: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: MM.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MM.border),
          ),
          child: const Row(children: [
            Icon(Icons.sort_rounded,
                color: MM.textSub, size: 16),
            SizedBox(width: 8),
            Text('Sort',
                style: TextStyle(
                    color: MM.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        itemBuilder: (_) => options.entries.map((e) {
          final selected = _sortBy == e.key;
          return PopupMenuItem(
            value: e.key,
            child: Row(children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? MM.brandBlue : MM.textMuted,
                size: 16,
              ),
              const SizedBox(width: 10),
              Text(e.value,
                  style: TextStyle(
                      color: selected
                          ? MM.brandBlue : MM.textPrimary,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700 : FontWeight.w400)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Stat row
  Widget _buildStatRow(bool isDesktop) {
    final stats = [
      ('Total',     '$_total',     Icons.calendar_month_rounded, MM.brandBlue),
      ('Pending',   '$_pending',   Icons.pending_actions_rounded, MM.accentAmber),
      ('Approved',  '$_approved',  Icons.check_circle_rounded,   MM.accentGreen),
      ('Completed', '$_completed', Icons.task_alt_rounded,       MM.accentPurple),
      ('Rejected',  '$_rejected',  Icons.cancel_rounded,         MM.accentRed),
    ];

    return GridView.count(
      crossAxisCount: isDesktop ? 5 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.8 : 1.5,
      children: stats.map((s) {
        return GestureDetector(
          onTap: () {
            setState(() => _selectedStatus =
                s.$1 == 'Total' ? 'All' : s.$1);
            _applyFilters();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MM.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedStatus == s.$1 ||
                        (_selectedStatus == 'All' &&
                            s.$1 == 'Total')
                    ? s.$4.withOpacity(0.4)
                    : MM.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: s.$4.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(s.$3, color: s.$4, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$2,
                        style: const TextStyle(
                            color: MM.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5)),
                    Text(s.$1,
                        style: const TextStyle(
                            color: MM.textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Search + filter bar
  Widget _buildSearchBar() {
    final statuses = ['All','Pending','Approved','Completed','Rejected'];

    return Column(
      children: [
        // Search field
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: MM.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MM.border),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(
                color: MM.textPrimary, fontSize: 14),
            cursorColor: MM.brandBlue,
            decoration: InputDecoration(
              hintText:
                  'Search by customer name, email, phone or vehicle…',
              hintStyle: const TextStyle(
                  color: MM.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: MM.textMuted, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _applyFilters();
                      },
                      child: const Icon(Icons.close_rounded,
                          color: MM.textMuted, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ),
        const SizedBox(height: 12),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statuses.map((s) {
              final selected = _selectedStatus == s;
              final color = s == 'Pending'
                  ? MM.accentAmber
                  : s == 'Approved'
                      ? MM.accentGreen
                      : s == 'Completed'
                          ? MM.accentPurple
                          : s == 'Rejected'
                              ? MM.accentRed
                              : MM.brandBlue;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStatus = s);
                  _applyFilters();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.12) : MM.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? color.withOpacity(0.4) : MM.border,
                    ),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          color: selected ? color : MM.textSub,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Reservation list
  Widget _buildList() {
    if (_filteredReservations.isEmpty) return _emptyState();

    return Column(
      children: _filteredReservations.map((r) {
        return _ReservationCard(
          reservation: r,
          onView: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReservationDetailsPage(
                reservationId: r['id'].toString(),
                onUpdated: () => _load(silent: true),
              ),
            ),
          ),
          onUpdateStatus: (status) => _updateStatus(
            r['id'].toString(),
            status,
            _customerName(r),
          ),
          onDelete: () => _delete(
            r['id'].toString(),
            _customerName(r),
          ),
        );
      }).toList(),
    );
  }

  String _customerName(Map r) {
    final profile = r['profiles'] as Map? ?? {};
    return profile['full_name']?.toString() ??
        r['customer_name']?.toString() ??
        'Customer';
  }

  // ════════════════════════════════════════════════════════
  //  STATES
  // ════════════════════════════════════════════════════════
  Widget _emptyState() {
    final isFiltered = _searchCtrl.text.isNotEmpty ||
        _selectedStatus != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: MM.bgSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MM.border),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: MM.textMuted, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'No reservations match your filters.'
                : 'No reservations yet.',
            style: const TextStyle(
                color: MM.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try adjusting your search or filter.'
                : 'New reservations will appear here.',
            style: const TextStyle(
                color: MM.textSub, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _loader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 34, height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(MM.brandBlue),
          ),
        ),
        SizedBox(height: 16),
        Text('Loading reservations…',
            style: TextStyle(color: MM.textSub, fontSize: 14)),
      ],
    ),
  );

  Widget _error() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded,
            color: MM.textMuted, size: 48),
        const SizedBox(height: 16),
        const Text('Could not load reservations.',
            style: TextStyle(
                color: MM.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: MM.brandBlue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
          ),
          icon: const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 18),
          label: const Text('Try again',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  // ════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════
  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MM.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: const TextStyle(
                  color: MM.textPrimary,
                  fontWeight: FontWeight.w700)),
          content: Text(message,
              style: const TextStyle(
                  color: MM.textSub,
                  fontSize: 14,
                  height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: MM.textSub)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(confirmLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? MM.accentRed : MM.accentGreen,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
        ]),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('network')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }

  String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ═══════════════════════════════════════════════════════════
//  RESERVATION CARD WIDGET
// ═══════════════════════════════════════════════════════════
class _ReservationCard extends StatelessWidget {
  final Map<String, dynamic> reservation;
  final VoidCallback onView;
  final void Function(String status) onUpdateStatus;
  final VoidCallback onDelete;

  const _ReservationCard({
    required this.reservation,
    required this.onView,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final profile = reservation['profiles'] as Map? ?? {};
    final car     = reservation['cars']     as Map? ?? {};
    final status  = reservation['status']?.toString() ?? 'pending';

    final customerName = profile['full_name']?.toString() ??
        reservation['customer_name']?.toString() ?? 'Unknown';
    final customerEmail = profile['email']?.toString() ??
        reservation['customer_email']?.toString() ?? '';
    final customerPhone = profile['phone']?.toString() ??
        reservation['customer_phone']?.toString() ?? '';
    final carLabel =
        '${car['year'] ?? ''} ${car['make'] ?? ''} ${car['model'] ?? ''}'
            .trim();
    final price    = car['price'];
    final resDate  = reservation['reservation_date'];
    final statusColor = MM.statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'pending'
              ? MM.accentAmber.withOpacity(0.3)
              : MM.border,
        ),
      ),
      child: Column(
        children: [
          // ── Header row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: MM.brandBlue.withOpacity(0.15),
                  backgroundImage: profile['avatar_url'] != null
                      ? NetworkImage(profile['avatar_url'])
                      : null,
                  child: profile['avatar_url'] == null
                      ? Text(
                          customerName.isNotEmpty
                              ? customerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: MM.brandBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName,
                          style: const TextStyle(
                              color: MM.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      if (customerEmail.isNotEmpty)
                        Text(customerEmail,
                            style: const TextStyle(
                                color: MM.textSub, fontSize: 12)),
                      if (customerPhone.isNotEmpty)
                        Text(customerPhone,
                            style: const TextStyle(
                                color: MM.textSub, fontSize: 12)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // ── Car + date row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MM.bgSurface,
              border: Border.symmetric(
                  horizontal: BorderSide(color: MM.border)),
            ),
            child: Row(children: [
              const Icon(Icons.directions_car_rounded,
                  color: MM.textMuted, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  carLabel.isEmpty ? 'Vehicle not specified' : carLabel,
                  style: const TextStyle(
                      color: MM.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (price != null) ...[
                Text('\$${_fmt(price)}',
                    style: const TextStyle(
                        color: MM.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
              ],
              if (resDate != null) ...[
                const Icon(Icons.calendar_today_rounded,
                    color: MM.textMuted, size: 13),
                const SizedBox(width: 5),
                Text(_fmtDate(resDate.toString()),
                    style: const TextStyle(
                        color: MM.textSub, fontSize: 12)),
              ],
            ]),
          ),

          // ── Action row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // View details
              Expanded(
                child: GestureDetector(
                  onTap: onView,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10),
                    decoration: BoxDecoration(
                      color: MM.brandBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: MM.brandBlue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_rounded,
                            color: MM.brandBlue, size: 15),
                        SizedBox(width: 6),
                        Text('View Details',
                            style: TextStyle(
                                color: MM.brandBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quick actions popup
              Theme(
                data: ThemeData.dark().copyWith(
                  popupMenuTheme: PopupMenuThemeData(
                    color: MM.bgSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: MM.border),
                    ),
                  ),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') {
                      onDelete();
                    } else {
                      onUpdateStatus(v);
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MM.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MM.border),
                    ),
                    child: const Row(children: [
                      Icon(Icons.more_horiz_rounded,
                          color: MM.textSub, size: 18),
                      SizedBox(width: 4),
                      Text('Actions',
                          style: TextStyle(
                              color: MM.textSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  itemBuilder: (_) => [
                    if (status != 'approved')
                      _mi('approved',  'Approve',
                          Icons.check_circle_outline, MM.accentGreen),
                    if (status != 'completed')
                      _mi('completed', 'Mark Complete',
                          Icons.task_alt_rounded,    MM.accentPurple),
                    if (status != 'rejected')
                      _mi('rejected',  'Reject',
                          Icons.cancel_outlined,     MM.accentRed),
                    const PopupMenuDivider(),
                    _mi('delete',    'Delete',
                        Icons.delete_outline_rounded, MM.accentRed),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _mi(
      String val, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _fmt(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000) return '\$${(n / 1000).toStringAsFixed(0)}K';
    return '\$${n.toStringAsFixed(0)}';
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final m  = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return raw; }
  }
}