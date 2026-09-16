import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/bom_sections.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// A measured room sizes each material from the surface it covers, instead of
/// the floor area times a guess.
RenovationTemplate _template(String type,
        [RenovationScope scope = RenovationScope.cosmetic]) =>
    RenovationTemplatesCatalog.forProject(type, scope);

List<RenovationTemplateItem> _bom(
  RenovationTemplate template,
  SiteDetails details, {
  RenovationScope scope = RenovationScope.cosmetic,
}) {
  final takeoff = SiteTakeoff.from(details);
  return BomQuantityEstimator.scaleTemplate(
    template: template,
    areaSqm: takeoff.floorSqm,
    scope: scope,
    takeoff: takeoff,
  );
}

Iterable<RenovationTemplateItem> _ofKind(
        List<RenovationTemplateItem> items, MaterialKind kind) =>
    items.where((i) => classifyMaterial(i) == kind);

RenovationTemplateItem _one(
        List<RenovationTemplateItem> items, MaterialKind kind) =>
    _ofKind(items, kind).single;

// A 2.0 × 1.5 m CR, 2.4 m high, one 0.70 × 2.10 door, one 0.60 × 0.60 vent.
// Floor 3.0 sq.m; walls 16.8 less 1.83 of openings = 14.97 sq.m.
const _bathroom = SiteDetails(
  job: RoomJob.wetRoom,
  lengthM: 2.0,
  widthM: 1.5,
  heightM: 2.4,
  doors: [Opening(widthM: 0.70, heightM: 2.10)],
  windows: [Opening(widthM: 0.60, heightM: 0.60)],
  wallTileHeight: WallTileHeight.full,
  paintCeiling: true,
);

