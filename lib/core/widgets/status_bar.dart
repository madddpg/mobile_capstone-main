import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons for a screen whose top is navy: light, so the clock,
/// signal and battery stay readable. Without it the sign-in screens and the
/// room picker kept the dark icons of the cream screens, dark grey on navy.
const SystemUiOverlayStyle lightStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark, // iOS names it by the background
);

/// Status bar icons for a screen whose top is cream or white: dark. The app
/// default, set at its root, so a screen that does not choose never keeps the
/// light icons of the navy screen before it.
const SystemUiOverlayStyle darkStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// Gives [child], a screen with a navy top, light status bar icons.
class LightStatusBar extends StatelessWidget {
  const LightStatusBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: lightStatusBar, child: child);
}
