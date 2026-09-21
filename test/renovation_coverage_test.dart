import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

/// Coverage — Full, Partial, Extension — is how much of the space the job
/// covers, and is a different question from what kind of work it is. The two
/// must never be written into the same field: `projectScope` already means the
/// renovation type on a database a second application reads, and the words
/// "Full Renovation" and "Extension" are already parsed as types there.

void main() {
  group('coverage is its own dimension', () {
    test('an estimate saved before coverage existed covered the whole space',
        () {
      expect(RenovationCoverage.fromString(null), RenovationCoverage.full);
      expect(RenovationCoverage.fromString(''), RenovationCoverage.full);
    });

    test('reads its own stored name and its label', () {
      expect(RenovationCoverage.fromString('partial'),
          RenovationCoverage.partial);
      expect(RenovationCoverage.fromString('Extension'),
          RenovationCoverage.extension);
    });

    test('only a partial job has a portion to describe', () {
      expect(RenovationCoverage.partial.hasPortion, isTrue);
      expect(RenovationCoverage.full.hasPortion, isFalse);
      expect(RenovationCoverage.extension.hasPortion, isFalse);
    });

    test('only an extension measures new floor area', () {
      expect(RenovationCoverage.extension.isNewArea, isTrue);
      expect(RenovationCoverage.full.isNewArea, isFalse);
    });
  });

  // The bug this whole naming decision exists to avoid.
  group('coverage never collides with the renovation type', () {
    test('the type parser still reads the legacy words as types', () {
      expect(RenovationScope.fromString('Full Renovation'),
          RenovationScope.cosmetic);
      expect(
          RenovationScope.fromString('Extension'), RenovationScope.structural);
    });

    test('a post carries the type and the coverage in different fields', () {
      final data = projectPostFields(
        postId: 'post-1',
        userId: 'builder-1',
        projectId: 'project-1',
        projectName: 'Master Bathroom',
        projectType: 'Bathroom Renovation',
        projectScope: RenovationScope.cosmetic.label,
        ownerName: 'Ahmad Paguta',
        materials: const [],
        totalAreaSqm: 3.0,
        budget: 'medium',
        coverage: RenovationCoverage.extension.name,
      );
      expect(data['projectScope'], 'Cosmetic');
      expect(data['coverage'], 'extension');
    });

    test('a post without a coverage leaves the key out', () {
      final data = projectPostFields(
        postId: 'post-1',
        userId: 'builder-1',
        projectId: 'project-1',
        projectName: 'Master Bathroom',
        projectType: 'Bathroom Renovation',
        projectScope: 'Cosmetic',
        ownerName: 'Ahmad Paguta',
        materials: const [],
        totalAreaSqm: 3.0,
        budget: 'medium',
      );
      expect(data.containsKey('coverage'), isFalse);
      expect(data['projectScope'], 'Cosmetic');
    });

    test('a reopened estimate reads each field under its own meaning', () {
      final project = ProjectModel.fromMap('p1', {
        'projectName': 'Extension of Master Bedroom',
        'projectScope': 'Structural',
        'coverage': 'extension',
      });
      expect(project.scope, RenovationScope.structural);
      expect(project.coverage, RenovationCoverage.extension);
    });

    test('an estimate saved before coverage existed still reads its type', () {
      final project = ProjectModel.fromMap('p1', {
        'projectName': 'Old Estimate',
        'projectScope': 'Extension',
      });
      expect(project.scope, RenovationScope.structural);
      expect(project.coverage, RenovationCoverage.full);
    });
  });

  group('which coverages a project offers', () {
    test('a room that can gain floor area can be extended', () {
      for (final type in ['Bathroom Renovation', 'Kitchen Renovation']) {
        expect(
          RenovationTemplatesCatalog.offersCoverage(
              type, RenovationCoverage.extension),
          isTrue,
          reason: '$type can be extended',
        );
      }
    });

    test('work on a room that is already there cannot be an extension', () {
      for (final type in [
        'Floor Renovation',
        'Interior Painting',
        'Roof Repair',
        'Wall Finishing',
      ]) {
        expect(
          RenovationTemplatesCatalog.offersCoverage(
              type, RenovationCoverage.extension),
          isFalse,
          reason: '$type adds no floor area',
        );
      }
    });

    test('every project can be done whole or in part', () {
      for (final type in RenovationTemplatesCatalog.projectTypes) {
        final offered = RenovationTemplatesCatalog.coveragesFor(type);
        expect(offered, contains(RenovationCoverage.full));
        expect(offered, contains(RenovationCoverage.partial));
      }
    });

    test('an unavailable coverage says why', () {
      expect(
        RenovationTemplatesCatalog.unavailableCoverageReason(
            'Interior Painting', RenovationCoverage.extension),
        contains('does not add floor area'),
      );
    });
  });
}
