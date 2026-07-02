import 'package:flutter/material.dart';
import '../widgets/car_browse_panel.dart';
import '../auth/customer_login_page.dart';

/// Public landing page. Anyone can browse and search here without an
/// account. Favoriting or reserving a car requires authentication, so
/// those actions route to [CustomerAuthPage] via [CarBrowsePanel]'s
/// onFavoriteTap callback.
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
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CustomerAuthPage(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeHeader(onSignIn: _goToAuth),
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: const Color(0xFF1A1A1D),
                onRefresh: () =>
                    _panelKey.currentState?.loadCars() ?? Future.value(),
                child: CarBrowsePanel(
                  key: _panelKey,
                  favoriteCarIds: const {},
                  showIntroHeader: false, // header is already in _HomeHeader
                  onFavoriteTap: (_) => _goToAuth(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, isWide ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: isWide ? _wideHeader(context) : _narrowHeader(context),
    );
  }

  /// Mobile / narrow — stacked: logo row on top, headline + CTA below
  Widget _narrowHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _logo(height: 36),
            _signInButton(context, compact: true),
          ],
        ),
        const SizedBox(height: 14),
        // Headline
        const Text(
          'Find Your Dream Car',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Browse quality vehicles from our dealership and enjoy trading with us',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
      ],
    );
  }

  /// Desktop / wide — single row: logo + headline on left, CTA on right
  Widget _wideHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _logo(height: 80),
        const SizedBox(width: 24),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Your Dream Car',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'Browse quality vehicles from our dealership.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        _signInButton(context, compact: false),
      ],
    );
  }

  Widget _logo({required double height}) {
    return Image.asset(
      'assets/images/meridian_logo.png',
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Text(
        'MERIDIAN MOTORS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// The sign-in button is the primary CTA on this page — it should
  /// look more like a button than a ghost outline to actually pull
  /// attention. White-filled on dark background = maximum contrast.
  Widget _signInButton(BuildContext context, {required bool compact}) {
    return GestureDetector(
      onTap: onSignIn,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 28,
          vertical: compact ? 10 : 13,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 16, color: Color(0xFF111111)),
            const SizedBox(width: 6),
            Text(
              'Sign In',
              style: TextStyle(
                color: const Color(0xFF111111),
                fontWeight: FontWeight.bold,
                fontSize: compact ? 15 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
