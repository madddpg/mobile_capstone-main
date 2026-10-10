import 'package:flutter/material.dart';
import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/core/widgets/app_buttons.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/register_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/main_display.dart';

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
                    width: size.width * 0.85,
                    height: size.height * 0.68,
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
                      // Landing is the root once the intro or splash
                      // replaced itself, so back replays the intro.
                      _runExit(() {
                        AppNav.back(
                          context,
                          rootFallback: (_) => const MainDisplayScreen(),
                        );
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
          // Fills the card when there is room and scrolls when there is not,
          // as on a small phone with large text, instead of pushing the
          // buttons off the bottom of the card.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      // The display title is sized for impact, not to wrap. It
                      // scales down to the card's width rather than overflow.
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Create an\nAccount',
                          style: TextStyle(
                            fontFamily: 'Bungee-Regular',
                            fontSize: 45,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F3E4F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your project starts with us.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5B6E80),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Center(
                        child: _GetStartedButton(onPressed: onGetStarted),
                      ),
                      const SizedBox(height: 14),
                      _LoginPrompt(onLogin: onLogin),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The landing card's own pill: cream fading into the background blue, so it
/// reads as part of the card rather than one of the app's form buttons.
class _GetStartedButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GetStartedButton({required this.onPressed});

  static const _radius = BorderRadius.all(Radius.circular(30));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: ConstrainedBox(
        // A minimum, not a fixed size, so a large font setting grows the
        // pill instead of clipping its label.
        constraints: const BoxConstraints(
          minWidth: 200,
          minHeight: AppButtons.minHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFEDE4D4), // cream
                Color(0xFFE2DDD4),
                Color(0xFF7C9CC2), // background blue
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              borderRadius: _radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  // Bundled fonts only, as on the rest of this card: the
                  // first screen must not wait on a font download.
                  child: const Text(
                    'Get Started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Already have an account? Login" on one line, with Login as the link.
class _LoginPrompt extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginPrompt({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    // Full width so the Wrap can centre the line; on its own it shrinks to
    // the text and sits at the start of the card's left-aligned column.
    return SizedBox(
      width: double.infinity,
      child: _buildLine(),
    );
  }

  Widget _buildLine() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          textAlign: TextAlign.center,
          // Darker than the subtitle: this line sits low on the card, where
          // the cream has already faded towards the blue.
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF3F5266),
          ),
        ),
        TextButton(
          onPressed: onLogin,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2C3E50),
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Log in',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
