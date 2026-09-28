import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/data/remainder_canvass.dart';

/// Reading a partial acceptance back, and turning what was left into a new
/// estimate. A wrong line here sends a builder to buy the wrong materials, or
/// leaks one shop's prices to every other shop.
void main() {
  Map<String, dynamic> partlyAccepted() => {
        'status': 'partially_accepted',
        'estimatedTotal': 11980,
        'acceptedTotal': 5960,
        'items': [
          {'name': 'Portland Cement', 'quantity': 18, 'unit': 'bags', 'unitPrice': 260, 'accepted': true},
          {'name': 'Floor Tiles', 'quantity': 61, 'unit': 'pcs', 'subtotal': 4500, 'accepted': false},
          {'name': 'Tile Adhesive', 'quantity': 4, 'unit': 'bags', 'unitPrice': 320, 'accepted': true},
          {'name': 'Tile Grout (2 kg)', 'quantity': 6, 'unit': 'packs', 'unitPrice': 120, 'accepted': false},
        ],
      };

  group('readAcceptance', () {
    test('splits a partly accepted quotation by the builder\'s flags', () {
      final summary = readAcceptance(partlyAccepted());

      expect(summary.kept.map(quotedItemName),
          ['Portland Cement', 'Tile Adhesive']);
      expect(summary.dropped.map(quotedItemName),
          ['Floor Tiles', 'Tile Grout (2 kg)']);
      expect(summary.isPartial, isTrue);
      expect(summary.totalCount, 4);
    });

    test('uses the total the acceptance recorded', () {
      expect(readAcceptance(partlyAccepted()).keptTotal, 5960);
    });

    test('ignores line flags on a quotation that was not partly accepted', () {
      // A shop could put accepted:false on its own open offer. Only the
      // builder's acceptance gives the flags meaning.
      final open = partlyAccepted()..['status'] = 'submitted';
      final summary = readAcceptance(open);

      expect(summary.dropped, isEmpty);
      expect(summary.isPartial, isFalse);
    });

    test('a full acceptance has nothing left over', () {
      final full = partlyAccepted()..['status'] = 'accepted';
      expect(readAcceptance(full).dropped, isEmpty);
    });
  });

  group('remainderMaterials', () {
    final estimate = [
      {'name': 'Floor Tiles', 'quantity': 61, 'unit': 'pcs', 'size': '600x600', 'category': 'Floor Surface'},
      {'name': 'Tile Grout (2 kg)', 'quantity': 6, 'unit': 'packs', 'size': null, 'category': 'Tile Setting'},
      {'name': 'Portland Cement', 'quantity': 18, 'unit': 'bags', 'size': null, 'category': 'Masonry'},
    ];

    test('uses the builder\'s own entries for the lines left behind', () {
      final dropped = readAcceptance(partlyAccepted()).dropped;
      final materials =
          remainderMaterials(dropped: dropped, estimateMaterials: estimate);

      expect(materials, [estimate[0], estimate[1]]);
    });

    test('matches names regardless of case and punctuation', () {
      final materials = remainderMaterials(
        dropped: [
          {'name': 'FLOOR tiles', 'unitPrice': 75, 'accepted': false},
        ],
        estimateMaterials: estimate,
      );

      expect(materials.single['size'], '600x600');
      expect(materials.single['quantity'], 61);
    });

    test('never carries a shop price into the new estimate', () {
      // An unmatched line falls back to the shop's wording, and that is
      // exactly where a price could leak to every other shop.
      final materials = remainderMaterials(
        dropped: [
          {
            'name': 'Ceramic Wall Tiles',
            'quantity': 265,
            'unit': 'pcs',
            'size': '300x600',
            'unitPrice': 42,
            'subtotal': 11130,
            'accepted': false,
          },
        ],
        estimateMaterials: estimate,
      );

      final line = materials.single;
      expect(line['name'], 'Ceramic Wall Tiles');
      expect(line['quantity'], 265);
      expect(line['size'], '300x600');
      for (final key in ['unitPrice', 'subtotal', 'price', 'accepted']) {
        expect(line.containsKey(key), isFalse, reason: key);
      }
    });

    test('a line listed twice is canvassed once', () {
      final materials = remainderMaterials(
        dropped: [
          {'name': 'Floor Tiles'},
          {'name': 'Floor tiles'},
        ],
        estimateMaterials: estimate,
      );
      expect(materials, hasLength(1));
    });
  });

  group('remainderProjectName', () {
    test('marks the estimate as the remaining lines', () {
      expect(remainderProjectName('Kitchen Renovation'),
          'Kitchen Renovation (remaining lines)');
    });

    test('stays within the 200-character limit the posting rule enforces', () {
      expect(remainderProjectName('x' * 250).length, 200);
    });
  });

  // The leftover lines go out as an estimate in their own right, so shops must
  // receive them exactly as they receive any estimate.
  group('remainderPostData', () {
    // A parent estimate as the app posts it, with a shop already selected.
    final parent = <String, dynamic>{
      'projectName': 'Bathroom',
      'projectType': 'Floor Renovation',
      'projectScope': 'Structural',
      'renovationTypes': ['cosmetic', 'structural'],
      'coverage': 'partial',
      'ownerName': 'Cups Cuddles',
      'totalAreaSqm': 4.05,
      'budget': 'medium',
      'siteDetails': {'job': 'floorOnly', 'lengthM': 1.5, 'widthM': 2.7},
      'selectedQuotationId': 'q-b',
      'excludedWork': [
        {'name': 'Repaint'},
      ],
    };

    Map<String, dynamic> post() => remainderPostData(
          parent: parent,
          parentPostId: 'post-1',
          newPostId: 'post-2',
          userId: 'builder-1',
          savedProjectId: 'saved-2',
          materials: const [
            {'name': 'Floor Tiles', 'quantity': 12, 'unit': 'pcs'},
          ],
        );

    test('names the builder, as every estimate does', () {
      // Built by hand before, it left the name off and shops saw an estimate
      // from nobody.
      expect(post()['ownerName'], 'Cups Cuddles');
    });

    test('keeps the renovation types, coverage and measured room', () {
      final data = post();
      expect(data['renovationTypes'], ['cosmetic', 'structural']);
      expect(data['coverage'], 'partial');
      expect(data['siteDetails'], parent['siteDetails']);
      expect(data['projectScope'], 'Structural');
    });

    test('opens like a first posting, linked to the estimate it came from', () {
      final data = post();
      expect(data['status'], 'open');
      expect(data['quotationCount'], 0);
      expect(data['userId'], 'builder-1');
      expect(data['builderId'], 'builder-1');
      expect(data['projectId'], 'saved-2');
      expect(data['parentPostId'], 'post-1');
      expect(data['materialsCount'], 1);
      expect(data['projectName'], 'Bathroom (remaining lines)');
    });

    test('carries nothing of the first estimate\'s selection or prices', () {
      final data = post();
      for (final key in [
        'selectedQuotationId',
        'excludedWork',
        'price',
        'unitPrice',
        'estimatedTotal',
      ]) {
        expect(data.containsKey(key), isFalse, reason: key);
      }
    });

    test('falls back to the builder\'s email when the parent has no name', () {
      final data = remainderPostData(
        parent: {...parent}..remove('ownerName'),
        parentPostId: 'post-1',
        newPostId: 'post-2',
        userId: 'builder-1',
        savedProjectId: 'saved-2',
        materials: const [
          {'name': 'Floor Tiles'},
        ],
        fallbackOwnerEmail: 'cups@example.com',
      );
      expect(data['ownerName'], 'cups');
    });
  });

  group('remainderPostIdFor', () {
    test('finds the leftover estimate for the quotation it came from', () {
      final post = {'remainderPostId': 'post-2', 'remainderQuotationId': 'q-a'};
      expect(remainderPostIdFor(post, 'q-a'), 'post-2');
    });

    test('lets a later selection post its own leftovers', () {
      // Shop A's leftovers were canvassed, then A was cancelled and part of
      // shop B's offer taken. B's lines are different lines.
      final post = {'remainderPostId': 'post-2', 'remainderQuotationId': 'q-a'};
      expect(remainderPostIdFor(post, 'q-b'), isEmpty);
    });

    test('reads a link saved before it named its quotation', () {
      expect(remainderPostIdFor({'remainderPostId': 'post-2'}, 'q-a'), 'post-2');
    });

    test('is empty when nothing was canvassed', () {
      expect(remainderPostIdFor({}, 'q-a'), isEmpty);
    });
  });
}
