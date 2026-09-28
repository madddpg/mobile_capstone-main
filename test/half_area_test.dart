import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// A half job is the opposite of a partial one: the builder measures the whole
/// room once, and every surface the materials are sized from is half of it.

// A 3.0 x 2.4 m bathroom with its usual door and window, tiled full height.
final _wholeBathroom = SiteDetails.defaultsFor(RoomJob.wetRoom)
    .copyWith(lengthM: 3.0, widthM: 2.4);

final _halfBathroom = _wholeBathroom.copyWith(half: true);

List<RenovationTemplateItem> _bom(SiteDetails details) {
  final takeoff = SiteTakeoff.from(details);
  return BomQuantityEstimator.scaleTemplate(
    template: RenovationTemplatesCatalog.forProject(
        'Bathroom Renovation', RenovationScope.cosmetic),
    areaSqm: takeoff.floorSqm,
    scope: RenovationScope.cosmetic,
    takeoff: takeoff,
  );
}

double _qtyOf(List<RenovationTemplateItem> items, MaterialKind kind) =>
    items.where((i) => classifyMaterial(i) == kind).first.defaultQuantity;

void main() {
  group('every surface is half of the whole room', () {
    final whole = SiteTakeoff.from(_wholeBathroom);
    final half = SiteTakeoff.from(_halfBathroom);

    test('floor, walls, tiles, paint, skirting and waterproofing', () {
      expect(half.floorSqm, closeTo(whole.floorSqm / 2, 0.01));
      expect(half.netWallSqm, closeTo(whole.netWallSqm / 2, 0.01));
      expect(half.wallTileSqm, closeTo(whole.wallTileSqm / 2, 0.01));
      expect(half.paintSqm, closeTo(whole.paintSqm / 2, 0.01));
      expect(half.skirtingM, closeTo(whole.skirtingM / 2, 0.01));
      expect(half.waterproofingSqm, closeTo(whole.waterproofingSqm / 2, 0.01));
    });

    test('a kitchen counter is halved too', () {
      final kitchen = SiteDetails.defaultsFor(RoomJob.kitchen)
          .copyWith(lengthM: 3.0, widthM: 2.4, counterLengthM: 2.5);
      final wholeKitchen = SiteTakeoff.from(kitchen);
      final halfKitchen = SiteTakeoff.from(kitchen.copyWith(half: true));
      expect(halfKitchen.countertopSqm,
          closeTo(wholeKitchen.countertopSqm / 2, 0.01));
    });

    test('a full room is not halved', () {
      expect(whole.floorSqm, closeTo(7.2, 0.01));
    });
  });

  group('the arithmetic stays readable', () {
    test('a line shows the whole room, then the half it is sized from', () {
      final line = SiteTakeoff.from(_halfBathroom).floorLine;
      expect(line, contains('3.00 × 2.40 m = 7.2 sq.m'));
      expect(line, endsWith('→ half: 3.6 sq.m'));
    });

    test('a full room reads exactly as before', () {
      expect(SiteTakeoff.from(_wholeBathroom).floorLine,
          'Floor: 3.00 × 2.40 m = 7.2 sq.m');
    });

    test('the summary says it is half of the room', () {
      expect(SiteTakeoff.from(_halfBathroom).summary,
          endsWith('(half of the room)'));
      expect(SiteTakeoff.from(_wholeBathroom).summary,
          isNot(contains('half of the room')));
    });
  });

  group('a saved estimate keeps it', () {
    test('half survives saving and reopening', () {
      final reopened = SiteDetails.fromMap(_halfBathroom.toMap())!;
      expect(reopened.half, isTrue);
    });

    test('a full room saves no half key', () {
      expect(_wholeBathroom.toMap().containsKey('half'), isFalse);
      expect(SiteDetails.fromMap(_wholeBathroom.toMap())!.half, isFalse);
    });
  });

  group('quantities come from the half', () {
    test('a half retile buys less tile than the whole room', () {
      expect(
        _qtyOf(_bom(_halfBathroom), MaterialKind.floorTile),
        lessThan(_qtyOf(_bom(_wholeBathroom), MaterialKind.floorTile)),
      );
    });

    test('the floor tile count is sized from the halved floor', () {
      final takeoff = SiteTakeoff.from(_halfBathroom);
      final line = _bom(_halfBathroom)
          .firstWhere((i) => classifyMaterial(i) == MaterialKind.floorTile);
      expect(
        line.defaultQuantity,
        BomQuantityEstimator.estimateQuantity(
          item: line,
          areaSqm: takeoff.floorSqm,
          takeoff: takeoff,
        ),
      );
    });
  });
}
