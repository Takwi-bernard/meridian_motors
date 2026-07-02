import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';
import '../widgets/car_browse_panel.dart';
import '../welcome/welcome_page.dart';
import '../services/favorite_service.dart';
import '../services/notification_service.dart';
import 'panel/dashboard_nav.dart';
import 'panel/favorites_panel.dart';
import 'panel/reservations_panel.dart';
import 'panel/inquiries_panel.dart';
import 'panel/notifications_panel.dart';
import 'panel/profile_panel.dart';

/// Authenticated customer's home base.
///
/// Desktop (>900px): persistent 260px sidebar, content fills the rest.
/// Mobile          : hamburger AppBar + slide-in Drawer, identical nav.
///
/// Tab order MUST match [dashboardNavItems] in dashboard_nav.dart:
///   0 Browse Cars  1 Favorites  2 Reservations
///   3 Inquiries    4 Notifications  5 Profile
class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  static const int _notificationsTabIndex = 4;

  final FavoriteService _favoriteService = FavoriteService();
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<CarBrowsePanelState> _browseKey =
      GlobalKey<CarBrowsePanelState>();
  final GlobalKey<FavoritesPanelState> _favoritesKey =
      GlobalKey<FavoritesPanelState>();
  final GlobalKey<NotificationsPanelState> _notificationsKey =
      GlobalKey<NotificationsPanelState>();

  int _selectedIndex = 0;
  Set<String> _favoriteCarIds = {};
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadUnreadCount();
  }

  Future<void> _loadFavorites() async {
    try {
      final ids = await _favoriteService.fetchFavoriteCarIds();
      if (mounted) setState(() => _favoriteCarIds = ids);
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.fetchUnreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {}
  }

  Future<void> _handleFavoriteTap(CarModel car) async {
    final wasFavorite = _favoriteCarIds.contains(car.id);
    setState(() {
      if (wasFavorite) {
        _favoriteCarIds.remove(car.id);
      } else {
        _favoriteCarIds.add(car.id);
      }
    });
    try {
      await _favoriteService.toggleFavorite(
          car.id, isCurrentlyFavorite: wasFavorite);
      _favoritesKey.currentState?.load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteCarIds.add(car.id);
        } else {
          _favoriteCarIds.remove(car.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update favorite. Please try again.')),
      );
    }
  }

  Future<void> _signOut() async {
    // Confirm on mobile to prevent accidental taps from the drawer.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Color(0xFF9CA3AF))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const WelcomePage(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  void _goToNotifications() {
    setState(() => _selectedIndex = _notificationsTabIndex);
    _notificationsKey.currentState?.load();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        return isDesktop ? _desktopScaffold() : _mobileScaffold();
      },
    );
  }

  // ── Desktop ──────────────────────────────────────────────────────────────

  Widget _desktopScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: const Color(0xFF0D0D10),
            child: SafeArea(
              child: DashboardNavList(
                selectedIndex: _selectedIndex,
                onSelect: _selectTab,
                onSignOut: _signOut,
                badgeCounts: {_notificationsTabIndex: _unreadNotifications},
              ),
            ),
          ),
          // Subtle separator
          Container(
            width: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          // Content
          Expanded(
            child: SafeArea(child: _buildContent()),
          ),
        ],
      ),
    );
  }

  // ── Mobile ───────────────────────────────────────────────────────────────

  Widget _mobileScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: _mobileAppBar(),
      drawer: _mobileDrawer(),
      body: SafeArea(top: false, child: _buildContent()),
    );
  }

  PreferredSizeWidget _mobileAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D10),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      // Hamburger icon (Flutter adds this automatically when drawer is set)
      iconTheme: const IconThemeData(color: Colors.white),
      title: Image.asset(
        'assets/images/meridian_logo.png',
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'MERIDIAN MOTORS',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      centerTitle: false,
      actions: [
        // Quick-access notification bell with live badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 24),
              onPressed: _goToNotifications,
            ),
            if (_unreadNotifications > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.06),
        ),
      ),
    );
  }

  Widget _mobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D10),
      child: SafeArea(
        child: DashboardNavList(
          selectedIndex: _selectedIndex,
          onSelect: (index) {
            Navigator.pop(context); // close drawer first
            // Small delay so the drawer close animation finishes
            // before the content panel switches — feels cleaner.
            Future.delayed(const Duration(milliseconds: 180),
                () => _selectTab(index));
          },
          onSignOut: () {
            Navigator.pop(context);
            Future.delayed(
                const Duration(milliseconds: 180), _signOut);
          },
          badgeCounts: {_notificationsTabIndex: _unreadNotifications},
        ),
      ),
    );
  }

  // ── Content ──────────────────────────────────────────────────────────────

  Widget _buildContent() {
    // IndexedStack keeps each panel's scroll position and state alive
    // when switching tabs. Order must match dashboardNavItems.
    return IndexedStack(
      index: _selectedIndex,
      children: [
        RefreshIndicator(
          color: Colors.white,
          backgroundColor: const Color(0xFF1A1A1D),
          onRefresh: () =>
              _browseKey.currentState?.loadCars() ?? Future.value(),
          child: CarBrowsePanel(
            key: _browseKey,
            favoriteCarIds: _favoriteCarIds,
            onFavoriteTap: _handleFavoriteTap,
            // Dashboard has no separate page-level header, so the panel
            // renders its own "Find Your Dream Car" intro.
            showIntroHeader: true,
          ),
        ),
        FavoritesPanel(key: _favoritesKey),
        const ReservationsPanel(),
        const InquiriesPanel(),
        NotificationsPanel(
          key: _notificationsKey,
          onUnreadCountChanged: (count) {
            if (mounted) setState(() => _unreadNotifications = count);
          },
        ),
        ProfilePanel(
          onSignOut: _signOut,
          onViewNotifications: _goToNotifications,
          unreadNotificationCount: _unreadNotifications,
          onNavigateToTab: _selectTab,
        ),
      ],
    );
  }
}
