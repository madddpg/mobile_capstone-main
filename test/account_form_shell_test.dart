// Edit Profile and Change Password open on a navy band, so the status bar
// icons over it must be light. The cream screens around them ask for dark
// icons, and those all but vanished against the navy.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/auth/presentation/widgets/account_form_shell.dart';

void main() {
  testWidgets('asks for light status bar icons over the navy band',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountFormShell(
          title: 'Change Password',
          hero: SizedBox(height: 80),
          form: SizedBox(height: 200),
        ),
      ),
    );
    // What the framework reads to style the status bar: the region painted
    // at the top of the screen.
    final style = tester.binding.renderViews.first.debugLayer!
        .find<SystemUiOverlayStyle>(const Offset(100, 1));
    expect(style?.statusBarIconBrightness, Brightness.light);
    expect(style?.statusBarBrightness, Brightness.dark); // iOS says it backwards
  });
}
