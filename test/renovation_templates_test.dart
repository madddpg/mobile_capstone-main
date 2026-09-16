import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

void main() {
  const renovationTypes = [
    'Bathroom\nRenovation',
    'Kitchen\nRenovation',
    'Floor\nRenovation',
    'Roof\nRepair',
    'Interior\nPainting',
    'Electrical\nInstallation',
    'Plumbing\nInstallation',
  ];

  test('every renovation type offers the same three styles', () {
    for (final type in renovationTypes) {
      final templates = RenovationTemplatesCatalog.threeForType(type);

      expect(templates.length, 3, reason: 'type: $type');
      expect(
        templates.map((t) => t.style).toList(),
        RenovationTemplatesCatalog.styles,
        reason: 'type: $type',
      );
      expect(
        templates.every((t) => t.items.isNotEmpty),
        isTrue,
        reason: 'type: $type',
      );
    }
  });

  test('unknown renovation types get three templates named for that type', () {
    final templates =
        RenovationTemplatesCatalog.threeForType('Door Replacement');

    expect(templates.length, 3);
    expect(
      templates.map((t) => t.style).toList(),
      RenovationTemplatesCatalog.styles,
    );
    for (final template in templates) {
      expect(template.renovationType, 'Door Replacement');
      expect(template.items, isNotEmpty);
    }
  });

  test('template photos are no longer bundled with the app', () {
    // Templates are chosen by name, style and material list. The photos only
    // existed for two of seven renovation types and added about 13 MB to the
    // app. Material photos stay: those help a builder match goods at a counter.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('assets/images/templates/'), isFalse);
    expect(pubspec.contains('assets/images/materials/'), isTrue);
  });

  test('remote templates win per style and gaps fall back to the catalog', () {
    const remote = RenovationTemplate(
      id: 'remote_modern_kitchen',
      renovationType: 'Kitchen Renovation',
      style: 'Modern',
      name: 'Shop Modern Kitchen',
      description: 'Remote package',
      items: [
        RenovationTemplateItem(
          name: 'Floor Tiles',
          category: 'Flooring',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1,
        ),
      ],
    );

    final templates = RenovationTemplatesCatalog.threeFrom(
      [remote, ...RenovationTemplatesCatalog.forType('Kitchen Renovation')],
      'Kitchen Renovation',
    );

    expect(templates.length, 3);
    expect(templates.first.name, 'Shop Modern Kitchen');
    expect(templates[1].style, 'minimalist');
    expect(templates[2].style, 'traditional');
  });

  test('a single available style is expanded into all three', () {
    final onlyModern = RenovationTemplatesCatalog.forType('Kitchen Renovation')
        .where((t) => t.style == 'modern')
        .toList();

    final templates = RenovationTemplatesCatalog.threeFrom(
      onlyModern,
      'Kitchen Renovation',
    );

    expect(
      templates.map((t) => t.style).toList(),
      RenovationTemplatesCatalog.styles,
    );
    expect(templates[1].name, 'Minimalist Kitchen');
    expect(templates[2].name, 'Traditional Kitchen');
    expect(templates[1].items, isNotEmpty);
  });

  test('styleKey normalizes free-form labels', () {
    expect(RenovationTemplatesCatalog.styleKey('Basic'), 'minimalist');
    expect(RenovationTemplatesCatalog.styleKey('Classic'), 'traditional');
    expect(RenovationTemplatesCatalog.styleKey('contemporary'), 'modern');
    expect(RenovationTemplatesCatalog.styleLabel('minimal'), 'Minimalist');
  });
}
