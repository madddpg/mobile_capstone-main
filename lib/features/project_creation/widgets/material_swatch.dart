import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';

/// Shows a material the way it looks on the hardware shelf.
///
/// Renders the bundled photograph when the material has one, and falls back to
/// a drawn glyph when it does not. The photo is always preferred: a buyer
/// matching goods at a counter needs the actual product, not a drawing of it.
/// Add photos under `assets/images/materials/` and list their keys in
/// `kBundledMaterialPhotos`.
///
/// Both paths are static images. Nothing here animates.
///
/// [size] is the selected spec string from the BOM row. It is not decoration:
/// a 300×300 tile draws a denser grid than a 600×600, a subway tile draws in a
/// brick bond, a 6" CHB draws deeper than a 4", and a 16 mm bar draws thicker
/// than a 10 mm. What the user sees on the card matches what they ordered.
class MaterialSwatch extends StatelessWidget {
  final MaterialVisual visual;

  /// Selected spec for the row, e.g. `600x600`, `4"`, `10mm`. Optional.
  final String? size;

  final double dimension;

  /// Draw the rounded plate behind the glyph. Off for large hero renders that
  /// already sit inside their own container.
  final bool showPlate;

  const MaterialSwatch({
    super.key,
    required this.visual,
    this.size,
    this.dimension = 44,
    this.showPlate = true,
  });

  @override
  Widget build(BuildContext context) {
    // Photograph first. A drawing is an interpretation of the goods; someone
    // matching an item against a hardware shelf needs the real product. The
    // glyph only stands in where no photo has been supplied yet.
    if (kBundledMaterialPhotos.contains(visual.assetKey)) {
      return SizedBox(
        width: dimension,
        height: dimension,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dimension * 0.24),
          child: Image.asset(
            materialPhotoPath(visual.assetKey),
            width: dimension,
            height: dimension,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => _drawn(),
          ),
        ),
      );
    }
    return _drawn();
  }

  Widget _drawn() {
    return SizedBox(
      width: dimension,
      height: dimension,
      child: CustomPaint(
        painter: _GlyphPainter(
          visual: visual,
          spec: _SpecHint.parse(size),
          showPlate: showPlate,
        ),
        isComplex: true,
      ),
    );
  }
}

/// Numbers pulled out of a spec string so the drawing can respond to it.
class _SpecHint {
  /// Tile face width in mm, or block thickness / bar diameter in mm.
  final double? widthMm;
  final double? lengthMm;

  const _SpecHint({this.widthMm, this.lengthMm});

  static const empty = _SpecHint();

  static _SpecHint parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    final s = raw.toLowerCase();

    // "600x600", "300 × 600 mm", "600 x 1200"
    final pair = RegExp(r'(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)').firstMatch(s);
    if (pair != null) {
      return _SpecHint(
        widthMm: double.tryParse(pair.group(1)!),
        lengthMm: double.tryParse(pair.group(2)!),
      );
    }

    // Inch thickness: 4", 6 inch, 1/2"
    final inch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:"|inch|in\b)').firstMatch(s);
    if (inch != null) {
      final v = double.tryParse(inch.group(1)!);
      if (v != null) return _SpecHint(widthMm: v * 25.4);
    }

    // Millimetre diameter: 10mm, 12 mm
    final mm = RegExp(r'(\d+(?:\.\d+)?)\s*mm').firstMatch(s);
    if (mm != null) return _SpecHint(widthMm: double.tryParse(mm.group(1)!));

    return empty;
  }
}

class _GlyphPainter extends CustomPainter {
  final MaterialVisual visual;
  final _SpecHint spec;
  final bool showPlate;

  _GlyphPainter({
    required this.visual,
    required this.spec,
    required this.showPlate,
  });

