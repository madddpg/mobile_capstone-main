// The privacy notice covers what the Data Privacy Act asks for, and claims
// nothing the app does not do.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/auth/data/terms_content.dart';
import 'package:iconstruct/features/auth/presentation/screens/terms_conditions_screen.dart';

void main() {
  final text = iconstructTerms
      .map((t) => '${t['title']}\n${t['body']}')
      .join('\n');

  test('names the law and every required part of a privacy notice', () {
    expect(text, contains('Republic Act No. 10173'));
    expect(text, contains('National Privacy Commission'));
    for (final heading in [
      'Your Consent',
      'Personal Information We Collect',
      'Why We Use Your Information',
      'Who Can See Your Information',
      'How Long We Keep Your Information',
      'Your Rights as a Data Subject',
    ]) {
      expect(text, contains(heading));
    }
    expect(text, contains(privacyContactEmail));
  });

  test('does not claim data the app never collects', () {
    expect(text, isNot(contains('location-related')));
    expect(text, isNot(contains('favorites')));
    expect(text, contains('does not collect your GPS location'));
  });

  test('sections are numbered in order', () {
    for (var i = 0; i < iconstructTerms.length; i++) {
      expect(iconstructTerms[i]['title'], startsWith('${i + 1}. '));
    }
  });

  testWidgets('the Profile terms screen shows the privacy sections', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: TermsConditionsScreen()));
    await tester.scrollUntilVisible(
      find.text('13. Your Rights as a Data Subject'),
      300,
    );
    expect(find.text('13. Your Rights as a Data Subject'), findsOneWidget);
  });
}
