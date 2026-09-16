import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

RenovationTemplateItem _item(
  String name,
  String category,
  String unit, {
  List<MaterialAlternative> alternatives = const [],
}) =>
    RenovationTemplateItem(
      name: name,
      category: category,
      unit: unit,
      defaultQuantity: 1,
      alternatives: alternatives,
    );

void main() {
  const area = 20.0;

  // Every BOM row the template picker can produce, as the review screen sees it.
  final rows = <(String, RenovationTemplateItem)>[
    for (final template in RenovationTemplatesCatalog.allTemplates)
      for (final item in BomQuantityEstimator.scaleTemplate(
        template: template,
        areaSqm: area,
        scope: template.scope,
      ))
        (template.id, item),
  ];

  group('BOM type chips', () {
    test('only offer the same kind of material as the row', () {
      for (final (label, item) in rows) {
        final kind = classifyMaterial(item);
        for (final alt in item.alternatives) {
          expect(
            classifyMaterialParts(
              name: alt.name,
              category: item.category,
              unit: item.unit,
            ),
            kind,
            reason: '$label: "${item.name}" offers "${alt.name}"',
          );
        }
      }
    });

    test('never offer made-up Premium or Economy variants', () {
      for (final (label, item) in rows) {
        for (final alt in item.alternatives) {
          expect(
            alt.name,
            isNot(anyOf(startsWith('Premium '), startsWith('Economy '))),
            reason: '$label: ${item.name}',
          );
        }
      }
    });

    test('a row is swappable exactly when it has chips', () {
      for (final (label, item) in rows) {
        expect(
          item.isSwappable,
          item.alternatives.isNotEmpty,
          reason: '$label: ${item.name}',
        );
      }
    });

    test('installation consumables and non-finish goods get no chips', () {
      for (final item in [
        _item('Tile Adhesive', 'Floor Installation', 'bags'),
        _item('Grout', 'Wall Finishing', 'bags'),
        _item('Tile Spacers', 'Floor Installation', 'packs'),
        _item('Waterproofing Membrane', 'Floor Installation', 'L'),
        _item('Primer', 'Paint', 'gal'),
        _item('Laminate Countertop', 'Countertops', 'sqm'),
        _item('Underlayment', 'Flooring', 'sqm'),
        _item('Toilet', 'Fixtures', 'pcs'),
      ]) {
        expect(
          BomQuantityEstimator.ensureSwappable(item).alternatives,
          isEmpty,
          reason: item.name,
        );
      }
    });

    test('drops a template alternative of a different kind', () {
      final vinyl = BomQuantityEstimator.ensureSwappable(
        _item(
          'Vinyl Flooring',
          'Flooring',
          'sqm',
          alternatives: const [
            MaterialAlternative(name: 'Ceramic Floor Tiles', size: '600x600'),
            MaterialAlternative(name: 'Vinyl Flooring Planks'),
          ],
        ),
      );
      final names = vinyl.alternatives.map((a) => a.name);
      expect(names, isNot(contains('Ceramic Floor Tiles')));
      expect(names, contains('Vinyl Flooring Planks'));
      expect(vinyl.alternatives.length, greaterThanOrEqualTo(2));
    });

    test('is stable when applied again', () {
      for (final (label, item) in rows) {
        expect(
          BomQuantityEstimator.ensureSwappable(item)
              .alternatives
              .map((a) => a.name)
              .toList(),
          item.alternatives.map((a) => a.name).toList(),
          reason: '$label: ${item.name}',
        );
      }
    });
  });

  group('applyAlternative', () {
    test('keeps the row kind, a sellable unit and a positive quantity', () {
      for (final (label, item) in rows) {
        final kind = classifyMaterial(item);
        for (final alt in item.alternatives) {
          final swapped = BomQuantityEstimator.applyAlternative(
            item: item,
            alternative: alt,
            areaSqm: area,
          );
          final reason = '$label: "${item.name}" -> "${alt.name}"';
          expect(swapped.name, alt.name, reason: reason);
          expect(classifyMaterial(swapped), kind, reason: reason);
          expect(swapped.defaultQuantity, greaterThan(0), reason: reason);
          if (kTileKinds.contains(kind)) {
            expect(swapped.unit, 'pcs', reason: reason);
          }
        }
      }
    });

    test('a smaller tile face re-estimates to more pieces', () {
      final floor = BomQuantityEstimator.scaleTemplate(
        template:
            RenovationTemplatesCatalog.forProject(
                'Floor Renovation', RenovationScope.cosmetic),
        areaSqm: area,
      ).firstWhere((i) => classifyMaterial(i) == MaterialKind.floorTile);
      final nonSlip = floor.alternatives.firstWhere((a) => a.size == '300x300');

      final swapped = BomQuantityEstimator.applyAlternative(
        item: floor,
        alternative: nonSlip,
        areaSqm: area,
      );

      expect(swapped.size, '300x300');
      expect(swapped.defaultQuantity, greaterThan(floor.defaultQuantity));
    });
  });
}
