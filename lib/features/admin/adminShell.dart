import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/admin_login.dart';
import 'dashboard/admin_dashboard.dart';
import 'inventory/inventory_page.dart';

// ─────────────────────────────────────────────────────────────
//  MERIDIAN MOTORS — Admin Shell
//  Persistent sidebar + body-swap navigation (shell pattern)
//  All admin pages live inside this shell.
// ─────────────────────────────────────────────────────────────

// ── Brand tokens (single source of truth across all admin pages)
class MM {
  static const bgDeep      = Color(0xFF0A0A0F);
  static const bgCard      = Color(0xFF12121A);
  static const bgSurface   = Color(0xFF1C1C27);
  static const bgDrawer    = Color(0xFF0D0D16);
  static const brandNavy   = Color(0xFF0F2C59);
  static const brandBlue   = Color(0xFF1E56D6);
  static const accentGreen  = Color(0xFF22C55E);
  static const accentAmber  = Color(0xFFF59E0B);
  static const accentRed    = Color(0xFFEF4444);
  static const accentPurple = Color(0xFF8B5CF6);
  static const border       = Color(0xFF1F1F2E);
  static const textPrimary  = Color(0xFFFFFFFF);
  static const textSub      = Color(0xFF8A8A9A);
  static const textMuted    = Color(0xFF3D3D50);

  // Status badge helper — used by all child pages
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':  return accentGreen;
      case 'reserved':   return accentAmber;
      case 'sold':       return accentRed;
      case 'pending':    return accentAmber;
      case 'confirmed':  return accentGreen;
      case 'cancelled':  return accentRed;
      case 'completed':  return brandBlue;
      default:           return textSub;
    }
  }

  static String statusLabel(String status) {
    if (status.isEmpty) return '—';
    return status[0].toUpperCase() + status.substring(1);
  }
}

// ── Nav item model
class _NavItem {
  final IconData icon;
  final String label;
  final String? badgeKey; // which counter to show as badge
  const _NavItem(this.icon, this.label, {this.badgeKey});
}

