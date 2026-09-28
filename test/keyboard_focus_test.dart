// Opening the keyboard must not cost the text field its focus.
//
// On a small phone the keyboard leaves some screens too little height, and
// they switch to a compact or scrolling layout. If that switch rebuilds the
// field that was tapped, the field loses focus, the keyboard closes, the
// layout switches back, and the builder cannot type at all. These tap a
// field on the smallest phone, open the keyboard, and check the field still
// has focus and sits above the keyboard.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/layout/app_scale.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';
import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
import 'package:iconstruct/features/project_creation/screens/create_project_screen.dart';

/// The smallest phone, and one tall enough that the layout only switches
/// when the keyboard opens, which is where a rebuild would drop focus.
const _screens = <String, Size>{
  '320x568': Size(320, 568),
  '375x667': Size(375, 667),
};
const double _keyboard = 300;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final screens = <String, Widget Function()>{
    'Name your project': () =>
        const CreateProjectScreen(renovationType: 'Bathroom Renovation'),
    'AI consultant': () =>
        const AIConsultationScreen(projectName: 'Bathroom Renovation'),
    'Shop chat': () => const ChatThreadScreen(
      conversationId: 'post-1_shop-1',
      shopName: 'Santo Niño Construction Supply and Hardware',
      projectTitle: 'Bathroom Renovation',
    ),
  };

  for (final entry in screens.entries) {
    for (final size in _screens.entries) {
      testWidgets(
        '${entry.key} keeps focus when the keyboard opens on ${size.key}',
        (tester) async {
          final screen = size.value;
          tester.view.physicalSize = screen * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => UserProvider(),
              child: MaterialApp(
                builder: (context, child) => ResponsiveFrame(child: child!),
                home: entry.value(),
              ),
            ),
          );
          // The AI consultant types its opening messages on timers.
          await tester.pump(const Duration(seconds: 3));

          final field = find.byType(EditableText).last;
          await tester.tap(field);
          await tester.pump();
          expect(
            _hasFocus(tester),
            isTrue,
            reason: 'the tap focused the field',
          );

          tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 3);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            _hasFocus(tester),
            isTrue,
            reason: 'opening the keyboard rebuilt the field and dropped focus',
          );
          final rect = tester.getRect(find.byType(EditableText).last);
          expect(
            rect.bottom,
            lessThanOrEqualTo(screen.height - _keyboard),
            reason: 'the focused field is hidden behind the keyboard',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 30));
        },
      );
    }
  }
}

bool _hasFocus(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).last)
    .focusNode
    .hasFocus;
