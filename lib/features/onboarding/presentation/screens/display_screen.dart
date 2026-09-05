import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconstruct/core/state/onboarding_preferences.dart';
import 'package:iconstruct/core/widgets/app_image.dart';
import 'package:iconstruct/features/auth/presentation/screens/main_home_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/landing_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/main_display.dart';

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _scale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _navTimer = Timer(const Duration(milliseconds: 3000), _goToNextScreen);
  }

  /// Returning builders skip the intro: straight to home if their session is
  /// still valid, otherwise to sign-in.
  Future<void> _goToNextScreen() async {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final seenIntro = signedIn || await OnboardingPreferences.hasSeenIntro();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) {
          if (signedIn) return const MainHomeScreen();
          if (seenIntro) return const LandingScreen();
          return const MainDisplayScreen();
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _DisplayBackground(),

          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppImage.asset(
                        context,
                        'assets/images/logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'iConstruct',
                        style: TextStyle(
                          color: Color(0xFFF4E7CB),
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Plan smarter. Build better.',
                        style: TextStyle(
                          color: Color(0xFFEADAC2),
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayBackground extends StatelessWidget {
  const _DisplayBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2F3E4F), Color(0xFF4F6B8A), Color(0xFF6F8FAF)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