// ── Shell widget
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  // ── Nav
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  // ── Admin profile
  String _adminName  = 'Admin';
  String _adminEmail = '';

  // ── Live badge counts (fed from dashboard data)
  int _unreadInquiries    = 0;
  int _pendingReservations = 0;

  // ── Nav items
  static const _navItems = [
    _NavItem(Icons.dashboard_rounded,       'Dashboard'),
    _NavItem(Icons.directions_car_rounded,  'Inventory'),
    _NavItem(Icons.calendar_month_rounded,  'Reservations', badgeKey: 'reservations'),
    _NavItem(Icons.people_rounded,          'Customers'),
    _NavItem(Icons.mail_rounded,            'Inquiries',    badgeKey: 'inquiries'),
    _NavItem(Icons.settings_rounded,        'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _initShell();
  }

  Future<void> _initShell() async {
    final ok = await _checkAdmin();
    if (ok) {
      await _loadProfile();
      await _loadBadgeCounts();
    }
  }

  Future<bool> _checkAdmin() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) { _redirectLogin(); return false; }
    try {
      final p = await supabase
          .from('profiles').select('role').eq('id', user.id).single();
      if (p['role'] != 'admin') {
        await supabase.auth.signOut();
        _redirectLogin();
        return false;
      }
      return true;
    } catch (_) { _redirectLogin(); return false; }
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final p = await Supabase.instance.client
          .from('profiles').select('full_name,email').eq('id', user.id).single();
      setState(() {
        _adminName  = p['full_name'] ?? 'Admin';
        _adminEmail = p['email']     ?? user.email ?? '';
      });
    } catch (_) {
      _adminEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    }
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final supabase = Supabase.instance.client;
      final results = await Future.wait([
        supabase.from('inquiries').select('id').eq('is_read', false),
        supabase.from('reservations').select('id').eq('status', 'pending'),
      ]);
      if (!mounted) return;
      setState(() {
        _unreadInquiries     = (results[0] as List).length;
        _pendingReservations = (results[1] as List).length;
      });
    } catch (_) {}
  }

  void _redirectLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const AdminLoginPage()));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MM.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?',
            style: TextStyle(color: MM.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('You will be returned to the login screen.',
            style: TextStyle(color: MM.textSub, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: MM.textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MM.accentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await Supabase.instance.client.auth.signOut();
    _redirectLogin();
  }

  // ── Badge count for a nav item
  int _badgeFor(_NavItem item) {
    if (item.badgeKey == 'inquiries')    return _unreadInquiries;
    if (item.badgeKey == 'reservations') return _pendingReservations;
    return 0;
  }

  // ── The page shown for each nav index
  Widget _buildPage(int index) {
    switch (index) {
      case 0:  return AdminDashboardBody(
                 onBadgeUpdate: (unread, pending) => setState(() {
                   _unreadInquiries     = unread;
                   _pendingReservations = pending;
                 }),
               );
      case 1:  return const InventoryPage();
      case 2:  return _PlaceholderPage('Reservations',   Icons.calendar_month_rounded,  MM.accentAmber);
      case 3:  return _PlaceholderPage('Customers',      Icons.people_rounded,           MM.accentPurple);
      case 4:  return _PlaceholderPage('Inquiries',      Icons.mail_rounded,             MM.accentRed);
      case 5:  return _PlaceholderPage('Settings',       Icons.settings_rounded,         MM.textSub);
      default: return const AdminDashboardBody();
    }
  }

  String _firstName() {
    final parts = _adminName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : 'Admin';
  }

  // ── Build
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: MM.bgDeep,
        drawer: isDesktop ? null : _buildDrawer(),
        body: isDesktop
            ? Row(children: [
                _buildSideNav(),
                Expanded(child: _buildBodyColumn(isDesktop)),
              ])
            : _buildBodyColumn(isDesktop),
      ),
    );
  }

  ThemeData _darkTheme() => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: MM.bgDeep,
        cardColor: MM.bgCard,
        dividerColor: MM.border,
      );

  Widget _buildBodyColumn(bool isDesktop) {
    return Column(
      children: [
        _buildTopBar(isDesktop),
        Expanded(child: _buildPage(_selectedIndex)),
      ],
    );
  }

  // ── Top bar
  Widget _buildTopBar(bool isDesktop) {
    final pageTitle = _navItems[_selectedIndex].label;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: MM.bgCard,
        border: Border(bottom: BorderSide(color: MM.border)),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            _iconBtn(Icons.menu_rounded,
                () => _scaffoldKey.currentState?.openDrawer()),
            const SizedBox(width: 14),
            const Text('MERIDIAN MOTORS',
                style: TextStyle(
                    color: MM.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ] else ...[
            // Breadcrumb on desktop
            Text('Admin',
                style: TextStyle(color: MM.textSub, fontSize: 13)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded,
                  color: MM.textMuted, size: 16),
            ),
            Text(pageTitle,
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              _iconBtn(Icons.notifications_none_rounded, () {}),
              if (_unreadInquiries > 0)
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: MM.accentRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: MM.bgCard, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        _unreadInquiries > 9 ? '9+' : '$_unreadInquiries',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 8,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          // Avatar chip → logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MM.bgSurface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: MM.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: MM.brandBlue.withOpacity(0.2),
                    child: Text(
                      _firstName().isNotEmpty
                          ? _firstName()[0].toUpperCase() : 'A',
                      style: const TextStyle(
                          color: MM.brandBlue, fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_firstName(),
                      style: const TextStyle(
                          color: MM.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: MM.textSub, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: MM.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MM.border),
        ),
        child: Icon(icon, color: MM.textSub, size: 20),
      ),
    );
  }

  // ── Desktop side nav
  Widget _buildSideNav() {
    return Container(
      width: 240,
      color: MM.bgDrawer,
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: MM.border))),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: MM.brandNavy,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MERIDIAN',
                        style: TextStyle(
                            color: MM.textPrimary, fontSize: 12,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Text('MOTORS',
                        style: TextStyle(
                            color: MM.textSub, fontSize: 10,
                            fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('MAIN MENU',
                  style: TextStyle(
                      color: MM.textMuted, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _navItems.asMap().entries.map((e) {
                return _navTile(e.key, e.value);
              }).toList(),
            ),
          ),
          // Sign out
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MM.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MM.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, color: MM.accentRed, size: 18),
                    SizedBox(width: 12),
                    Text('Sign out',
                        style: TextStyle(
                            color: MM.accentRed, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile drawer
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: MM.bgDrawer,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MM.brandNavy, MM.brandBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MERIDIAN MOTORS',
                          style: TextStyle(
                              color: MM.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      Text('Admin Panel',
                          style: TextStyle(color: MM.textSub, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: MM.border, height: 1),
            // Profile tile
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MM.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MM.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: MM.brandBlue.withOpacity(0.18),
                    child: Text(
                      _firstName().isNotEmpty
                          ? _firstName()[0].toUpperCase() : 'A',
                      style: const TextStyle(
                          color: MM.brandBlue, fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_adminName,
                            style: const TextStyle(
                                color: MM.textPrimary, fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        Text(_adminEmail,
                            style: const TextStyle(
                                color: MM.textSub, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _navItems.asMap().entries.map((e) {
                  return _navTile(e.key, e.value, inDrawer: true);
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MM.accentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MM.accentRed.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: MM.accentRed, size: 18),
                      SizedBox(width: 10),
                      Text('Sign out',
                          style: TextStyle(
                              color: MM.accentRed, fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(int index, _NavItem item, {bool inDrawer = false}) {
    final selected = _selectedIndex == index;
    final badge    = _badgeFor(item);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (inDrawer) Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? MM.brandBlue.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? MM.brandBlue.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(item.icon,
                color: selected ? MM.brandBlue : MM.textSub, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.label,
                  style: TextStyle(
                      color: selected ? MM.brandBlue : MM.textSub,
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: MM.accentRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Placeholder page — used for pages not yet built
// ─────────────────────────────────────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _PlaceholderPage(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  color: MM.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('This page is coming soon.',
              style: TextStyle(color: MM.textSub, fontSize: 14)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text('Under construction',
                style: TextStyle(
                    color: color, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}