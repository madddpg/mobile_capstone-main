import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

void main() {
  group('what a description sets', () {
    test('no wall tiles is read as no wall tiles, not as wall tiles', () {
      final hints = parseSiteHints('Repaint the walls, no wall tiles please');
      expect(hints.wallTileHeight, WallTileHeight.none);
      expect(hints.applied, contains('no wall tiles'));
    });

    test('half-wall and full-height are told apart', () {
      expect(
        parseSiteHints('tile the walls half height').wallTileHeight,
        WallTileHeight.wainscot,
      );
      expect(
        parseSiteHints('tiles from floor to ceiling').wallTileHeight,
        WallTileHeight.full,
      );
    });

    test('a kitchen backsplash is its own choice', () {
      expect(
        parseSiteHints('add a backsplash above the counter').wallTileHeight,
        WallTileHeight.backsplash,
      );
    });

    test('removing the old floor tiles is picked up', () {
      expect(parseSiteHints('remove the old tiles first').removeOldTiles, isTrue);
      expect(parseSiteHints('tanggalin ang tiles sa sahig').removeOldTiles, isTrue);
    });

    test('keeping the old tiles is picked up too, and wins over removing', () {
      expect(
        parseSiteHints('just tile over the old tiles').removeOldTiles,
        isFalse,
      );
    });

    test('the ceiling is only painted when asked for', () {
      expect(parseSiteHints('repaint the ceiling as well').paintCeiling, isTrue);
      expect(
        parseSiteHints('paint the walls only, do not paint the ceiling')
            .paintCeiling,
        isFalse,
      );
      expect(parseSiteHints('retile the floor').paintCeiling, isNull);
    });
  });

  group('when it says nothing', () {
    test('an empty description sets nothing', () {
      final hints = parseSiteHints('   ');
      expect(hints.isEmpty, isTrue);
      expect(hints.wallTileHeight, isNull);
      expect(hints.removeOldTiles, isNull);
      expect(hints.paintCeiling, isNull);
    });

    test('a description about something else sets nothing', () {
      final hints = parseSiteHints('I want it finished before fiesta');
      expect(hints.isEmpty, isTrue);
    });

    test('silence is not a decision: nulls leave the defaults alone', () {
      final hints = parseSiteHints('replace the floor tiles with 600x600');
      expect(hints.wallTileHeight, isNull);
      expect(hints.paintCeiling, isNull);
    });
  });

  test('what was read is listed back for the builder to check', () {
    final hints = parseSiteHints(
      'No wall tiles, remove the old tiles, and repaint the ceiling',
    );
    expect(hints.applied, hasLength(3));
    expect(hints.isEmpty, isFalse);
  });
}
