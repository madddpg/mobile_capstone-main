// Above the area breakdown, Site Details reads back what the builder typed
// and the total floor area, so a wrong figure is caught before it sizes
// every material.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, String asset) =>
      (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  const poppins = 'assets/fonts/Poppins-Light.ttf';
  await load('Poppins', poppins);
  for (final variant in [
    'regular',
    for (var w = 100; w <= 900; w += 100) '$w',
  ]) {
    await load('Poppins_$variant', poppins);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  RenovationCoverage coverage = RenovationCoverage.full,
  String room = 'Bathroom Renovation',
  String package = 'retile_only',
  Set<String>? work,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 3000) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final catalogue = RenovationTemplatesCatalog.workCatalogueFor(room);
  final ticked = work ?? catalogue.packageById(package)!.itemIds.toSet();
  final types = catalogue.typesOf(ticked);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: MaterialApp(
        home: TemplateAreaScreen(
          template: catalogue.templateFor(ticked),
          projectName: 'Bathroom Renovation',
          scope: types.primary,
          renovationTypes: types,
          coverage: coverage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The metres box whose hint is [hint] ("3.0" is Length, "2.5" is Width).
Finder _field(String hint) => find.ancestor(
      of: find.text(hint),
      matching: find.byType(TextField),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('reads the room back with its total floor area', (tester) async {
    await _pump(tester);

    expect(find.text('Your measurements'), findsOneWidget);
    expect(find.text('Area breakdown'), findsOneWidget);
    expect(find.text('Takeoff'), findsNothing);
    expect(
      find.text('Enter the length, width and height to see the total area.'),
      findsOneWidget,
    );

    await tester.enterText(_field('3.0'), '2');
    await tester.enterText(_field('2.5'), '1.5');
    await tester.pump();

    // The bathroom's ceiling height starts at 2.4 m.
    expect(find.text('2.00 m long × 1.50 m wide, 2.40 m high'), findsOneWidget);
    expect(find.text('Total floor area: 2.00 × 1.50 = 3.0 sq.m'),
        findsOneWidget);

    // The guide sits above the area breakdown.
    expect(
      tester.getTopLeft(find.text('Your measurements')).dy,
      lessThan(tester.getTopLeft(find.text('Area breakdown')).dy),
    );

    // Full-height tiles cover the wall line just above them, so they point
    // to it instead of repeating "Walls: 7.00 m around × …" word for word.
    expect(
      find.text('Walls: 7.00 m around × 2.40 m = 16.8 sq.m, less 1.83 sq.m '
          'of doors and windows = 14.97 sq.m'),
      findsOneWidget,
    );
    expect(
      find.text('Full-height tiles: all of the wall area above = 14.97 sq.m'),
      findsOneWidget,
    );
  });

  testWidgets('an odd size reads back exactly', (tester) async {
    await _pump(tester);
    await tester.enterText(_field('3.0'), '2.35');
    await tester.enterText(_field('2.5'), '1.85');
    await tester.pump();
    expect(find.text('Total floor area: 2.35 × 1.85 = 4.3475 sq.m'),
        findsOneWidget);
  });

  testWidgets('a half job says how much of the room is used', (tester) async {
    await _pump(tester, coverage: RenovationCoverage.half);
    await tester.enterText(_field('3.0'), '3');
    await tester.enterText(_field('2.5'), '2');
    await tester.pump();
    expect(find.text('Total floor area: 3.00 × 2.00 = 6.0 sq.m'),
        findsOneWidget);
    expect(find.text('Half of the room is used: 3.0 sq.m'), findsOneWidget);
  });

  testWidgets('work that paints nothing lists no paint area', (tester) async {
    // What the AI picked for "retile and waterproof the floor, the wall
    // tiles are fine". The breakdown still listed "Paint: … sq.m".
    await _pump(tester, work: {'retile_floor', 'waterproof_floor'});
    await tester.enterText(_field('3.0'), '2');
    await tester.enterText(_field('2.5'), '1.5');
    await tester.pump();

    expect(find.text('Area breakdown'), findsOneWidget);
    expect(find.textContaining('Waterproofing: 3.0 sq.m floor'), findsOneWidget);
    expect(find.textContaining('Paint:'), findsNothing);
  });

  group('room size boxes', () {
    // Length, width and height, in that order: the first boxes on the screen.
    final boxes = find.byType(TextField);

    /// Whether box [i] scrolls, i.e. part of its value is out of sight.
    double overflow(WidgetTester tester, int i) => tester
        .state<ScrollableState>(find.descendant(
          of: boxes.at(i),
          matching: find.byType(Scrollable),
        ))
        .position
        .maxScrollExtent;

    for (final phone in [360.0, 390.0, 412.0]) {
      testWidgets('show the whole value on a ${phone.toInt()} wide phone',
          (tester) async {
        await _pump(tester, width: phone);
        for (var i = 0; i < 3; i++) {
          await tester.enterText(boxes.at(i), '12.35');
        }
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          expect(overflow(tester, i), 0, reason: 'box ${i + 1} is cut off');
        }
        // Too narrow for three across, so the height has a row of its own.
        expect(
          tester.getTopLeft(boxes.at(2)).dy,
          greaterThan(tester.getBottomLeft(boxes.at(0)).dy),
        );
      });
    }

    for (final phone in [360.0, 412.0]) {
      testWidgets(
          'a door of another size shows its whole size on a '
          '${phone.toInt()} wide phone', (tester) async {
        await _pump(tester, width: phone);
        await tester.ensureVisible(find.text('Add another door size'));
        await tester.tap(find.text('Add another door size'));
        await tester.pumpAndSettle();
        final width = _field('0.80'), height = _field('2.10');
        await tester.enterText(width, '0.85');
        await tester.enterText(height, '2.15');
        await tester.pump();
        for (final box in [width, height]) {
          final scroll = tester.state<ScrollableState>(find.descendant(
            of: box,
            matching: find.byType(Scrollable),
          ));
          expect(scroll.position.maxScrollExtent, 0, reason: 'cut off');
        }
      });
    }

    testWidgets('sit three across where there is room', (tester) async {
      await _pump(tester, width: 800);
      expect(tester.getTopLeft(boxes.at(2)).dy,
          tester.getTopLeft(boxes.at(0)).dy);
    });
  });

  group('counters are read out in proper English', () {
    Finder label(String text) =>
        find.bySemanticsLabel(RegExp('(^|\\n)$text(\\n|\$)'));

    testWidgets('one door, two doors', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      // The bathroom starts with one bathroom door and none of the others.
      expect(label('1 door'), findsOneWidget);
      expect(label('0 doors'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('1 doors')), findsNothing);

      await tester.tap(find.byTooltip('One more door').first);
      await tester.pump();
      expect(label('2 doors'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('switches, not switchs', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, room: 'Bedroom Renovation', package: 'rewire');
      expect(label(r'\d+ (switch|switches)'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('switchs')), findsNothing);
      semantics.dispose();
    });
  });
}
