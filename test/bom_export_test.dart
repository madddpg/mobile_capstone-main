import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/bom_export_service.dart';

BomExportData _sample({int extraItems = 0}) {
  return BomExportData.fromMaterials(
    estimateName: 'Bahay ni Ate — Bathroom Refresh',
    renovationType: 'Bathroom Renovation',
    areaSqm: 12.5,
    budgetPreference: 'Mid Budget',
    notes: 'Prefer non-slip finish. Shop can suggest an equivalent brand.',
    generatedAt: DateTime(2026, 7, 31),
    materials: [
      {
        'name': 'Ceramic floor tiles',
        'category': 'Floor Surface',
        'quantity': 13.75,
        'unit': 'sqm',
        'size': '600x600',
        'notes': 'non-slip',
      },
      {
        'name': 'Ceramic wall tiles',
        'category': 'Wall Surface',
        'quantity': 27.5,
        'unit': 'sqm',
        'size': '300x600',
      },
      {
        'name': 'Toilet bowl set',
        'category': 'Fixtures',
        'quantity': 1,
        'unit': 'pcs',
      },
      'Legacy material saved as plain text',
      for (var i = 0; i < extraItems; i++)
        {
          'name': 'Filler material $i',
          'category': 'Installation',
          'quantity': i + 1,
          'unit': 'bags',
        },
    ],
  );
}

void main() {
  test('builds a valid PDF for a normal estimate', () async {
    final bytes = await BomExportService.buildPdf(_sample());

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));

    final out = File('${Directory.systemTemp.path}/bom_sample.pdf');
    await out.writeAsBytes(bytes);
    // ignore: avoid_print
    print('wrote ${out.path} (${bytes.length} bytes)');
  });

  test('long lists paginate without throwing', () async {
    final bytes = await BomExportService.buildPdf(_sample(extraItems: 60));
    expect(bytes.length, greaterThan(1000));

    final out = File('${Directory.systemTemp.path}/bom_sample_long.pdf');
    await out.writeAsBytes(bytes);
  });

  test('image export PDF builds with the high-contrast option', () async {
    final bytes = await BomExportService.buildPdf(_sample(), forImage: true);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('legacy string materials keep their name', () {
    final data = _sample();
    expect(data.materials.length, 4);
    expect(data.materials.last.name, 'Legacy material saved as plain text');
    expect(data.materials.last.quantityLabel, '—');
  });

  test('file name is a safe slug with the date', () {
    expect(_sample().fileBaseName, 'bahay-ni-ate-bathroom-refresh-bom-20260731');
  });

  test('empty estimate name falls back', () {
    final data = BomExportData.fromMaterials(
      estimateName: '   ',
      renovationType: 'Kitchen Renovation',
      areaSqm: 0,
      materials: const [],
    );
    expect(data.estimateName, 'Material Estimate');
    expect(data.materials, isEmpty);
  });
}
