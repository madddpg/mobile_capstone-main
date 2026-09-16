import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

RenovationTemplateItem _item(
  String name, {
  String category = 'General',
  String unit = 'pcs',
  double? qtyPerSqm,
  String? size,
}) =>
    RenovationTemplateItem(
      name: name,
      category: category,
      unit: unit,
      defaultQuantity: 1,
      qtyPerSqm: qtyPerSqm,
      size: size,
    );

void main() {
  group('classifyMaterial — deny-list collisions', () {
    test('"Sandpaper Pack" is a consumable, not washed sand', () {
      expect(
        classifyMaterial(_item('Sandpaper Pack',
            category: 'Tools & Supplies', unit: 'packs')),
        MaterialKind.genericConsumable,
      );
    });

    test('"Painter\'s Tape" is a consumable, not paint', () {
      expect(
        classifyMaterial(_item("Painter's Tape",
            category: 'Tools & Supplies', unit: 'pcs')),
        MaterialKind.genericConsumable,
      );
    });

    test('"Solvent Cement" is a plumbing consumable, not Portland cement', () {
      expect(
        classifyMaterial(
            _item('Solvent Cement', category: 'Supplies', unit: 'pcs')),
        MaterialKind.plumbingConsumable,
      );
    });

    test('"Vinyl Flooring" is area goods, not floor tile', () {
      expect(
        classifyMaterial(
            _item('Vinyl Flooring', category: 'Flooring', unit: 'sqm')),
        MaterialKind.areaGoods,
      );
    });

    test('"Teflon Tape" is a plumbing consumable', () {
      expect(
        classifyMaterial(
            _item('Teflon Tape', category: 'Supplies', unit: 'pcs')),
        MaterialKind.plumbingConsumable,
      );
    });

    test('"Pre-painted GI Roofing Sheet" is roofing, not paint', () {
      // 'paint' matches inside 'pre-painted', which priced a roofing sheet as
      // gallons of latex.
      expect(
        classifyMaterial(_item('Pre-painted GI Roofing Sheet',
            category: 'Roofing', unit: 'ln.m')),
        MaterialKind.roofingSheet,
      );
    });

    test('"Pre-painted C-Purlin" stays roof framing', () {
      expect(
        classifyMaterial(
            _item('Pre-painted C-Purlin', category: 'Roofing', unit: 'pcs')),
        MaterialKind.roofPurlin,
      );
    });

    test('ordinary latex paint still classifies as paint', () {
      expect(
        classifyMaterial(
            _item('Latex Topcoat Paint', category: 'Paint', unit: 'gal')),
        MaterialKind.paintTopcoat,
      );
    });
  });

  group('classifyMaterial — tiles', () {
    test('bare "Floor Tiles" classifies as floor tile', () {
      expect(
        classifyMaterial(
            _item('Floor Tiles', category: 'Floor Surface', unit: 'sqm')),
        MaterialKind.floorTile,
      );
    });

    test('"Wall Tiles (Backsplash)" classifies as wall tile', () {
      expect(
        classifyMaterial(_item('Wall Tiles (Backsplash)',
            category: 'Wall Finishing', unit: 'sqm', qtyPerSqm: 0.35)),
        MaterialKind.wallTile,
      );
    });
  });

  group('estimateQuantity', () {
    test('backsplash uses its own qtyPerSqm as the wall multiplier, not 2.2x',
        () {
      final backsplash = _item('Wall Tiles (Backsplash)',
          category: 'Wall Finishing',
          unit: 'sqm',
          qtyPerSqm: 0.35,
          size: '75x300');
      final fullWall = _item('Wall Tiles',
          category: 'Wall Surface',
          unit: 'sqm',
          qtyPerSqm: 2.2,
          size: '75x300');

      final backsplashPcs =
          BomQuantityEstimator.estimateQuantity(item: backsplash, areaSqm: 12);
      final fullWallPcs =
          BomQuantityEstimator.estimateQuantity(item: fullWall, areaSqm: 12);

      // 0.35 vs 2.2 wall multiplier -> roughly 6x fewer subway tiles.
      expect(backsplashPcs, lessThan(fullWallPcs / 4));
    });

    test('primer + topcoat on the same area do not double-count the primer coat',
        () {
      final primer = _item('Primer', category: 'Paint', unit: 'gal');
      final topcoat = _item('Interior Paint', category: 'Paint', unit: 'gal');

      final primerGal =
          BomQuantityEstimator.estimateQuantity(item: primer, areaSqm: 20);
      final topcoatGal =
          BomQuantityEstimator.estimateQuantity(item: topcoat, areaSqm: 20);

      // Old bug: topcoat returned primer+topcoat, so total was ~primer*2 + topcoat.
      // ~0.10 gal/m2 across all three coats => ~2 gal for 20 m2.
      expect(primerGal + topcoatGal, lessThanOrEqualTo(4));
    });

    test('vinyl flooring is scaled by area, not by 600x600 tile pieces', () {
      final vinyl = _item('Vinyl Flooring',
          category: 'Flooring', unit: 'sqm', qtyPerSqm: 1.0);
      final qty =
          BomQuantityEstimator.estimateQuantity(item: vinyl, areaSqm: 20);
      // ~20 m2 + waste, nowhere near 20 / 0.36 * 1.08 tile pieces.
      expect(qty, lessThan(30));
    });
  });

  group('scope filtering', () {
    test('roofing sheets survive a Full-Renovation scale (Roof Repair type)',
        () {
      final template = RenovationTemplate(
        id: 'test_roof',
        renovationType: 'Roof Repair',
        name: 'Roof',
        description: '',
        items: const [
          RenovationTemplateItem(
            name: 'Roofing Sheets',
            category: 'Roofing',
            unit: 'pcs',
            defaultQuantity: 12,
            qtyPerSqm: 0.35,
          ),
        ],
      );

      final scaled = BomQuantityEstimator.scaleTemplate(
        template: template,
        areaSqm: 20,
        scope: RenovationScope.cosmetic,
      );

      expect(
        scaled.any((i) => i.name.toLowerCase().contains('roofing sheet')),
        isTrue,
      );
    });

    test('CHB is filtered out of a Full-Renovation scale but kept for Extension',
        () {
      final template = RenovationTemplate(
        id: 'test_ext',
        renovationType: 'Kitchen Renovation',
        name: 'K',
        description: '',
        items: const [
          RenovationTemplateItem(
            name: 'CHB 4"',
            category: 'Masonry',
            unit: 'pcs',
            defaultQuantity: 1,
          ),
        ],
      );

      final full = BomQuantityEstimator.scaleTemplate(
        template: template,
        areaSqm: 20,
        scope: RenovationScope.cosmetic,
      );
      final ext = BomQuantityEstimator.scaleTemplate(
        template: template,
        areaSqm: 20,
        scope: RenovationScope.structural,
      );

      expect(full.any((i) => i.name.toLowerCase().contains('chb')), isFalse);
      expect(ext.any((i) => i.name.toLowerCase().contains('chb')), isTrue);
    });
  });

  group('inferScope', () {
    test('confirmed structural materials imply an Extension', () {
      expect(
        BomQuantityEstimator.inferScope(
            'Kitchen Renovation', const ['Ceramic floor tiles', 'CHB 6"']),
        RenovationScope.structural,
      );
    });

    test('finish-only materials stay a Full Renovation', () {
      expect(
        BomQuantityEstimator.inferScope('Kitchen Renovation',
            const ['Ceramic floor tiles', 'Tile adhesive', 'Interior paint']),
        RenovationScope.cosmetic,
      );
    });
  });
}
