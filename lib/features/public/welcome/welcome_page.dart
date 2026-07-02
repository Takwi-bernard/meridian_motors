import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/home_page.dart';
import '../dashboard/customer_dashboard.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  bool _checkingAuth = true;
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _checkAuthAndRoute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAuthAndRoute() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboardPage()),
        );
      });
    } else {
      setState(() => _checkingAuth = false);
      _controller.forward();
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F11),
        body: SizedBox.shrink(),
      );
    }
    return FadeTransition(
      opacity: _fadeIn,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth > 900
            ? _DesktopWelcome(onExplore: _goToHome)
            : _MobileWelcome(onExplore: _goToHome),
      ),
    );
  }
}

class _MobileWelcome extends StatelessWidget {
  const _MobileWelcome({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/welcome_bg.jpeg', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0F0F11))),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.72),
                  Colors.black.withOpacity(0.97),
                ],
                stops: const [0.0, 0.38, 0.65, 0.92],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  Image.asset('assets/images/meridian_logo.png',
                      width: w * 0.68, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('MERIDIAN MOTORS',
                          style: TextStyle(color: Colors.white, fontSize: 28,
                              fontWeight: FontWeight.w900, letterSpacing: 2))),
                  const Spacer(flex: 4),
                  const Text('Find Your\nDream Car',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 36,
                          fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1)),
                  const SizedBox(height: 16),
                  const Text(
                    'Browse premium vehicles, reserve your favourite car,\nand enjoy a trusted dealership experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: Color(0xFFD1D5DB), height: 1.55),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onExplore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111111),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Explore Cars',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: onExplore,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF9CA3AF)),
                    child: const Text('Skip for now',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopWelcome extends StatelessWidget {
  const _DesktopWelcome({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Row(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/welcome_bg.jpeg', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF111111))),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF111111),
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/meridian_logo.png',
                      height: 72, fit: BoxFit.contain, alignment: Alignment.centerLeft,
                      errorBuilder: (_, __, ___) => const Text('MERIDIAN MOTORS',
                          style: TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.w900, letterSpacing: 2))),
                  const SizedBox(height: 36),
                  const Text('Find Your\nDream Car',
                      style: TextStyle(color: Colors.white, fontSize: 48,
                          fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.05)),
                  const SizedBox(height: 20),
                  const Text(
                    'Browse premium vehicles, reserve your favourite\ncar, and enjoy a trusted dealership experience.',
                    style: TextStyle(fontSize: 15.5, color: Color(0xFF9CA3AF), height: 1.6),
                  ),
                  const SizedBox(height: 44),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onExplore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111111),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Explore Cars',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: onExplore,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280), padding: EdgeInsets.zero),
                    child: const Text('Skip for now',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
