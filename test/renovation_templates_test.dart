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

  test('a template photo always matches its renovation type and style', () {
    // The picker used to fill empty slots from a random stock-photo service,
    // which put park scenery on a Laundry Renovation. A photo must now name
    // the type and style it belongs to, or there must be no photo at all.
    for (final type in [...renovationTypes, 'Bedroom Renovation', 'Laundry Renovation']) {
      final templates = RenovationTemplatesCatalog.threeForType(type);
      final key = RenovationTemplatesCatalog.photoKeyForType(type);
      for (final t in templates) {
        final asset = (t.imageAsset ?? '').trim();
        if (asset.isEmpty) continue; // no photo yet is allowed
        expect(
          asset,
          startsWith('assets/images/templates/${key}_'),
          reason: 'photo for $type / ${t.style} does not belong to $key',
        );
        expect(
          asset,
          endsWith('_${RenovationTemplatesCatalog.styleKey(t.style)}.png'),
          reason: 'photo for $type / ${t.style} is the wrong style',
        );
      }
    }
  });

  test('no template points at a random stock-photo service', () {
    for (final type in [...renovationTypes, 'Laundry Renovation', 'Dining Room Renovation']) {
      for (final t in RenovationTemplatesCatalog.threeForType(type)) {
        final url = (t.imageUrl ?? '').toLowerCase();
        expect(url.contains('loremflickr'), isFalse);
        expect(url.contains('picsum'), isFalse);
        expect(url.contains('unsplash'), isFalse);
      }
    }
  });

  test('a bundled photo exists on disk for every key the catalog claims', () {
    for (final type in renovationTypes) {
      for (final t in RenovationTemplatesCatalog.threeForType(type)) {
        final asset = (t.imageAsset ?? '').trim();
        if (asset.isEmpty) continue;
        expect(File(asset).existsSync(), isTrue,
            reason: 'missing bundled file: $asset');
      }
    }
  });

  test('a type with no bundled photo carries no image rather than a wrong one', () {
    // Interior Painting ships no artwork yet. The picker draws its labelled
    // card, which is honest; a stand-in photo of someone else's room is not.
    final templates = RenovationTemplatesCatalog.threeForType('Interior Painting');
    for (final t in templates) {
      expect((t.imageAsset ?? '').isEmpty, isTrue);
      expect((t.imageUrl ?? '').isEmpty, isTrue);
    }
  });

  test('a template keeps its own imageUrl instead of the catalog fallback', () {
    const remote = RenovationTemplate(
      id: 'remote_modern_kitchen',
      renovationType: 'Kitchen Renovation',
      style: 'modern',
      name: 'Shop Modern Kitchen',
      description: 'Remote package',
      imageUrl: 'https://cdn.example.com/kitchen.jpg',
      items: [
        RenovationTemplateItem(
          name: 'Floor Tiles',
          category: 'Flooring',
          unit: 'sqm',
          defaultQuantity: 1,
        ),
      ],
    );

    // A curated remote photo from Firestore is never overwritten by the
    // generic bundled one for its type.
    final filled = remote
        .withReferenceAsset('assets/images/templates/kitchen_modern.png');
    expect(filled.imageUrl, 'https://cdn.example.com/kitchen.jpg');
    expect((filled.imageAsset ?? '').isEmpty, isTrue);
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
