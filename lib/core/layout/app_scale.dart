import 'package:flutter/material.dart';

/// Screen-size rules shared by every screen.
///
/// The screens were drawn for one phone width, with fixed font sizes (over 400
/// of them) and a few fixed boxes. On a small Android phone the text crowded
/// its rows, and on a large phone or tablet it looked undersized. Rather than
/// touch every screen, text is scaled here once, from the width of the screen,
/// and every `fontSize` in the app follows.
class AppScale {
  const AppScale._();

  /// Width the screens were designed at. Text keeps its written size here.
  static const double designWidth = 390;

  /// Widest layout the app uses. A tablet shows a centered column this wide,
  /// so the offset panels and forms keep their phone proportions instead of
  /// stretching edge to edge.
  static const double maxContentWidth = 600;

  static const double minWidthFactor = 0.85;
  static const double maxWidthFactor = 1.2;

  /// Ceiling on the phone's own font-size setting (accessibility).
  static const double maxUserTextScale = 1.3;

  /// Ceiling on screen factor × user setting together, so the largest text
  /// the app can produce still fits its layouts.
  static const double maxCombinedTextScale = 1.5;

  /// How much text grows or shrinks for a screen [width] in logical pixels.
  static double widthFactor(double width) =>
      (width / designWidth).clamp(minWidthFactor, maxWidthFactor);

  /// The phone's font-size setting as a single factor, from 1.0 up to
  /// [maxUserTextScale]. Settings below 1.0 are ignored, as before, because
  /// the estimate tables are already dense.
  static double userFactor(TextScaler system) =>
      (system.scale(14) / 14).clamp(1.0, maxUserTextScale);

  static TextScaler textScalerFor({
    required double width,
    required TextScaler system,
  }) {
    final factor = widthFactor(width) * userFactor(system);
    return TextScaler.linear(
      factor.clamp(minWidthFactor, maxCombinedTextScale),
    );
  }

  /// Width the app lays out at on a screen [width] wide.
  static double contentWidthFor(double width) =>
      width > maxContentWidth ? maxContentWidth : width;
}

/// Applies [AppScale] to everything below it.
///
/// Text scales with the screen width. On a screen wider than
/// [AppScale.maxContentWidth], the app is laid out in a centered column of
/// that width, and the [MediaQuery] below reports the column's width. Screens
/// that size themselves from `MediaQuery.sizeOf` therefore keep their phone
/// proportions, and dialogs and sheets open inside the column.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  /// Fills the space beside the column on a tablet.
  static const Color surroundColor = Color(0xFF16242F);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final contentWidth = AppScale.contentWidthFor(width);

    final content = MediaQuery(
      data: media.copyWith(
        size: Size(contentWidth, media.size.height),
        textScaler: AppScale.textScalerFor(
          width: contentWidth,
          system: media.textScaler,
        ),
      ),
      child: child,
    );

    if (contentWidth == width) return content;

    return ColoredBox(
      color: surroundColor,
      child: Center(
        child: SizedBox(width: contentWidth, child: content),
      ),
    );
  }
}
