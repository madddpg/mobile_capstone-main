// The Material Estimator functionality test (cycle 5), run against the code.
//
// The paper test enters two rooms and compares the app with a computation
// done by hand: 3.0 m of wire per outlet run, 1.08 waste, and the room's own
// measurements. Every expected number below is that hand computation, typed
// in, not the app's formula called again. The older tests compared the app
// with itself, which is how a tile count one piece too high went unnoticed.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// Test room A: bathroom, "Retile only", 2.0 × 1.5 m, 2.4 m high, one door
/// 0.70 × 2.10 m, one vent 0.60 × 0.60 m, full-height wall tiles.
const _roomA = SiteDetails(
  job: RoomJob.wetRoom,
  lengthM: 2.0,
  widthM: 1.5,
  heightM: 2.4,
  doors: [Opening(widthM: 0.70, heightM: 2.10)],
  windows: [Opening(widthM: 0.60, heightM: 0.60)],
  wallTileHeight: WallTileHeight.full,
);

/// Test room B: living room, "Rewire". The sheet gives no size; wiring is
/// sized from the device counts, so any room gives the same wire.
const _roomB = SiteDetails(
  job: RoomJob.dryRoom,
  lengthM: 4.0,
  widthM: 3.0,
  heightM: 2.7,
);

/// The list the screens build: the package's ticked work, measured.
List<RenovationTemplateItem> _estimate(
  String project,
  String package,
  SiteDetails room, {
  FunctionalCounts? counts,
}) {
  final catalogue = RenovationTemplatesCatalog.workCatalogueFor(project);
  final ticked = catalogue.packageById(package)!.itemIds.toSet();
  final types = catalogue.typesOf(ticked);
  final takeoff = SiteTakeoff.from(room);
  return BomQuantityEstimator.scaleTemplate(
    template: catalogue.templateFor(ticked),
    areaSqm: takeoff.floorSqm,
    scope: types.primary,
    types: types,
    takeoff: takeoff,
    counts: counts,
  );
}

RenovationTemplateItem _named(List<RenovationTemplateItem> items, String part) =>
    items.singleWhere((i) => i.name.contains(part));

String _formula(
  List<RenovationTemplateItem> items,
  RenovationTemplateItem item,
  SiteDetails room, {
  FunctionalCounts? counts,
}) {
  final takeoff = SiteTakeoff.from(room);
  return BomQuantityEstimator.getFormulaString(
    item: item,
    areaSqm: takeoff.floorSqm,
    currentQty: item.defaultQuantity,
    bom: items,
    takeoff: takeoff,
    counts: counts,
  );
}