  Color get _base => visual.base;
  Color get _accent => visual.accent;

  Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Paint _line(Color c, [double w = 2]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Color get _edge => Color.alphaBlend(Colors.black.withValues(alpha: 0.35), _base);
  Color get _shade => Color.alphaBlend(Colors.black.withValues(alpha: 0.18), _base);
  Color get _light => Color.alphaBlend(Colors.white.withValues(alpha: 0.28), _base);

  @override
  void paint(Canvas canvas, Size size) {
    if (showPlate) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.width * 0.24),
        ),
        _fill(const Color(0xFF16242F)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(size.width * 0.24),
        ),
        _line(const Color(0xFFEDE4D4).withValues(alpha: 0.22), 1),
      );
    }

    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    switch (visual.glyph) {
      case MaterialGlyph.tileGrid:
        _tileGrid(canvas);
      case MaterialGlyph.bagPowder:
        _bagPowder(canvas);
      case MaterialGlyph.pouchPack:
        _pouchPack(canvas);
      case MaterialGlyph.paintCan:
        _paintCan(canvas);
      case MaterialGlyph.hollowBlock:
        _hollowBlock(canvas);
      case MaterialGlyph.rebarBar:
        _rebarBar(canvas);
      case MaterialGlyph.wireCoil:
        _wireCoil(canvas);
      case MaterialGlyph.gravelPile:
        _gravelPile(canvas);
      case MaterialGlyph.sandPile:
        _sandPile(canvas);
      case MaterialGlyph.corrugatedSheet:
        _corrugatedSheet(canvas);
      case MaterialGlyph.cPurlin:
        _cPurlin(canvas);
      case MaterialGlyph.plywoodSheet:
        _plywoodSheet(canvas);
      case MaterialGlyph.lumberStick:
        _lumberStick(canvas);
      case MaterialGlyph.nailsBox:
        _nailsBox(canvas);
      case MaterialGlyph.bucketLiquid:
        _bucketLiquid(canvas);
      case MaterialGlyph.waterCloset:
        _waterCloset(canvas);
      case MaterialGlyph.lavatory:
        _lavatory(canvas);
      case MaterialGlyph.showerSet:
        _showerSet(canvas);
      case MaterialGlyph.faucet:
        _faucet(canvas);
      case MaterialGlyph.tubeSealant:
        _tubeSealant(canvas);
      case MaterialGlyph.tapeRoll:
        _tapeRoll(canvas);
      case MaterialGlyph.spacerCross:
        _spacerCross(canvas);
      case MaterialGlyph.rollerBrush:
        _rollerBrush(canvas);
      case MaterialGlyph.paintBrush:
        _paintBrushGlyph(canvas);
      case MaterialGlyph.sandpaperSheet:
        _sandpaperSheet(canvas);
      case MaterialGlyph.wireSpool:
        _wireSpool(canvas);
      case MaterialGlyph.plankGoods:
        _plankGoods(canvas);
      case MaterialGlyph.pipeLength:
        _pipeLength(canvas);
      case MaterialGlyph.cuttingDisc:
        _cuttingDisc(canvas);
      case MaterialGlyph.genericBox:
        _genericBox(canvas);
    }

    canvas.restore();
  }

  // ── Tile works ───────────────────────────────────────────────────────────

  /// Grid density and bond pattern follow the selected face size, so a
  /// 300×300 row visibly reads as smaller tiles than a 600×600 row.
  void _tileGrid(Canvas canvas) {
    const rect = Rect.fromLTWH(12, 12, 76, 76);
    final a = spec.widthMm ?? 600;
    final b = spec.lengthMm ?? a;

    // Oblong tiles are laid with the long side horizontal, so the swatch reads
    // the way the wall will: subway courses run across, not up and down.
    final faceW = math.max(a, b);
    final faceH = math.min(a, b);

    final cols = (1200 / faceW).round().clamp(1, 8);
    final rows = (1200 / faceH).round().clamp(1, 8);
    final brick = (faceW / faceH) >= 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      _fill(_accent),
    );

    final cw = rect.width / cols;
    final ch = rect.height / rows;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
    );

    for (var r = 0; r < rows; r++) {
      // Subway and plank formats lay in a running bond, offset every course.
      final offset = brick && r.isOdd ? -cw / 2 : 0.0;
      for (var c = -1; c <= cols; c++) {
        final x = rect.left + c * cw + offset;
        final face = Rect.fromLTWH(x + 1, rect.top + r * ch + 1, cw - 2, ch - 2);
        if (face.right < rect.left || face.left > rect.right) continue;
        canvas.drawRect(face, _fill((r + c).isEven ? _base : _light));
      }
    }

    // Glossy wall tile catches a diagonal highlight; matte floor tile does not.
    if (_base.computeLuminance() > 0.7) {
      final gloss = Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left + 30, rect.bottom)
        ..lineTo(rect.right, rect.top + 10)
        ..lineTo(rect.right, rect.top)
        ..close();
      canvas.drawPath(gloss, _fill(Colors.white.withValues(alpha: 0.30)));
    }
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      _line(_edge, 2),
    );
  }

  void _spacerCross(Canvas canvas) {
    void cross(double cx, double cy, double arm, double thick, Color c) {
      final p = Path()
        ..addRect(Rect.fromCenter(center: Offset(cx, cy), width: arm, height: thick))
        ..addRect(Rect.fromCenter(center: Offset(cx, cy), width: thick, height: arm));
      canvas.drawPath(p, _fill(c));
      canvas.drawPath(p, _line(_edge, 1.4));
    }

    cross(44, 44, 46, 13, _base);
    cross(72, 74, 26, 8, _accent);
  }

  void _cuttingDisc(Canvas canvas) {
    const c = Offset(50, 50);
    canvas.drawCircle(c, 34, _fill(_base));
    canvas.drawCircle(c, 34, _line(_accent, 3));
    canvas.drawCircle(c, 28, _line(_accent.withValues(alpha: 0.55), 1.5));
    canvas.drawCircle(c, 9, _fill(const Color(0xFF16242F)));
    canvas.drawCircle(c, 9, _line(_accent, 2));
    // Rim segments — the visible tell between a tile disc and a masonry disc.
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawLine(
        c + Offset(math.cos(a) * 29, math.sin(a) * 29),
        c + Offset(math.cos(a) * 34, math.sin(a) * 34),
        _line(_accent.withValues(alpha: 0.8), 2),
      );
    }
  }

  // ── Bagged & packaged goods ─────────────────────────────────────────────

  void _bagPowder(Canvas canvas) {
    // Sack with the pinched top fold that distinguishes a cement bag on sight.
    final body = Path()
      ..moveTo(24, 26)
      ..lineTo(76, 26)
      ..quadraticBezierTo(82, 56, 78, 86)
      ..lineTo(22, 86)
      ..quadraticBezierTo(18, 56, 24, 26)
      ..close();
    canvas.drawPath(body, _fill(_base));
    canvas.drawPath(body, _line(_edge, 2));

    final fold = Path()
      ..moveTo(24, 26)
      ..lineTo(30, 16)
      ..lineTo(70, 16)
      ..lineTo(76, 26)
      ..close();
    canvas.drawPath(fold, _fill(_shade));
    canvas.drawPath(fold, _line(_edge, 2));

    // Printed band — where the weight and product name are read off the sack.
    canvas.drawRect(Rect.fromLTWH(21, 44, 58, 16), _fill(_accent));
    canvas.drawLine(const Offset(28, 68), const Offset(72, 68),
        _line(_edge.withValues(alpha: 0.5), 2));
    canvas.drawLine(const Offset(28, 75), const Offset(62, 75),
        _line(_edge.withValues(alpha: 0.35), 2));
  }

  void _pouchPack(Canvas canvas) {
    final body = Path()
      ..moveTo(28, 26)
      ..lineTo(72, 26)
      ..lineTo(74, 84)
      ..lineTo(26, 84)
      ..close();
    canvas.drawPath(body, _fill(_base));
    canvas.drawPath(body, _line(_edge, 2));

    // Serrated heat seal across the top of a grout pouch.
    final seal = Path()..moveTo(26, 26);
    for (var x = 26.0; x < 74; x += 6) {
      seal.lineTo(x + 3, 19);
      seal.lineTo(x + 6, 26);
    }
    canvas.drawPath(seal, _line(_accent, 2.4));

    canvas.drawRect(Rect.fromLTWH(34, 44, 32, 22), _fill(_accent.withValues(alpha: 0.75)));
    canvas.drawRect(Rect.fromLTWH(34, 44, 32, 22), _line(_edge, 1.4));
  }

  void _genericBox(Canvas canvas) {
    final front = Path()
      ..moveTo(22, 40)
      ..lineTo(62, 40)
      ..lineTo(62, 82)
      ..lineTo(22, 82)
      ..close();
    final top = Path()
      ..moveTo(22, 40)
      ..lineTo(38, 26)
      ..lineTo(78, 26)
      ..lineTo(62, 40)
      ..close();
    final side = Path()
      ..moveTo(62, 40)
      ..lineTo(78, 26)
      ..lineTo(78, 68)
      ..lineTo(62, 82)
      ..close();

    canvas.drawPath(top, _fill(_light));
    canvas.drawPath(side, _fill(_shade));
    canvas.drawPath(front, _fill(_base));
    for (final p in [front, top, side]) {
      canvas.drawPath(p, _line(_edge, 2));
    }
    canvas.drawLine(const Offset(42, 40), const Offset(42, 82), _line(_accent, 3));
  }

  // ── Liquids ─────────────────────────────────────────────────────────────

  void _paintCan(Canvas canvas) {
    // Wire handle first so the can body overlaps it.
    canvas.drawArc(
      const Rect.fromLTWH(30, 8, 40, 34),
      math.pi,
      math.pi,
      false,
      _line(_accent, 3),
    );

    const body = Rect.fromLTWH(26, 30, 48, 54);
    canvas.drawRect(body, _fill(_base));
    canvas.drawOval(const Rect.fromLTWH(26, 76, 48, 14), _fill(_shade));
    canvas.drawRect(body, _fill(_base));
    canvas.drawOval(const Rect.fromLTWH(26, 23, 48, 14), _fill(_light));
    canvas.drawOval(const Rect.fromLTWH(26, 23, 48, 14), _line(_edge, 2));
    canvas.drawLine(const Offset(26, 30), const Offset(26, 84), _line(_edge, 2));
    canvas.drawLine(const Offset(74, 30), const Offset(74, 84), _line(_edge, 2));
    canvas.drawArc(const Rect.fromLTWH(26, 70, 48, 20), 0, math.pi, false, _line(_edge, 2));

    // Label band — where the sheen and the tint code are printed.
    canvas.drawRect(Rect.fromLTWH(26, 48, 48, 18), _fill(_accent.withValues(alpha: 0.45)));
    canvas.drawLine(const Offset(32, 40), const Offset(52, 40),
        _line(_edge.withValues(alpha: 0.5), 2));
  }

  void _bucketLiquid(Canvas canvas) {
    // Tapered pail, the standard container for waterproofing and sealant.
    final body = Path()
      ..moveTo(24, 32)
      ..lineTo(76, 32)
      ..lineTo(69, 86)
      ..lineTo(31, 86)
      ..close();
    canvas.drawArc(
      const Rect.fromLTWH(24, 6, 52, 40),
      math.pi,
      math.pi,
      false,
      _line(_accent, 3),
    );
    canvas.drawPath(body, _fill(_base));
    canvas.drawPath(body, _line(_edge, 2));
    canvas.drawOval(const Rect.fromLTWH(24, 25, 52, 14), _fill(_light));
    canvas.drawOval(const Rect.fromLTWH(24, 25, 52, 14), _line(_edge, 2));
    canvas.drawRect(Rect.fromLTWH(30, 52, 40, 18), _fill(_accent.withValues(alpha: 0.5)));
  }

  void _tubeSealant(Canvas canvas) {
    // Cartridge body plus the tapered nozzle that identifies a caulking tube.
    const body = Rect.fromLTWH(22, 40, 52, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      _fill(_base),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      _line(_edge, 2),
    );
    final nozzle = Path()
      ..moveTo(74, 46)
      ..lineTo(88, 51)
      ..lineTo(88, 59)
      ..lineTo(74, 64)
      ..close();
    canvas.drawPath(nozzle, _fill(_accent));
    canvas.drawPath(nozzle, _line(_edge, 2));
    canvas.drawRect(Rect.fromLTWH(28, 46, 12, 18), _fill(_accent.withValues(alpha: 0.6)));
    canvas.drawLine(const Offset(46, 48), const Offset(46, 62),
        _line(_edge.withValues(alpha: 0.4), 2));
    canvas.drawLine(const Offset(54, 48), const Offset(54, 62),
        _line(_edge.withValues(alpha: 0.4), 2));
    canvas.drawRect(Rect.fromLTWH(18, 44, 6, 22), _fill(_shade));
  }

  // ── Masonry, aggregate, steel ───────────────────────────────────────────

  /// Block depth tracks the selected thickness, so a 6" CHB reads visibly
  /// deeper on the card than a 4".
  void _hollowBlock(Canvas canvas) {
    final thickMm = spec.widthMm ?? 100;
    final depth = (thickMm / 100 * 16).clamp(10.0, 26.0);

    const left = 18.0, right = 74.0, topY = 34.0, botY = 82.0;

    final top = Path()
      ..moveTo(left, topY)
      ..lineTo(left + depth, topY - depth)
      ..lineTo(right + depth, topY - depth)
      ..lineTo(right, topY)
      ..close();
    final side = Path()
      ..moveTo(right, topY)
      ..lineTo(right + depth, topY - depth)
      ..lineTo(right + depth, botY - depth)
      ..lineTo(right, botY)
      ..close();
    final front = Rect.fromLTRB(left, topY, right, botY);

    canvas.drawPath(top, _fill(_light));
    canvas.drawPath(side, _fill(_shade));
    canvas.drawRect(front, _fill(_base));

    // The two cells are what makes a block read as hollow rather than solid.
    for (final cx in [left + 14.0, left + 38.0]) {
      final cell = Path()
        ..moveTo(cx, topY - 1)
        ..lineTo(cx + depth * 0.55, topY - depth * 0.55)
        ..lineTo(cx + 14 + depth * 0.55, topY - depth * 0.55)
        ..lineTo(cx + 14, topY - 1)
        ..close();
      canvas.drawPath(cell, _fill(const Color(0xFF16242F)));
      canvas.drawPath(cell, _line(_edge, 1.4));
    }

    canvas.drawPath(top, _line(_edge, 2));
    canvas.drawPath(side, _line(_edge, 2));
    canvas.drawRect(front, _line(_edge, 2));
    canvas.drawLine(Offset(left, topY + 16), Offset(right, topY + 16),
        _line(_edge.withValues(alpha: 0.4), 1.6));
  }

  /// Bar thickness scales with the selected diameter, so 10 mm, 12 mm and
  /// 16 mm are distinguishable at a glance in the list.
  void _rebarBar(Canvas canvas) {
    final dia = spec.widthMm ?? 10;
    final t = (dia / 10 * 13).clamp(9.0, 22.0);

    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-math.pi / 7);

    final bar = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 84, height: t),
      Radius.circular(t / 2),
    );
    canvas.drawRRect(bar, _fill(_base));
    canvas.drawRRect(bar, _line(_edge, 2));

    // Raised deformation ribs — the visible difference from plain round bar.
    canvas.save();
    canvas.clipRRect(bar);
    for (var x = -40.0; x < 44; x += 9) {
      canvas.drawLine(
        Offset(x, -t / 2),
        Offset(x + t * 0.55, t / 2),
        _line(_accent.withValues(alpha: 0.85), 3),
      );
    }
    canvas.restore();
    canvas.drawRRect(bar, _line(_edge, 2));
    canvas.restore();
  }

  void _wireCoil(Canvas canvas) {
    const c = Offset(50, 52);
    canvas.drawCircle(c, 33, _fill(_shade));
    canvas.drawCircle(c, 33, _line(_edge, 2));
    canvas.drawCircle(c, 14, _fill(const Color(0xFF16242F)));
    canvas.drawCircle(c, 14, _line(_edge, 2));
    // Individual windings, drawn as chords across the coil face.
    for (var i = 0; i < 9; i++) {
      final a = i * math.pi / 9;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 24),
        a,
        math.pi * 0.55,
        false,
        _line(_base.withValues(alpha: 0.9), 2.4),
      );
    }
    canvas.drawLine(const Offset(74, 34), const Offset(88, 22), _line(_base, 2.4));
  }

  void _gravelPile(Canvas canvas) {
    // Angular faces: crushed aggregate, not rounded river pebbles.
    final stones = <List<Offset>>[
      [const Offset(20, 82), const Offset(30, 62), const Offset(46, 68), const Offset(40, 84)],
      [const Offset(40, 84), const Offset(46, 66), const Offset(64, 62), const Offset(66, 84)],
      [const Offset(64, 84), const Offset(66, 66), const Offset(82, 70), const Offset(84, 84)],
      [const Offset(34, 62), const Offset(44, 44), const Offset(60, 48), const Offset(58, 64)],
      [const Offset(58, 62), const Offset(62, 46), const Offset(78, 52), const Offset(74, 66)],
      [const Offset(46, 44), const Offset(56, 28), const Offset(70, 36), const Offset(64, 48)],
    ];
    for (var i = 0; i < stones.length; i++) {
      final p = Path()..addPolygon(stones[i], true);
      canvas.drawPath(p, _fill(i.isEven ? _base : _light));
      canvas.drawPath(p, _line(_accent, 1.8));
    }
  }

  void _sandPile(Canvas canvas) {
    // Smooth conical heap: fine material flows, aggregate does not.
    final heap = Path()
      ..moveTo(14, 84)
      ..quadraticBezierTo(30, 34, 50, 30)
      ..quadraticBezierTo(70, 34, 86, 84)
      ..close();
    canvas.drawPath(heap, _fill(_base));
    canvas.drawPath(heap, _line(_edge, 2));

    final shadow = Path()
      ..moveTo(50, 30)
      ..quadraticBezierTo(70, 34, 86, 84)
      ..lineTo(50, 84)
      ..close();
    canvas.drawPath(shadow, _fill(_shade.withValues(alpha: 0.55)));

    final grain = _fill(_accent.withValues(alpha: 0.65));
    const seeds = [
      Offset(34, 70), Offset(46, 58), Offset(58, 66), Offset(66, 76),
      Offset(28, 79), Offset(52, 46), Offset(72, 80), Offset(42, 76),
    ];
    for (final s in seeds) {
      canvas.drawCircle(s, 1.9, grain);
    }
  }

  // ── Roofing & framing ───────────────────────────────────────────────────

  void _corrugatedSheet(Canvas canvas) {
    // Trapezoidal rib profile viewed at an angle — the rib-type GI sheet.
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-0.20);
    canvas.translate(-50, -50);

    // Shallow ribs on a wide pan: the actual rib-type profile, not a sawtooth.
    const top = 44.0, bot = 74.0, panTop = 64.0;

    // Flat pan the ribs stand on. Drawn dark so the raised ribs separate from
    // it — a rib profile that merges into one block is unreadable at 44 px.
    canvas.drawRect(const Rect.fromLTRB(10, panTop, 90, bot), _fill(_shade));
    canvas.drawRect(const Rect.fromLTRB(10, panTop, 90, bot), _line(_edge, 1.8));

    for (var i = 0; i < 4; i++) {
      final x = 12 + i * 20.0;
      final crown = Path()
        ..moveTo(x, bot)
        ..lineTo(x + 5, top)
        ..lineTo(x + 13, top)
        ..lineTo(x + 13, bot)
        ..close();
      final face = Path()
        ..moveTo(x + 13, top)
        ..lineTo(x + 18, bot)
        ..lineTo(x + 13, bot)
        ..close();
      canvas.drawPath(crown, _fill(_base));
      canvas.drawPath(face, _fill(_shade));
      canvas.drawPath(crown, _line(_edge, 1.8));
      canvas.drawPath(face, _line(_edge, 1.8));
      canvas.drawLine(Offset(x + 7, top + 3), Offset(x + 9, bot - 4),
          _line(_light.withValues(alpha: 0.85), 1.8));
    }
    canvas.restore();
  }

  void _cPurlin(Canvas canvas) {
    // C-section drawn as an extrusion so the open channel is unmistakable.
    const d = 16.0;
    final face = Path()
      ..moveTo(30, 24)
      ..lineTo(66, 24)
      ..lineTo(66, 34)
      ..lineTo(40, 34)
      ..lineTo(40, 66)
      ..lineTo(66, 66)
      ..lineTo(66, 76)
      ..lineTo(30, 76)
      ..close();

    final back = face.shift(const Offset(d, -d));
    canvas.drawPath(back, _fill(_shade));
    canvas.drawPath(back, _line(_edge, 1.6));

    for (final seg in [
      [const Offset(30, 24), const Offset(66, 24)],
      [const Offset(30, 76), const Offset(66, 76)],
      [const Offset(66, 34), const Offset(40, 34)],
      [const Offset(66, 66), const Offset(40, 66)],
    ]) {
      canvas.drawLine(seg[0], seg[0] + const Offset(d, -d), _line(_edge, 1.4));
      canvas.drawLine(seg[1], seg[1] + const Offset(d, -d), _line(_edge, 1.4));
    }

    canvas.drawPath(face, _fill(_base));
    canvas.drawPath(face, _line(_edge, 2));
  }

  void _plywoodSheet(Canvas canvas) {
    // Layered plies at the cut edge: the check for real marine grade.
    final front = Path()
      ..moveTo(18, 32)
      ..lineTo(72, 22)
      ..lineTo(72, 72)
      ..lineTo(18, 82)
      ..close();
    canvas.drawPath(front, _fill(_base));
    canvas.drawPath(front, _line(_edge, 2));

    final edge = Path()
      ..moveTo(72, 22)
      ..lineTo(84, 28)
      ..lineTo(84, 78)
      ..lineTo(72, 72)
      ..close();
    canvas.drawPath(edge, _fill(_shade));
    canvas.drawPath(edge, _line(_edge, 2));
    for (var i = 1; i < 5; i++) {
      final t = i / 5;
      canvas.drawLine(
        Offset(72, 22 + 50 * t),
        Offset(84, 28 + 50 * t),
        _line(_accent.withValues(alpha: 0.7), 1.6),
      );
    }
    canvas.drawLine(const Offset(26, 44), const Offset(64, 37),
        _line(_accent.withValues(alpha: 0.35), 2));
    canvas.drawLine(const Offset(26, 62), const Offset(64, 55),
        _line(_accent.withValues(alpha: 0.35), 2));
  }

  void _lumberStick(Canvas canvas) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-math.pi / 6);

    const stick = Rect.fromLTWH(-42, -13, 74, 26);
    canvas.drawRect(stick, _fill(_base));
    canvas.drawRect(stick, _line(_edge, 2));
    // Sawn end face, lighter than the length.
    final end = Path()
      ..moveTo(32, -13)
      ..lineTo(42, -19)
      ..lineTo(42, 7)
      ..lineTo(32, 13)
      ..close();
    canvas.drawPath(end, _fill(_light));
    canvas.drawPath(end, _line(_edge, 2));
    for (final y in [-5.0, 3.0]) {
      canvas.drawLine(Offset(-38, y), Offset(28, y),
          _line(_accent.withValues(alpha: 0.5), 1.8));
    }
    canvas.restore();
  }

  void _nailsBox(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final angle = -0.5 + i * 0.42;
      canvas.save();
      canvas.translate(38 + i * 12.0, 74);
      canvas.rotate(angle);
      final shank = Path()
        ..moveTo(-3.5, 0)
        ..lineTo(3.5, 0)
        ..lineTo(1.2, -48)
        ..lineTo(-1.2, -48)
        ..close();
      // Drawn point-down: head at the top, taper to the tip.
      canvas.drawPath(shank, _fill(_base));
      canvas.drawPath(shank, _line(_edge, 1.4));
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -49), width: 15, height: 5),
        _fill(_light),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -49), width: 15, height: 5),
        _line(_edge, 1.4),
      );
      canvas.restore();
    }
    canvas.drawLine(const Offset(18, 80), const Offset(84, 80),
        _line(_accent.withValues(alpha: 0.5), 2));
  }

  // ── Plumbing fixtures ───────────────────────────────────────────────────

  void _waterCloset(Canvas canvas) {
    // Side elevation: tank behind, bowl in front.
    final tank = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 22, 26, 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(tank, _fill(_base));
    canvas.drawRRect(tank, _line(_edge, 2));
    canvas.drawCircle(const Offset(31, 28), 3, _fill(_accent));

    final bowl = Path()
      ..moveTo(44, 44)
      ..lineTo(80, 44)
      ..quadraticBezierTo(84, 60, 70, 66)
      ..lineTo(56, 66)
      ..quadraticBezierTo(48, 74, 50, 84)
      ..lineTo(38, 84)
      ..quadraticBezierTo(36, 62, 44, 44)
      ..close();
    canvas.drawPath(bowl, _fill(_base));
    canvas.drawPath(bowl, _line(_edge, 2));
    canvas.drawOval(const Rect.fromLTWH(46, 40, 36, 10), _fill(_light));
    canvas.drawOval(const Rect.fromLTWH(46, 40, 36, 10), _line(_edge, 2));
  }

  void _lavatory(Canvas canvas) {
    final basin = Path()
      ..moveTo(16, 34)
      ..lineTo(84, 34)
      ..lineTo(72, 58)
      ..lineTo(28, 58)
      ..close();
    canvas.drawPath(basin, _fill(_base));
    canvas.drawPath(basin, _line(_edge, 2));
    canvas.drawOval(const Rect.fromLTWH(16, 28, 68, 12), _fill(_light));
    canvas.drawOval(const Rect.fromLTWH(16, 28, 68, 12), _line(_edge, 2));

    final pedestal = Path()
      ..moveTo(42, 58)
      ..lineTo(58, 58)
      ..lineTo(62, 84)
      ..lineTo(38, 84)
      ..close();
    canvas.drawPath(pedestal, _fill(_shade));
    canvas.drawPath(pedestal, _line(_edge, 2));
    canvas.drawLine(const Offset(50, 22), const Offset(50, 30), _line(_accent, 3));
  }

  void _showerSet(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(20, 20, 8, 24), _fill(_accent));
    canvas.drawLine(const Offset(28, 30), const Offset(52, 30), _line(_base, 5));
    final head = Path()
      ..moveTo(48, 24)
      ..lineTo(80, 30)
      ..lineTo(80, 42)
      ..lineTo(48, 40)
      ..close();
    canvas.drawPath(head, _fill(_base));
    canvas.drawPath(head, _line(_edge, 2));
    // Spray pattern below the rose.
    final drop = _line(_accent.withValues(alpha: 0.8), 2.4);
    for (var i = 0; i < 5; i++) {
      final x = 52 + i * 6.5;
      canvas.drawLine(Offset(x, 46), Offset(x - 3, 46 + 10 + i * 3.0), drop);
    }
  }

  void _faucet(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(20, 52, 12, 30), _fill(_shade));
    canvas.drawRect(Rect.fromLTWH(20, 52, 12, 30), _line(_edge, 2));
    final spout = Path()
      ..moveTo(26, 54)
      ..quadraticBezierTo(26, 22, 56, 22)
      ..quadraticBezierTo(74, 22, 74, 46);
    canvas.drawPath(spout, _line(_base, 10));
    canvas.drawPath(spout, _line(_edge, 2));
    canvas.drawRect(Rect.fromLTWH(69, 44, 10, 6), _fill(_accent));
    canvas.drawLine(const Offset(36, 40), const Offset(36, 28), _line(_base, 6));
    canvas.drawLine(const Offset(30, 28), const Offset(42, 28), _line(_base, 6));
  }

  void _pipeLength(Canvas canvas) {
    const body = Rect.fromLTWH(14, 38, 62, 26);
    canvas.drawRect(body, _fill(_base));
    canvas.drawRect(body, _line(_edge, 2));
    canvas.drawRect(Rect.fromLTWH(14, 38, 62, 7), _fill(_light));
    // Open end, so it reads as pipe rather than a solid bar.
    canvas.drawOval(const Rect.fromLTWH(66, 38, 20, 26), _fill(_shade));
    canvas.drawOval(const Rect.fromLTWH(66, 38, 20, 26), _line(_edge, 2));
    canvas.drawOval(const Rect.fromLTWH(70, 43, 12, 16), _fill(const Color(0xFF16242F)));
    canvas.drawLine(const Offset(20, 51), const Offset(56, 51),
        _line(_accent.withValues(alpha: 0.7), 2));
  }

  // ── Painting tools & sheet goods ────────────────────────────────────────

  void _tapeRoll(Canvas canvas) {
    const c = Offset(50, 52);
    canvas.drawCircle(c, 32, _fill(_base));
    canvas.drawCircle(c, 32, _line(_edge, 2));
    canvas.drawCircle(c, 13, _fill(const Color(0xFF16242F)));
    canvas.drawCircle(c, 13, _line(_edge, 2));
    canvas.drawCircle(c, 22, _line(_accent.withValues(alpha: 0.6), 1.6));
    // Loose tail, so the roll reads as tape and not as a washer.
    final tail = Path()
      ..moveTo(80, 44)
      ..quadraticBezierTo(92, 40, 88, 28);
    canvas.drawPath(tail, _line(_base, 6));
    canvas.drawPath(tail, _line(_edge, 1.4));
  }

  void _rollerBrush(Canvas canvas) {
    final sleeve = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 24, 58, 24),
      const Radius.circular(11),
    );
    canvas.drawRRect(sleeve, _fill(_base));
    canvas.drawRRect(sleeve, _line(_edge, 2));
    // Nap texture along the sleeve.
    for (var x = 22.0; x < 70; x += 6) {
      canvas.drawLine(Offset(x, 27), Offset(x, 45),
          _line(_edge.withValues(alpha: 0.28), 1.6));
    }
    final frame = Path()
      ..moveTo(45, 48)
      ..lineTo(45, 62)
      ..lineTo(66, 62);
    canvas.drawPath(frame, _line(_accent, 4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(64, 56, 22, 13),
        const Radius.circular(6),
      ),
      _fill(_accent),
    );
  }

  void _paintBrushGlyph(Canvas canvas) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(math.pi / 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-38, -7, 34, 14),
        const Radius.circular(6),
      ),
      _fill(_base),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-38, -7, 34, 14),
        const Radius.circular(6),
      ),
      _line(_edge, 2),
    );
    // Metal ferrule between handle and bristles.
    canvas.drawRect(const Rect.fromLTWH(-6, -11, 12, 22), _fill(_shade));
    canvas.drawRect(const Rect.fromLTWH(-6, -11, 12, 22), _line(_edge, 2));
    final bristles = Path()
      ..moveTo(6, -11)
      ..lineTo(38, -13)
      ..lineTo(38, 13)
      ..lineTo(6, 11)
      ..close();
    canvas.drawPath(bristles, _fill(_accent));
    canvas.drawPath(bristles, _line(_edge, 2));
    canvas.restore();
  }

  void _sandpaperSheet(Canvas canvas) {
    final sheet = Path()
      ..moveTo(20, 20)
      ..lineTo(80, 20)
      ..lineTo(80, 70)
      ..lineTo(46, 84)
      ..lineTo(20, 80)
      ..close();
    canvas.drawPath(sheet, _fill(_base));
    canvas.drawPath(sheet, _line(_edge, 2));
    // Grit speckle, the whole point of the sheet.
    final grit = _fill(_accent.withValues(alpha: 0.85));
    final rnd = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final x = 24 + rnd.nextDouble() * 52;
      final y = 25 + rnd.nextDouble() * 48;
      canvas.drawCircle(Offset(x, y), 1.5, grit);
    }
    // Curled corner.
    final curl = Path()
      ..moveTo(80, 70)
      ..quadraticBezierTo(64, 74, 46, 84);
    canvas.drawPath(curl, _line(_light, 3));
  }

  void _plankGoods(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final y = 30 + i * 17.0;
      final p = Path()
        ..moveTo(14, y + 10)
        ..lineTo(70, y)
        ..lineTo(86, y + 7)
        ..lineTo(30, y + 17)
        ..close();
      canvas.drawPath(p, _fill(i.isEven ? _base : _light));
      canvas.drawPath(p, _line(_edge, 1.8));
      canvas.drawLine(Offset(24, y + 11), Offset(72, y + 3),
          _line(_accent.withValues(alpha: 0.45), 1.4));
    }
  }

  void _wireSpool(Canvas canvas) {
    const c = Offset(50, 52);
    for (var i = 3; i >= 0; i--) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 66 - i * 9.0, height: 58 - i * 9.0),
        _line(i.isEven ? _base : _accent, 5),
      );
    }
    // Cut ends, so it reads as wire on a coil not as a stack of rings.
    canvas.drawLine(const Offset(78, 40), const Offset(90, 26), _line(_base, 4));
    canvas.drawLine(const Offset(22, 66), const Offset(10, 80), _line(_accent, 4));
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.visual.glyph != visual.glyph ||
      old.visual.base != visual.base ||
      old.visual.accent != visual.accent ||
      old.spec.widthMm != spec.widthMm ||
      old.spec.lengthMm != spec.lengthMm ||
      old.showPlate != showPlate;
}
