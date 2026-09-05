import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';

void main() {
  group('ProjectLifecycle card labels', () {
    test('use short chip copy instead of long waiting labels', () {
      expect(
        ProjectLifecycle.cardLabel(ProjectLifecycle.waitingForQuotations),
        'Awaiting bids',
      );
      expect(
        ProjectLifecycle.cardLabel(ProjectLifecycle.receivingQuotations),
        'New bids',
      );
      expect(
        ProjectLifecycle.cardLabel(ProjectLifecycle.supplierSelected),
        'Supplier picked',
      );
    });

    test('nextAction names the concrete next step for bids', () {
      expect(
        ProjectLifecycle.nextAction(
          ProjectLifecycle.receivingQuotations,
          bidCount: 1,
        ),
        'Compare 1 bid and pick a supplier',
      );
      expect(
        ProjectLifecycle.nextAction(
          ProjectLifecycle.receivingQuotations,
          bidCount: 3,
        ),
        'Compare 3 bids and pick a supplier',
      );
    });
  });
}
