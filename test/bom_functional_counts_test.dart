import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// A wiring job is sized by the devices it installs, not by the room they sit
/// in. These lock that in: the same counts must give the same wiring in a
/// small bedroom and a large one, and changing a count must change the BOM.

RenovationTemplate _functional(String type) =>
    RenovationTemplatesCatalog.forProject(type, RenovationScope.functional);

List<RenovationTemplateItem> _bom(
  String type,
  SiteDetails details, {
  FunctionalCounts? counts,
}) {
  final takeoff = SiteTakeoff.from(details);
  return BomQuantityEstimator.scaleTemplate(
    template: _functional(type),
    areaSqm: takeoff.floorSqm,
    scope: RenovationScope.functional,
    takeoff: takeoff,
    counts: counts,
  );
}

/// The one line whose name contains [needle].
RenovationTemplateItem? _line(
  List<RenovationTemplateItem> items,
  String needle,
) {
  final matches =
      items.where((i) => i.name.toLowerCase().contains(needle.toLowerCase()));
  return matches.isEmpty ? null : matches.first;
}

double _qty(List<RenovationTemplateItem> items, String needle) =>
    _line(items, needle)!.defaultQuantity;

// A 3.0 × 3.0 m bedroom, 2.7 m high: 9 sq.m of floor.
const _smallRoom = SiteDetails(
  job: RoomJob.dryRoom,
  lengthM: 3.0,
  widthM: 3.0,
  heightM: 2.7,
);

// The same room job at 6.0 × 5.0 m: 30 sq.m, more than three times the floor.
const _largeRoom = SiteDetails(
  job: RoomJob.dryRoom,
  lengthM: 6.0,
  widthM: 5.0,
  heightM: 2.7,
);

const _threeOutlets =
    FunctionalCounts(outlets: 3, switches: 1, lights: 1);

