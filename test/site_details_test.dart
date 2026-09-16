import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// Measured rooms replace the old "walls are 2.2 × floor" guess. Every wall
/// and floor quantity rests on these figures, so the arithmetic is pinned.
void main() {
  // A typical Filipino CR: 2.0 × 1.5 m, 2.4 m high, one 0.70 × 2.10 door and
  // one 0.60 × 0.60 vent window.
  SiteDetails bathroom({WallTileHeight tiles = WallTileHeight.full}) =>
      SiteDetails(
        job: RoomJob.wetRoom,
        lengthM: 2.0,
        widthM: 1.5,
        heightM: 2.4,
        doors: const [Opening(widthM: 0.70, heightM: 2.10)],
        windows: const [Opening(widthM: 0.60, heightM: 0.60)],
        wallTileHeight: tiles,
        paintCeiling: true,
      );

  group('roomJobFor', () {
    test('maps the home screen renovation types to their room jobs', () {
      expect(roomJobFor('Bathroom\nRenovation'), RoomJob.wetRoom);
      expect(roomJobFor('Laundry\nRenovation'), RoomJob.wetRoom);
      expect(roomJobFor('Kitchen\nRenovation'), RoomJob.kitchen);
      expect(roomJobFor('Living Room\nRenovation'), RoomJob.dryRoom);
      expect(roomJobFor('Bedroom\nRenovation'), RoomJob.dryRoom);
      expect(roomJobFor('Dining Room\nRenovation'), RoomJob.dryRoom);
      expect(roomJobFor('Floor\nRenovation'), RoomJob.floorOnly);
      expect(roomJobFor('Interior\nPainting'), RoomJob.wallsOnly);
      expect(roomJobFor('Wall\nFinishing'), RoomJob.wallsOnly);
    });

    test('work not sized from a room keeps a plain area', () {
      expect(roomJobFor('Roof\nRepair'), isNull);
      expect(roomJobFor('Electrical Installation'), isNull);
      expect(roomJobFor('Plumbing Installation'), isNull);
    });
  });

  group('SiteTakeoff', () {
    test('a full-height tiled bathroom', () {
      final t = SiteTakeoff.from(bathroom());

      expect(t.floorSqm, 3.0);
      expect(t.perimeterM, 7.0);
      expect(t.grossWallSqm, 16.8);
      // 0.70 × 2.10 door + 0.60 × 0.60 window.
      expect(t.openingsSqm, 1.83);
      expect(t.netWallSqm, 14.97);
      expect(t.wallTileSqm, 14.97);
      // Tiles cover every wall, so only the ceiling is painted.
      expect(t.paintWallSqm, 0);
      expect(t.ceilingSqm, 3.0);
      expect(t.paintSqm, 3.0);
      // Floor plus a 0.30 m upturn round the room.
      expect(t.waterproofingSqm, 5.1);
      // Tiled walls need no skirting, so the summary leaves it out.
      expect(t.summary, isNot(contains('skirting')));
    });

    test('half-wall tiles leave the upper wall for paint', () {
      final t = SiteTakeoff.from(bathroom(tiles: WallTileHeight.wainscot));

      // 7.0 m × 1.50 m, less the doorway up to the tile line (0.70 × 1.50).
      expect(t.wallTileSqm, 9.45);
      expect(t.paintWallSqm, closeTo(14.97 - 9.45, 0.001));
    });

    test('a kitchen backsplash follows the counter, not the room', () {
      final t = SiteTakeoff.from(
        const SiteDetails(
          job: RoomJob.kitchen,
          lengthM: 3.0,
          widthM: 2.5,
          heightM: 2.7,
          doors: [Opening(widthM: 0.80, heightM: 2.10)],
          wallTileHeight: WallTileHeight.backsplash,
          counterLengthM: 2.4,
        ),
      );

      expect(t.wallTileSqm, 1.44);
      expect(t.ceilingSqm, 0);
      // 11 m × 2.7 m = 29.7, less the 1.68 door = 28.02, less the backsplash.
      expect(t.paintWallSqm, closeTo(28.02 - 1.44, 0.001));
    });

    test('a floor job measures skirting round the room, not across doorways', () {
      final t = SiteTakeoff.from(
        const SiteDetails(
          job: RoomJob.floorOnly,
          lengthM: 4.0,
          widthM: 3.0,
          heightM: 2.7,
          doors: [Opening(widthM: 0.80, heightM: 2.10, count: 2)],
        ),
      );

      expect(t.floorSqm, 12.0);
      expect(t.skirtingM, 12.4);
      expect(t.netWallSqm, 0);
      expect(t.paintSqm, 0);
    });

    test('a painting job has walls and ceiling but no floor finish', () {
      final details = SiteDetails.defaultsFor(RoomJob.wallsOnly)
          .copyWith(lengthM: 3.5, widthM: 3.0);
      final t = SiteTakeoff.from(details);

      expect(details.job.hasFloor, isFalse);
      expect(t.wallTileSqm, 0);
      expect(t.paintSqm, closeTo(t.netWallSqm + 10.5, 0.001));
    });

    test('openings larger than the walls leave no wall rather than a negative one', () {
      final t = SiteTakeoff.from(
        bathroom().copyWith(
          windows: const [Opening(widthM: 1.50, heightM: 1.20, count: 20)],
        ),
      );
      expect(t.netWallSqm, 0);
      expect(t.wallTileSqm, 0);
    });

    test('each figure explains itself', () {
      final t = SiteTakeoff.from(bathroom());
      expect(t.floorLine, 'Floor: 2.00 × 1.50 m = 3.0 sq.m');
      expect(t.wallTileLine, contains('less 1.8 sq.m of doors and windows'));
      expect(t.paintLine, 'Paint: 0.0 sq.m of wall + 3.0 sq.m of ceiling = 3.0 sq.m');
      expect(t.summary, startsWith('Floor 3.0 sq.m'));
    });
  });

  group('SiteDetails', () {
    test('the form starts without a room size, so it has to be measured', () {
      final d = SiteDetails.defaultsFor(RoomJob.wetRoom);
      expect(d.lengthM, 0);
      expect(d.widthM, 0);
      expect(d.problems(), isNotEmpty);
    });

    test('a measured room has no problems', () {
      expect(bathroom().problems(), isEmpty);
    });

    test('a ceiling height outside 2.0 to 6.0 m is refused', () {
      expect(bathroom().copyWith(heightM: 1.2).problems(), isNotEmpty);
    });

    test('a kitchen backsplash needs a counter length that fits the room', () {
      final kitchen = SiteDetails.defaultsFor(RoomJob.kitchen)
          .copyWith(lengthM: 3.0, widthM: 2.5);
      expect(kitchen.problems(), isNotEmpty);
      expect(kitchen.copyWith(counterLengthM: 2.4).problems(), isEmpty);
      expect(kitchen.copyWith(counterLengthM: 40).problems(), isNotEmpty);
    });

    test('an unusually large bathroom is flagged but allowed', () {
      final big = bathroom().copyWith(lengthM: 5, widthM: 4);
      expect(big.problems(), isEmpty);
      expect(big.warnings(), isNotEmpty);
    });

    test('survives a round trip through Firestore', () {
      final original = bathroom(tiles: WallTileHeight.wainscot)
          .copyWith(removeOldTiles: true);
      final restored = SiteDetails.fromMap(original.toMap())!;

      expect(restored.job, RoomJob.wetRoom);
      expect(restored.wallTileHeight, WallTileHeight.wainscot);
      expect(restored.removeOldTiles, isTrue);
      expect(restored.doors.single.sameSize(original.doors.single), isTrue);
      expect(SiteTakeoff.from(restored).wallTileSqm,
          SiteTakeoff.from(original).wallTileSqm);
    });
  });
}
