// Every message the builder is shown must be visible: above an open sheet or
// dialog, below the status bar however long it is, clear of the keyboard,
// readable against its background, and read out by screen readers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/widgets/app_message.dart';

Widget _app(Widget home) => MaterialApp(
      builder: (context, child) => AppMessageHost(child: child!),
      home: home,
    );

/// A page with a button that runs [onOpen] with the page's context.
Widget _page(void Function(BuildContext) onOpen) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

/// A button that shows [message] from its own context.
Widget _say(String message) => Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            showAppMessage(context, SnackBar(content: Text(message))),
        child: const Text('say'),
      ),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('a message raised in a dialog shows above it', (tester) async {
    // The OTP dialog's "wrong code" message was drawn under its scrim.
    await tester.pumpWidget(_app(_page((context) => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(content: _say('Wrong code. Try again.')),
        ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('say'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong code. Try again.'), findsOneWidget);

    // On top of the dialog's barrier: a tap reaches the message and
    // dismisses it. Under the barrier, it would have closed the dialog.
    await tester.tap(find.text('Wrong code. Try again.'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong code. Try again.'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a message raised in a bottom sheet shows above it',
      (tester) async {
    // "Order line copied" was hidden under the material sheet.
    await tester.pumpWidget(_app(_page((context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SizedBox(height: 700, child: _say('Order line copied')),
        ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('say'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Order line copied'));
    await tester.pumpAndSettle();
    expect(find.text('Order line copied'), findsNothing);
    expect(find.text('say'), findsOneWidget, reason: 'the sheet stays open');
  });

  testWidgets('a long message starts below the status bar', (tester) async {
    // A three-line message ran up under the clock: the SnackBar's margin
    // assumed every message was 96 pixels tall.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3);
    addTearDown(tester.view.reset);

    const long = 'You can rate GShop once they have confirmed an order on one '
        'of your estimates. Ratings come only from builders who actually '
        'bought from a shop, so every star means something.';
    await tester.pumpWidget(_app(_page(
        (context) => showAppMessage(context, const SnackBar(content: Text(long))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(AppMessageCard));
    expect(card.top, greaterThanOrEqualTo(47));
    expect(card.height, greaterThan(96), reason: 'the card grows with its text');
  });

  testWidgets('the keyboard does not move or cover a message', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_page((context) =>
        showAppMessage(context, const SnackBar(content: Text('Saved.'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byType(AppMessageCard));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppMessageCard)), before);
  });

  testWidgets('a message goes after its time, or when tapped', (tester) async {
    await tester.pumpWidget(_app(_page((context) => showAppMessage(
          context,
          const SnackBar(content: Text('Draft saved.')),
          duration: const Duration(seconds: 2),
        ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved.'), findsNothing);
  });

  testWidgets('a new message replaces the one showing', (tester) async {
    var n = 0;
    await tester.pumpWidget(_app(_page((context) => showAppMessage(
        context, SnackBar(content: Text('Message ${++n}'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Message 1'), findsNothing);
    expect(find.text('Message 2'), findsOneWidget);
  });

  testWidgets('screen readers announce a message', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_page((context) =>
        showAppMessage(context, const SnackBar(content: Text('Saved.'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(AppMessageCard)),
      isSemantics(label: 'Saved.', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('a host that never showed a message closes cleanly',
      (tester) async {
    // Its animation was made lazily, so closing a quiet host created it
    // inside dispose() and threw.
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a host it still shows, as a SnackBar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: _page((context) =>
          showAppMessage(context, const SnackBar(content: Text('Saved.')))),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Saved.'), findsOneWidget);
  });

  group('readable text', () {
    Future<void> expectReadable(
        WidgetTester tester, AppMessageKind kind) async {
      await tester.pumpWidget(_app(_page((context) => showAppMessage(
          context, const SnackBar(content: Text('Check this.')),
          kind: kind))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final card = tester.widget<Material>(find.descendant(
          of: find.byType(AppMessageCard), matching: find.byType(Material)));
      final text = DefaultTextStyle.of(tester.element(find.text('Check this.')))
          .style
          .color!;
      expect(_contrast(text, card.color!), greaterThanOrEqualTo(4.5),
          reason: '$kind text on its background');
    }

    testWidgets('warning', (t) => expectReadable(t, AppMessageKind.warning));
    testWidgets('success', (t) => expectReadable(t, AppMessageKind.success));
    testWidgets('info', (t) => expectReadable(t, AppMessageKind.info));

    testWidgets('a field warning reads on any background', (tester) async {
      // On the sign-in screens it sat straight on navy at about 2:1.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF314C69),
          body: warningFieldError('Email is required')!,
        ),
      ));
      final text = tester.widget<Text>(find.text('Email is required'));
      final box = tester.widget<Container>(find.ancestor(
          of: find.text('Email is required'), matching: find.byType(Container)).first);
      final background = (box.decoration! as BoxDecoration).color!;
      expect(_contrast(text.style!.color!, background),
          greaterThanOrEqualTo(4.5));
    });
  });
}