void main() {
  group('FunctionalCounts', () {
    test('counts every device that needs a utility box', () {
      expect(const FunctionalCounts(outlets: 3, switches: 2, lights: 1).deviceCount, 6);
    });

    test('is empty only when nothing is installed', () {
      expect(FunctionalCounts.none.isEmpty, isTrue);
      expect(const FunctionalCounts(lights: 1).isEmpty, isFalse);
    });

    test('a kitchen starts with more outlets than a bathroom', () {
      final kitchen = FunctionalCounts.defaultsFor(RoomJob.kitchen);
      final wet = FunctionalCounts.defaultsFor(RoomJob.wetRoom);
      expect(kitchen.outlets, greaterThan(wet.outlets));
    });

    test('round-trips through a map', () {
      const counts = FunctionalCounts(outlets: 4, switches: 2, lights: 3);
      expect(FunctionalCounts.fromMap(counts.toMap()), counts);
    });
  });

  group('device lines follow the counts', () {
    final bom = _bom('Bedroom Renovation', _smallRoom, counts: _threeOutlets);

    test('outlets, switches and lights are exactly what was asked for', () {
      expect(_qty(bom, 'Convenience Outlet'), 3);
      expect(_qty(bom, 'Light Switch'), 1);
      expect(_qty(bom, 'LED Ceiling Light'), 1);
    });

    test('every device gets its own utility box', () {
      expect(_qty(bom, 'Utility Box'), 5);
    });

    test('a device set to zero leaves the list entirely', () {
      final noLights = _bom(
        'Bedroom Renovation',
        _smallRoom,
        counts: const FunctionalCounts(outlets: 2, switches: 1),
      );
      expect(_line(noLights, 'LED Ceiling Light'), isNull);
      // The switch is still wanted, so the lighting circuit stays.
      expect(_line(noLights, '2.0 mm'), isNotNull);
    });
  });

  group('the room no longer decides the wiring', () {
    test('the same counts give the same wire in a 9 and a 30 sq.m room', () {
      final small = _bom('Bedroom Renovation', _smallRoom, counts: _threeOutlets);
      final large = _bom('Bedroom Renovation', _largeRoom, counts: _threeOutlets);

      for (final needle in ['3.5 mm', '2.0 mm', 'Conduit', 'Utility Box']) {
        expect(_qty(large, needle), _qty(small, needle),
            reason: '$needle should not grow with the floor area');
      }
    });

    test('asking for more outlets does grow the outlet circuit', () {
      final few = _bom('Bedroom Renovation', _smallRoom,
          counts: const FunctionalCounts(outlets: 2, switches: 1, lights: 1));
      final many = _bom('Bedroom Renovation', _smallRoom,
          counts: const FunctionalCounts(outlets: 8, switches: 1, lights: 1));

      expect(_qty(many, '3.5 mm'), greaterThan(_qty(few, '3.5 mm')));
      expect(_qty(many, 'Convenience Outlet'), 8);
      // The lighting circuit is untouched by outlet count.
      expect(_qty(many, '2.0 mm'), _qty(few, '2.0 mm'));
    });

    test('without counts the old area-based rates still apply', () {
      final small = _bom('Bedroom Renovation', _smallRoom);
      final large = _bom('Bedroom Renovation', _largeRoom);
      expect(_qty(large, '3.5 mm'), greaterThan(_qty(small, '3.5 mm')));
    });
  });

  group('wire and conduit', () {
    test('conduit and couplings come from the combined run, in 3 m lengths', () {
      final bom = _bom('Bedroom Renovation', _smallRoom, counts: _threeOutlets);
      // 3 outlets × 3.0 m = 9.0 m, plus (1 switch + 1 light) × 2.5 m = 5.0 m.
      // 14.0 m of raceway over 3 m lengths = 5 pieces.
      expect(_qty(bom, 'Electrical Conduit'), 5);
      expect(_qty(bom, 'Conduit Coupling'), 5);
    });

    test('a breaker and tape stay fixed, however many devices there are', () {
      final few = _bom('Bedroom Renovation', _smallRoom,
          counts: const FunctionalCounts(outlets: 1, switches: 1, lights: 1));
      final many = _bom('Bedroom Renovation', _smallRoom,
          counts: const FunctionalCounts(outlets: 9, switches: 4, lights: 4));
      expect(_qty(many, 'Circuit Breaker'), _qty(few, 'Circuit Breaker'));
      expect(_qty(many, 'Electrical Tape'), _qty(few, 'Electrical Tape'));
    });

    test('the kitchen appliance circuit is one fixed run, not an area rate',
        () {
      const kitchen = SiteDetails(
        job: RoomJob.kitchen,
        lengthM: 3.0,
        widthM: 2.5,
        heightM: 2.7,
      );
      const bigKitchen = SiteDetails(
        job: RoomJob.kitchen,
        lengthM: 6.0,
        widthM: 5.0,
        heightM: 2.7,
      );
      final small = _bom('Kitchen Renovation', kitchen, counts: _threeOutlets);
      final large =
          _bom('Kitchen Renovation', bigKitchen, counts: _threeOutlets);
      expect(_qty(small, '5.5 mm'), _qty(large, '5.5 mm'));
    });
  });

  group('the formula says what it actually did', () {
    final bom = _bom('Bedroom Renovation', _smallRoom, counts: _threeOutlets);

    String formulaFor(String needle) => BomQuantityEstimator.getFormulaString(
          item: _line(bom, needle)!,
          areaSqm: 9.0,
          currentQty: _qty(bom, needle),
          bom: bom,
          counts: _threeOutlets,
        );

    test('a device line cites the count, not a floor area', () {
      final formula = formulaFor('Convenience Outlet');
      expect(formula, contains('3 outlets'));
      expect(formula, isNot(contains('sq.m x standard rate')));
    });

    test('the outlet circuit shows its run-length assumption', () {
      final formula = formulaFor('3.5 mm');
      expect(formula, contains('3 outlets'));
      expect(formula, contains('3.0 m per run'));
    });

    test('utility boxes are shown as one per device', () {
      expect(formulaFor('Utility Box'), contains('one utility box per device'));
    });
  });

  group('jobs with nothing to count are left alone', () {
    test('a functional bathroom is plumbing only and keeps fixed counts', () {
      const cr = SiteDetails(
        job: RoomJob.wetRoom,
        lengthM: 2.0,
        widthM: 1.5,
        heightM: 2.4,
      );
      final bom = _bom('Bathroom Renovation', cr);
      expect(
        bom.any((i) => classifyMaterial(i) == MaterialKind.electrical),
        isFalse,
        reason: 'a bathroom rough-in has no wiring to count',
      );
    });
  });
}
