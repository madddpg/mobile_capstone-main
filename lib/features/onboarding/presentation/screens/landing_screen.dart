import 'package:flutter/material.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/register_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitController;
  late final Animation<double> _fadeOut;
  late final Animation<Offset> _slideOut;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.04),
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _runExit(
    VoidCallback action, {
    bool restoreIfStaying = true,
  }) async {
    if (_exiting) return;
    setState(() => _exiting = true);
    await _exitController.forward();
    if (!mounted) return;
    action();

    if (restoreIfStaying && mounted) {
      await _exitController.reverse();
      if (mounted) setState(() => _exiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const _LandingBackground(),
            FadeTransition(
              opacity: _fadeOut,
              child: SlideTransition(
                position: _slideOut,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size.width * 0.9,
                    height: size.height * 0.75,
                    child: _LandingCard(
                      onGetStarted: () {
                        _runExit(() {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              )
                              .then((_) {
                                if (mounted) {
                                  _exitController.reverse();
                                  setState(() => _exiting = false);
                                }
                              });
                        }, restoreIfStaying: false);
                      },
                      onLogin: () {
                        _runExit(() {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              )
                              .then((_) {
                                if (mounted) {
                                  _exitController.reverse();
                                  setState(() => _exiting = false);
                                }
                              });
                        }, restoreIfStaying: false);
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: FadeTransition(
                opacity: _fadeOut,
                child: SlideTransition(
                  position: _slideOut,
                  child: _FloatingBackButton(
                    onTap: () {
                      _runExit(() {
                        Navigator.of(context).maybePop();
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2F3E4F), Color(0xFF4F6B8A), Color(0xFF6F8FAF)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LandingCard extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  const _LandingCard({required this.onGetStarted, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(45),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF), // white
            Color(0xCCEDE4D4), // warm cream
            Color(0x00EDE4D4), // fade to transparent
          ],
          stops: [0.19, 0.65, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Create an\nAccount',
                style: TextStyle(
                  fontFamily: 'Bungee-Regular',
                  fontSize: 45,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F3E4F),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your projects starts with us.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5B6E80),
                ),
              ),
              const SizedBox(height: 36),
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.75,
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: onGetStarted,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xE6EDE4D4), // #EDE4D4 @ 90%
                              Color(0xB3FFFFFF), // #FFFFFF @ 70%
                              Color(0xFF648DB6), // #648DB6 @ 100%
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Center(
                          child: Text(
                            'Get Started',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: Color(0xFF2C3E50),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: onLogin,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1E7D6),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF32465C),
          size: 18,
        ),
      ),
    );
  }
}
