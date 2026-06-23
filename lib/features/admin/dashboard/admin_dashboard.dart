// admin_dashboard_body.dart
//
// This widget is the BODY ONLY — no Scaffold, no sidebar,
// no top bar, no auth logic. All of that lives in AdminShell.
// AdminShell calls: AdminDashboardBody(onBadgeUpdate: ...)
//
// Supabase tables read:
//   cars · profiles · reservations · inquiries

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart'; // MM brand tokens

// ═══════════════════════════════════════════════════════════
//  MERIDIAN MOTORS — Dashboard Body
// ═══════════════════════════════════════════════════════════

class AdminDashboardBody extends StatefulWidget {
  /// Called when badge counts update so the shell can
  /// reflect them in the sidebar nav.
  final void Function(int unreadInquiries, int pendingReservations)?
      onBadgeUpdate;

  /// Lets the shell tell the dashboard which nav index
  /// was tapped (for "View all" shortcuts).
  final void Function(int index)? onNavigate;

  const AdminDashboardBody({
    super.key,
    this.onBadgeUpdate,
    this.onNavigate,
  });

  @override
  State<AdminDashboardBody> createState() => _AdminDashboardBodyState();
}

class _AdminDashboardBodyState extends State<AdminDashboardBody> {
  // ── Counts
  int _totalCars          = 0;
  int _availableCars      = 0;
  int _featuredCars       = 0;
  int _totalCustomers     = 0;
  int _totalReservations  = 0;
  int _pendingReservations = 0;
  int _totalInquiries     = 0;
  int _unreadInquiries    = 0;

  // ── Recent lists
  List _recentCars         = [];
  List _recentReservations = [];
  List _recentInquiries    = [];

  // ── UI state
  bool _isLoading = true;
  bool _hasError  = false;

