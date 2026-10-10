import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/core/widgets/offset_pill_nav.dart';

/// The global bar is home, bidding, chat, files. The calculator that used to
/// sit in the third slot is gone, and the estimate flow is reached from the
/// home screen instead.
void main() {
  Future<void> pumpNav(WidgetTester tester, OffsetNavTab tab) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OffsetPillNav(activeTab: tab)),
      ),
    );
    await tester.pump();
  }

  testWidgets('the bar carries a chat icon and no calculator', (tester) async {
    await pumpNav(tester, OffsetNavTab.home);

    // Filled, matching home and files. An outline bubble read lighter than
    // its neighbours and made the row look uneven.
    expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.calculate_rounded), findsNothing);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
  });

  testWidgets('the chat tab shows as active on the inbox', (tester) async {
    await pumpNav(tester, OffsetNavTab.chat);

    expect(find.text('Chat'), findsOneWidget);
    // Same icon in both states, as with home and files; only the chip differs.
    expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
  });

  testWidgets('the active label shows whole on a phone', (tester) async {
    // Every slot used to share the row equally, so "Home" was cut to "H…"
    // although the three icons beside it left room to spare.
    tester.view.physicalSize = const Size(411, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final (tab, label) in [
      (OffsetNavTab.home, 'Home'),
      (OffsetNavTab.bidding, 'Bidding'),
      (OffsetNavTab.chat, 'Chat'),
      (OffsetNavTab.files, 'Files'),
    ]) {
      await pumpNav(tester, tab);
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.didExceedMaxLines, isFalse, reason: '$label is cut off');
    }
  });

  testWidgets('planning steps highlight no destination', (tester) async {
    // Estimate and Finalize are steps inside the flow, not places in the bar.
    for (final tab in [OffsetNavTab.estimate, OffsetNavTab.finalize]) {
      await pumpNav(tester, tab);
      expect(find.text('Estimate'), findsNothing);
      expect(find.text('Finalize'), findsNothing);
      // The bar still renders its four destinations.
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    }
  });
}
