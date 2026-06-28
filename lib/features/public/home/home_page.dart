
import 'package:flutter/material.dart';
import '../widgets/car_browse_panel.dart';
import '../auth/customer_login_page.dart';

/// Public landing page. Anyone can browse and search here without an
/// account. Favoriting or reserving a car requires authentication, so
/// those actions route to [CustomerAuthPage] via [CarBrowsePanel]'s
/// onFavoriteTap callback rather than performing the action directly.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<CarBrowsePanelState> _panelKey =
      GlobalKey<CarBrowsePanelState>();

  void _goToAuth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerAuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: const Color(0xFF1A1A1D),
                onRefresh: () =>
                    _panelKey.currentState?.loadCars() ?? Future.value(),
                child: CarBrowsePanel(
                  key: _panelKey,
                  favoriteCarIds: const {},
                  // Public Home: favoriting always requires authentication.
                  onFavoriteTap: (_) => _goToAuth(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
               Image.asset(
                    'assets/images/meridian_logo.png',
                   width: 100,height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      "MERIDIAN MOTORS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                   const Text(
            'MERIDIAN MOTORS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
            ],
          ),
         
          OutlinedButton(
            onPressed: _goToAuth,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
