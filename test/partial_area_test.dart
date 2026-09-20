import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// A partial job is measured by the part it covers, not by the room the part
/// sits in, and never by a percentage of that room. The whole space is carried
/// as context so a shop can tell "2 sq.m of a big bathroom" from "a 2 sq.m
/// bathroom".

// Retiling the shower area only: 1.2 x 1.5 m of a 3.0 x 2.5 m bathroom.
const _showerArea = SiteDetails(
  job: RoomJob.wetRoom,
  lengthM: 1.2,
  widthM: 1.5,
  heightM: 2.4,
  wallTileHeight: WallTileHeight.full,
  partial: PartialArea(
    label: 'shower area',
    totalLengthM: 3.0,
    totalWidthM: 2.5,
  ),
);

/// The same bathroom done whole.
const _wholeBathroom = SiteDetails(
  job: RoomJob.wetRoom,
  lengthM: 3.0,
  widthM: 2.5,
  heightM: 2.4,
  wallTileHeight: WallTileHeight.full,
);

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
  group('the part is what gets measured', () {
    test('floor area is the part, not the room it sits in', () {
      final takeoff = SiteTakeoff.from(_showerArea);
      expect(takeoff.floorSqm, closeTo(1.8, 0.01));
    });

    test('the whole space is carried alongside it', () {
      expect(_showerArea.partial!.totalFloorSqm, closeTo(7.5, 0.01));
    });

    test('a job with no part named carries none', () {
      expect(_wholeBathroom.partial, isNull);
      expect(_wholeBathroom.portionOfSpace, isNull);
    });
  });

  group('quantities come from the part', () {
    test('a partial retile buys far less tile than the whole room', () {
      final part = _bom(_showerArea);
      final whole = _bom(_wholeBathroom);
      expect(
        _qtyOf(part, MaterialKind.floorTile),
        lessThan(_qtyOf(whole, MaterialKind.floorTile)),
      );
    });

    test('the floor tile count is sized from the part, 1.8 sq.m', () {
      final takeoff = SiteTakeoff.from(_showerArea);
      expect(takeoff.floorSqm, closeTo(1.8, 0.01));

      final line = _bom(_showerArea)
          .firstWhere((i) => classifyMaterial(i) == MaterialKind.floorTile);
      // The same line, asked directly at the part's area, must agree: the BOM
      // has no second opinion about how big the floor is.
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

  group('the share of the space is context, never a multiplier', () {
    test('reports what fraction the part comes to', () {
      // 1.8 of 7.5 sq.m.
      expect(_showerArea.portionOfSpace, closeTo(0.24, 0.005));
    });

    test('no quantity is that fraction of the whole room', () {
      final part = _qtyOf(_bom(_showerArea), MaterialKind.floorTile);
      final whole = _qtyOf(_bom(_wholeBathroom), MaterialKind.floorTile);
      // A percentage-scaled estimate would land on 24% of the whole. The real
      // answer is sized from 1.8 sq.m and rounded up to whole tiles, so it is
      // deliberately not that number.
      expect(part, isNot(closeTo(whole * 0.24, 0.001)));
    });
  });

  group('checking the part against the space', () {
    test('a part bigger than the whole space is refused', () {
      const impossible = SiteDetails(
        job: RoomJob.wetRoom,
        lengthM: 4.0,
        widthM: 3.0,
        heightM: 2.4,
        partial: PartialArea(
          label: 'shower area',
          totalLengthM: 2.0,
          totalWidthM: 1.5,
        ),
      );
      expect(
        impossible.problems().any((p) => p.contains('cannot be bigger')),
        isTrue,
      );
    });

    test('a part with no name is refused', () {
      const unnamed = SiteDetails(
        job: RoomJob.wetRoom,
        lengthM: 1.2,
        widthM: 1.5,
        heightM: 2.4,
        partial: PartialArea(label: '  ', totalLengthM: 3.0, totalWidthM: 2.5),
      );
      expect(unnamed.problems().any((p) => p.contains('Name the part')), isTrue);
    });

    test('a properly described part passes', () {
      expect(_showerArea.problems(), isEmpty);
    });
  });

  group('what the shop reads', () {
    test('the floor line names the part and the space it sits in', () {
      final line = SiteTakeoff.from(_showerArea).floorLine;
      expect(line, contains('shower area'));
      expect(line, contains('within'));
    });

    test('a whole-room job says nothing about parts', () {
      expect(SiteTakeoff.from(_wholeBathroom).floorLine,
          isNot(contains('within')));
    });

    test('round-trips through a map', () {
      final restored = SiteDetails.fromMap(_showerArea.toMap());
      expect(restored!.partial, _showerArea.partial);
      expect(restored.lengthM, _showerArea.lengthM);
    });

    test('an estimate saved before parts existed reads as a whole room', () {
      final map = Map<String, dynamic>.from(_wholeBathroom.toMap())
        ..remove('partial');
      expect(SiteDetails.fromMap(map)!.partial, isNull);
    });
  });
}
