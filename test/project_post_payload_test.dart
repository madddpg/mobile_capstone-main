import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';

void main() {
  Map<String, dynamic> post({
    String ownerName = 'Ahmad Paguta',
    String remarks = '',
    Map<String, dynamic>? siteDetails,
  }) => projectPostFields(
    postId: 'post-1',
    userId: 'builder-1',
    projectId: 'project-1',
    projectName: 'Master Bathroom',
    projectType: 'Bathroom Renovation',
    projectScope: 'Cosmetic',
    ownerName: ownerName,
    materials: const [
      {'name': 'Ceramic Floor Tiles', 'quantity': 9, 'unit': 'pcs'},
    ],
    totalAreaSqm: 3.0,
    budget: 'medium',
    siteDetails: siteDetails,
    remarks: remarks,
  );

  group('the shop dashboard contract', () {
    test('carries every field the dashboard reads', () {
      final data = post();
      for (final field in [
        'postId',
        'userId',
        'projectName',
        'projectType',
        'projectScope',
        'ownerName',
        'materials',
        'materialsCount',
        'totalAreaSqm',
        'budget',
      ]) {
        expect(data, contains(field), reason: 'missing $field');
      }
    });

    test('the owner id is written under both spellings the rules accept', () {
      final data = post();
      expect(data['userId'], 'builder-1');
      expect(data['builderId'], 'builder-1');
    });

    test('materialsCount matches the list, so a board cannot disagree', () {
      expect(post()['materialsCount'], 1);
    });

    test('optional fields are left out rather than written blank', () {
      final data = post();
      expect(data.containsKey('remarks'), isFalse);
      expect(data.containsKey('siteDetails'), isFalse);
    });

    test('a note and measurements are included when there are any', () {
      final data = post(
        remarks: '  Prefer Holcim cement  ',
        siteDetails: const {'lengthM': 2.0},
      );
      expect(data['remarks'], 'Prefer Holcim cement');
      expect(data['siteDetails'], isA<Map<String, dynamic>>());
    });
  });

  group('ownerDisplayName', () {
    test('uses the builder name when the profile has one', () {
      expect(
        ownerDisplayName(firstName: 'Ahmad', lastName: 'Paguta'),
        'Ahmad Paguta',
      );
      expect(ownerDisplayName(firstName: 'Ahmad'), 'Ahmad');
    });

    test(
      'falls back to the email name, so a shop has something to call them',
      () {
        expect(
          ownerDisplayName(
            firstName: '',
            lastName: '',
            email: 'cups@gmail.com',
          ),
          'cups',
        );
      },
    );

    test('never returns an empty name', () {
      expect(ownerDisplayName(), 'Builder');
      expect(ownerDisplayName(email: 'not-an-email'), 'Builder');
    });
  });

  group('photo keys for the shop dashboard', () {
    List<dynamic> keyed(List<dynamic> lines) => withPhotoKeys(lines);

    test('a material with a bundled photo carries its key', () {
      final lines = keyed([
        {'name': 'Concrete Hollow Block (CHB)', 'quantity': 120, 'unit': 'pcs'},
        {'name': 'Washed Sand - Floor Screed', 'quantity': 0.5, 'unit': 'cu.m'},
        {
          'name': 'Sanitary Silicone Sealant (300ml)',
          'quantity': 1,
          'unit': 'tube',
        },
      ]);
      expect(
        [for (final l in lines) (l as Map)['photoKey']],
        ['chb', 'washed_sand', 'silicone'],
      );
    });

    test('every key names a photo the app bundles', () {
      final line =
          keyed([
                {'name': 'Paint Roller Set (7") with Tray', 'unit': 'set'},
              ]).single
              as Map;
      expect(kBundledMaterialPhotos, contains(line['photoKey']));
    });

    test(
      'lines without a photo, old text lines and set keys are unchanged',
      () {
        const noPhoto = {
          'name': 'Ceramic Floor Tiles',
          'quantity': 9,
          'unit': 'pcs',
        };
        const preset = {
          'name': 'Concrete Hollow Block (CHB)',
          'photoKey': 'own',
        };
        final lines = keyed([noPhoto, 'Old plain line', preset]);
        expect(lines[0], noPhoto);
        expect((lines[0] as Map).containsKey('photoKey'), isFalse);
        expect(lines[1], 'Old plain line');
        expect(lines[2], preset);
      },
    );

    test('a post carries the keys and keeps the line count', () {
      final data = projectPostFields(
        postId: 'p',
        userId: 'u',
        projectId: 'j',
        projectName: 'Wall',
        projectType: 'Wall',
        projectScope: 'Structural',
        ownerName: 'A',
        materials: const [
          {
            'name': 'Concrete Hollow Block (CHB)',
            'quantity': 120,
            'unit': 'pcs',
          },
          {'name': 'Ceramic Floor Tiles', 'quantity': 9, 'unit': 'pcs'},
        ],
        totalAreaSqm: 4,
        budget: 'low',
      );
      final materials = data['materials'] as List;
      expect((materials[0] as Map)['photoKey'], 'chb');
      expect((materials[1] as Map).containsKey('photoKey'), isFalse);
      expect(data['materialsCount'], 2);
    });
  });
}
