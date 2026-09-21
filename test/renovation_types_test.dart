import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// A real job is often more than one kind of work — retiling a kitchen and
/// rewiring it — and forcing a single choice left one half of the job with no
/// materials. These lock in that a combination gets both halves, orders
/// nothing twice, and still writes the one label the shop dashboard reads.

const _cosmetic = RenovationScope.cosmetic;
const _structural = RenovationScope.structural;
const _functional = RenovationScope.functional;

Set<String> _names(Iterable<RenovationTemplateItem> items) =>
    {for (final i in items) i.name.trim().toLowerCase()};

bool _hasKind(Iterable<RenovationTemplateItem> items, MaterialKind kind) =>
    items.any((i) => classifyMaterial(i) == kind);

void main() {
  group('a selection of kinds of work', () {
    test('is the same selection whichever order it was ticked in', () {
      expect(RenovationTypes([_functional, _cosmetic]),
          RenovationTypes([_cosmetic, _functional]));
    });

    test('needs at least one kind', () {
      expect(() => RenovationTypes(const []), throwsArgumentError);
    });

    test('reads as every kind it holds', () {
      expect(RenovationTypes([_functional, _cosmetic]).label,
          'Cosmetic + Functional');
    });

    test('changes finishes if any kind in it does', () {
      expect(RenovationTypes([_cosmetic, _functional]).changesFinishes, isTrue);
      expect(RenovationTypes.only(_functional).changesFinishes, isFalse);
    });

    test('keeps structural materials if any structural work is in it', () {
      expect(
          RenovationTypes([_cosmetic, _structural]).includesStructural, isTrue);
      expect(
          RenovationTypes([_cosmetic, _functional]).includesStructural, isFalse);
    });
  });

  group('the one label the dashboard reads', () {
    test('is the heaviest kind chosen', () {
      expect(RenovationTypes([_cosmetic, _structural]).primary, _structural);
      expect(RenovationTypes([_cosmetic, _functional]).primary, _functional);
      expect(RenovationTypes([_cosmetic, _structural, _functional]).primary,
          _structural);
      expect(RenovationTypes.only(_cosmetic).primary, _cosmetic);
    });

    test('a post carries the single label and the full selection separately',
        () {
      final types = RenovationTypes([_cosmetic, _functional]);
      final data = projectPostFields(
        postId: 'post-1',
        userId: 'builder-1',
        projectId: 'project-1',
        projectName: 'Kitchen',
        projectType: 'Kitchen Renovation',
        projectScope: types.primary.label,
        ownerName: 'Ahmad Paguta',
        materials: const [],
        totalAreaSqm: 7.5,
        budget: 'medium',
        renovationTypes: types.names,
      );
      // Still exactly one of the three words the dashboard already knows.
      expect(data['projectScope'], 'Functional');
      expect(data['renovationTypes'], ['cosmetic', 'functional']);
    });

    test('a reopened estimate reads back its whole selection', () {
      final project = ProjectModel.fromMap('p1', {
        'projectName': 'Kitchen',
        'projectScope': 'Functional',
        'renovationTypes': ['cosmetic', 'functional'],
      });
      expect(project.types, RenovationTypes([_cosmetic, _functional]));
    });

    test('an estimate saved before multi-select reads as its single kind', () {
      final project = ProjectModel.fromMap('p1', {
        'projectName': 'Old Bathroom',
        'projectScope': 'Structural',
      });
      expect(project.types, RenovationTypes.only(_structural));
    });

    test('unknown names fall back to the saved single kind', () {
      expect(
        RenovationTypes.fromStored(['plaster'], 'Cosmetic'),
        RenovationTypes.only(_cosmetic),
      );
    });
  });

  group('the combined template', () {
    test('one kind gives exactly the template it always did', () {
      final single = RenovationTemplatesCatalog.forProjectTypes(
          'Kitchen Renovation', RenovationTypes.only(_cosmetic));
      final before =
          RenovationTemplatesCatalog.forProject('Kitchen Renovation', _cosmetic);
      expect(single.id, before.id);
      expect(_names(single.items), _names(before.items));
    });

    test('carries every material from each kind chosen', () {
      final combined = RenovationTemplatesCatalog.forProjectTypes(
          'Kitchen Renovation', RenovationTypes([_cosmetic, _functional]));
      for (final scope in [_cosmetic, _functional]) {
        final part =
            RenovationTemplatesCatalog.forProject('Kitchen Renovation', scope);
        expect(_names(combined.items), containsAll(_names(part.items)),
            reason: '${scope.label} materials must survive the merge');
      }
    });

    test('never lists the same material twice', () {
      final combined = RenovationTemplatesCatalog.forProjectTypes(
          'Bathroom Renovation', RenovationTypes([_cosmetic, _structural]));
      final names = [
        for (final i in combined.items) i.name.trim().toLowerCase(),
      ];
      expect(names.length, names.toSet().length);
    });

    test('is named for the whole combination', () {
      final combined = RenovationTemplatesCatalog.forProjectTypes(
          'Kitchen Renovation', RenovationTypes([_cosmetic, _functional]));
      expect(combined.name, 'Cosmetic + Functional Kitchen');
      expect(combined.scope, _functional);
    });
  });

  group('a combined job measured in a real room', () {
    // A 3.0 x 2.5 m kitchen, retiled and rewired at once.
    const kitchen = SiteDetails(
      job: RoomJob.kitchen,
      lengthM: 3.0,
      widthM: 2.5,
      heightM: 2.7,
      wallTileHeight: WallTileHeight.backsplash,
      counterLengthM: 2.4,
    );
    final types = RenovationTypes([_cosmetic, _functional]);
    final takeoff = SiteTakeoff.from(kitchen);
    final bom = BomQuantityEstimator.scaleTemplate(
      template: RenovationTemplatesCatalog.forProjectTypes(
          'Kitchen Renovation', types),
      areaSqm: takeoff.floorSqm,
      scope: types.primary,
      types: types,
      takeoff: takeoff,
      counts: const FunctionalCounts(outlets: 4, switches: 2, lights: 2),
    );

    test('gets the finishes of the cosmetic half', () {
      expect(_hasKind(bom, MaterialKind.floorTile), isTrue);
      expect(_hasKind(bom, MaterialKind.paintTopcoat), isTrue);
    });

    test('gets the pipes and wiring of the functional half', () {
      expect(_hasKind(bom, MaterialKind.electrical), isTrue);
    });

    test('sizes the wiring from the device counts, not the floor', () {
      final outlets = bom.firstWhere(
          (i) => i.name.toLowerCase().contains('convenience outlet'));
      expect(outlets.defaultQuantity, 4);
    });

    test('a single functional job still leaves the finishes out', () {
      final functionalOnly = RenovationTypes.only(_functional);
      final lines = BomQuantityEstimator.scaleTemplate(
        template: RenovationTemplatesCatalog.forProjectTypes(
            'Kitchen Renovation', functionalOnly),
        areaSqm: takeoff.floorSqm,
        scope: _functional,
        types: functionalOnly,
        takeoff: takeoff,
      );
      expect(_hasKind(lines, MaterialKind.floorTile), isFalse);
    });
  });

  group('structural materials follow structural work', () {
    List<RenovationTemplateItem> bathroom(RenovationTypes types) =>
        BomQuantityEstimator.scaleTemplate(
          template: RenovationTemplatesCatalog.forProjectTypes(
              'Bathroom Renovation', types),
          areaSqm: 6,
          scope: types.primary,
          types: types,
        );

    test('adding structural work brings in the CHB wall', () {
      expect(_hasKind(bathroom(RenovationTypes.only(_cosmetic)),
          MaterialKind.chbBlock), isFalse);
      expect(
          _hasKind(bathroom(RenovationTypes([_cosmetic, _structural])),
              MaterialKind.chbBlock),
          isTrue);
    });
  });

  group('what is ticked to begin with', () {
    test('a roof repair starts as structural work', () {
      expect(RenovationTemplatesCatalog.defaultTypeFor('Roof Repair'),
          _structural);
    });

    test('a room renovation starts as cosmetic work', () {
      for (final type in [
        'Bathroom Renovation',
        'Kitchen Renovation',
        'Interior Painting',
        'Floor Renovation',
      ]) {
        expect(RenovationTemplatesCatalog.defaultTypeFor(type), _cosmetic,
            reason: type);
      }
    });

    test('the default is always something the project offers', () {
      for (final type in RenovationTemplatesCatalog.projectTypes) {
        expect(
          RenovationTemplatesCatalog.offers(
              type, RenovationTemplatesCatalog.defaultTypeFor(type)),
          isTrue,
          reason: type,
        );
      }
    });
  });
}