void main() {
  final cosmeticBathroom = _template('Bathroom Renovation');

  group('a measured bathroom', () {
    final items = _bom(cosmeticBathroom, _bathroom);

    test('tiles the floor it measured and the walls less their openings', () {
      expect(_one(items, MaterialKind.floorTile).defaultQuantity,
          PhRenovationRates.calculateFloorTilePieces(3.0, '300x300'));
      expect(_one(items, MaterialKind.wallTile).defaultQuantity,
          PhRenovationRates.calculateWallTilePieces(14.97, '300x600'));
    });

    test('sets both tiled surfaces with adhesive and grout', () {
      expect(_one(items, MaterialKind.tileAdhesive).defaultQuantity,
          PhRenovationRates.calculateTileAdhesiveBags(3.0 + 14.97));
      expect(
        _one(items, MaterialKind.tileGrout).defaultQuantity,
        PhRenovationRates.groutPacksForKg(3.0 * 0.25 + 14.97 * 0.18),
      );
    });

    test('waterproofs the floor and its upturn', () {
      // 5.1 sq.m × 0.8 L × 1.08 = 4.4 → 5 L.
      expect(_one(items, MaterialKind.waterproofing).defaultQuantity, 5);
    });

    test('paints the ceiling the tiles leave bare, with a primer', () {
      expect(_one(items, MaterialKind.paintTopcoat).defaultQuantity,
          PhRenovationRates.calculatePaintWorks(3.0).topcoatGal);
      expect(_ofKind(items, MaterialKind.paintPrimer), hasLength(1));
    });

    test('each formula starts from the measurement', () {
      String formula(MaterialKind kind) {
        final item = _one(items, kind);
        return BomQuantityEstimator.getFormulaString(
          item: item,
          areaSqm: 3.0,
          currentQty: item.defaultQuantity,
          bom: items,
          takeoff: SiteTakeoff.from(_bathroom),
        );
      }

      expect(formula(MaterialKind.floorTile), startsWith('Floor: 2.00 × 1.50 m'));
      expect(formula(MaterialKind.wallTile),
          contains('less 1.8 sq.m of doors and windows'));
      expect(formula(MaterialKind.tileAdhesive),
          contains('Tiled area: 3.0 sq.m floor + 15.0 sq.m wall'));
      expect(formula(MaterialKind.paintTopcoat), startsWith('Paint: '));
      expect(formula(MaterialKind.waterproofing), startsWith('Waterproofing: '));
    });

    test('groups into floor, walls, tile setting, then the rest', () {
      final sections = sortBySection(items).map(bomSectionOf).toList();
      expect(sections.first, BomSection.floor);
      for (var i = 1; i < sections.length; i++) {
        expect(sections[i].index, greaterThanOrEqualTo(sections[i - 1].index));
      }
    });
  });

  test('no wall tiles drops the wall tile line and paints the walls instead', () {
    final items = _bom(
        cosmeticBathroom, _bathroom.copyWith(wallTileHeight: WallTileHeight.none));

    expect(_ofKind(items, MaterialKind.wallTile), isEmpty);
    expect(_one(items, MaterialKind.tileAdhesive).defaultQuantity,
        PhRenovationRates.calculateTileAdhesiveBags(3.0));
    expect(_one(items, MaterialKind.paintTopcoat).defaultQuantity,
        PhRenovationRates.calculatePaintWorks(14.97 + 3.0).topcoatGal);
  });

  test('removing old tiles adds cement and sand for a new screed', () {
    final items =
        _bom(cosmeticBathroom, _bathroom.copyWith(removeOldTiles: true));

    expect(_one(items, MaterialKind.cementBedding).defaultQuantity,
        PhRenovationRates.calculateTileBeddingMortar(3.0).cementBags);
    expect(_one(items, MaterialKind.washedSand).defaultQuantity,
        PhRenovationRates.calculateTileBeddingMortar(3.0).sandCum);
  });

  test('a painting job carries no floor finish and sizes paint from the walls', () {
    const details = SiteDetails(
      job: RoomJob.wallsOnly,
      lengthM: 3.5,
      widthM: 3.0,
      heightM: 2.7,
      doors: [Opening(widthM: 0.80, heightM: 2.10)],
      windows: [Opening(widthM: 1.20, heightM: 1.20)],
      paintCeiling: true,
    );
    final takeoff = SiteTakeoff.from(details);
    final items = _bom(_template('Wall Finishing'), details);

    expect(_ofKind(items, MaterialKind.floorTile), isEmpty);
    expect(_ofKind(items, MaterialKind.cementBedding), isEmpty);
    expect(_ofKind(items, MaterialKind.washedSand), isEmpty);
    expect(_one(items, MaterialKind.paintTopcoat).defaultQuantity,
        PhRenovationRates.calculatePaintWorks(takeoff.paintSqm).topcoatGal);
    expect(_ofKind(items, MaterialKind.paintPrimer), hasLength(1));
  });

  test('a kitchen backsplash and countertop follow the counter length', () {
    const details = SiteDetails(
      job: RoomJob.kitchen,
      lengthM: 3.0,
      widthM: 2.5,
      heightM: 2.7,
      doors: [Opening(widthM: 0.80, heightM: 2.10)],
      wallTileHeight: WallTileHeight.backsplash,
      counterLengthM: 2.4,
    );
    final items = _bom(_template('Kitchen Renovation'), details);

    expect(_one(items, MaterialKind.wallTile).defaultQuantity,
        PhRenovationRates.calculateWallTilePieces(1.44, '75x300'));
    // 2.4 m × 0.60 m = 1.44 sq.m × 1.08 = 1.56 → 2 sq.m.
    expect(
      items.singleWhere((i) => i.name == 'Granite Countertop').defaultQuantity,
      2,
    );
    expect(_ofKind(items, MaterialKind.tileAdhesive), hasLength(1));
    expect(_ofKind(items, MaterialKind.tileGrout), hasLength(1));
  });

  test('skirting runs round the room, not across its doorways', () {
    const details = SiteDetails(
      job: RoomJob.floorOnly,
      lengthM: 4.0,
      widthM: 3.0,
      heightM: 2.7,
      doors: [Opening(widthM: 0.80, heightM: 2.10, count: 2)],
    );
    final items = _bom(_template('Floor Renovation'), details);

    // 14.0 m less 1.6 m of doorways = 12.4 m × 1.05 = 13.02 → 14 lm.
    expect(items.singleWhere((i) => i.name == 'Skirting').defaultQuantity, 14);
    expect(_one(items, MaterialKind.floorTile).defaultQuantity,
        PhRenovationRates.calculateFloorTilePieces(12.0, '600x600'));
  });

  test('a swap or a new size keeps the measured basis', () {
    final takeoff = SiteTakeoff.from(_bathroom);
    final items = _bom(cosmeticBathroom, _bathroom);
    final wall = _one(items, MaterialKind.wallTile);

    final subway = BomQuantityEstimator.applyAlternative(
      item: wall,
      alternative:
          const MaterialAlternative(name: 'Subway Wall Tiles', size: '75x300'),
      areaSqm: 3.0,
      takeoff: takeoff,
    );
    expect(subway.defaultQuantity,
        PhRenovationRates.calculateWallTilePieces(14.97, '75x300'));

    final resized = BomQuantityEstimator.recalculateForSize(
      item: _one(items, MaterialKind.floorTile),
      newSize: '300x300',
      areaSqm: 3.0,
      takeoff: takeoff,
    );
    expect(resized.newQty,
        PhRenovationRates.calculateFloorTilePieces(3.0, '300x300'));
    expect(resized.formulaString, startsWith('Floor: '));

    final swapped = [
      for (final item in items) identical(item, wall) ? subway : item,
    ];
    final settled = BomQuantityEstimator.requantifyTileSetting(
        swapped, 3.0,
        takeoff: takeoff);
    expect(
      _one(settled, MaterialKind.tileGrout).defaultQuantity,
      PhRenovationRates.groutPacksForKg(3.0 * 0.25 + 14.97 * 0.30),
    );
  });

  test('a structural job builds CHB over the measured walls, not 2.2 × floor', () {
    final takeoff = SiteTakeoff.from(_bathroom);
    final items =
        _bom(_template('Bathroom Renovation', RenovationScope.structural), _bathroom,
            scope: RenovationScope.structural);

    expect(_one(items, MaterialKind.chbBlock).defaultQuantity,
        PhRenovationRates.calculateChbPieces(14.97));
    expect(BomQuantityEstimator.structuralNoteFor(takeoff),
        contains('measured 15.0 sq.m of wall'));
  });

  test('without a measured room nothing changes', () {
    final withNull = BomQuantityEstimator.scaleTemplate(
      template: cosmeticBathroom,
      areaSqm: 20,
    );
    // Walls still come from the template's 2.2 × floor.
    expect(_one(withNull, MaterialKind.wallTile).defaultQuantity,
        PhRenovationRates.calculateWallTilePieces(44, '300x600'));
    expect(_one(withNull, MaterialKind.floorTile).defaultQuantity,
        PhRenovationRates.calculateFloorTilePieces(20, '300x300'));
  });
}
