import 'package:flutter/material.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';

/// Cream-on-light or cream-on-navy shimmer, shared by every loading placeholder.
enum AppSkeletonTone { onLight, onDark }

/// One sweep shared by every bone under this widget.
///
/// Bones used on their own start a sweep automatically, so a screen can drop
/// in a single [AppSkeleton] without wrapping it.
class AppSkeletonShimmer extends StatefulWidget {
  final Widget child;

  const AppSkeletonShimmer({super.key, required this.child});

  static Animation<double>? animationOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppSkeletonScope>()
        ?.animation;
  }

  @override
  State<AppSkeletonShimmer> createState() => _AppSkeletonShimmerState();
}

class _AppSkeletonShimmerState extends State<AppSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: 0.42,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _syncTicker() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppSkeletonScope(animation: _controller, child: widget.child);
  }
}

class _AppSkeletonScope extends InheritedWidget {
  final Animation<double> animation;

  const _AppSkeletonScope({required this.animation, required super.child});

  @override
  bool updateShouldNotify(_AppSkeletonScope oldWidget) =>
      animation != oldWidget.animation;
}

/// A single shimmering block. Compose these (or the layouts below) so a
/// loading screen echoes the cards, rows, or thread it will become.
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final AppSkeletonTone tone;

  /// Fills the cross-axis when [width] is null.
  final bool expandWidth;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
    this.tone = AppSkeletonTone.onLight,
    this.expandWidth = true,
  });

  const AppSkeleton.circle({
    super.key,
    required double size,
    this.tone = AppSkeletonTone.onLight,
  }) : width = size,
       height = size,
       radius = size / 2,
       expandWidth = false;

  static Color baseOf(AppSkeletonTone tone) => switch (tone) {
    AppSkeletonTone.onLight => const Color(0xFFD5CBBC),
    AppSkeletonTone.onDark => const Color(0x66EDE4D4),
  };

  static Color highlightOf(AppSkeletonTone tone) => switch (tone) {
    AppSkeletonTone.onLight => const Color(0xFFF8F3EA),
    AppSkeletonTone.onDark => const Color(0xB3EDE4D4),
  };

  @override
  Widget build(BuildContext context) {
    final bone = _AppSkeletonBone(
      width: width,
      height: height,
      radius: radius,
      tone: tone,
      expandWidth: expandWidth,
    );
    if (AppSkeletonShimmer.animationOf(context) != null) return bone;
    return AppSkeletonShimmer(child: bone);
  }
}

class _AppSkeletonBone extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final AppSkeletonTone tone;
  final bool expandWidth;

  const _AppSkeletonBone({
    required this.width,
    required this.height,
    required this.radius,
    required this.tone,
    required this.expandWidth,
  });

  @override
  Widget build(BuildContext context) {
    final animation = AppSkeletonShimmer.animationOf(context);
    final resolvedWidth = width ?? (expandWidth ? double.infinity : null);

    Widget paint(double t) {
      final base = AppSkeleton.baseOf(tone);
      final highlight = AppSkeleton.highlightOf(tone);
      return SizedBox(
        width: resolvedWidth,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.4 + (2.8 * t), 0),
              end: Alignment(-0.2 + (2.8 * t), 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        ),
      );
    }

    if (animation == null) return paint(0.35);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => paint(animation.value),
    );
  }
}

/// Rounded card of bones: a list row, a shop, a saved estimate, a quotation.
class AppSkeletonCard extends StatelessWidget {
  final AppSkeletonTone tone;
  final Color? cardColor;
  final double cardRadius;
  final EdgeInsetsGeometry cardPadding;
  final bool leadingCircle;
  final double leadingSize;
  final int textLines;
  final bool statusPill;

  const AppSkeletonCard({
    super.key,
    this.tone = AppSkeletonTone.onLight,
    this.cardColor,
    this.cardRadius = 20,
    this.cardPadding = const EdgeInsets.all(16),
    this.leadingCircle = false,
    this.leadingSize = 36,
    this.textLines = 2,
    this.statusPill = false,
  });

  @override
  Widget build(BuildContext context) {
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: AppSkeleton(height: 14, tone: tone)),
            if (statusPill) ...[
              const SizedBox(width: 12),
              AppSkeleton(width: 68, height: 20, radius: 10, tone: tone),
            ],
          ],
        ),
        for (var i = 1; i < textLines; i++) ...[
          const SizedBox(height: 8),
          AppSkeleton(
            width: i == textLines - 1 ? 140 : null,
            height: 11,
            tone: tone,
          ),
        ],
      ],
    );

    final body = leadingCircle
        ? Row(
            children: [
              AppSkeleton.circle(size: leadingSize, tone: tone),
              const SizedBox(width: 14),
              Expanded(child: lines),
            ],
          )
        : lines;

    final padded = Padding(padding: cardPadding, child: body);
    return SizedBox(
      width: double.infinity,
      child: cardColor == null
          ? padded
          : DecoratedBox(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(cardRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: padded,
            ),
    );
  }
}

/// A vertical run of [AppSkeletonCard]s. Scrolls when it is the page body.
class AppSkeletonCardList extends StatelessWidget {
  final int count;
  final AppSkeletonTone tone;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry cardMargin;
  final Color? cardColor;
  final double cardRadius;
  final EdgeInsetsGeometry cardPadding;
  final bool leadingCircle;
  final double leadingSize;
  final int textLines;
  final bool statusPill;
  final bool scrollable;

  const AppSkeletonCardList({
    super.key,
    this.count = 4,
    this.tone = AppSkeletonTone.onLight,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.cardMargin = const EdgeInsets.only(bottom: 14),
    this.cardColor,
    this.cardRadius = 20,
    this.cardPadding = const EdgeInsets.all(16),
    this.leadingCircle = false,
    this.leadingSize = 36,
    this.textLines = 2,
    this.statusPill = false,
    this.scrollable = true,
  });

