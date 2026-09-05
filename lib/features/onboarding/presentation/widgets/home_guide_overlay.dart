import 'package:flutter/material.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/features/onboarding/data/home_guide_steps.dart';

/// Dims the home screen and walks through [steps], optionally cutting a
/// spotlight hole around the current control.
class HomeGuideOverlay extends StatelessWidget {
  final List<HomeGuideStep> steps;
  final int stepIndex;
  final Rect? highlight;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const HomeGuideOverlay({
    super.key,
    required this.steps,
    required this.stepIndex,
    required this.highlight,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final step = steps[stepIndex];
    final media = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);

    final cardWidth = media.width.clamp(0, 360) - 48;
    final highlight = this.highlight;
    final placeBelow =
        highlight == null || highlight.center.dy < media.height * 0.42;
    double cardTop;
    if (highlight == null) {
      cardTop = media.height * 0.28;
    } else if (placeBelow) {
      cardTop = highlight.bottom + 18;
    } else {
      cardTop = highlight.top - 196;
    }
    cardTop = cardTop.clamp(pad.top + 12, media.height - 220 - pad.bottom);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(hole: highlight),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),
          Positioned(
            top: pad.top + 8,
            right: 16,
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cream,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            width: cardWidth > 0 ? cardWidth.toDouble() : media.width - 48,
            top: cardTop,
            child: _GuideCard(
              step: step,
              stepIndex: stepIndex,
              stepCount: steps.length,
              onNext: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final HomeGuideStep step;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onNext;

  const _GuideCard({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(stepCount, (i) {
                final active = i == stepIndex;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.navySoft
                        : AppColors.navySoft.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Text(
              step.title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppColors.navySoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: AppColors.navySoft.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navySoft,
                  foregroundColor: AppColors.cream,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  step.nextLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
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

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;

  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole != null && hole.width > 0 && hole.height > 0) {
      overlay.addRRect(
        RRect.fromRectAndRadius(
          hole.inflate(6),
          const Radius.circular(24),
        ),
      );
      overlay.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}
