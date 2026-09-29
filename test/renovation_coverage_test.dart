import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';

/// Coverage — Full, Half, Partial — is how much of the space the job
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
      expect(RenovationCoverage.fromString('Half'), RenovationCoverage.half);
    });

    test('offers Full, Half and Partial, in that order', () {
      expect(RenovationCoverage.values.map((c) => c.label),
          ['Full', 'Half', 'Partial']);
    });

    test('an estimate saved as an extension reads as Full', () {
      // An extension was measured whole and sized from everything measured,
      // which is what Full does.
      expect(RenovationCoverage.fromString('extension'),
          RenovationCoverage.full);
      expect(RenovationCoverage.fromString('Extension'),
          RenovationCoverage.full);
    });

    test('only a partial job has a portion to describe', () {
      expect(RenovationCoverage.partial.hasPortion, isTrue);
      expect(RenovationCoverage.full.hasPortion, isFalse);
      expect(RenovationCoverage.half.hasPortion, isFalse);
    });

    test('only a half job is sized at half', () {
      expect(RenovationCoverage.half.isHalf, isTrue);
      expect(RenovationCoverage.full.isHalf, isFalse);
      expect(RenovationCoverage.partial.isHalf, isFalse);
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
        coverage: RenovationCoverage.half.name,
      );
      expect(data['projectScope'], 'Cosmetic');
      expect(data['coverage'], 'half');
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
        'projectName': 'Master Bedroom, left side',
        'projectScope': 'Structural',
        'coverage': 'half',
      });
      expect(project.scope, RenovationScope.structural);
      expect(project.coverage, RenovationCoverage.half);
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
}
