// The clock, signal and battery must stay readable: light icons on the navy
// sign-in screens and room picker, dark icons everywhere else.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/widgets/status_bar.dart';

/// What the framework reads to style the status bar: the region painted at
/// the top of the screen.
Brightness? _icons(WidgetTester tester) => tester
    .binding.renderViews.first.debugLayer!
    .find<SystemUiOverlayStyle>(const Offset(100, 1))
    ?.statusBarIconBrightness;

void main() {
  testWidgets('a navy screen gets light icons, and the next screen does not '
      'keep them', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) =>
          AnnotatedRegion<SystemUiOverlayStyle>(value: darkStatusBar, child: child!),
      home: const LightStatusBar(
        child: Scaffold(backgroundColor: Color(0xFF22384C)),
      ),
    ));
    expect(_icons(tester), Brightness.light);

    // A cream screen that sets nothing, as home does after sign-in.
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(backgroundColor: Color(0xFFEBE0CC)),
    ));
    await tester.pumpAndSettle();
    expect(_icons(tester), Brightness.dark);
  });
}