  Widget _card() {
    return Padding(
      padding: cardMargin,
      child: AppSkeletonCard(
        tone: tone,
        cardColor: cardColor,
        cardRadius: cardRadius,
        cardPadding: cardPadding,
        leadingCircle: leadingCircle,
        leadingSize: leadingSize,
        textLines: textLines,
        statusPill: statusPill,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = List<Widget>.generate(count, (_) => _card());
    final list = scrollable
        ? ListView(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: cards,
          )
        : Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cards,
            ),
          );

    return Semantics(
      label: 'Loading',
      container: true,
      child: AppSkeletonShimmer(child: list),
    );
  }
}

/// Incoming and outgoing bubbles while a shop thread loads.
class AppSkeletonChatThread extends StatelessWidget {
  const AppSkeletonChatThread({super.key});

  @override
  Widget build(BuildContext context) {
    const gaps = [0.0, 10.0, 18.0, 8.0, 18.0, 8.0];
    const widths = [0.62, 0.46, 0.72, 0.38, 0.55, 0.34];
    const heights = [44.0, 36.0, 64.0, 36.0, 48.0, 36.0];
    const mine = [false, false, true, true, false, true];

    return Semantics(
      label: 'Loading',
      container: true,
      child: AppSkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (var i = 0; i < widths.length; i++)
              Align(
                alignment: mine[i]
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: gaps[i]),
                  child: FractionallySizedBox(
                    widthFactor: widths[i],
                    child: AppSkeleton(
                      height: heights[i],
                      radius: 18,
                      tone: AppSkeletonTone.onDark,
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

/// Avatar, name, and action cards while the profile document loads.
class AppSkeletonProfile extends StatelessWidget {
  final VoidCallback? onBack;

  const AppSkeletonProfile({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: AppSkeletonShimmer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: Row(
                        children: [
                          Material(
                            color: AppColors.navySoft,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onBack,
                              child: const SizedBox(
                                width: 38,
                                height: 38,
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  color: AppColors.cream,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppSkeleton(
                      width: 120,
                      height: 22,
                      tone: AppSkeletonTone.onLight,
                    ),
                    const SizedBox(height: 16),
                    const AppSkeleton.circle(
                      size: 96,
                      tone: AppSkeletonTone.onDark,
                    ),
                    const SizedBox(height: 14),
                    const AppSkeleton(
                      width: 180,
                      height: 16,
                      tone: AppSkeletonTone.onLight,
                    ),
                    const SizedBox(height: 8),
                    const AppSkeleton(
                      width: 140,
                      height: 12,
                      tone: AppSkeletonTone.onLight,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _profileCard(rows: 4),
              const SizedBox(height: 14),
              _profileCard(rows: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard({required int rows}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navySoft,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < rows; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                const Row(
                  children: [
                    AppSkeleton.circle(size: 28, tone: AppSkeletonTone.onDark),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeleton(height: 13, tone: AppSkeletonTone.onDark),
                          SizedBox(height: 6),
                          AppSkeleton(
                            width: 160,
                            height: 10,
                            tone: AppSkeletonTone.onDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox-and-label rows while recommended work is being read.
class AppSkeletonChecklist extends StatelessWidget {
  final int count;
  final AppSkeletonTone tone;

  const AppSkeletonChecklist({
    super.key,
    this.count = 5,
    this.tone = AppSkeletonTone.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: AppSkeletonShimmer(
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              Row(
                children: [
                  AppSkeleton.circle(size: 22, tone: tone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(height: 13, tone: tone),
                        const SizedBox(height: 6),
                        AppSkeleton(width: 120, height: 10, tone: tone),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cream curve and navy estimate card, matching a posted-estimate screen
/// before its document arrives.
class AppSkeletonEstimateBody extends StatelessWidget {
  final VoidCallback? onBack;

  const AppSkeletonEstimateBody({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(60),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  if (onBack != null)
                    Positioned(
                      top: 10,
                      left: 20,
                      child: Material(
                        color: AppColors.navySoft,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onBack,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 90,
                    right: 0,
                    left: IConstructPanel.leftInsetOf(context),
                    child: AppSkeletonShimmer(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.navySoft,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(55),
                            bottomLeft: Radius.circular(55),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 15,
                              offset: Offset(-5, 10),
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(28, 36, 24, 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSkeleton(
                                width: 190,
                                height: 22,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 20),
                              AppSkeleton(
                                height: 1,
                                radius: 1,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 20),
                              AppSkeleton(
                                width: 130,
                                height: 14,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 12),
                              AppSkeleton(
                                height: 12,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 8),
                              AppSkeleton(
                                width: 210,
                                height: 12,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 8),
                              AppSkeleton(
                                width: 160,
                                height: 12,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 8),
                              AppSkeleton(
                                width: 120,
                                height: 12,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 28),
                              AppSkeleton(
                                height: 1,
                                radius: 1,
                                tone: AppSkeletonTone.onDark,
                              ),
                              SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppSkeleton(
                                      height: 13,
                                      tone: AppSkeletonTone.onDark,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  AppSkeleton(
                                    width: 64,
                                    height: 13,
                                    tone: AppSkeletonTone.onDark,
                                  ),
                                ],
                              ),
                              SizedBox(height: 28),
                              Align(
                                alignment: Alignment.centerRight,
                                child: AppSkeleton(
                                  width: 148,
                                  height: 36,
                                  radius: 20,
                                  tone: AppSkeletonTone.onDark,
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
            ),
          ],
        ),
      ),
    );
  }
}
