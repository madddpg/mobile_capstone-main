import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

// 20 sq.m of floor under a roof at about 30° pitch = 23 sq.m of roof.
const _area = 20.0;

List<RenovationTemplateItem> _roof(String style) =>
    BomQuantityEstimator.scaleTemplate(
      template: RenovationTemplatesCatalog.threeForType('Roof Repair')
          .firstWhere((t) => t.style == style),
      areaSqm: _area,
    );

RenovationTemplateItem _named(List<RenovationTemplateItem> items, String part) =>
    items.singleWhere((i) => i.name.toLowerCase().contains(part));

String _formula(List<RenovationTemplateItem> items, RenovationTemplateItem item) =>
    BomQuantityEstimator.getFormulaString(
      item: item,
      areaSqm: _area,
      currentQty: item.defaultQuantity,
      bom: items,
    );

void main() {
  group('metal roofing', () {
    final items = _roof('modern');

    test('rib-type sheets are ordered by the linear metre', () {
      final sheets = _named(items, 'rib-type');
      // 23 sq.m ÷ 1.0 m effective width × 1.10 lap = 25.3 -> 26 ln.m.
      expect(sheets.defaultQuantity, 26);
      expect(sheets.unit, 'ln.m');
      expect(classifyMaterial(sheets), MaterialKind.roofingSheet);
    });

    test('ridge, screws and sealant follow the roof area', () {
      // √20 × 1.10 = 4.9 -> 5 ln.m of ridge.
      expect(_named(items, 'ridge roll').defaultQuantity, 5);
      // 23 sq.m × 8 = 184 tekscrews.
      final screws = _named(items, 'tekscrew');
      expect(screws.defaultQuantity, 184);
      expect(classifyMaterial(screws), MaterialKind.genericConsumable);
      // 23 sq.m ÷ 15 = 1.53 -> 2 cans.
      final sealant = _named(items, 'sealant');
      expect(sealant.defaultQuantity, 2);
      expect(classifyMaterial(sealant), MaterialKind.roofSealant);
    });

    test('formulas state the slope assumption', () {
      expect(_formula(items, _named(items, 'rib-type')),
          contains('23.0 sq.m roof'));
      expect(_formula(items, _named(items, 'tekscrew')),
          contains('23.0 sq.m roof'));
      expect(_formula(items, _named(items, 'ridge roll')),
          contains('measure the actual ridge'));
    });
  });

  group('tile roofing', () {
    final items = _roof('traditional');

    test('concrete roof tiles cover the sloped area', () {
      // 23 sq.m × 10.5 pcs × 1.05 breakage = 253.6 -> 254 pcs.
      final tiles = _named(items, 'concrete roof tiles');
      expect(tiles.defaultQuantity, 254);
      expect(classifyMaterial(tiles), MaterialKind.roofingSheet);
      expect(_formula(items, tiles), contains('23.0 sq.m roof'));
    });

    test('ridge tiles and their bedding cement follow the ridge', () {
      final ridgeTiles = _named(items, 'ridge tiles');
      expect(classifyMaterial(ridgeTiles), MaterialKind.roofingSheet);
      // 5 ln.m × 3 pcs = 15.
      expect(ridgeTiles.defaultQuantity, 15);
      // 5 ln.m ÷ 6 ln.m per bag -> 1 bag.
      final cement = _named(items, 'ridge bedding');
      expect(cement.defaultQuantity, 1);
      expect(classifyMaterial(cement), MaterialKind.cementBedding);
    });

    test('a tile roof gets no floor-tile setting materials', () {
      for (final kind in const [
        MaterialKind.floorTile,
        MaterialKind.tileAdhesive,
        MaterialKind.tileGrout,
        MaterialKind.tileSpacer,
      ]) {
        expect(items.where((i) => classifyMaterial(i) == kind), isEmpty,
            reason: kind.name);
      }
    });
  });

  test('a leak patch keeps its fixed patch sheet count', () {
    expect(_named(_roof('minimalist'), 'patch sheets').defaultQuantity, 6);
  });

  test('roofing lines survive a Full Renovation scope filter', () {
    for (final template
        in RenovationTemplatesCatalog.threeForType('Roof Repair')) {
      final full = BomQuantityEstimator.scaleTemplate(
        template: template,
        areaSqm: _area,
        scope: RenovationScope.fullRenovation,
      );
      expect(full.length, greaterThanOrEqualTo(template.items.length),
          reason: template.id);
    }
  });
}
