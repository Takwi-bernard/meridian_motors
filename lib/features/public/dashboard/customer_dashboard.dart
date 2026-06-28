import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';
import '../widgets/car_browse_panel.dart';
import '../welcome/welcome_page.dart';
import '../services/favorite_service.dart';
import 'widgets/dashboard_nav.dart';
import 'panel/reservations_panel.dart';
import 'panel/inquiries_panel.dart';
import 'panel/profile_panel.dart';

/// Authenticated customer's home base. Desktop gets a persistent
/// sidebar; mobile gets a hamburger-triggered drawer with the same
/// nav items, per spec. The default tab is the car grid (same data
/// as the public Home page) but here favoriting actually works
/// instead of redirecting to auth.
class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  final FavoriteService _favoriteService = FavoriteService();
  final GlobalKey<CarBrowsePanelState> _browseKey =
      GlobalKey<CarBrowsePanelState>();

  int _selectedIndex = 0;
  Set<String> _favoriteCarIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final ids = await _favoriteService.fetchFavoriteCarIds();
      if (mounted) setState(() => _favoriteCarIds = ids);
    } catch (_) {
      // Non-fatal — cards just show unfavorited until the next reload.
    }
  }

  /// Optimistically updates the UI, then syncs with Supabase. Reverts
  /// and shows an error if the write fails, so the heart icon never
  /// lies about the actual saved state.
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
      await _favoriteService.toggleFavorite(car.id, isCurrentlyFavorite: wasFavorite);
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
        const SnackBar(content: Text('Could not update favorite. Please try again.')),
      );
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        return isDesktop ? _desktopLayout() : _mobileLayout();
      },
    );
  }

  Widget _desktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Row(
        children: [
          Container(
            width: 260,
            color: const Color(0xFF111111),
            child: SafeArea(
              child: DashboardNavList(
                selectedIndex: _selectedIndex,
                onSelect: _selectTab,
                onSignOut: _signOut,
              ),
            ),
          ),
          const VerticalDivider(color: Colors.white12, width: 1),
          Expanded(child: SafeArea(child: _buildContent())),
        ],
      ),
    );
  }

  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'MERIDIAN MOTORS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF111111),
        child: SafeArea(
          child: DashboardNavList(
            selectedIndex: _selectedIndex,
            onSelect: (index) {
              _selectTab(index);
              Navigator.pop(context); // close the drawer after picking a tab
            },
            onSignOut: _signOut,
          ),
        ),
      ),
      body: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    // IndexedStack keeps each panel's state alive (scroll position,
    // search text, etc.) when switching tabs instead of rebuilding it.
    return IndexedStack(
      index: _selectedIndex,
      children: [
        RefreshIndicator(
          color: Colors.white,
          backgroundColor: const Color(0xFF1A1A1D),
          onRefresh: () => _browseKey.currentState?.loadCars() ?? Future.value(),
          child: CarBrowsePanel(
            key: _browseKey,
            favoriteCarIds: _favoriteCarIds,
            onFavoriteTap: _handleFavoriteTap,
          ),
        ),
        const ReservationsPanel(),
        const InquiriesPanel(),
        //ProfilePanel(onSignOut: _signOut),
      ],
    );
  }
}