  // ── Admin name (passed down from shell via profile already
  //    loaded there — we pull it again cheaply here)
  String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _isLoading = true; _hasError = false; });

    try {
      final sb = Supabase.instance.client;

      // Pull admin name
      final user = sb.auth.currentUser;
      if (user != null) {
        try {
          final p = await sb
              .from('profiles')
              .select('full_name')
              .eq('id', user.id)
              .single();
          _adminName = p['full_name'] ?? 'Admin';
        } catch (_) {}
      }

      // Parallel fetch — all 4 tables at once
      final results = await Future.wait([
        sb.from('cars').select().order('created_at', ascending: false),
        sb.from('profiles').select('id').eq('role', 'customer'),
        sb.from('reservations').select().order('created_at', ascending: false),
        sb.from('inquiries').select().order('created_at', ascending: false),
      ]);

      final cars         = results[0] as List;
      final customers    = results[1] as List;
      final reservations = results[2] as List;
      final inquiries    = results[3] as List;

      final unread  = inquiries.where((e) => e['is_read'] == false).length;
      final pending = reservations.where((e) => e['status'] == 'pending').length;

      // Notify shell so sidebar badges update
      widget.onBadgeUpdate?.call(unread, pending);

      if (!mounted) return;
      setState(() {
        _totalCars           = cars.length;
        _availableCars       = cars.where((e) => e['status'] == 'available').length;
        _featuredCars        = cars.where((e) => e['featured'] == true).length;
        _totalCustomers      = customers.length;
        _totalReservations   = reservations.length;
        _pendingReservations = pending;
        _totalInquiries      = inquiries.length;
        _unreadInquiries     = unread;
        _recentCars          = cars.take(5).toList();
        _recentReservations  = reservations.take(5).toList();
        _recentInquiries     = inquiries.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── Helpers
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName() {
    final parts = _adminName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : 'Admin';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return '—'; }
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
            _buildGreeting(isDesktop),
            const SizedBox(height: 28),
            _buildQuickStats(isDesktop),
            const SizedBox(height: 32),
            _buildAlertBanner(),
            const SizedBox(height: 24),
            _buildRecentActivity(isDesktop),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  GREETING HEADER
  // ════════════════════════════════════════════════════════
  Widget _buildGreeting(bool isDesktop) {
    final now = DateTime.now();
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr =
        '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, ${_firstName()} 👋',
                style: TextStyle(
                  color: MM.textPrimary,
                  fontSize: isDesktop ? 28 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(dateStr,
                  style: const TextStyle(
                      color: MM.textSub, fontSize: 13)),
            ],
          ),
        ),
        // Refresh button
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MM.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MM.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded,
                    color: MM.brandBlue, size: 16),
                SizedBox(width: 8),
                Text('Refresh',
                    style: TextStyle(
                        color: MM.brandBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  QUICK STATS GRID
  // ════════════════════════════════════════════════════════
  Widget _buildQuickStats(bool isDesktop) {
    final isMedium = MediaQuery.of(context).size.width > 600;

    // Grouped for visual clarity
    final groups = [
      _StatGroup('INVENTORY', [
        _StatItem('Total Cars',  '$_totalCars',
            Icons.directions_car_rounded,  MM.brandBlue,   '+${_featuredCars} featured'),
        _StatItem('Available',   '$_availableCars',
            Icons.check_circle_rounded,    MM.accentGreen,
            '${_totalCars == 0 ? 0 : ((_availableCars / _totalCars) * 100).toStringAsFixed(0)}% of fleet'),
        _StatItem('Featured',    '$_featuredCars',
            Icons.star_rounded,            MM.accentAmber, 'On homepage'),
      ]),
      _StatGroup('PEOPLE', [
        _StatItem('Customers',   '$_totalCustomers',
            Icons.people_rounded,          MM.accentPurple,'Registered'),
      ]),
      _StatGroup('RESERVATIONS', [
        _StatItem('Total',       '$_totalReservations',
            Icons.calendar_month_rounded,  MM.brandBlue,   'All time'),
        _StatItem('Pending',     '$_pendingReservations',
            Icons.pending_actions_rounded, MM.accentAmber,
            _pendingReservations > 0 ? 'Needs attention' : 'All clear'),
      ]),
      _StatGroup('INQUIRIES', [
        _StatItem('Total',       '$_totalInquiries',
            Icons.mail_rounded,            MM.brandBlue,   'All time'),
        _StatItem('Unread',      '$_unreadInquiries',
            Icons.mark_email_unread_rounded, MM.accentRed,
            _unreadInquiries > 0 ? 'Action required' : 'All clear ✓'),
      ]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((g) {
        final cols = isDesktop
            ? g.items.length.clamp(1, 4)
            : isMedium ? 2 : 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(g.label,
                  style: const TextStyle(
                      color: MM.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isDesktop ? 1.75 : 1.5,
              children: g.items.map(_buildStatCard).toList(),
            ),
            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(item.sub,
                    style: TextStyle(
                        color: item.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value,
                  style: const TextStyle(
                      color: MM.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0)),
              const SizedBox(height: 2),
              Text(item.title,
                  style: const TextStyle(
                      color: MM.textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  ALERT BANNER — shows only when action is needed
  // ════════════════════════════════════════════════════════
  Widget _buildAlertBanner() {
    final alerts = <_Alert>[];

    if (_unreadInquiries > 0) {
      alerts.add(_Alert(
        icon: Icons.mark_email_unread_rounded,
        color: MM.accentRed,
        message:
            '$_unreadInquiries unread ${_unreadInquiries == 1 ? 'inquiry' : 'inquiries'} waiting for a response.',
        actionLabel: 'View Inquiries',
        navIndex: 4,
      ));
    }
    if (_pendingReservations > 0) {
      alerts.add(_Alert(
        icon: Icons.pending_actions_rounded,
        color: MM.accentAmber,
        message:
            '$_pendingReservations pending ${_pendingReservations == 1 ? 'reservation' : 'reservations'} need review.',
        actionLabel: 'View Reservations',
        navIndex: 2,
      ));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: a.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: a.color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(a.icon, color: a.color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(a.message,
                    style: TextStyle(
                        color: a.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              if (widget.onNavigate != null)
                GestureDetector(
                  onTap: () => widget.onNavigate!(a.navIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: a.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: a.color.withOpacity(0.3)),
                    ),
                    child: Text(a.actionLabel,
                        style: TextStyle(
                            color: a.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ════════════════════════════════════════════════════════
  //  RECENT ACTIVITY
  // ════════════════════════════════════════════════════════
  Widget _buildRecentActivity(bool isDesktop) {
    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _recentCarsCard()),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _recentReservationsCard(),
                    const SizedBox(height: 16),
                    _recentInquiriesCard(),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              _recentCarsCard(),
              const SizedBox(height: 16),
              _recentReservationsCard(),
              const SizedBox(height: 16),
              _recentInquiriesCard(),
            ],
          );
  }

  Widget _recentCarsCard() {
    return _SectionCard(
      title: 'Recent Cars',
      icon: Icons.directions_car_rounded,
      actionLabel: 'View all',
      onAction: () => widget.onNavigate?.call(1), // → Inventory
      child: _recentCars.isEmpty
          ? _empty('No vehicles added yet.',
              Icons.directions_car_rounded)
          : Column(
              children: _recentCars.map<Widget>((car) {
                final status = car['status']?.toString() ?? '';
                final price  = car['price'];
                return _listRow(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: MM.brandBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.directions_car_rounded,
                        color: MM.brandBlue, size: 20),
                  ),
                  title:
                    '${car['year'] ?? ''} ${car['make'] ?? ''} ${car['model'] ?? ''}'
                        .trim(),
                  subtitle: price != null
                      ? '\$${_fmt(price)}'
                      : 'Price not set',
                  trailing: _Badge(status),
                );
              }).toList(),
            ),
    );
  }

  Widget _recentReservationsCard() {
    return _SectionCard(
      title: 'Recent Reservations',
      icon: Icons.calendar_month_rounded,
      actionLabel: 'View all',
      onAction: () => widget.onNavigate?.call(2), // → Reservations
      child: _recentReservations.isEmpty
          ? _empty('No reservations yet.',
              Icons.calendar_month_rounded)
          : Column(
              children: _recentReservations.map<Widget>((item) {
                final status = item['status']?.toString() ?? '';
                final date   = item['created_at'] != null
                    ? _formatDate(item['created_at'].toString())
                    : '—';
                return _listRow(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: MM.accentAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.calendar_month_rounded,
                        color: MM.accentAmber, size: 20),
                  ),
                  title: item['customer_name']?.toString() ??
                      'Reservation #${(item['id']?.toString() ?? '—').substring(0, 6)}',
                  subtitle: date,
                  trailing: _Badge(status),
                );
              }).toList(),
            ),
    );
  }

  Widget _recentInquiriesCard() {
    return _SectionCard(
      title: 'Recent Inquiries',
      icon: Icons.mail_rounded,
      actionLabel: 'View all',
      onAction: () => widget.onNavigate?.call(4), // → Inquiries
      child: _recentInquiries.isEmpty
          ? _empty('No inquiries yet.', Icons.mail_rounded)
          : Column(
              children: _recentInquiries.map<Widget>((item) {
                final isRead = item['is_read'] == true;
                final date   = item['created_at'] != null
                    ? _formatDate(item['created_at'].toString())
                    : '—';
                return _listRow(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isRead
                          ? MM.bgSurface
                          : MM.accentRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRead
                          ? Icons.mail_outline_rounded
                          : Icons.mark_email_unread_rounded,
                      color: isRead ? MM.textSub : MM.accentRed,
                      size: 20,
                    ),
                  ),
                  title: item['subject']?.toString() ?? 'No subject',
                  subtitle: date,
                  trailing: isRead
                      ? null
                      : Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: MM.accentRed,
                              shape: BoxShape.circle),
                        ),
                );
              }).toList(),
            ),
    );
  }

  // ── Shared row
  Widget _listRow({
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: MM.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: MM.textSub, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _empty(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: MM.textMuted, size: 36),
            const SizedBox(height: 10),
            Text(msg,
                style: const TextStyle(
                    color: MM.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Number formatter  e.g. 45000 → 45K
  String _fmt(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }

  // ════════════════════════════════════════════════════════
  //  LOADING / ERROR STATES
  // ════════════════════════════════════════════════════════
  Widget _loader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 34, height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation<Color>(MM.brandBlue),
            ),
          ),
          SizedBox(height: 16),
          Text('Loading dashboard…',
              style: TextStyle(
                  color: MM.textSub, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: MM.textMuted, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load dashboard data.',
              style: TextStyle(
                  color: MM.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Check your connection and try again.',
              style: TextStyle(color: MM.textSub, fontSize: 13)),
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
}

// ═══════════════════════════════════════════════════════════
//  Local data models
// ═══════════════════════════════════════════════════════════
class _StatGroup {
  final String label;
  final List<_StatItem> items;
  const _StatGroup(this.label, this.items);
}

class _StatItem {
  final String title, value, sub;
  final IconData icon;
  final Color color;
  const _StatItem(this.title, this.value, this.icon, this.color, this.sub);
}

class _Alert {
  final IconData icon;
  final Color color;
  final String message, actionLabel;
  final int navIndex;
  const _Alert({
    required this.icon,
    required this.color,
    required this.message,
    required this.actionLabel,
    required this.navIndex,
  });
}

// ═══════════════════════════════════════════════════════════
//  Section card wrapper
// ═══════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title, actionLabel;
  final IconData icon;
  final VoidCallback onAction;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MM.brandBlue, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: MM.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: onAction,
                child: const Text('View all',
                    style: TextStyle(
                        color: MM.brandBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Divider(color: MM.border, height: 20),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Status badge
// ═══════════════════════════════════════════════════════════
class _Badge extends StatelessWidget {
  final String status;
  const _Badge(this.status);

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = MM.statusColor(status);
    final label = MM.statusLabel(status);
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