import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/excluded_work.dart';

/// Work removed from an estimate used to vanish, so a shop could not tell a
/// deliberate exclusion from a forgotten line. These lock in that the decision
/// survives the save, the post and the canvass sheet.

const _tile = ExcludedWork(
  name: 'Ceramic Floor Tile',
  category: 'Tiles',
  unit: 'pcs',
  size: '600x600',
  quantity: 96,
);

void main() {
  group('reading one excluded line', () {
    test('round-trips through a map', () {
      expect(ExcludedWork.fromMap(_tile.toMap()), _tile);
    });

    test('leaves empty fields out rather than writing blanks', () {
      const bare = ExcludedWork(name: 'Skim Coat');
      expect(bare.toMap(), {'name': 'Skim Coat'});
    });

    test('a line with no name is not a line', () {
      expect(ExcludedWork.fromMap({'name': '   '}), isNull);
      expect(ExcludedWork.fromMap(null), isNull);
    });

    test('reads a quantity that arrived as a string', () {
      final item = ExcludedWork.fromMap({'name': 'Cement', 'quantity': '12'});
      expect(item!.quantity, 12);
    });
  });

  group('how a line reads', () {
    test('names the size and the quantity it would have carried', () {
      expect(_tile.label, 'Ceramic Floor Tile 600x600 — 96 pcs');
    });

    test('a line that never had a quantity just gives its name', () {
      expect(const ExcludedWork(name: 'Waterproofing').label, 'Waterproofing');
      expect(const ExcludedWork(name: 'Waterproofing').quantityLabel, '—');
    });

    test('a fractional quantity keeps two places', () {
      const sand = ExcludedWork(name: 'Washed Sand', unit: 'cu.m', quantity: 1.5);
      expect(sand.label, 'Washed Sand — 1.50 cu.m');
    });
  });

  group('reading a saved list', () {
    test('accepts plain strings, which is how older posts stored them', () {
      final items = ExcludedWork.listFrom(['Floor Tile', 'Skirting']);
      expect(items.map((i) => i.name), ['Floor Tile', 'Skirting']);
    });

    test('skips entries that carry no name', () {
      final items = ExcludedWork.listFrom([
        {'name': 'Cement'},
        {'name': ''},
        {'quantity': 4},
        '',
      ]);
      expect(items.map((i) => i.name), ['Cement']);
    });

    test('anything that is not a list reads as nothing excluded', () {
      expect(ExcludedWork.listFrom(null), isEmpty);
      expect(ExcludedWork.listFrom('Floor Tile'), isEmpty);
    });
  });

  group('the shop dashboard contract', () {
    Map<String, dynamic> post({List<ExcludedWork> excluded = const []}) =>
        projectPostFields(
          postId: 'post-1',
          userId: 'builder-1',
          projectId: 'project-1',
          projectName: 'Master Bathroom',
          projectType: 'Bathroom Renovation',
          projectScope: 'Cosmetic',
          ownerName: 'Ahmad Paguta',
          materials: const [
            {'name': 'Ceramic Wall Tiles', 'quantity': 44, 'unit': 'pcs'},
          ],
          totalAreaSqm: 3.0,
          budget: 'medium',
          excludedWork: ExcludedWork.listToMaps(excluded),
        );

    test('an excluded line reaches the post', () {
      final data = post(excluded: const [_tile]);
      expect(data['excludedWork'], isA<List>());
      expect((data['excludedWork'] as List).single, _tile.toMap());
    });

    test('nothing excluded means the key is absent, not an empty list', () {
      expect(post().containsKey('excludedWork'), isFalse);
    });

    test('the field the dashboard already reads is untouched', () {
      final withExclusions = post(excluded: const [_tile]);
      final without = post();
      expect(withExclusions['materials'], without['materials']);
      expect(withExclusions['materialsCount'], without['materialsCount']);
      expect(withExclusions['projectScope'], 'Cosmetic');
    });
  });

  group('reopening a saved estimate', () {
    test('carries the exclusions it was saved with', () {
      final project = ProjectModel.fromMap('p1', {
        'projectName': 'Master Bathroom',
        'excludedWork': [_tile.toMap()],
      });
      expect(project.excludedWork, [_tile]);
    });

    test('an estimate saved before exclusions existed reads as none', () {
      final project = ProjectModel.fromMap('p1', {'projectName': 'Kitchen'});
      expect(project.excludedWork, isEmpty);
    });
  });

  group('the canvass sheet', () {
    test('carries the excluded lines alongside the materials', () {
      final data = BomExportData.fromMaterials(
        estimateName: 'Master Bathroom',
        renovationType: 'Bathroom Renovation',
        areaSqm: 3.0,
        materials: const [
          {'name': 'Ceramic Wall Tiles', 'quantity': 44, 'unit': 'pcs'},
        ],
        excluded: const [_tile],
      );
      expect(data.materials, hasLength(1));
      expect(data.excluded.single.label, contains('Ceramic Floor Tile'));
    });

    test('a sheet with nothing excluded has an empty list, not a null', () {
      final data = BomExportData.fromMaterials(
        estimateName: 'Master Bathroom',
        renovationType: 'Bathroom Renovation',
        areaSqm: 3.0,
        materials: const [],
      );
      expect(data.excluded, isEmpty);
    });
  });
}
