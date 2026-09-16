import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

void main() {
  const homeScreenTypes = [
    'Bathroom\nRenovation',
    'Kitchen\nRenovation',
    'Floor\nRenovation',
    'Roof\nRepair',
    'Interior\nPainting',
    'Living Room\nRenovation',
    'Bedroom\nRenovation',
    'Laundry\nRenovation',
    'Dining Room\nRenovation',
    'Wall\nFinishing',
  ];

  const catalog = RenovationTemplatesCatalog.forProject;

  test('the home screen and the catalog list the same projects', () {
    expect(
      homeScreenTypes.map(RenovationTemplatesCatalog.normalizeType).toList(),
      RenovationTemplatesCatalog.projectTypes,
    );
  });

  test('every project has one template for each type it offers', () {
    for (final type in homeScreenTypes) {
      final scopes = RenovationTemplatesCatalog.scopesFor(type);
      expect(scopes, isNotEmpty, reason: type);
      for (final scope in scopes) {
        final template = catalog(type, scope);
        expect(template.scope, scope, reason: template.id);
        expect(template.renovationType,
            RenovationTemplatesCatalog.normalizeType(type));
        expect(template.items, isNotEmpty, reason: template.id);
        expect(template.name, startsWith(scope.label));
      }
    }
  });

  test('painting is only cosmetic, and a floor or wall has nothing functional',
      () {
    expect(RenovationTemplatesCatalog.scopesFor('Interior Painting'),
        [RenovationScope.cosmetic]);
    for (final type in ['Floor Renovation', 'Wall Finishing']) {
      expect(RenovationTemplatesCatalog.scopesFor(type),
          isNot(contains(RenovationScope.functional)));
    }
    expect(RenovationTemplatesCatalog.scopesFor('Bathroom Renovation'),
        RenovationScope.values);
    expect(
      RenovationTemplatesCatalog.unavailableReason(
          'Interior Painting', RenovationScope.structural),
      contains('Interior Painting'),
    );
  });

  test('template ids are unique', () {
    final ids =
        RenovationTemplatesCatalog.allTemplates.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('cosmetic and functional templates carry no structural materials', () {
    for (final template in RenovationTemplatesCatalog.allTemplates
        .where((t) => !t.scope.includesStructural)) {
      for (final item in template.items) {
        expect(kStructuralOnlyKinds.contains(classifyMaterial(item)), isFalse,
            reason: '${template.id}: ${item.name}');
      }
    }
  });

  test('every structural template carries structure', () {
    for (final template in RenovationTemplatesCatalog.allTemplates
        .where((t) => t.scope.includesStructural)) {
      expect(
        template.items
            .any((i) => kStructuralOnlyKinds.contains(classifyMaterial(i))),
        isTrue,
        reason: template.id,
      );
    }
  });

  test('functional room templates are plumbing and wiring, not finishes', () {
    const finishes = {
      MaterialKind.floorTile,
      MaterialKind.wallTile,
      MaterialKind.paintPrimer,
      MaterialKind.paintTopcoat,
      MaterialKind.skimCoat,
    };
    const services = {
      MaterialKind.plumbingConsumable,
      MaterialKind.plumbingFixture,
      MaterialKind.electrical,
    };
    for (final template in RenovationTemplatesCatalog.allTemplates.where((t) =>
        t.scope == RenovationScope.functional &&
        !t.renovationType.contains('Roof'))) {
      final kinds = template.items.map(classifyMaterial).toSet();
      expect(kinds.intersection(finishes), isEmpty, reason: template.id);
      expect(kinds.any(services.contains), isTrue, reason: template.id);
    }
  });

  test('template materials classify as what they are', () {
    final byName = {
      for (final template in RenovationTemplatesCatalog.allTemplates)
        for (final item in template.items) item.name: item,
    };
    MaterialKind kindOf(String name) {
      expect(byName, contains(name));
      return classifyMaterial(byName[name]!);
    }

    expect(kindOf('THHN Stranded Wire 3.5 mm² (#12)'), MaterialKind.electrical);
    expect(kindOf('PVC Electrical Conduit 1/2" (3 m length)'),
        MaterialKind.electrical);
    expect(kindOf('PPR Pipe 1/2" (4 m length)'),
        MaterialKind.plumbingConsumable);
    expect(kindOf('Floor Drain 4" x 4" (Stainless)'),
        MaterialKind.plumbingConsumable);
    expect(kindOf('Water Closet (Two-piece)'), MaterialKind.plumbingFixture);
    expect(kindOf('Cementitious Waterproofing'), MaterialKind.waterproofing);
    expect(kindOf('Skim Coat (20 kg)'), MaterialKind.skimCoat);
    expect(kindOf('Metal Primer (Red Oxide, 4 L)'), MaterialKind.paintPrimer);
    expect(kindOf('Roof Paint (4 L)'), MaterialKind.paintTopcoat);
    expect(kindOf('C-Purlin 2" x 4" x 1.5 mm (6 m length)'),
        MaterialKind.roofPurlin);
    expect(kindOf('Welded Mesh Reinforcement 6"x6" (Ga.10)'),
        MaterialKind.areaGoods);
    // "Wire brush" and "gutter" read as wiring and roofing sheet by name alone.
    expect(kindOf('Steel Brush (for rust removal)'),
        MaterialKind.genericConsumable);
    expect(kindOf('Pre-painted Roof Gutter Ga.24 (3 m length)'),
        MaterialKind.genericConsumable);
  });

  test('an unknown project still gets a template for each type', () {
    for (final scope in RenovationScope.values) {
      final template = catalog('Door Replacement', scope);
      expect(template.renovationType, 'Door Replacement');
      expect(template.items, isNotEmpty);
    }
  });

  test('labels saved before the three types still read correctly', () {
    expect(RenovationScope.fromString('Full Renovation'),
        RenovationScope.cosmetic);
    expect(RenovationScope.fromString('Extension'), RenovationScope.structural);
    expect(RenovationScope.fromString('Functional'), RenovationScope.functional);
    expect(RenovationScope.fromString(null), RenovationScope.cosmetic);
  });

  test('a template survives a round trip through a map', () {
    final template =
        catalog('Kitchen Renovation', RenovationScope.functional);
    final restored = RenovationTemplate.fromMap(template.id, template.toMap());
    expect(restored.scope, RenovationScope.functional);
    expect(restored.items.length, template.items.length);
  });

  test('template photos are no longer bundled with the app', () {
    // Templates are chosen by project and type. The photos only existed for
    // two renovation types and added about 13 MB to the app. Material photos
    // stay: those help a builder match goods at a counter.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('assets/images/templates/'), isFalse);
    expect(pubspec.contains('assets/images/materials/'), isTrue);
  });
}