void main() {
  group('run 1: tiles use the measured area plus 8% cutting waste', () {
    final items = _estimate('Bathroom Renovation', 'retile_only', _roomA);
    final floor =
        items.singleWhere((i) => classifyMaterial(i) == MaterialKind.floorTile);
    final wall =
        items.singleWhere((i) => classifyMaterial(i) == MaterialKind.wallTile);

    test('floor tiles default to 600 × 600 and wall tiles to 300 × 600', () {
      expect(floor.size, '600x600');
      expect(wall.size, '300x600');
    });

    test('floor: 3.0 sq.m ÷ 0.36 × 1.08 = 9.00 → 9 pcs', () {
      // 9 exactly on paper. Floating point made it 9.000000000000002, and a
      // plain ceil turned that into 10.
      expect(floor.defaultQuantity, 9);
      expect(_formula(items, floor, _roomA), contains('3.0 sq.m ÷ (0.6 m × 0.6 m = 0.36 sq.m per tile)'));
      expect(_formula(items, floor, _roomA), contains('× 1.08 waste = 9 pcs'));
    });

    test('walls: (16.8 − 1.47 − 0.36) = 14.97 sq.m ÷ 0.18 × 1.08 = 89.82 → 90',
        () {
      expect(wall.defaultQuantity, 90);
      final formula = _formula(items, wall, _roomA);
      // The note shows the figure a hand computation gets, not "15.0".
      expect(formula, contains('less 1.83 sq.m of doors and windows'));
      expect(formula, contains('14.97 sq.m wall ÷ (0.3 m × 0.6 m = 0.18 sq.m per tile)'));
      expect(formula, contains('× 1.08 waste = 89.82 → 90 pcs'));
    });
  });

  group('runs 2 and 3: wiring', () {
    for (final outlets in [3, 4]) {
      final counts = FunctionalCounts(outlets: outlets, switches: 1, lights: 1);
      final items = _estimate('Living Room Renovation', 'rewire', _roomB,
          counts: counts);

      test('$outlets outlets: heavy-appliance wiring is 8.0 m × 1.08 → 9 m', () {
        final appliance = _named(items, '5.5 mm');
        expect(appliance.defaultQuantity, 9);
        expect(_formula(items, appliance, _roomB, counts: counts),
            contains('8.0 m × 1.08 waste = 8.64 → 9 m'));
      });

      test('$outlets outlets: outlet wire is outlets × 3.0 m × 1.08, rounded up',
          () {
        // 3 × 3.0 × 1.08 = 9.72 → 10 m; 4 × 3.0 × 1.08 = 12.96 → 13 m.
        expect(_named(items, '3.5 mm').defaultQuantity, outlets == 3 ? 10 : 13);
      });
    }

    test('typing 4 outlets on the review re-sizes the wiring that follows them',
        () {
      const three = FunctionalCounts(outlets: 3, switches: 1, lights: 1);
      final items =
          _estimate('Living Room Renovation', 'rewire', _roomB, counts: three);
      final outletLine = _named(items, 'Convenience Outlet');
      final edited = [
        for (final item in items)
          identical(item, outletLine) ? item.copyWith(defaultQuantity: 4) : item,
      ];

      final four =
          BomQuantityEstimator.countsAfterEdit(outletLine, 4, three)!;
      expect(four.outlets, 4);
      final settled = BomQuantityEstimator.requantifyWiring(edited, four);

      expect(_named(settled, '3.5 mm').defaultQuantity, 13);
      // 4 outlets + 1 switch + 1 light, one box each.
      expect(_named(settled, 'Utility Box').defaultQuantity, 6);
      // (12 + 5) m of circuit wire ÷ 3 m lengths = 5.67 → 6.
      expect(_named(settled, 'Electrical Conduit').defaultQuantity, 6);
      // The appliance run and the typed line itself are left alone.
      expect(_named(settled, '5.5 mm').defaultQuantity, 9);
      expect(_named(settled, 'Convenience Outlet').defaultQuantity, 4);
      expect(_named(settled, 'Electrical Tape').defaultQuantity,
          _named(items, 'Electrical Tape').defaultQuantity);
    });

    test('a line that is not a device count changes no counts', () {
      const counts = FunctionalCounts(outlets: 3, switches: 1, lights: 1);
      final items =
          _estimate('Living Room Renovation', 'rewire', _roomB, counts: counts);
      expect(
          BomQuantityEstimator.countsAfterEdit(
              _named(items, 'Electrical Tape'), 5, counts),
          isNull);
    });
  });

  group('run 3 on the review screen', () {
    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      Future<void> load(String family, String asset) =>
          (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      const poppins = 'assets/fonts/Poppins-Light.ttf';
      await load('Poppins', poppins);
      for (var weight = 100; weight <= 900; weight += 100) {
        await load('Poppins_$weight', poppins);
      }
      await load('Poppins_regular', poppins);
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    testWidgets('typing 4 outlets turns 10 m of outlet wire into 13 m',
        (tester) async {
      // Tall enough that the lazily built list lays out every line at once.
      tester.view.physicalSize = const Size(390, 4000) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      const counts = FunctionalCounts(outlets: 3, switches: 1, lights: 1);
      final catalogue =
          RenovationTemplatesCatalog.workCatalogueFor('Living Room Renovation');
      final ticked = catalogue.packageById('rewire')!.itemIds.toSet();
      final takeoff = SiteTakeoff.from(_roomB);
      final items = _estimate('Living Room Renovation', 'rewire', _roomB,
          counts: counts);

      await tester.pumpWidget(MaterialApp(
        home: CostEstimationScreen(
          projectName: 'Living Room Renovation',
          template: catalogue.templateFor(ticked).copyWithItems(items),
          projectAreaSqm: takeoff.floorSqm,
          scope: RenovationScope.functional,
          takeoff: takeoff,
          counts: counts,
        ),
      ));
      await tester.pump();

      // The quantity box on each line, keyed by what it shows. The outlet
      // line is the only one at 3; the outlet wire the only one at 10.
      Finder box(String qty) => find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == qty);
      expect(box('3'), findsOneWidget);
      expect(box('10'), findsOneWidget);

      await tester.enterText(box('3'), '4');
      await tester.pump();

      expect(box('10'), findsNothing);
      expect(box('13'), findsOneWidget);
    });

    testWidgets('a fractional quantity shows, and is kept, exactly',
        (tester) async {
      tester.view.physicalSize = const Size(390, 4000) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // Room A with the old floor tiles hacked off: the new 25 mm screed
      // needs 3.0 × 0.025 = 0.075 cu.m of sand, ordered as 0.08.
      final room = _roomA.copyWith(removeOldTiles: true);
      final catalogue =
          RenovationTemplatesCatalog.workCatalogueFor('Bathroom Renovation');
      final ticked = catalogue.packageById('retile_only')!.itemIds.toSet();
      final takeoff = SiteTakeoff.from(room);
      final items = _estimate('Bathroom Renovation', 'retile_only', room);
      expect(_named(items, 'Washed Sand').defaultQuantity, 0.08);
      // 0.075 cu.m × 12.0 bags = 0.9 → 1 bag of cement.
      expect(_named(items, 'Portland Cement').defaultQuantity, 1);

      await tester.pumpWidget(MaterialApp(
        home: CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: catalogue.templateFor(ticked).copyWithItems(items),
          projectAreaSqm: takeoff.floorSqm,
          takeoff: takeoff,
        ),
      ));
      await tester.pump();

      // The box is what is saved and posted. It used to show one decimal,
      // so 0.08 cu.m went to the shops as 0.1.
      bool shows(String text) => find
          .byWidgetPredicate(
              (w) => w is TextField && w.controller?.text == text)
          .evaluate()
          .isNotEmpty;
      expect(shows('0.08'), isTrue);
      expect(shows('0.1'), isFalse);
      // Every box shows its line's quantity exactly.
      final boxes = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text)
          .toList();
      for (final item in items) {
        expect(boxes, contains(PhRenovationRates.numText(item.defaultQuantity)),
            reason: item.name);
      }
    });

    testWidgets('a list that paints nothing names no paint area',
        (tester) async {
      tester.view.physicalSize = const Size(390, 4000) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // The AI's picks on the emulator for "replace the cracked floor tiles
      // and waterproof the floor; the wall tiles are fine". The header read
      // "walls 16.8 sq.m · paint 16.8 sq.m" with no paint on the list.
      final catalogue =
          RenovationTemplatesCatalog.workCatalogueFor('Bathroom Renovation');
      const ticked = {'retile_floor', 'waterproof_floor'};
      final types = catalogue.typesOf(ticked);
      const room = SiteDetails(
        job: RoomJob.wetRoom,
        lengthM: 2.0,
        widthM: 1.5,
        heightM: 2.4,
      );
      final takeoff = SiteTakeoff.from(room);
      final items = BomQuantityEstimator.scaleTemplate(
        template: catalogue.templateFor(ticked),
        areaSqm: takeoff.floorSqm,
        scope: types.primary,
        types: types,
        takeoff: takeoff,
      );

      await tester.pumpWidget(MaterialApp(
        home: CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: catalogue.templateFor(ticked).copyWithItems(items),
          projectAreaSqm: takeoff.floorSqm,
          takeoff: takeoff,
        ),
      ));
      await tester.pump();

      expect(
        find.textContaining(
            'Measured room: Floor 3.0 sq.m · walls 16.8 sq.m. Every quantity'),
        findsOneWidget,
      );
    });

    testWidgets('the list opens in plain words that match how it was sized',
        (tester) async {
      tester.view.physicalSize = const Size(390, 4000) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final catalogue =
          RenovationTemplatesCatalog.workCatalogueFor('Bathroom Renovation');
      final ticked = catalogue.packageById('retile_only')!.itemIds.toSet();
      final takeoff = SiteTakeoff.from(_roomA);
      final items = _estimate('Bathroom Renovation', 'retile_only', _roomA);

      await tester.pumpWidget(MaterialApp(
        home: CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: catalogue.templateFor(ticked).copyWithItems(items),
          projectAreaSqm: takeoff.floorSqm,
          takeoff: takeoff,
        ),
      ));
      await tester.pump();

      // It said "Reference package — quantities scaled from area" over a list
      // sized from the measured room, as the line under it says.
      expect(find.textContaining('Here is your material list.'), findsOneWidget);
      expect(find.textContaining('Reference package'), findsNothing);
      expect(find.textContaining('scaled from'), findsNothing);
      expect(
        find.textContaining('Every quantity is sized from these measurements'),
        findsOneWidget,
      );
    });
  });

  test('run 4: the structural note names the measured floor', () {
    expect(
      BomQuantityEstimator.structuralNoteFor(SiteTakeoff.from(_roomA)),
      startsWith('Structural quantities use the measured 3.0 sq.m of floor '
          'for a 100 mm slab'),
    );
  });

  group('run 5: supplies are added for the work', () {
    test('a tile job gets tile cross spacers', () {
      final items = _estimate('Bathroom Renovation', 'retile_only', _roomA);
      expect(items.where((i) => i.name.contains('Tile Cross Spacers')),
          hasLength(1));
    });

    test('a painting job gets sandpaper and a roller set', () {
      final catalogue =
          RenovationTemplatesCatalog.workCatalogueFor('Interior Painting');
      final ticked = catalogue.packageById('paint_only')!.itemIds.toSet();
      final items = BomQuantityEstimator.scaleTemplate(
        template: catalogue.templateFor(ticked),
        areaSqm: 12,
        scope: RenovationScope.cosmetic,
      );
      expect(items.where((i) => i.name.contains('Assorted Sandpaper')),
          hasLength(1));
      expect(items.where((i) => i.name.contains('Paint Roller Set')),
          hasLength(1));
    });
  });

  group('rounding up matches a hand computation', () {
    test('a whole result stays whole', () {
      expect(PhRenovationRates.calculateFloorTilePieces(3.0, '600x600'), 9);
      // 3.0 ÷ 0.09 × 1.08 = 36 exactly; it used to come out 37.
      expect(PhRenovationRates.calculateFloorTilePieces(3.0, '300x300'), 36);
    });

    test('a real fraction still rounds up', () {
      expect(PhRenovationRates.roundUp(8.64), 9);
      expect(PhRenovationRates.roundUp(89.82), 90);
      expect(PhRenovationRates.roundUp(9.000000000000002), 9);
    });

    test('areas print exactly, with one decimal when that is exact', () {
      expect(PhRenovationRates.areaText(3.0), '3.0');
      expect(PhRenovationRates.areaText(16.8), '16.8');
      expect(PhRenovationRates.areaText(14.97), '14.97');
      expect(PhRenovationRates.areaText(1.83), '1.83');
    });
  });
}
