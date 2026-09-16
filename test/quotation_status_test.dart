import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/bidding/data/quotation_status.dart';

void main() {
  group('displayQuotationStatus', () {
    test('an open offer shows as it is', () {
      expect(
        displayQuotationStatus(
          rawStatus: 'submitted',
          quotationId: 'shop-1',
          selectedQuotationId: null,
        ),
        'submitted',
      );
    });

    test('a quotation with no status is pending', () {
      expect(
        displayQuotationStatus(
          rawStatus: null,
          quotationId: 'shop-1',
          selectedQuotationId: null,
        ),
        'pending',
      );
    });

    test('the quotation the builder selected shows as accepted', () {
      expect(
        displayQuotationStatus(
          rawStatus: 'Accepted',
          quotationId: 'shop-1',
          selectedQuotationId: 'shop-1',
        ),
        'accepted',
      );
      expect(
        displayQuotationStatus(
          rawStatus: 'partially_accepted',
          quotationId: 'shop-1',
          selectedQuotationId: 'shop-1',
        ),
        'partially_accepted',
      );
    });

    test('a selected quotation reads as accepted even if its own status lagged',
        () {
      // The card used to show "Pending" and "Selected supplier" at once,
      // which is the acceptance having written the estimate but not the
      // quotation. The estimate is the builder's own document, so it wins.
      for (final raw in ['submitted', 'pending', '', null]) {
        expect(
          displayQuotationStatus(
            rawStatus: raw,
            quotationId: 'shop-1',
            selectedQuotationId: 'shop-1',
          ),
          'accepted',
          reason: 'raw status: $raw',
        );
      }
    });

    test('a quotation claiming acceptance the builder never gave is an open offer',
        () {
      expect(
        displayQuotationStatus(
          rawStatus: 'accepted',
          quotationId: 'shop-2',
          selectedQuotationId: null,
        ),
        'submitted',
      );
    });

    test('a quotation claiming acceptance when another was selected is an open offer',
        () {
      expect(
        displayQuotationStatus(
          rawStatus: 'partially_accepted',
          quotationId: 'shop-2',
          selectedQuotationId: 'shop-1',
        ),
        'submitted',
      );
    });

    test('a rejection stands, since only the builder can record one', () {
      expect(
        displayQuotationStatus(
          rawStatus: 'rejected',
          quotationId: 'shop-2',
          selectedQuotationId: 'shop-1',
        ),
        'rejected',
      );
    });
  });

  group('quotationNeedsStatusRepair', () {
    test('a selected quotation still marked open needs the write finished', () {
      for (final raw in ['submitted', 'pending', '', null]) {
        expect(
          quotationNeedsStatusRepair(
            rawStatus: raw,
            quotationId: 'shop-1',
            selectedQuotationId: 'shop-1',
          ),
          isTrue,
          reason: 'raw status: $raw',
        );
      }
    });

    test('a quotation already marked accepted needs nothing', () {
      expect(
        quotationNeedsStatusRepair(
          rawStatus: 'accepted',
          quotationId: 'shop-1',
          selectedQuotationId: 'shop-1',
        ),
        isFalse,
      );
      expect(
        quotationNeedsStatusRepair(
          rawStatus: 'partially_accepted',
          quotationId: 'shop-1',
          selectedQuotationId: 'shop-1',
        ),
        isFalse,
      );
    });

    test('a quotation the estimate did not select is never repaired', () {
      expect(
        quotationNeedsStatusRepair(
          rawStatus: 'submitted',
          quotationId: 'shop-2',
          selectedQuotationId: null,
        ),
        isFalse,
      );
      expect(
        quotationNeedsStatusRepair(
          rawStatus: 'submitted',
          quotationId: 'shop-2',
          selectedQuotationId: 'shop-1',
        ),
        isFalse,
      );
    });
  });
}
