import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// An L-shaped room used to be entered as "the nearest rectangle", which
/// overstated its floor. It is now measured the way a foreman measures it:
/// each wall in turn, with the floor split into rectangles and added up.

// A 5.0 x 4.0 m room with a 2.0 x 1.5 m corner taken out of it.
//
// Walked from the bottom-left: 5.0 across, 4.0 up the right, 3.0 back along
// the top, 1.5 down into the notch, 2.0 across it, 2.5 down the left side.
const _lShaped = SiteDetails(
  job: RoomJob.dryRoom,
  lengthM: 0,
  widthM: 0,
  heightM: 2.7,
  irregular: IrregularRoom(
    wallRunsM: [5.0, 4.0, 3.0, 1.5, 2.0, 2.5],
    floorSqm: 17.0, // 20.0 less the 3.0 sq.m notch
  ),
);

/// The bounding rectangle the app used to ask for instead.
const _nearestRectangle = SiteDetails(
  job: RoomJob.dryRoom,
  lengthM: 5.0,
  widthM: 4.0,
  heightM: 2.7,
);

void main() {
  group('an irregular room is measured, not derived', () {
    test('the floor is what was measured, not length x width', () {
      expect(SiteTakeoff.from(_lShaped).floorSqm, closeTo(17.0, 0.01));
    });

    test('the perimeter is the walls added up', () {
      expect(SiteTakeoff.from(_lShaped).perimeterM, closeTo(18.0, 0.01));
    });

    test('the measured floor area is the one quantities use', () {
      expect(_lShaped.measuredFloorSqm, 17.0);
      expect(_nearestRectangle.measuredFloorSqm, 20.0);
    });
  });

  group('what the nearest rectangle got wrong', () {
    test('it overstated the floor by the notch, 3 sq.m', () {
      final l = SiteTakeoff.from(_lShaped);
      final box = SiteTakeoff.from(_nearestRectangle);
      expect(box.floorSqm - l.floorSqm, closeTo(3.0, 0.01));
    });

    // Worth stating: for a room made by cutting a corner out of a rectangle,
    // the walls happen to come to the same length. The floor does not. A room
    // with a recess or a bay differs on both, which the next test covers.
    test('but it happened to get the walls right for this shape', () {
      expect(
        SiteTakeoff.from(_lShaped).perimeterM,
        closeTo(SiteTakeoff.from(_nearestRectangle).perimeterM, 0.01),
      );
    });

    test('a room with a recess differs on the walls too', () {
      const withRecess = SiteDetails(
        job: RoomJob.dryRoom,
        lengthM: 0,
        widthM: 0,
        heightM: 2.7,
        irregular: IrregularRoom(
          wallRunsM: [5.0, 4.0, 2.0, 1.0, 1.0, 1.0, 2.0, 4.0],
          floorSqm: 21.0,
        ),
      );
      expect(SiteTakeoff.from(withRecess).perimeterM, closeTo(20.0, 0.01));
      expect(
        SiteTakeoff.from(withRecess).perimeterM,
        greaterThan(SiteTakeoff.from(_nearestRectangle).perimeterM),
      );
    });
  });

  group('everything downstream follows from those two figures', () {
    test('wall area uses the measured perimeter', () {
      final takeoff = SiteTakeoff.from(_lShaped);
      expect(takeoff.grossWallSqm, closeTo(18.0 * 2.7, 0.01));
    });

    test('a painted ceiling uses the measured floor', () {
      const painted = SiteDetails(
        job: RoomJob.dryRoom,
        lengthM: 0,
        widthM: 0,
        heightM: 2.7,
        paintCeiling: true,
        irregular: IrregularRoom(
          wallRunsM: [5.0, 4.0, 3.0, 1.5, 2.0, 2.5],
          floorSqm: 17.0,
        ),
      );
      expect(SiteTakeoff.from(painted).ceilingSqm, closeTo(17.0, 0.01));
    });

    test('skirting runs the measured perimeter less the doorways', () {
      const withDoor = SiteDetails(
        job: RoomJob.dryRoom,
        lengthM: 0,
        widthM: 0,
        heightM: 2.7,
        doors: [Opening(widthM: 0.80, heightM: 2.10)],
        irregular: IrregularRoom(
          wallRunsM: [5.0, 4.0, 3.0, 1.5, 2.0, 2.5],
          floorSqm: 17.0,
        ),
      );
      expect(SiteTakeoff.from(withDoor).skirtingM, closeTo(17.2, 0.01));
    });
  });

  group('checking the measurements', () {
    test('a room needs at least three walls to enclose it', () {
      const twoWalls = SiteDetails(
        job: RoomJob.dryRoom,
        lengthM: 0,
        widthM: 0,
        heightM: 2.7,
        irregular: IrregularRoom(wallRunsM: [5.0, 4.0], floorSqm: 17.0),
      );
      expect(
        twoWalls.problems().any((p) => p.contains('at least three')),
        isTrue,
      );
    });

    test('a floor area is required', () {
      const noFloor = SiteDetails(
        job: RoomJob.dryRoom,
        lengthM: 0,
        widthM: 0,
        heightM: 2.7,
        irregular: IrregularRoom(wallRunsM: [5.0, 4.0, 3.0], floorSqm: 0),
      );
      expect(
        noFloor.problems().any((p) => p.contains('floor area')),
        isTrue,
      );
    });

    test('length and width are not asked for once walls are given', () {
      // Both are zero above, which would fail the rectangle check.
      expect(_lShaped.problems(), isEmpty);
    });

    test('a rectangle is still checked as a rectangle', () {
      const tooSmall = SiteDetails(
        job: RoomJob.dryRoom,
        lengthM: 0.1,
        widthM: 4.0,
        heightM: 2.7,
      );
      expect(
        tooSmall.problems().any((p) => p.contains('room length')),
        isTrue,
      );
    });
  });

  group('what the shop reads', () {
    test('the floor line says it was measured, and how many walls', () {
      final line = SiteTakeoff.from(_lShaped).floorLine;
      expect(line, contains('17.0 sq.m measured'));
      expect(line, contains('6 walls'));
    });

    test('a rectangle still shows its length and width', () {
      expect(SiteTakeoff.from(_nearestRectangle).floorLine, contains('×'));
    });

    test('round-trips through a map', () {
      final restored = SiteDetails.fromMap(_lShaped.toMap());
      expect(restored!.irregular, _lShaped.irregular);
      expect(SiteTakeoff.from(restored).floorSqm, closeTo(17.0, 0.01));
    });

    test('an estimate saved before this existed reads as a rectangle', () {
      final map = Map<String, dynamic>.from(_nearestRectangle.toMap());
      expect(map.containsKey('irregular'), isFalse);
      expect(SiteDetails.fromMap(map)!.irregular, isNull);
    });
  });
}
