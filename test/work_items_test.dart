import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// The bathroom is estimated from ticked work rather than from a whole
/// template. These lock in that the starting ticks give the list the template
/// always gave, that unticked work stays out even once the room is measured,
/// and that what was left out can be told to the shop by name.

const _cosmetic = RenovationScope.cosmetic;
const _structural = RenovationScope.structural;
const _functional = RenovationScope.functional;

final _bathroom =
    RenovationTemplatesCatalog.workCatalogueFor('Bathroom Renovation')!;

Set<String> _names(Iterable<RenovationTemplateItem> items) =>
    {for (final i in items) i.name.trim().toLowerCase()};

bool _hasKind(Iterable<RenovationTemplateItem> items, MaterialKind kind) =>
    items.any((i) => classifyMaterial(i) == kind);

void main() {
  group('which projects use work items', () {
    test('the bathroom does', () {
      expect(RenovationTemplatesCatalog.workCatalogueFor('Bathroom\nRenovation'),
          isNotNull);
    });

    test('every other project still uses its template', () {
      for (final type in RenovationTemplatesCatalog.projectTypes) {
        if (type.contains('Bathroom')) continue;
        expect(RenovationTemplatesCatalog.workCatalogueFor(type), isNull,
            reason: type);
      }
    });
  });

  group('the catalogue itself', () {
    test('every package names work items that exist', () {
      for (final package in _bathroom.packages) {
        for (final id in package.itemIds) {
          expect(_bathroom.byId(id), isNotNull, reason: '${package.id}: $id');
        }
      }
    });

    test('every kind of work starts from a package that exists', () {
      for (final scope in RenovationScope.values) {
        expect(_bathroom.packageById(_bathroom.startingPackages[scope]!),
            isNotNull,
            reason: scope.label);
      }
    });

    test('every work item brings at least one material', () {
      for (final item in _bathroom.items) {
        expect(item.materials, isNotEmpty, reason: item.id);
      }
    });
  });

  group('the starting ticks', () {
    for (final scope in RenovationScope.values) {
      test('for ${scope.label} work give the list its template always gave',
          () {
        final ticks = _bathroom.startingSelection(RenovationTypes.only(scope));
        final before =
            RenovationTemplatesCatalog.forProject('Bathroom Renovation', scope);
        expect(_names(_bathroom.templateFor(ticks).items), _names(before.items));
      });
    }

    test('for a combined job give both halves', () {
      final types = RenovationTypes([_cosmetic, _functional]);
      final ticks = _bathroom.startingSelection(types);
      final before = RenovationTemplatesCatalog.forProjectTypes(
          'Bathroom Renovation', types);
      expect(_names(_bathroom.templateFor(ticks).items), _names(before.items));
    });
  });

  group('ticked work', () {
    test('a retile brings tiles and waterproofing, and no fixtures or paint',
        () {
      final retile = _bathroom.packageById('retile_only')!.itemIds.toSet();
      final items = _bathroom.templateFor(retile).items;
      expect(_hasKind(items, MaterialKind.floorTile), isTrue);
      expect(_hasKind(items, MaterialKind.wallTile), isTrue);
      expect(_hasKind(items, MaterialKind.waterproofing), isTrue);
      expect(_hasKind(items, MaterialKind.plumbingFixture), isFalse);
      expect(_hasKind(items, MaterialKind.paintTopcoat), isFalse);
    });

    test('lists a material two items share only once', () {
      final template = _bathroom.templateFor({'build_walls', 'cast_slab'});
      final names = [for (final i in template.items) i.name.toLowerCase()];
      expect(names.length, names.toSet().length);
    });

    test('decides the kinds of work, not the step before', () {
      expect(_bathroom.typesOf({'retile_floor', 'supply_lines'}),
          RenovationTypes([_cosmetic, _functional]));
      expect(_bathroom.typesOf({'retile_floor'}),
          RenovationTypes.only(_cosmetic));
    });

    test('names the list for the kinds it adds up to', () {
      final template = _bathroom.templateFor({'build_walls', 'retile_floor'});
      expect(template.name, 'Cosmetic + Structural Bathroom');
      expect(template.scope, _structural);
      expect(template.workItemIds, ['build_walls', 'retile_floor']);
    });

    test('must hold at least one item', () {
      expect(() => _bathroom.templateFor(const {}), throwsArgumentError);
    });

    test('matching a package exactly is recognised as that package', () {
      final swap = _bathroom.packageById('fixture_swap')!;
      expect(_bathroom.packageMatching(swap.itemIds.toSet()), swap);
      expect(_bathroom.packageMatching({'replace_toilet'}), isNull);
    });
  });

  group('work left out', () {
    test('is the unticked work of the same kinds', () {
      final left = _bathroom
          .leftOut(_bathroom.packageById('retile_only')!.itemIds.toSet())
          .map((i) => i.id);
      expect(left, containsAll(['repaint', 'replace_toilet']));
      expect(left, isNot(contains('tile_walls')));
    });

    test('does not list a kind of work the job never included', () {
      final left = _bathroom.leftOut({'retile_floor'}).map((i) => i.scope);
      expect(left, isNot(contains(_functional)));
      expect(left, isNot(contains(_structural)));
    });
  });

  group('a list built from work, once the room is measured', () {
    // A 2.0 x 1.5 m bathroom measured with wainscot tiles and a painted
    // ceiling, as a builder might leave the switches.
    final takeoff = SiteTakeoff.from(
      const SiteDetails(
        job: RoomJob.wetRoom,
        lengthM: 2.0,
        widthM: 1.5,
        heightM: 2.4,
        doors: [Opening(widthM: 0.70, heightM: 2.10)],
        wallTileHeight: WallTileHeight.wainscot,
        removeOldTiles: true,
        paintCeiling: true,
      ),
    );

    List<RenovationTemplateItem> sized(RenovationTemplate template) =>
        BomQuantityEstimator.scaleTemplate(
          template: template,
          areaSqm: takeoff.floorSqm,
          scope: template.scope,
          takeoff: takeoff,
        );

    test('keeps unticked walls and paint out', () {
      final items = sized(_bathroom.templateFor({'retile_floor'}));
      expect(_hasKind(items, MaterialKind.floorTile), isTrue);
      expect(_hasKind(items, MaterialKind.wallTile), isFalse);
      expect(_hasKind(items, MaterialKind.paintTopcoat), isFalse);
      expect(_hasKind(items, MaterialKind.waterproofing), isFalse);
    });

    test('still sets the tiles it has', () {
      final items = sized(_bathroom.templateFor({'retile_floor'}));
      expect(_hasKind(items, MaterialKind.tileAdhesive), isTrue);
      expect(_hasKind(items, MaterialKind.tileGrout), isTrue);
    });

    test('lays a screed under a new floor when the old tiles come off', () {
      final items = sized(_bathroom.templateFor({'retile_floor'}));
      expect(items.any((i) => i.name.contains('Floor Screed')), isTrue);
    });

    test('adds no screed when the floor is not being retiled', () {
      final items = sized(_bathroom.templateFor({'replace_toilet'}));
      expect(items.any((i) => i.name.contains('Floor Screed')), isFalse);
      expect(_hasKind(items, MaterialKind.floorTile), isFalse);
    });

    test('a whole template is still fitted to the room as before', () {
      final template = RenovationTemplatesCatalog.forProject(
          'Bathroom Renovation', _cosmetic);
      final items = BomQuantityEstimator.scaleTemplate(
        template: template.copyWithItems([
          for (final i in template.items)
            if (classifyMaterial(i) != MaterialKind.wallTile) i,
        ]),
        areaSqm: takeoff.floorSqm,
        takeoff: takeoff,
      );
      // Measured with wainscot tiles, so fitting puts the wall tile back.
      expect(_hasKind(items, MaterialKind.wallTile), isTrue);
    });

    test('brings the CHB wall only when new walls are ticked', () {
      final walls = _bathroom.templateFor({'build_walls', 'retile_floor'});
      final items = BomQuantityEstimator.scaleTemplate(
        template: walls,
        areaSqm: takeoff.floorSqm,
        types: _bathroom.typesOf({'build_walls', 'retile_floor'}),
        takeoff: takeoff,
      );
      expect(_hasKind(items, MaterialKind.chbBlock), isTrue);
      expect(_hasKind(sized(_bathroom.templateFor({'retile_floor'})),
          MaterialKind.chbBlock), isFalse);
    });
  });

  group('the ticked work travels with the list', () {
    final template = _bathroom.templateFor({'retile_floor', 'repaint'});

    test('through a resize', () {
      expect(template.copyWithItems(const []).workItemIds,
          template.workItemIds);
    });

    test('through saving and reading back', () {
      final back = RenovationTemplate.fromMap(template.id, template.toMap());
      expect(back.workItemIds, template.workItemIds);
      expect(back.isFromWorkItems, isTrue);
    });

    test('a template saved without work items reads as a whole template', () {
      final plain = RenovationTemplatesCatalog.forProject(
          'Kitchen Renovation', _cosmetic);
      expect(plain.toMap().containsKey('workItemIds'), isFalse);
      expect(RenovationTemplate.fromMap(plain.id, plain.toMap()).isFromWorkItems,
          isFalse);
    });
  });
}
