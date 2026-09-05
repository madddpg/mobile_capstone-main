import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:iconstruct/features/project_creation/data/bom_export.dart';

/// Renders a bill of materials as a canvass sheet a builder can hand to a
/// hardware shop — as a PDF, as images for chat apps, or straight to a printer.
class _ExportPalette {
  const _ExportPalette({
    required this.page,
    required this.headerBg,
    required this.headerFg,
    required this.ink,
    required this.muted,
    required this.line,
    required this.band,
    required this.tableHeaderBg,
    required this.tableHeaderFg,
    required this.notesBg,
    required this.filledHeader,
  });

  final PdfColor page;
  final PdfColor headerBg;
  final PdfColor headerFg;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor line;
  final PdfColor band;
  final PdfColor tableHeaderBg;
  final PdfColor tableHeaderFg;
  final PdfColor notesBg;
  final bool filledHeader;
}

class BomExportService {
  BomExportService._();

  static const _appPalette = _ExportPalette(
    page: PdfColor.fromInt(0xFFFFFFFF),
    headerBg: PdfColor.fromInt(0xFF2C3E50),
    headerFg: PdfColor.fromInt(0xFFEDE4D4),
    ink: PdfColor.fromInt(0xFF1E3042),
    muted: PdfColor.fromInt(0xFF5A6E7E),
    line: PdfColor.fromInt(0xFFBFC8D2),
    band: PdfColor.fromInt(0xFFEFEAE0),
    tableHeaderBg: PdfColor.fromInt(0xFF2C3E50),
    tableHeaderFg: PdfColor.fromInt(0xFFEDE4D4),
    notesBg: PdfColor.fromInt(0xFFF6F1E7),
    filledHeader: true,
  );

  /// High-contrast sheet for chat/image export: white page, black type.
  static const _imagePalette = _ExportPalette(
    page: PdfColors.white,
    headerBg: PdfColors.white,
    headerFg: PdfColors.black,
    ink: PdfColors.black,
    muted: PdfColor.fromInt(0xFF222222),
    line: PdfColors.black,
    band: PdfColors.white,
    tableHeaderBg: PdfColors.white,
    tableHeaderFg: PdfColors.black,
    notesBg: PdfColors.white,
    filledHeader: false,
  );

