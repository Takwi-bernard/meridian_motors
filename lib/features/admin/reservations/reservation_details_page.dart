// reservation_details_page.dart
//
// Loads reservation fresh from Supabase by ID.
// All status changes update DB immediately.
// Completing a reservation marks the car as sold.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';

// ═══════════════════════════════════════════════════════════
//  RESERVATION DETAILS PAGE
// ═══════════════════════════════════════════════════════════

class ReservationDetailsPage extends StatefulWidget {
  final String reservationId;
  final VoidCallback? onUpdated;

  const ReservationDetailsPage({
    super.key,
    required this.reservationId,
    this.onUpdated,
  });

  @override
  State<ReservationDetailsPage> createState() =>
      _ReservationDetailsPageState();
}

class _ReservationDetailsPageState
    extends State<ReservationDetailsPage> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _reservation;
  bool _isLoading  = true;
  bool _hasError   = false;
  bool _isActing   = false; // prevents double-taps during update

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ════════════════════════════════════════════════════════
  //  DATA — always load fresh from DB
  // ════════════════════════════════════════════════════════
  Future<void> _load() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final data = await _supabase
          .from('reservations')
          .select('''
            *,
            cars(
              id, make, model, year, trim, vin,
              stock_number, condition, price, sale_price,
              mileage, fuel_type, transmission, body_type,
              drivetrain, engine, exterior_color,
              interior_color, doors, seats, status, featured
            ),
            profiles!customer_id(
              id, full_name, email, phone,
              avatar_url, role, is_active
            )
          ''')
          .eq('id', widget.reservationId)
          .single();

      if (!mounted) return;
      setState(() {
        _reservation = Map<String, dynamic>.from(data);
        _isLoading   = false;
      });
    } catch (e) {
      debugPrint('ReservationDetails load error: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ════════════════════════════════════════════════════════
  //  ACTIONS — all update DB immediately
  // ════════════════════════════════════════════════════════
  Future<void> _updateStatus(String status) async {
    final confirm = await _confirmDialog(
      title: 'Mark as ${_label(status)}?',
      message: status == 'completed'
          ? 'This reservation will be completed and the vehicle will be marked as sold.'
          : 'The reservation status will be updated to "${_label(status)}".',
      confirmLabel: _label(status),
      confirmColor: MM.statusColor(status),
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      // Update reservation
      await _supabase.from('reservations').update({
        'status':     status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.reservationId);

      // If completed → mark car as sold immediately
      if (status == 'completed') {
        final carId = _reservation?['car_id'];
        if (carId != null) {
          await _supabase
              .from('cars')
              .update({'status': 'sold'})
              .eq('id', carId);
        }
      }

      // Reload fresh data
      await _load();
      widget.onUpdated?.call();
      _toast('Reservation marked as ${_label(status)}.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await _confirmDialog(
      title: 'Delete reservation?',
      message:
          'This reservation will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: MM.accentRed,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      await _supabase
          .from('reservations')
          .delete()
          .eq('id', widget.reservationId);

      widget.onUpdated?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: MM.bgDeep),
      child: Scaffold(
        backgroundColor: MM.bgDeep,
        body: _isLoading
            ? _loader()
            : _hasError
                ? _error()
                : Column(children: [
                    _topBar(),
                    if (_isActing) _actingBanner(),
                    Expanded(child: _buildContent()),
                  ]),
      ),
    );
  }

  Widget _topBar() {
    final status =
        _reservation?['status']?.toString() ?? 'pending';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: MM.bgCard,
        border: Border(bottom: BorderSide(color: MM.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: MM.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MM.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: MM.textSub, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Text('Reservations',
            style: TextStyle(color: MM.textSub, fontSize: 13)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right_rounded,
              color: MM.textMuted, size: 16),
        ),
        const Text('Details',
            style: TextStyle(
                color: MM.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        // Status badge
        _StatusBadge(status),
        const SizedBox(width: 12),
        // More menu
        _moreMenu(status),
      ]),
    );
  }

  Widget _actingBanner() {
    return Container(
      color: MM.brandNavy,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      child: const Row(children: [
        SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        SizedBox(width: 12),
        Text('Updating reservation…',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _moreMenu(String status) {
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
          if (v == 'delete') { _delete(); return; }
          if (v == 'copy')   {
            Clipboard.setData(ClipboardData(
                text: widget.reservationId));
            _toast('Reservation ID copied.');
            return;
          }
          _updateStatus(v);
        },
        icon: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MM.border),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: MM.textSub, size: 20),
        ),
        itemBuilder: (_) => [
          if (status != 'approved')
            _mi('approved',  'Approve',
                Icons.check_circle_outline,  MM.accentGreen),
          if (status != 'completed')
            _mi('completed', 'Mark Complete',
                Icons.task_alt_rounded,      MM.accentPurple),
          if (status != 'rejected')
            _mi('rejected',  'Reject',
                Icons.cancel_outlined,       MM.accentRed),
          const PopupMenuDivider(),
          _mi('copy',      'Copy Reservation ID',
              Icons.copy_rounded,            MM.textSub),
          const PopupMenuDivider(),
          _mi('delete',    'Delete Reservation',
              Icons.delete_outline_rounded,  MM.accentRed),
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
                color: color == MM.textSub
                    ? MM.textPrimary : color,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── Main content
  Widget _buildContent() {
    final res     = _reservation!;
    final car     = res['cars']     as Map? ?? {};
    final profile = res['profiles'] as Map? ?? {};
    final status  = res['status']?.toString() ?? 'pending';
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(children: [
                    _customerCard(profile, res),
                    const SizedBox(height: 16),
                    _reservationInfoCard(res, status),
                    const SizedBox(height: 16),
                    _actionBar(status),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _vehicleCard(car),
                ),
              ],
            )
          : Column(children: [
              _customerCard(profile, res),
              const SizedBox(height: 16),
              _vehicleCard(car),
              const SizedBox(height: 16),
              _reservationInfoCard(res, status),
              const SizedBox(height: 16),
              _actionBar(status),
              const SizedBox(height: 32),
            ]),
    );
  }

  // ── Customer card
  Widget _customerCard(Map profile, Map res) {
    final name  = profile['full_name']?.toString() ??
        res['customer_name']?.toString() ?? 'Unknown';
    final email = profile['email']?.toString() ??
        res['customer_email']?.toString() ?? '';
    final phone = profile['phone']?.toString() ??
        res['customer_phone']?.toString() ?? '';
    final role  = profile['role']?.toString() ?? '';
    final active = profile['is_active'];

    return _card(
      icon: Icons.person_rounded,
      color: MM.brandBlue,
      title: 'Customer Information',
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: MM.brandBlue.withOpacity(0.15),
            backgroundImage: profile['avatar_url'] != null
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: profile['avatar_url'] == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: MM.brandBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 20),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: MM.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                if (email.isNotEmpty)
                  Text(email,
                      style: const TextStyle(
                          color: MM.textSub, fontSize: 13)),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: const TextStyle(
                          color: MM.textSub, fontSize: 13)),
              ],
            ),
          ),
          if (active != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: active == true
                    ? MM.accentGreen.withOpacity(0.12)
                    : MM.accentRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active == true
                      ? MM.accentGreen.withOpacity(0.3)
                      : MM.accentRed.withOpacity(0.3),
                ),
              ),
              child: Text(
                active == true ? 'Active' : 'Inactive',
                style: TextStyle(
                    color: active == true
                        ? MM.accentGreen : MM.accentRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        if (role.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(color: MM.border),
          const SizedBox(height: 8),
          _infoRow('Role', role[0].toUpperCase() + role.substring(1)),
        ],
      ]),
    );
  }

  // ── Vehicle card
  Widget _vehicleCard(Map car) {
    if (car.isEmpty) {
      return _card(
        icon: Icons.directions_car_rounded,
        color: MM.accentAmber,
        title: 'Vehicle Information',
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Vehicle data not available.',
                style: TextStyle(color: MM.textMuted)),
          ),
        ),
      );
    }

    return _card(
      icon: Icons.directions_car_rounded,
      color: MM.accentAmber,
      title: 'Vehicle Information',
      child: Column(children: [
        // Vehicle title
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: MM.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.directions_car_rounded,
                  color: MM.accentAmber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car['year'] ?? ''} ${car['make'] ?? ''} ${car['model'] ?? ''}',
                    style: const TextStyle(
                        color: MM.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  if (car['trim'] != null)
                    Text(car['trim'].toString(),
                        style: const TextStyle(
                            color: MM.textSub, fontSize: 12)),
                ],
              ),
            ),
            if (car['price'] != null)
              Text('\$${_fmt(car['price'])}',
                  style: const TextStyle(
                      color: MM.accentGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 14),
        // Specs grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (car['condition']    != null) _specChip(car['condition'].toString()),
            if (car['fuel_type']    != null) _specChip(car['fuel_type'].toString()),
            if (car['transmission'] != null) _specChip(car['transmission'].toString()),
            if (car['body_type']    != null) _specChip(car['body_type'].toString()),
            if (car['drivetrain']   != null) _specChip(car['drivetrain'].toString()),
            if (car['status']       != null)
              _StatusBadge(car['status'].toString()),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: MM.border),
        const SizedBox(height: 4),
        // Info rows
        if (car['vin']          != null) _infoRow('VIN',           car['vin'].toString()),
        if (car['stock_number'] != null) _infoRow('Stock #',       car['stock_number'].toString()),
        if (car['mileage']      != null) _infoRow('Mileage',       '${_fmt(car['mileage'])} mi'),
        if (car['engine']       != null) _infoRow('Engine',        car['engine'].toString()),
        if (car['exterior_color'] != null) _infoRow('Exterior',    car['exterior_color'].toString()),
        if (car['interior_color'] != null) _infoRow('Interior',    car['interior_color'].toString()),
        if (car['doors']        != null) _infoRow('Doors',         '${car['doors']}'),
        if (car['seats']        != null) _infoRow('Seats',         '${car['seats']}'),
        if (car['sale_price']   != null) _infoRow('Sale Price',    '\$${_fmt(car['sale_price'])}'),
      ]),
    );
  }

  // ── Reservation info card
  Widget _reservationInfoCard(Map res, String status) {
    return _card(
      icon: Icons.calendar_month_rounded,
      color: MM.accentPurple,
      title: 'Reservation Information',
      child: Column(children: [
        _infoRow('Reservation ID', res['id']?.toString() ?? '—',
            copyable: true),
        _infoRow('Status',
            status[0].toUpperCase() + status.substring(1)),
        if (res['reservation_date'] != null)
          _infoRow('Reservation Date',
              _fmtDate(res['reservation_date'].toString())),
        if (res['notes'] != null && res['notes'].toString().isNotEmpty)
          _infoRow('Notes', res['notes'].toString()),
        if (res['created_at'] != null)
          _infoRow('Created',
              _fmtDateTime(res['created_at'].toString())),
        if (res['updated_at'] != null)
          _infoRow('Last Updated',
              _fmtDateTime(res['updated_at'].toString())),
      ]),
    );
  }

  // ── Action bar
  Widget _actionBar(String status) {
    final actions = <_ActionBtn>[];

    if (status != 'approved')
      actions.add(_ActionBtn(
        label: 'Approve',
        icon: Icons.check_circle_rounded,
        color: MM.accentGreen,
        onTap: () => _updateStatus('approved'),
      ));

    if (status != 'completed')
      actions.add(_ActionBtn(
        label: 'Complete',
        icon: Icons.task_alt_rounded,
        color: MM.accentPurple,
        onTap: () => _updateStatus('completed'),
      ));

    if (status != 'rejected')
      actions.add(_ActionBtn(
        label: 'Reject',
        icon: Icons.cancel_rounded,
        color: MM.accentRed,
        onTap: () => _updateStatus('rejected'),
      ));

    actions.add(_ActionBtn(
      label: 'Delete',
      icon: Icons.delete_outline_rounded,
      color: MM.accentRed,
      outlined: true,
      onTap: _delete,
    ));

    return AbsorbPointer(
      absorbing: _isActing,
      child: Opacity(
        opacity: _isActing ? 0.5 : 1.0,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.map((a) {
            return GestureDetector(
              onTap: a.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: a.outlined
                      ? Colors.transparent
                      : a.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: a.color.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icon, color: a.color, size: 17),
                    const SizedBox(width: 8),
                    Text(a.label,
                        style: TextStyle(
                            color: a.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════
  Widget _card({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          Divider(color: MM.border, height: 24),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: MM.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: copyable
                  ? () async {
                      await Clipboard.setData(
                          ClipboardData(text: value));
                      _toast('Copied to clipboard.');
                    }
                  : null,
              child: Row(children: [
                Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          color: MM.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                if (copyable)
                  const Icon(Icons.copy_rounded,
                      color: MM.textMuted, size: 13),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MM.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MM.border),
      ),
      child: Text(label,
          style: const TextStyle(
              color: MM.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }

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

  String _fmt(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final m  = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return raw; }
  }

  String _fmtDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final m  = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h  = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min';
    } catch (_) { return raw; }
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
        Text('Loading reservation…',
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
        const Text('Could not load reservation.',
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
}

// ── Status badge
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = MM.statusColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ── Action button model
class _ActionBtn {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });
}