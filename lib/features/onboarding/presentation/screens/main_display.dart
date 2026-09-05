import 'package:flutter/material.dart';
import 'package:iconstruct/core/state/onboarding_preferences.dart';
import 'package:iconstruct/core/widgets/app_image.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/landing_screen.dart';

class MainDisplayScreen extends StatefulWidget {
  const MainDisplayScreen({super.key});

  @override
  State<MainDisplayScreen> createState() => _MainDisplayScreenState();
}

class _MainDisplayScreenState extends State<MainDisplayScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _textAnim;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  int _index = 0;

  final _slides = const [
    _Slide(
      imagePath: 'assets/images/display 1.jpg',
      title: 'Estimate\nMaterials',
      subtitle:
          'Describe the renovation you have in mind and get a material list that scales to your floor area.',
    ),
    _Slide(
      imagePath: 'assets/images/display 2.jpg',
      title: 'Canvass\nSuppliers',
      subtitle:
          'Send your material list to hardware shops and collect their quotations in one place.',
    ),
    _Slide(
      imagePath: 'assets/images/display 3.jpg',
      title: 'Compare\nand Choose',
      subtitle:
          'Compare offers side by side, then pick the supplier that fits your budget.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _textAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _fadeIn = CurvedAnimation(parent: _textAnim, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fadeIn);

    // play initial in-animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textAnim.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textAnim.dispose();
    super.dispose();
  }

  Color get _accentBlue => const Color(0xFF6FA8FF); // matches prototype vibe
  Color get _dotGrey => const Color(0xFFBFC6CE);

  Future<void> _goTo(int next) async {
    if (next == _index) return;
    await _textAnim.reverse(); // out animation
    setState(() => _index = next);
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _textAnim.forward(); // in animation
  }

  Future<void> _handleNext() async {
    if (_index < _slides.length - 1) {
      await _goTo(_index + 1);
    } else {
      // After last slide, proceed to Landing
      if (!mounted) return;
      await _textAnim.reverse();
      await OnboardingPreferences.markIntroSeen();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LandingScreen(),
          transitionsBuilder: (context, anim, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // pages
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // control animations
            itemCount: _slides.length,
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return _SlideBackground(imagePath: slide.imagePath);
            },
          ),

          // bottom text + controls overlay
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _textAnim,
                      builder: (context, child) => FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideUp,
                          child: child,
                        ),
                      ),
                      child: _SlideText(slide: _slides[_index]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _NextButton(onPressed: _handleNext),
                ],
              ),
            ),
          ),

          // indicators
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Row(
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: active ? 42 : 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? _accentBlue
                          : _dotGrey.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String imagePath;
  final String title;
  final String subtitle;
  const _Slide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}

class _SlideBackground extends StatelessWidget {
  final String imagePath;
  const _SlideBackground({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Builder(
          builder: (context) {
            final size = MediaQuery.sizeOf(context);
            return AppImage.asset(
              context,
              imagePath,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
            );
          },
        ),
        // dark gradient overlay for text legibility (prototype style)
        const _BottomFadeOverlay(),
      ],
    );
  }
}

class _BottomFadeOverlay extends StatelessWidget {
  const _BottomFadeOverlay();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.55),
          ],
          stops: const [0.5, 0.7, 0.85, 1.0],
        ),
      ),
    );
  }
}

class _SlideText extends StatelessWidget {
  final _Slide slide;
  const _SlideText({required this.slide});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      color: Colors.white,
      height: 1.05,
      fontWeight: FontWeight.w700,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(slide.title, style: titleStyle),
        const SizedBox(height: 10),
        Text(slide.subtitle, style: bodyStyle),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _NextButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: const Color(0xFFF2F2F2).withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Center(
            child: Icon(Icons.arrow_forward_rounded, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
