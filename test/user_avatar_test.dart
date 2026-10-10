// A tappable avatar says what it opens; screen readers met an unlabeled
// button in every header.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/widgets/user_avatar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget avatar) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: avatar))),
      );

  testWidgets('a header avatar is a button named Profile', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, UserAvatar(onTap: () {}));
    expect(
      tester.getSemantics(find.byType(UserAvatar)),
      matchesSemantics(
        label: 'Profile',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the Profile screen avatar says it changes the photo',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      UserAvatar(onTap: () {}, semanticLabel: 'Change profile photo'),
    );
    expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an avatar that does nothing is not a button', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const UserAvatar());
    expect(find.bySemanticsLabel('Profile'), findsNothing);
    semantics.dispose();
  });
}
