// Login asks for the same minimum password length as registration.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/validation/password_policy.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('a password shorter than 8 characters is refused at login', (
    tester,
  ) async {
    expect(PasswordPolicy.minLength, 8);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'builder@example.com');
    await tester.enterText(fields.last, 'Abc1234');
    await tester.pump();

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(find.textContaining('6 characters'), findsNothing);

    await tester.enterText(fields.last, 'Abc12345');
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsNothing);
  });
}
