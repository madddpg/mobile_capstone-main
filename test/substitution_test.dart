import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/data/remainder_canvass.dart';
import 'package:iconstruct/features/bidding/widgets/line_selection_sheet.dart';

/// A shop that does not stock a material can quote its own product in its
/// place. The dashboard stores the shop's product as the line's name, the
/// builder's material as `requestedName`, and `status: "substituted"`. These
/// lock in that every screen reads such a line as an answer to what was asked
/// for, and shows it as a substitute.

/// Exactly as the shop dashboard stored it.
Map<String, dynamic> _laway() => {
      'category': 'Tile Setting',
      'lineNote': '',
      'price': 343,
      'productName': 'laway',
      'qty': 20,
      'requestedName': 'Tile Adhesive (25 kg)',
      'size': '',
      'status': 'substituted',
      'subtotal': 6860,
      'unit': 'bags',
    };

Map<String, dynamic> _paint() => {
      'productName': 'Interior Latex Paint (4 L)',
      'qty': 4,
      'unit': 'gal',
      'price': 10,
      'subtotal': 40,
    };

void main() {
  group('a substituted line', () {
    test('is recognised from the dashboard\'s status', () {
      expect(isSubstitutedLine(_laway()), isTrue);
      expect(isSubstitutedLine(_paint()), isFalse);
    });

    test('is recognised by a different requested name alone', () {
      final line = _laway()..remove('status');
      expect(isSubstitutedLine(line), isTrue);
    });

    test('is not one when the requested name is the product itself', () {
      expect(
        isSubstitutedLine({
          'productName': 'Portland Cement',
          'requestedName': 'portland cement',
        }),
        isFalse,
      );
    });

    test('names the shop\'s product, and answers the builder\'s material', () {
      expect(quotedItemName(_laway()), 'laway');
      expect(requestedItemName(_laway()), 'Tile Adhesive (25 kg)');
      expect(requestedItemName(_paint()), 'Interior Latex Paint (4 L)');
    });
  });

  group('the price comparison', () {
    final bom = [
      const QuotedLine(name: 'Tile Adhesive (25 kg)', quantity: 20),
      const QuotedLine(name: 'Interior Latex Paint (4 L)', quantity: 4),
    ];
    final quote = parseQuotedLines({
      'items': [_laway(), _paint()],
    });

    test('keeps what the line substitutes for', () {
      final line = quote.firstWhere((l) => l.name == 'laway');
      expect(line.isSubstitute, isTrue);
      expect(line.requestedName, 'Tile Adhesive (25 kg)');
    });

    test('matches a substitute to the material that was asked for', () {
      final line = findQuotedLine(quote, 'Tile Adhesive (25 kg)');
      expect(line?.name, 'laway');
      expect(line?.lineTotal, 6860);
    });

    test('counts the substitute toward the shop\'s coverage', () {
      final shop = BidQuote(
        id: 'q1',
        shopName: 'Shop',
        estimatedTotal: 6900,
        leadTimeRaw: '',
        materialsCovered: 2,
        lines: quote,
      );
      expect(bomCoverageCount(bom, shop), 2);
      expect(unquotedBomItems(bom, shop), isEmpty);
    });

    test('does not list the substitute as an extra', () {
      final shop = BidQuote(
        id: 'q1',
        shopName: 'Shop',
        estimatedTotal: 6900,
        leadTimeRaw: '',
        materialsCovered: 2,
        lines: quote,
      );
      expect(extraQuotedLines(bom, shop), isEmpty);
    });
  });

  test('a dropped substitute is re-canvassed as the builder\'s material', () {
    final out = remainderMaterials(
      dropped: [_laway()],
      estimateMaterials: [
        {'name': 'Tile Adhesive (25 kg)', 'quantity': 20, 'unit': 'bags'},
      ],
    );
    expect(out.single['name'], 'Tile Adhesive (25 kg)');
    expect(out.single.containsKey('price'), isFalse);
  });

  group('the select-shop modal', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> items,
        {double total = 0}) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SelectShopSheet(
              items: items,
              shopName: 'Chito Hardware',
              quotedTotal: total,
            ),
          ),
        ),
      ));
    }

    testWidgets('shows a substitute and what it replaces', (tester) async {
      await pump(tester, [_paint(), _laway()]);

      expect(find.text('laway'), findsOneWidget);
      expect(find.text('SUBSTITUTE'), findsOneWidget);
      expect(find.text('instead of Tile Adhesive (25 kg)'), findsOneWidget);
      expect(find.text('20 bags × ₱343'), findsOneWidget);
      expect(find.text('2 lines quoted · 1 substitute'), findsOneWidget);
      expect(find.text('₱6,900'), findsOneWidget);
    });

    testWidgets('unticking a line takes it out of the total', (tester) async {
      await pump(tester, [_paint(), _laway()]);

      await tester.tap(find.text('laway'));
      await tester.pump();

      expect(find.text('1 of 2 lines'), findsOneWidget);
      expect(find.text('₱40'), findsWidgets);
      expect(find.text('Accept 1 line and chat'), findsOneWidget);
    });

    testWidgets('a lump-sum offer is accepted whole', (tester) async {
      await pump(tester, const [], total: 12500);

      expect(find.text('One price for the whole order'), findsOneWidget);
      expect(find.text('₱12,500'), findsOneWidget);
      expect(find.text('Accept offer and chat'), findsOneWidget);
    });
  });
}
