import 'package:flutter/material.dart';
import 'package:meridian_motors/features/admin/auth/admin_login.dart';
import 'package:meridian_motors/features/admin/dashboard/admin_dashboard.dart';
import '../home/home_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Midnight structural fallback
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return isDesktop
              ? _desktopLayout(context, size)
              : _mobileLayout(context, size);
        },
      ),
    );
  }

  Widget _mobileLayout(BuildContext context, Size size) {
    return Stack(
      children: [
        // LAYER 1: Full Canvas Image Render
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/welcome_bg.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // LAYER 2: Advanced Gradient Overlay Mask (Blends image box edges away)
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.40),
                Colors.black.withOpacity(0.75),
                Colors.black.withOpacity(0.98), // Solid bottom anchor for contrast
              ],
              stops: const [0.0, 0.4, 0.7, 0.95],
            ),
          ),
        ),

        // LAYER 3: User Interface Components
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // --- MERIDIAN LOGO CONTAINER OVERLAYED ON CANVAS ---
                Center(
                  child: Image.asset(
                    'assets/images/meridian_logo.png',
                    width: size.width * 0.72,
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
                ),

                const Spacer(flex: 3),

                // Brand Heading Typography
                const Text(
                  "Find Your Dream Car",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Browse premium vehicles, reserve your favourite car, and enjoy a trusted dealership experience.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFE5E7EB),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                // Action System Buttons
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Explore Cars",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 14),


                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminLoginPage(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9CA3AF),
                  ),
                  child: const Text(
                    "Skip for now",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopLayout(BuildContext context, Size size) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/welcome_bg.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                // child: Image.asset(
                //   'assets/images/meridian_logo.png',
                //   width: 450,
                //   fit: BoxFit.contain,
                // ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: ListView(
              // mainAxisAlignment: MainAxisAlignment.center,
              // crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Image.asset(
                  'assets/images/meridian_logo.png',
                  width: 450,
                  fit: BoxFit.contain,
                ),
                 const SizedBox(height: 18),
                const Text(
                  "Find Your Dream Car",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Browse premium vehicles, reserve your favourite car, and enjoy a trusted dealership experience.",
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.grey,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 45),
                SizedBox(
                  width: 280,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomePage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Explore Cars",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}