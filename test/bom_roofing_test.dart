import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

// 20 sq.m of floor under a roof at about 30° pitch = 23 sq.m of roof.
const _area = 20.0;

List<RenovationTemplateItem> _roof(RenovationScope scope) =>
    BomQuantityEstimator.scaleTemplate(
      template: RenovationTemplatesCatalog.forProject('Roof Repair', scope),
      areaSqm: _area,
      scope: scope,
    );

List<RenovationTemplateItem> _custom(List<RenovationTemplateItem> items) =>
    BomQuantityEstimator.scaleTemplate(
      template: RenovationTemplate(
        id: 'custom_roof',
        renovationType: 'Roof Repair',
        name: 'Custom roof',
        description: '',
        items: items,
      ),
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
  group('structural: new sheets and purlins', () {
    final items = _roof(RenovationScope.structural);

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

    test('purlins at 600 mm follow the floor area', () {
      // 0.32 lengths per sq.m × 20 × 1.08 = 6.9 -> 7 lengths.
      final purlins = _named(items, 'purlin');
      expect(purlins.defaultQuantity, 7);
      expect(classifyMaterial(purlins), MaterialKind.roofPurlin);
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

  group('cosmetic: repaint and reseal', () {
    final items = _roof(RenovationScope.cosmetic);

    test('paint covers the sloped roof, not the floor under it', () {
      // 23 sq.m × 0.04 gal = 0.92 -> 1 gal of primer.
      expect(_named(items, 'metal primer').defaultQuantity, 1);
      // 23 sq.m × 0.06 gal = 1.38 -> 2 gal of roof paint.
      final paint = _named(items, 'roof paint');
      expect(paint.defaultQuantity, 2);
      expect(_formula(items, paint), contains('23.0 sq.m roof'));
    });

    test('roof paint offers roof paints, not interior paint', () {
      final names = _named(items, 'roof paint').alternatives.map((a) => a.name);
      expect(names, isNotEmpty);
      expect(names.every((n) => n.contains('Roof Paint')), isTrue);
    });
  });

  group('functional: gutters and downspouts', () {
    final items = _roof(RenovationScope.functional);

    test('gutters run along both eaves', () {
      // 2 eaves × 5 ln.m = 10 ln.m ÷ 3 m lengths = 3.3 -> 4 pcs.
      final gutter = _named(items, 'gutter ga.24');
      expect(gutter.defaultQuantity, 4);
      expect(_formula(items, gutter), contains('measure the real eaves'));
      // 10 ln.m ÷ 0.60 m = 16.7 -> 17 brackets.
      expect(_named(items, 'bracket').defaultQuantity, 17);
    });

    test('downspouts and their elbows follow the gutter length', () {
      // 10 ln.m ÷ 9 m = 1.1 -> 2, and never fewer than 2.
      expect(_named(items, 'downspout pipe').defaultQuantity, 2);
      expect(_named(items, 'downspout elbow').defaultQuantity, 4);
    });
  });

  group('tile roofing', () {
    final items = _custom(const [
      RenovationTemplateItem(
          name: 'Concrete Roof Tiles', category: 'Roofing', unit: 'pcs',
          defaultQuantity: 1),
      RenovationTemplateItem(
          name: 'Ridge Tiles', category: 'Roofing', unit: 'pcs',
          defaultQuantity: 1),
      RenovationTemplateItem(
          name: 'Portland Cement - Ridge Bedding (40 kg)',
          category: 'Roof Installation', unit: 'bags', defaultQuantity: 1),
    ]);

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
    final items = _custom(const [
      RenovationTemplateItem(
          name: 'Patch Sheets', category: 'Roofing', unit: 'pcs',
          defaultQuantity: 6),
    ]);
    expect(_named(items, 'patch sheets').defaultQuantity, 6);
  });

  test('every roof template keeps all its lines under its own type', () {
    for (final scope in RenovationTemplatesCatalog.scopesFor('Roof Repair')) {
      final template =
          RenovationTemplatesCatalog.forProject('Roof Repair', scope);
      final scaled = BomQuantityEstimator.scaleTemplate(
        template: template,
        areaSqm: _area,
        scope: scope,
      );
      expect(scaled.length, greaterThanOrEqualTo(template.items.length),
          reason: template.id);
    }
  });
}
