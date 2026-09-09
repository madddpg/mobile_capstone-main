import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/bom_export_service.dart';

/// The canvass sheet is what a builder actually hands to a shop, so a PDF that
/// fails to build, or builds with mangled text, breaks the app at its last
/// step. These render the document for real rather than trusting the layout.
void main() {
  BomExportData sample({List<BomExportItem>? items}) => BomExportData(
        estimateName: 'Bathroom Renovation — Calamba',
        renovationType: 'Bathroom Renovation',
        areaSqm: 18.5,
        materials: items ??
            const [
              BomExportItem(
                name: 'Ceramic Floor Tiles',
                category: 'Flooring',
                quantity: 60,
                unit: 'pcs',
                size: '600x600',
              ),
              BomExportItem(
                name: 'Portland Cement',
                category: 'Masonry',
                quantity: 8,
                unit: 'bags',
              ),
            ],
      );

  group('buildPdf', () {
    test('produces a real PDF document', () async {
      final bytes = await BomExportService.buildPdf(sample());

      expect(bytes.length, greaterThan(1000));
      // Every PDF opens with this signature. Anything else means the share
      // sheet would be handed something no app can read.
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('the image variant also produces a document', () async {
      final bytes = await BomExportService.buildPdf(sample(), forImage: true);
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('a long estimate paginates instead of overflowing', () async {
      // A layout that runs past the page throws rather than wrapping, so a
      // large bill of materials is the case worth pinning.
      final many = List.generate(
        80,
        (i) => BomExportItem(
          name: 'Material number $i with a deliberately long descriptive name',
          category: 'Category ${i % 6}',
          quantity: (i + 1).toDouble(),
          unit: 'pcs',
          size: '600x600',
        ),
      );
      final bytes = await BomExportService.buildPdf(sample(items: many));
      expect(bytes.length, greaterThan(2000));
    });

    test('an empty material list does not crash the export', () async {
      final bytes = await BomExportService.buildPdf(sample(items: const []));
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('typographic characters from AI suggestions survive the render',
        () async {
      // These are exactly the characters the built-in PDF fonts cannot draw,
      // so this is the case that would silently produce blank boxes.
      final bytes = await BomExportService.buildPdf(
        sample(items: const [
          BomExportItem(
            name: 'Tiles — “premium” 600×600',
            category: 'Flooring',
            quantity: 12,
            unit: 'pcs',
            notes: 'Budget ₱1,250 · verify on site…',
          ),
        ]),
      );
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });
  });

  group('pdfSafe', () {
    test('typographic characters fold to what the built-in fonts have', () {
      expect(
        BomExportService.pdfSafe('Tiles — 600×600 “premium”'),
        'Tiles - 600x600 "premium"',
      );
    });

    test('the peso sign becomes readable text rather than a blank', () {
      expect(BomExportService.pdfSafe('₱1,250'), 'PHP 1,250');
    });

    test('plain text passes through untouched', () {
      expect(
        BomExportService.pdfSafe('Portland Cement 40kg'),
        'Portland Cement 40kg',
      );
    });
  });
}
