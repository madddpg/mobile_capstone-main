import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

void main() {
  test('a builder who picks four materials reviews four materials', () {
    final template = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bathroom Renovation',
      style: 'modern',
      areaSqm: 12,
      materialNames: const [
        'Ceramic floor tiles (600x600, non-slip)',
        'Ceramic wall tiles',
        'Toilet bowl set',
        'Liquid waterproofing membrane for the shower area and wet walls',
      ],
    );

    expect(template.items.length, 4);
    expect(
      template.items.map((i) => i.name).toList(),
      const [
        'Ceramic floor tiles',
        'Ceramic wall tiles',
        'Toilet bowl set',
        'Liquid waterproofing membrane for the shower area and wet walls',
      ],
    );
  });

  test('parenthetical detail becomes size and notes, not extra line items', () {
    final template = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Kitchen Renovation',
      style: 'modern',
      areaSqm: 10,
      materialNames: const ['Ceramic floor tiles (600x600, non-slip)'],
    );

    final item = template.items.single;
    expect(item.name, 'Ceramic floor tiles');
    expect(item.size, '600x600');
    expect(item.notes, 'non-slip');
  });

  test('duplicate picks are merged case-insensitively', () {
    final template = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Kitchen Renovation',
      style: 'modern',
      areaSqm: 10,
      materialNames: const ['Tile adhesive', 'Tile Adhesive', 'Tile grout'],
    );

    expect(template.items.length, 2);
  });

  test('AI consultation BOM offers no swap alternatives by default', () {
    final template = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Kitchen Renovation',
      style: 'modern',
      areaSqm: 12,
      materialNames: const ['Ceramic floor tiles', 'Interior paint', 'Toilet'],
    );
    expect(template.items.every((i) => i.alternatives.isEmpty), isTrue);
    expect(template.items.every((i) => i.isSwappable == false), isTrue);
  });

  test('explicit Extension scope keeps structural picks in the AI BOM', () {
    final full = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bedroom Renovation',
      style: 'modern',
      areaSqm: 20,
      materialNames: const ['Ceramic floor tiles', 'CHB 6"', 'Deformed rebar 12mm'],
      scope: RenovationScope.fullRenovation,
    );
    final ext = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bedroom Renovation',
      style: 'modern',
      areaSqm: 20,
      materialNames: const ['Ceramic floor tiles', 'CHB 6"', 'Deformed rebar 12mm'],
      scope: RenovationScope.extension,
    );

    bool hasChb(RenovationTemplate t) =>
        t.items.any((i) => i.name.toLowerCase().contains('chb'));
    expect(hasChb(full), isFalse);
    expect(hasChb(ext), isTrue);
  });

  test('only vague category labels expand into basics', () {
    expect(
      BomQuantityEstimator.expandVagueMaterialName('Ceramic floor tiles'),
      ['Ceramic floor tiles'],
    );
    expect(
      BomQuantityEstimator.expandVagueMaterialName(
        'Essential materials for flooring',
      ).length,
      greaterThan(1),
    );
  });
}
