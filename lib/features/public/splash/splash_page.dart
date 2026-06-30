import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meridian_motors/features/admin/auth/admin_login.dart';
import '../welcome/welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToWelcome();
  }

  void _navigateToWelcome() {
    // 3 seconds gives the user the perfect amount of time to take in the brand logo
    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Primary branding colors derived from your official logo
    const brandNavy = Color(0xFF0F2C59); 

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 244, 248), // Clean, high-end white canvas to let the logo pop
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // --- MERIDIAN MOTORS OFFICIAL LOGO ---
                // Once added to your pubspec.yaml assets, swap this with:
                 Image.asset('assets/images/meridian_logo.png', width: MediaQuery.of(context).size.width * 0.7),
               
                
                const Spacer(),
                
                // Premium, ultra-thin progress indicator matched to the logo theme
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 6.0,
                    valueColor: const AlwaysStoppedAnimation<Color>(brandNavy),
                    backgroundColor: brandNavy.withOpacity(0.1),
                  ),
                ),
                
          
              ],
            ),
          ),
        ),
      ),
    );
  }
}