  static Future<Uint8List> buildPdf(
    BomExportData data, {
    bool forImage = false,
  }) async {
    final palette = forImage ? _imagePalette : _appPalette;
    final doc = pw.Document(
      title: '${data.estimateName} — Material Canvass Sheet',
      author: 'iConstruct',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: palette.page),
          ),
        ),
        header: (context) => context.pageNumber == 1
            ? _header(data, palette)
            : _continuedHeader(data, palette),
        footer: (context) => _footer(context, palette),
        build: (context) => [
          _summary(data, palette),
          pw.SizedBox(height: 16),
          _materialsTable(data, palette),
          pw.SizedBox(height: 18),
          _shopBlock(data, palette),
        ],
      ),
    );

    return doc.save();
  }

  /// Opens the system share sheet with the canvass sheet as a PDF.
  static Future<void> sharePdf(BomExportData data) async {
    final bytes = await buildPdf(data);
    await SharePlus.instance.share(
      ShareParams(
        subject: '${data.estimateName} — material list',
        text: _shareMessage(data),
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: '${data.fileBaseName}.pdf',
          ),
        ],
        fileNameOverrides: ['${data.fileBaseName}.pdf'],
      ),
    );
  }

  /// Shares the sheet as PNG pages, which chat apps preview inline.
  static Future<void> shareImages(BomExportData data) async {
    final bytes = await buildPdf(data, forImage: true);

    final files = <XFile>[];
    final names = <String>[];
    var page = 1;
    await for (final raster in Printing.raster(bytes, dpi: 144)) {
      final png = await raster.toPng();
      files.add(
        XFile.fromData(
          png,
          mimeType: 'image/png',
          name: '${data.fileBaseName}-p$page.png',
        ),
      );
      names.add('${data.fileBaseName}-p$page.png');
      page++;
    }

    if (files.isEmpty) {
      await sharePdf(data);
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        subject: '${data.estimateName} — material list',
        text: _shareMessage(data),
        files: files,
        fileNameOverrides: names,
      ),
    );
  }

  /// Opens the platform print / save-as-PDF preview.
  static Future<void> printSheet(BomExportData data) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(data),
      name: data.fileBaseName,
    );
  }

  static String _shareMessage(BomExportData data) {
    final area = data.areaSqm > 0
        ? ' (${_trimDouble(data.areaSqm)} sq.m)'
        : '';
    return 'Requesting a quotation for ${data.materials.length} materials — '
        '${data.estimateName}$area. Prices and availability are up to you; '
        'please fill in the blank columns.';
  }

  static pw.Widget _header(BomExportData data, _ExportPalette p) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: pw.BoxDecoration(
              color: p.headerBg,
              border: p.filledHeader
                  ? null
                  : pw.Border(bottom: pw.BorderSide(color: p.line, width: 1)),
            ),
            width: double.infinity,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'iConstruct',
                      style: pw.TextStyle(
                        color: p.headerFg,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Material Canvass Sheet',
                      style: pw.TextStyle(color: p.headerFg, fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Prepared',
                      style: pw.TextStyle(color: p.headerFg, fontSize: 8),
                    ),
                    pw.Text(
                      _formatDate(data.generatedAt),
                      style: pw.TextStyle(
                        color: p.headerFg,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            pdfSafe(data.estimateName),
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _continuedHeader(BomExportData data, _ExportPalette p) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: p.line)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            pdfSafe(data.estimateName),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: p.ink,
            ),
          ),
          pw.Text(
            'Material Canvass Sheet · continued',
            style: pw.TextStyle(fontSize: 9, color: p.muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context, _ExportPalette p) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: p.line)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              'Generated by iConstruct. Prices are set by the hardware shop; '
              'no payment is processed in the app.',
              style: pw.TextStyle(fontSize: 7.5, color: p.muted),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: p.muted),
          ),
        ],
      ),
    );
  }
  static pw.Widget _summary(BomExportData data, _ExportPalette p) {
    final entries = <List<String>>[
      ['Renovation type', data.renovationType.isEmpty ? '-' : data.renovationType],
      [
        'Project area',
        data.areaSqm > 0 ? '${_trimDouble(data.areaSqm)} sq.m' : 'Not set',
      ],
      ['Materials', '${data.materials.length} items'],
      [
        'Budget preference',
        (data.budgetPreference ?? '').trim().isEmpty
            ? 'Not set'
            : data.budgetPreference!.trim(),
      ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            for (final entry in entries)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      entry[0].toUpperCase(),
                      style: pw.TextStyle(fontSize: 7, color: p.muted),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      pdfSafe(entry[1]),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if ((data.notes ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: p.notesBg,
              borderRadius: pw.BorderRadius.circular(4),
              border: p.filledHeader
                  ? null
                  : pw.Border.all(color: p.line, width: 0.5),
            ),
            child: pw.Text(
              pdfSafe('Notes: ${data.notes!.trim()}'),
              style: pw.TextStyle(fontSize: 9, color: p.ink),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _materialsTable(BomExportData data, _ExportPalette p) {
    const headers = [
      '#',
      'Material',
      'Size',
      'Qty',
      'Unit',
      'Unit Price (PHP)',
      'Amount (PHP)',
    ];

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: p.tableHeaderBg),
        children: [
          for (var i = 0; i < headers.length; i++)
            _cell(
              headers[i],
              palette: p,
              bold: true,
              color: p.tableHeaderFg,
              align: i >= 3 ? pw.TextAlign.center : pw.TextAlign.left,
            ),
        ],
      ),
    ];

    var index = 1;
    data.byCategory.forEach((category, items) {
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: p.band),
          children: [
            _cell('', palette: p),
            _cell(category.toUpperCase(), palette: p, bold: true, size: 8),
            _cell('', palette: p),
            _cell('', palette: p),
            _cell('', palette: p),
            _cell('', palette: p),
            _cell('', palette: p),
          ],
        ),
      );

      for (final item in items) {
        rows.add(
          pw.TableRow(
            children: [
              _cell('${index++}', palette: p, align: pw.TextAlign.center, size: 8.5),
              _cell(
                item.name,
                palette: p,
                bold: true,
                secondary: item.notes,
              ),
              _cell(item.size ?? '-', palette: p, size: 8.5),
              _cell(item.quantityLabel, palette: p, align: pw.TextAlign.center),
              _cell(
                item.unit.isEmpty ? '-' : item.unit,
                palette: p,
                align: pw.TextAlign.center,
                size: 8.5,
              ),
              _cell('', palette: p),
              _cell('', palette: p),
            ],
          ),
        );
      }
    });

    rows.add(
      pw.TableRow(
        children: [
          _cell('', palette: p),
          _cell('GRAND TOTAL', palette: p, bold: true),
          _cell('', palette: p),
          _cell('', palette: p),
          _cell('', palette: p),
          _cell('', palette: p),
          _cell('', palette: p),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: p.line, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FlexColumnWidth(3.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FixedColumnWidth(38),
        4: pw.FixedColumnWidth(40),
        5: pw.FlexColumnWidth(1.4),
        6: pw.FlexColumnWidth(1.4),
      },
      children: rows,
    );
  }

  static pw.Widget _cell(
    String text, {
    required _ExportPalette palette,
    bool bold = false,
    double size = 9.5,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
    String? secondary,
  }) {
    final ink = color ?? palette.ink;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Column(
        crossAxisAlignment: align == pw.TextAlign.center
            ? pw.CrossAxisAlignment.center
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(text),
            textAlign: align,
            style: pw.TextStyle(
              fontSize: size,
              color: ink,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          if (secondary != null && secondary.trim().isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              pdfSafe(secondary.trim()),
              style: pw.TextStyle(fontSize: 7.5, color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _shopBlock(BomExportData data, _ExportPalette p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: p.line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'For the hardware shop',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: p.ink,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _blankField('Shop name', p),
              _blankField('Contact number', p),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _blankField('Quotation valid until', p),
              _blankField('Estimated delivery / lead time', p),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'You can also submit this quotation digitally through iConstruct so '
            'the builder can compare it with other shops.',
            style: pw.TextStyle(fontSize: 8, color: p.muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _blankField(String label, _ExportPalette p) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(fontSize: 7, color: p.muted),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              height: 0.6,
              width: double.infinity,
              color: p.line,
            ),
          ],
        ),
      ),
    );
  }

  /// The built-in PDF fonts only cover Latin-1, so typographic characters that
  /// arrive from AI suggestions or a builder's own notes are folded to ASCII
  /// instead of rendering as blanks.
  static String pdfSafe(String text) {
    const replacements = {
      '\u2014': '-',
      '\u2013': '-',
      '\u2018': "'",
      '\u2019': "'",
      '\u201C': '"',
      '\u201D': '"',
      '\u2026': '...',
      '\u2022': '-',
      '\u00D7': 'x',
      '\u20B1': 'PHP ',
      '\u20AC': 'EUR ',
      '\u2192': '->',
      '\u00A0': ' ',
    };

    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final mapped = replacements[char];
      if (mapped != null) {
        buffer.write(mapped);
      } else if (rune <= 0xFF) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _trimDouble(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
