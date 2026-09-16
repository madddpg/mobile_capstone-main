import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

const _area = 20.0;

List<RenovationTemplateItem> _scaled(String type, String style) =>
    BomQuantityEstimator.scaleTemplate(
      template: RenovationTemplatesCatalog.threeForType(type)
          .firstWhere((t) => t.style == style),
      areaSqm: _area,
    );

List<RenovationTemplateItem> _ofKind(
  List<RenovationTemplateItem> items,
  MaterialKind kind,
) =>
    items.where((i) => classifyMaterial(i) == kind).toList();

void main() {
  test('every tiled BOM carries exactly one adhesive and one grout line', () {
    for (final type in {
      ...RenovationTemplatesCatalog.allTemplates.map((t) => t.renovationType),
      'Living Room Renovation',
    }) {
      for (final template in RenovationTemplatesCatalog.threeForType(type)) {
        for (final scope in RenovationScope.values) {
          final items = BomQuantityEstimator.scaleTemplate(
            template: template,
            areaSqm: _area,
            scope: scope,
          );
          if (!items.any(BomQuantityEstimator.affectsTileSetting)) continue;
          final reason = '${template.id} ${scope.name}';
          expect(_ofKind(items, MaterialKind.tileAdhesive), hasLength(1),
              reason: reason);
          expect(_ofKind(items, MaterialKind.tileGrout), hasLength(1),
              reason: reason);
        }
      }
    }
  });

  test('a bathroom sizes adhesive and grout from floor plus wall tile', () {
    final items = _scaled('Bathroom Renovation', 'modern');

    // 20 sq.m floor + 44 sq.m wall (2.2x) = 64 sq.m tiled.
    // Adhesive: 64 x 0.22 = 14.08 -> 15 bags.
    expect(_ofKind(items, MaterialKind.tileAdhesive).single.defaultQuantity, 15);
    // Grout: 64 x 0.18 kg = 11.52 kg -> 6 packs of 2 kg.
    final grout = _ofKind(items, MaterialKind.tileGrout).single;
    expect(grout.defaultQuantity, 6);
    expect(grout.unit, 'packs');
  });

  test('added setting lines sit right after the tiles', () {
    final items = _scaled('Bathroom Renovation', 'modern');
    final lastTile = items.lastIndexWhere(BomQuantityEstimator.affectsTileSetting);

    expect(classifyMaterial(items[lastTile + 1]), MaterialKind.tileAdhesive);
    expect(classifyMaterial(items[lastTile + 2]), MaterialKind.tileGrout);
  });

  test("a template's own adhesive line is kept and resized", () {
    final items = _scaled('Bathroom Renovation', 'traditional');
    final adhesive = _ofKind(items, MaterialKind.tileAdhesive).single;

    expect(adhesive.name, 'Tile Adhesive');
    expect(adhesive.defaultQuantity, 15);
  });

  test('grout follows the tile face when a wall tile is swapped', () {
    final items = _scaled('Bathroom Renovation', 'modern');
    final wall = items.indexWhere(
        (i) => classifyMaterial(i) == MaterialKind.wallTile);
    final subway =
        items[wall].alternatives.firstWhere((a) => a.size == '75x300');
    items[wall] = BomQuantityEstimator.applyAlternative(
      item: items[wall],
      alternative: subway,
      areaSqm: _area,
    );

    final settled = BomQuantityEstimator.requantifyTileSetting(items, _area);

    // 20 x 0.18 + 44 x 0.30 = 16.8 kg -> 9 packs; the tiled area is unchanged.
    expect(_ofKind(settled, MaterialKind.tileGrout).single.defaultQuantity, 9);
    expect(
        _ofKind(settled, MaterialKind.tileAdhesive).single.defaultQuantity, 15);
  });

  test('duplicate adhesive lines in a template collapse to one', () {
    final items = BomQuantityEstimator.scaleTemplate(
      template: const RenovationTemplate(
        id: 'dupes',
        renovationType: 'Floor Renovation',
        style: 'modern',
        name: 'Dupes',
        description: '',
        items: [
          RenovationTemplateItem(
              name: 'Floor Tiles', category: 'Floor Surface', unit: 'pcs',
              defaultQuantity: 1),
          RenovationTemplateItem(
              name: 'Tile Adhesive', category: 'Installation', unit: 'bags',
              defaultQuantity: 1),
          RenovationTemplateItem(
              name: 'Tile adhesive (wall)', category: 'Installation',
              unit: 'bags', defaultQuantity: 1),
        ],
      ),
      areaSqm: _area,
    );

    expect(_ofKind(items, MaterialKind.tileAdhesive), hasLength(1));
  });

  test('a BOM without tiles gets no adhesive or grout', () {
    for (final items in [
      _scaled('Interior Painting', 'modern'),
      _scaled('Floor Renovation', 'minimalist'),
      _scaled('Roof Repair', 'traditional'),
    ]) {
      expect(_ofKind(items, MaterialKind.tileAdhesive), isEmpty);
      expect(_ofKind(items, MaterialKind.tileGrout), isEmpty);
    }
  });

  test('roof tiles are roofing, not floor tile', () {
    expect(
      classifyMaterialParts(name: 'Roof Tiles', category: 'Roofing', unit: 'pcs'),
      MaterialKind.roofingSheet,
    );
    final roof = _scaled('Roof Repair', 'traditional');
    expect(_ofKind(roof, MaterialKind.tileSpacer), isEmpty);
    expect(roof.where(BomQuantityEstimator.affectsTileSetting), isEmpty);
  });

  test('the AI consultation BOM is resized but never extended', () {
    final withoutSetting = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bathroom Renovation',
      style: 'modern',
      areaSqm: 10,
      materialNames: const ['Ceramic floor tiles', 'Ceramic wall tiles'],
    );
    expect(_ofKind(withoutSetting.items, MaterialKind.tileAdhesive), isEmpty);
    expect(_ofKind(withoutSetting.items, MaterialKind.tileGrout), isEmpty);

    final withAdhesive = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bathroom Renovation',
      style: 'modern',
      areaSqm: 10,
      materialNames: const [
        'Ceramic floor tiles',
        'Ceramic wall tiles',
        'Tile adhesive',
      ],
    );
    // 10 sq.m floor + 10 sq.m wall = 20 sq.m -> 4.4 -> 5 bags.
    expect(
      _ofKind(withAdhesive.items, MaterialKind.tileAdhesive)
          .single
          .defaultQuantity,
      5,
    );
  });

  test('the adhesive formula explains the tiled area it was sized from', () {
    final items = _scaled('Bathroom Renovation', 'modern');
    final adhesive = _ofKind(items, MaterialKind.tileAdhesive).single;

    final formula = BomQuantityEstimator.getFormulaString(
      item: adhesive,
      areaSqm: _area,
      currentQty: adhesive.defaultQuantity,
      bom: items,
    );

    expect(formula, contains('20.0 sq.m floor + 44.0 sq.m wall'));
    expect(formula, contains('64.0 sq.m'));
  });
}
