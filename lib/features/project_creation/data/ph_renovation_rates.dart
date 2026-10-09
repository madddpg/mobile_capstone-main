import 'dart:math' as math;

/// Philippine National Standard Material Estimation Rates & Mathematical Formulas.
///
/// Every rate below is traceable to a Philippine authority. See
/// `docs/material-data-sources.md` for the full provenance table.
///
/// Material specifications: DPWH Standard Specifications for Public Works
/// Structures, Volume III (Buildings), with DPWH Department Orders for the
/// amended items, and Philippine National Standards from DTI-BPS.
///
/// Quantity coefficients: Max Fajardo, *Simplified Construction Estimate*,
/// plus published manufacturer coverage rates for proprietary goods.
///
/// Structural detailing: National Structural Code of the Philippines (NSCP),
/// published by ASEP. The National Building Code (PD 1096) is a separate
/// instrument and is not the NSCP.
class PhRenovationRates {
  PhRenovationRates._();

  // ---------------------------------------------------------------------------
  // DPWH Waste Allowances & Buffers
  // ---------------------------------------------------------------------------

  static const double tileWasteFactor = 0.08; // 8% cut/breakage allowance
  static const double chbWasteFactor = 0.05; // 5% handling breakage
  static const double paintWasteFactor = 0.05; // 5% residue buffer
  static const double roofingWasteFactor = 0.10; // 10% side & end lap overlap
  static const double rebarWasteFactor = 0.05; // 5% cutting cutoff & hook bends

  // ---------------------------------------------------------------------------
  // Rounding and the numbers the formulas print
  // ---------------------------------------------------------------------------
  //
  // Every quantity must be reproducible by hand from the formula printed
  // beside it. Two things used to break that. Binary floating point cannot
  // hold 0.36 or 1.08 exactly, so 3.0 sq.m of 600 × 600 tile, which is
  // 3.0 ÷ 0.36 × 1.08 = 9 pieces, computed as 9.000000000000002 and a plain
  // ceil ordered 10. And figures were printed rounded, so a wall of 14.97
  // sq.m read "15.0" and a tile face of 0.0225 m² read "0.023".

  /// [value] without binary floating-point noise: rounded to six decimals,
  /// far finer than anything measured on site or carried by a rate.
  static double clean(double value) => (value * 1e6).roundToDouble() / 1e6;

  /// Rounds a quantity up to the next whole unit, as a hand estimate does.
  static double roundUp(double value) => clean(value).ceilToDouble();

  /// Rounds up to the next 0.01, for sand, gravel and tie wire, which are
  /// ordered in fractions of a cubic metre or a kilogram. Rounding to the
  /// nearest 0.01 used to round 0.075 m³ down to 0.07.
  static double roundUpHundredths(double value) =>
      clean(clean(value) * 100).ceilToDouble() / 100;

  /// A number exactly as computed, without trailing zeros: 14.97, 0.0225, 9.
  static String numText(double value) => _trimmed(clean(value), 6);

  /// A quantity for a list or a sheet: a whole number bare, a fraction to at
  /// least two places and more only when they are real: 1.50, 0.08, 0.125.
  static String qtyText(double value) {
    final text = numText(value);
    final dot = text.indexOf('.');
    if (dot < 0) return text;
    return text.length - dot - 1 < 2 ? '${text}0' : text;
  }

  /// An area, exactly, with at least one decimal: 3.0, 14.97, 4.3475.
  static String areaText(double sqm) {
    final text = numText(sqm);
    return text.contains('.') ? text : '$text.0';
  }

  /// The end of a formula: "= 89.82 → 90 pcs" when the figure was rounded
  /// up, "= 9 pcs" when it was already exact.
  ///
  /// The unrounded figure is shown to four decimals, or to six when four
  /// would not justify the rounding: 13.29 × 0.076 is 1.01004 cu.m, which
  /// needs 1.02, and "1.01 → 1.02" would look like an error.
  static String resultText(double raw, double qty, String unit) {
    final shownQty = numText(qty);
    final exact = clean(raw);
    if (exact == clean(qty)) return '= $shownQty $unit';
    var shownRaw = _trimmed(exact, 4);
    if (shownRaw == shownQty || !_roundsUpTo(double.parse(shownRaw), qty)) {
      shownRaw = numText(exact);
    }
    return '= $shownRaw → $shownQty $unit';
  }

  /// Whether [shown], rounded up the way [qty] was (to a whole unit, or to
  /// 0.01), gives [qty], or [qty] is the one-unit minimum.
  static bool _roundsUpTo(double shown, double qty) {
    final target = clean(qty);
    final whole = target == target.roundToDouble();
    final up = whole ? roundUp(shown) : roundUpHundredths(shown);
    return up == target || (target == 1 && up < 1);
  }

  static String _trimmed(double value, int decimals) {
    var text = value.toStringAsFixed(decimals);
    if (!text.contains('.')) return text;
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  /// The face of a tile in metres, read from its size ("600x600" is 0.60 ×
  /// 0.60 m), or [fallback] when the size names no dimensions.
  static ({double widthM, double lengthM}) tileFace(
    String sizeKey,
    ({double widthM, double lengthM}) fallback,
  ) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*[x×X]\s*(\d+(?:\.\d+)?)')
        .firstMatch(sizeKey);
    if (match == null) return fallback;
    final w = double.parse(match.group(1)!) / 1000;
    final l = double.parse(match.group(2)!) / 1000;
    return w > 0 && l > 0 ? (widthM: w, lengthM: l) : fallback;
  }

  static String _faceText(({double widthM, double lengthM}) face) =>
      '${numText(face.widthM)} m × ${numText(face.lengthM)} m = '
      '${numText(clean(face.widthM * face.lengthM))} sq.m per tile';

  // ---------------------------------------------------------------------------
  // 1. FLOOR TILES (Footprint Area based, Non-Slip / Matt)
  // ---------------------------------------------------------------------------

  /// Standard floor tile sizes available in Philippine hardware stores.
  static const List<({String value, String label, double widthM, double lengthM})> floorTileSizes = [
    (value: '300x300', label: '300 × 300 mm (12"×12")', widthM: 0.30, lengthM: 0.30),
    (value: '400x400', label: '400 × 400 mm (16"×16")', widthM: 0.40, lengthM: 0.40),
    (value: '600x600', label: '600 × 600 mm (24"×24")', widthM: 0.60, lengthM: 0.60),
  ];

  static const _defaultFloorFace = (widthM: 0.60, lengthM: 0.60);

  /// Unrounded floor tile pieces: area ÷ tile face × 1.08 (DPWH Item 1018).
  static double floorTilePiecesRaw(double areaSqm, String sizeKey) {
    final face = tileFace(sizeKey, _defaultFloorFace);
    return areaSqm / (face.widthM * face.lengthM) * (1.0 + tileWasteFactor);
  }

  static double calculateFloorTilePieces(double areaSqm, String sizeKey) =>
      roundUp(floorTilePiecesRaw(areaSqm, sizeKey));

  static String floorTileFormulaString(double areaSqm, String sizeKey, double resultPcs) {
    final face = tileFace(sizeKey, _defaultFloorFace);
    return '${areaText(areaSqm)} sq.m ÷ (${_faceText(face)}) × 1.08 waste '
        '${resultText(floorTilePiecesRaw(areaSqm, sizeKey), resultPcs, 'pcs')}\n'
        '(Material spec: DPWH Vol. III Item 1018 Ceramic/Granite Tiles | Quantity: tile face geometry + 8% cutting waste, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 2. WALL TILES (Wall Surface Area based, Glazed / Subway / Large Format)
  // ---------------------------------------------------------------------------

  /// Standard wall tile sizes available in Philippine hardware stores.
  static const List<({String value, String label, double widthM, double lengthM})> wallTileSizes = [
    (value: '75x300', label: '75 × 300 mm (Subway Tile)', widthM: 0.075, lengthM: 0.30),
    (value: '300x600', label: '300 × 600 mm (Standard Wall)', widthM: 0.30, lengthM: 0.60),
    (value: '600x1200', label: '600 × 1200 mm (Large Format)', widthM: 0.60, lengthM: 1.20),
  ];

  static const _defaultWallFace = (widthM: 0.30, lengthM: 0.60);

  /// Unrounded wall tile pieces: wall area ÷ tile face × 1.08 (DPWH Item 1018).
  static double wallTilePiecesRaw(double wallAreaSqm, String sizeKey) {
    final face = tileFace(sizeKey, _defaultWallFace);
    return wallAreaSqm / (face.widthM * face.lengthM) * (1.0 + tileWasteFactor);
  }

  static double calculateWallTilePieces(double wallAreaSqm, String sizeKey) =>
      roundUp(wallTilePiecesRaw(wallAreaSqm, sizeKey));

  static String wallTileFormulaString(double wallAreaSqm, String sizeKey, double resultPcs) {
    final face = tileFace(sizeKey, _defaultWallFace);
    return '${areaText(wallAreaSqm)} sq.m wall ÷ (${_faceText(face)}) × 1.08 waste '
        '${resultText(wallTilePiecesRaw(wallAreaSqm, sizeKey), resultPcs, 'pcs')}\n'
        '(Material spec: DPWH Vol. III Item 1018 Ceramic/Granite Tiles | Quantity: tile face geometry + 8% cutting waste, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 3. TILE ADHESIVE & TILE GROUT CONSUMPTION
  // ---------------------------------------------------------------------------

  /// Sq.m of tile one 25 kg bag of adhesive sets at a 6 mm notch, per the
  /// manufacturer coverage the source table cites. The bag count used to be
  /// area × 0.22, which is not 1 ÷ 4.5 and disagreed with it at the edges:
  /// 4.52 sq.m needs 2 bags at 4.5 sq.m a bag, and 0.22 gave 1.
  static const double adhesiveSqmPerBag = 4.5;

  static double calculateTileAdhesiveBags(double areaSqm) =>
      math.max(1.0, roundUp(areaSqm / adhesiveSqmPerBag));

  static String tileAdhesiveFormulaString(double areaSqm, double resultBags) {
    return '${areaText(areaSqm)} sq.m ÷ $adhesiveSqmPerBag sq.m per 25 kg bag '
        '${resultText(areaSqm / adhesiveSqmPerBag, resultBags, 'bags')}\n'
        '(Material spec: DPWH Vol. III Item 1018 | Quantity: manufacturer coverage, 25 kg bag per 4.5 sq.m at 6 mm notch)';
  }

  /// Tile grout (2kg packs): Scales with perimeter joint line length per sqm
  static double calculateTileGroutPacks(double areaSqm, String sizeKey) {
    return groutPacksForKg(areaSqm * groutKgPerSqm(sizeKey));
  }

  /// Grout consumed per sq.m of tiled face. A smaller face has more joint line
  /// per sq.m, so it takes more grout.
  static double groutKgPerSqm(String sizeKey) {
    if (sizeKey == '75x300') return 0.30; // High joint frequency
    if (sizeKey == '300x300' || sizeKey == '200x200') return 0.25;
    if (sizeKey == '600x1200') return 0.12; // Low joint frequency
    return 0.18; // Default for 400x400 or 600x600
  }

  /// Whole 2 kg commercial packs needed for [kg] of grout, at least one.
  static double groutPacksForKg(double kg) {
    return math.max(1.0, roundUp(kg / 2.0));
  }

  /// The grout part of a formula: "3.0 sq.m × 0.18 kg/sq.m (600x600)".
  static String groutPartText(double sqm, String sizeKey, {String? surface}) =>
      '${areaText(sqm)} sq.m${surface == null ? '' : ' $surface'} × '
      '${numText(groutKgPerSqm(sizeKey))} kg/sq.m'
      '${sizeKey.trim().isEmpty ? '' : ' (${sizeKey.trim()})'}';

  /// The rest of a grout formula, from the kilograms to the packs.
  static String groutPacksText(double kg, double packs) =>
      '= ${numText(kg)} kg ÷ 2 kg per pack ${resultText(kg / 2, packs, 'packs')}';

  static String tileGroutFormulaString(double areaSqm, String sizeKey, double resultPacks) {
    final kg = areaSqm * groutKgPerSqm(sizeKey);
    return '${groutPartText(areaSqm, sizeKey)} ${groutPacksText(kg, resultPacks)}\n'
        '(Material spec: DPWH Vol. III Item 1018 | Quantity: joint volume from tile size, manufacturer coverage)';
  }

  // Floor screed and tile bedding: 25 mm of Class B 1:3 mortar. Fajardo's
  // Class B mortar takes 12.0 bags of 40 kg cement and 1.0 cu.m of sand per
  // cu.m, the same basis as the plaster rate in calculateChbMortarAndPlaster
  // (16 mm a face × 12.0 = 0.19 bags/sq.m). The cement used to be 0.25
  // bags/sq.m, which is 10 bags a cu.m: neither Class B nor any other class.
  static const double beddingThicknessM = 0.025;
  static const double classBCementBagsPerCum = 12.0;
  static const double mortarSandCumPerCum = 1.0;

  static double beddingVolumeCum(double areaSqm) => areaSqm * beddingThicknessM;

  static ({double cementBags, double sandCum}) calculateTileBeddingMortar(double areaSqm) {
    final volume = beddingVolumeCum(areaSqm);
    return (
      cementBags: math.max(1.0, roundUp(volume * classBCementBagsPerCum)),
      sandCum: roundUpHundredths(volume * mortarSandCumPerCum),
    );
  }

  static String _beddingVolumeText(double areaSqm) =>
      '${areaText(areaSqm)} sq.m × $beddingThicknessM m (25 mm) = '
      '${numText(beddingVolumeCum(areaSqm))} cu.m of mortar';

  static String beddingCementFormulaString(double areaSqm, double bags) {
    final volume = beddingVolumeCum(areaSqm);
    return '${_beddingVolumeText(areaSqm)} × $classBCementBagsPerCum bags/cu.m '
        '${resultText(volume * classBCementBagsPerCum, bags, 'bags')} (40 kg Portland Cement)\n'
        '(Material spec: DPWH Vol. III Item 1018 | Quantity: 25 mm Class B 1:3 bedding, 12.0 bags + 1.0 cu.m sand per cu.m, Fajardo)';
  }

  static String beddingSandFormulaString(double areaSqm, double sandCum) {
    final volume = beddingVolumeCum(areaSqm);
    return '${_beddingVolumeText(areaSqm)} × $mortarSandCumPerCum cu.m sand/cu.m '
        '${resultText(volume * mortarSandCumPerCum, sandCum, 'cu.m')} washed sand\n'
        '(Material spec: DPWH Vol. III Item 1018 | Quantity: 25 mm Class B 1:3 bedding, 12.0 bags + 1.0 cu.m sand per cu.m, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 4. PAINTING WORKS (DPWH Vol. III Item 1032 — 3-Coat System)
  // ---------------------------------------------------------------------------

  /// Gallons (4 L) per sq.m: one sealing coat of primer, two finish coats.
  static const double primerGalPerSqm = 0.04;
  static const double topcoatGalPerSqm = 0.06;

  /// Sq.m one 20 kg bag of skim coat covers, per the manufacturer coverage
  /// the source table cites. The count used to be area × 0.09, while the
  /// formula beside it said a bag covers 10 sq.m, which is 0.10.
  static const double skimCoatSqmPerBag = 10.0;

  static ({double primerGal, double topcoatGal, double totalGal, double skimCoatBags}) calculatePaintWorks(double areaSqm) {
    final primer = math.max(1.0, roundUp(areaSqm * primerGalPerSqm));
    final topcoat = math.max(1.0, roundUp(areaSqm * topcoatGalPerSqm));
    final skimCoat = math.max(1.0, roundUp(areaSqm / skimCoatSqmPerBag));
    return (
      primerGal: primer,
      topcoatGal: topcoat,
      totalGal: primer + topcoat,
      skimCoatBags: skimCoat,
    );
  }

  static String primerFormulaString(double areaSqm, double gal) =>
      '${areaText(areaSqm)} sq.m × $primerGalPerSqm gal/sq.m (1 sealing coat) '
      '${resultText(areaSqm * primerGalPerSqm, gal, 'gal')} (4 L)\n'
      '(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, 1 sealing coat)';

  static String topcoatFormulaString(double areaSqm, double gal) =>
      '${areaText(areaSqm)} sq.m × $topcoatGalPerSqm gal/sq.m (2 finish coats) '
      '${resultText(areaSqm * topcoatGalPerSqm, gal, 'gal')} (4 L)\n'
      '(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, 2 finish coats; primer counted separately)';

  static String skimCoatFormulaString(double areaSqm, double bags) {
    return '${areaText(areaSqm)} sq.m ÷ $skimCoatSqmPerBag sq.m per 20 kg bag '
        '${resultText(areaSqm / skimCoatSqmPerBag, bags, 'bags')}\n'
        '(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer coverage, 20 kg bag per 10 sq.m)';
  }

  // ---------------------------------------------------------------------------
  // 5. MASONRY / CHB WALLS (DPWH Vol. III Item 1046 / 1027 — Extension Scope)
  // ---------------------------------------------------------------------------

  static const List<({String value, String label, double thicknessM})> chbSizes = [
    (value: '4"', label: '4" CHB (100 × 200 × 400 mm) - Partition', thicknessM: 0.10),
    (value: '6"', label: '6" CHB (150 × 200 × 400 mm) - Load-Bearing', thicknessM: 0.15),
  ];

  static const double chbPerSqm = 12.5;

  static double calculateChbPieces(double wallAreaSqm) =>
      roundUp(wallAreaSqm * chbPerSqm * (1.0 + chbWasteFactor));

  static String chbFormulaString(double wallAreaSqm, double resultPcs) {
    return '${areaText(wallAreaSqm)} sq.m wall × $chbPerSqm pcs/sq.m × 1.05 breakage '
        '${resultText(wallAreaSqm * chbPerSqm * (1.0 + chbWasteFactor), resultPcs, 'pcs')} CHB\n'
        '(Material spec: DPWH Vol. III Item 1046 Masonry Works; units to PNS ASTM C90/C129:2019 | Quantity: 400x200 mm block face + 5% breakage)';
  }

  /// Class B mortar for the block joints and 16 mm of Class B plaster on
  /// both faces, per sq.m of wall (Fajardo). Cement in 40 kg bags, sand in
  /// cu.m. 0.38 bags and 0.032 cu.m are 2 faces × 0.016 m × 12.0 bags and
  /// × 1.0 cu.m per cu.m of mortar.
  static ({double mortarCement, double mortarSand, double plasterCement, double plasterSand})
      chbRates(String chbSizeKey) {
    final isSixInch = chbSizeKey.contains('6');
    return (
      mortarCement: isSixInch ? 1.02 : 0.52,
      mortarSand: isSixInch ? 0.084 : 0.044,
      plasterCement: 0.38,
      plasterSand: 0.032,
    );
  }

  static ({double cementBags, double sandCum}) calculateChbMortarAndPlaster(double wallAreaSqm, String chbSizeKey) {
    final r = chbRates(chbSizeKey);
    return (
      cementBags: math.max(
          1.0, roundUp(wallAreaSqm * clean(r.mortarCement + r.plasterCement))),
      sandCum:
          roundUpHundredths(wallAreaSqm * clean(r.mortarSand + r.plasterSand)),
    );
  }

  static String chbCementFormulaString(double wallAreaSqm, String chbSizeKey, double bags) {
    final r = chbRates(chbSizeKey);
    final rate = clean(r.mortarCement + r.plasterCement);
    return '${areaText(wallAreaSqm)} sq.m wall × (${numText(r.mortarCement)} mortar + '
        '${numText(r.plasterCement)} two-face plaster = ${numText(rate)} bags/sq.m) '
        '${resultText(wallAreaSqm * rate, bags, 'bags')} (40 kg cement)\n'
        '(Material spec: DPWH Vol. III Item 1046 Masonry Works and Item 1027 Cement Plaster Finish | Quantity: Class B 1:3 mortar + 16 mm two-face plaster, Fajardo)';
  }

  static String chbSandFormulaString(double wallAreaSqm, String chbSizeKey, double sandCum) {
    final r = chbRates(chbSizeKey);
    final rate = clean(r.mortarSand + r.plasterSand);
    return '${areaText(wallAreaSqm)} sq.m wall × (${numText(r.mortarSand)} mortar + '
        '${numText(r.plasterSand)} two-face plaster = ${numText(rate)} cu.m/sq.m) '
        '${resultText(wallAreaSqm * rate, sandCum, 'cu.m')} washed sand\n'
        '(Material spec: DPWH Vol. III Item 1046 Masonry Works and Item 1027 Cement Plaster Finish | Quantity: Class B 1:3 mortar + 16 mm two-face plaster, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 6. STRUCTURAL CONCRETE SLAB (DPWH Vol. III Item 900 Class A 1:2:4 — Extension Scope)
  // ---------------------------------------------------------------------------

  static const List<({String value, String label, double thicknessM})> slabThicknesses = [
    (value: '100mm', label: '100 mm (4") Slab on Grade', thicknessM: 0.10),
    (value: '125mm', label: '125 mm (5") Reinforced Slab', thicknessM: 0.125),
    (value: '150mm', label: '150 mm (6") Heavy Suspended Slab', thicknessM: 0.15),
  ];

  /// Class A (1:2:4) concrete per cu.m: 9.0 bags of 40 kg cement, 0.50 cu.m
  /// sand and 1.00 cu.m gravel (Fajardo).
  static const double classACementBagsPerCum = 9.0;
  static const double classASandCumPerCum = 0.50;
  static const double classAGravelCumPerCum = 1.00;

  static double slabThicknessM(String thicknessKey) => slabThicknesses
      .firstWhere(
        (t) => t.value == thicknessKey,
        orElse: () => slabThicknesses[0],
      )
      .thicknessM;

  static double slabVolumeCum(double areaSqm, String thicknessKey) =>
      areaSqm * slabThicknessM(thicknessKey);

  /// Sand and gravel are the computed volume rounded up to 0.01 cu.m. They
  /// used to be rounded to the nearest 0.01 and then raised to at least
  /// 0.25 and 0.50 cu.m, so a small slab's formula printed a product that
  /// did not equal the quantity beside it.
  static ({double cementBags, double sandCum, double gravelCum}) calculateStructuralConcreteSlab(double areaSqm, String thicknessKey) {
    final volumeCum = slabVolumeCum(areaSqm, thicknessKey);
    return (
      cementBags: math.max(1.0, roundUp(volumeCum * classACementBagsPerCum)),
      sandCum: roundUpHundredths(volumeCum * classASandCumPerCum),
      gravelCum: roundUpHundredths(volumeCum * classAGravelCumPerCum),
    );
  }

  /// "3.0 sq.m × 0.1 m = 0.3 cu.m of concrete".
  static String slabVolumeText(double areaSqm, String thicknessKey) =>
      '${areaText(areaSqm)} sq.m × ${numText(slabThicknessM(thicknessKey))} m = '
      '${numText(slabVolumeCum(areaSqm, thicknessKey))} cu.m of concrete';

  static const String _classASource =
      '(Material spec: DPWH Vol. III Item 900 Reinforced Concrete | Quantity: Class A 1:2:4 mix, 9.0 bags + 0.50 cu.m sand + 1.00 cu.m gravel per cu.m, Fajardo)';

  static String structuralCementFormulaString(double areaSqm, String thicknessKey, double bags) {
    final volume = slabVolumeCum(areaSqm, thicknessKey);
    return '${slabVolumeText(areaSqm, thicknessKey)} × $classACementBagsPerCum bags/cu.m '
        '${resultText(volume * classACementBagsPerCum, bags, 'bags')} (40 kg cement)\n$_classASource';
  }

  static String slabSandFormulaString(double areaSqm, String thicknessKey, double sandCum) {
    final volume = slabVolumeCum(areaSqm, thicknessKey);
    return '${slabVolumeText(areaSqm, thicknessKey)} × $classASandCumPerCum cu.m sand/cu.m '
        '${resultText(volume * classASandCumPerCum, sandCum, 'cu.m')} washed sand\n$_classASource';
  }

  static String slabGravelFormulaString(double areaSqm, String thicknessKey, double gravelCum) {
    final volume = slabVolumeCum(areaSqm, thicknessKey);
    return '${slabVolumeText(areaSqm, thicknessKey)} × $classAGravelCumPerCum cu.m gravel/cu.m '
        '${resultText(volume * classAGravelCumPerCum, gravelCum, 'cu.m')} crushed gravel\n$_classASource';
  }

  // ---------------------------------------------------------------------------
  // 7. STEEL REINFORCEMENT (DPWH Vol. III Item 902 / PNS 49:2020 — Extension Scope)
  // ---------------------------------------------------------------------------

  static const List<({String value, String label, int diameterMm, double kgPerMeter})> rebarSizes = [
    (value: '10mm', label: '10 mm Ø Deformed Rebar', diameterMm: 10, kgPerMeter: 0.617),
    (value: '12mm', label: '12 mm Ø Deformed Rebar', diameterMm: 12, kgPerMeter: 0.888),
    (value: '16mm', label: '16 mm Ø Deformed Rebar', diameterMm: 16, kgPerMeter: 1.578),
  ];

  /// Bar per sq.m of CHB wall, before laps and cut-offs, and the commercial
  /// length it is sold in.
  static const double rebarMPerSqm = 4.28;
  static const double rebarBarLengthM = 6.0;
  static const double tieWireKgPerSqm = 0.025;

  static double rebarLengthM(double wallAreaSqm) =>
      wallAreaSqm * rebarMPerSqm * (1.0 + rebarWasteFactor);

  /// Commercial 6 m bars and #16 tie wire for CHB wall reinforcement. The
  /// tie wire is the computed weight rounded up to 0.01 kg; it used to be
  /// raised to at least 0.5 kg, which its formula never said.
  static ({double totalKg, int commercialBars, double tieWireKg}) calculateChbRebar(double wallAreaSqm, String rebarKey) {
    final rebarSpec = rebarSizes.firstWhere(
      (r) => r.value == rebarKey,
      orElse: () => rebarSizes[0], // Default to 10mm
    );
    final totalMeters = rebarLengthM(wallAreaSqm);
    return (
      totalKg: totalMeters * rebarSpec.kgPerMeter,
      commercialBars:
          math.max(1, roundUp(totalMeters / rebarBarLengthM).toInt()),
      tieWireKg: roundUpHundredths(wallAreaSqm * tieWireKgPerSqm),
    );
  }

  /// The 5% for laps and cut-offs is in the count, so it is in the formula:
  /// "64.07 m ÷ 6.0 m" used to sit beside a count of 12, which is 67.28 m.
  static String rebarFormulaString(double wallAreaSqm, String rebarKey, int bars) {
    final rebarSpec = rebarSizes.firstWhere(
      (r) => r.value == rebarKey,
      orElse: () => rebarSizes[0],
    );
    final metres = rebarLengthM(wallAreaSqm);
    return '${areaText(wallAreaSqm)} sq.m wall × $rebarMPerSqm m/sq.m × 1.05 laps and cut-offs = '
        '${numText(metres)} m ÷ $rebarBarLengthM m per bar '
        '${resultText(metres / rebarBarLengthM, bars.toDouble(), 'pcs')} (${rebarSpec.label}, 6.0 m commercial length)\n'
        '(Material spec: DPWH Vol. III Item 902 Reinforcing Steel; bars to PNS 49:2020 | Quantity: W = D²/162.2 nominal mass, spacing per NSCP detailing)';
  }

  static String tieWireFormulaString(double wallAreaSqm, double kg) =>
      '${areaText(wallAreaSqm)} sq.m wall × $tieWireKgPerSqm kg/sq.m '
      '${resultText(wallAreaSqm * tieWireKgPerSqm, kg, 'kg')} #16 G.I. tie wire\n'
      '(Material spec: DPWH Vol. III Item 902 Reinforcing Steel | Quantity: tie wire for CHB wall reinforcement, Fajardo)';

  // ---------------------------------------------------------------------------
  // 7b. ROOFING (Roof Repair — sized from the floor/plan area)
  // ---------------------------------------------------------------------------
  //
  // Builders know the floor area of the house, not the sloped surface of the
  // roof, so quantities start from plan area and apply a slope factor.

  /// Sloped roof area per sq.m of plan: 1 / cos 30° ≈ 1.155, a common pitch.
  static const double roofSlopeFactor = 1.15;

  /// Width a rib-type sheet covers after its side lap.
  static const double ribTypeEffectiveWidthM = 1.0;

  /// Standard concrete roof tile coverage. Clay tiles run about 16 per sq.m.
  static const double concreteRoofTilesPerSqm = 10.5;
  static const double roofTileBreakageFactor = 0.05;
  static const double ridgeTilesPerMeter = 3.0;

  /// Purlins at 600 mm, fastened every second rib.
  static const double tekscrewsPerSqm = 8.0;
  static const double roofSqmPerSealantCan = 15.0;
  static const double ridgeMetersPerCementBag = 6.0;

  static double roofAreaFromPlan(double planAreaSqm) =>
      planAreaSqm * roofSlopeFactor;

  /// Ridge length before rounding up: √plan × 1.10 lap.
  static double ridgeLengthRawM(double planAreaSqm) =>
      math.sqrt(planAreaSqm) * (1.0 + roofingWasteFactor);

  /// Ridge length, taking the plan as square, plus lap, in whole metres.
  /// Rough by nature: the formula text tells the builder to measure it.
  static double ridgeLengthM(double planAreaSqm) =>
      roundUp(ridgeLengthRawM(planAreaSqm));

  static double ribTypeLinearMetersRaw(double planAreaSqm) =>
      roofAreaFromPlan(planAreaSqm) /
      ribTypeEffectiveWidthM *
      (1.0 + roofingWasteFactor);

  static double calculateRibTypeLinearMeters(double planAreaSqm) =>
      roundUp(ribTypeLinearMetersRaw(planAreaSqm));

  static double roofTilePiecesRaw(double planAreaSqm) =>
      roofAreaFromPlan(planAreaSqm) *
      concreteRoofTilesPerSqm *
      (1.0 + roofTileBreakageFactor);

  static double calculateRoofTilePieces(double planAreaSqm) =>
      roundUp(roofTilePiecesRaw(planAreaSqm));

  static double calculateRidgeTilePieces(double planAreaSqm) =>
      roundUp(ridgeLengthM(planAreaSqm) * ridgeTilesPerMeter);

  static double calculateTekscrews(double planAreaSqm) =>
      roundUp(roofAreaFromPlan(planAreaSqm) * tekscrewsPerSqm);

  static double calculateRoofSealantCans(double planAreaSqm) => math.max(
      1.0, roundUp(roofAreaFromPlan(planAreaSqm) / roofSqmPerSealantCan));

  static double calculateRidgeCementBags(double planAreaSqm) => math.max(
      1.0, roundUp(ridgeLengthM(planAreaSqm) / ridgeMetersPerCementBag));

  static String roofAreaLine(double planAreaSqm) =>
      '${areaText(planAreaSqm)} sq.m floor × $roofSlopeFactor slope '
      'factor (about 30° pitch) = '
      '${areaText(roofAreaFromPlan(planAreaSqm))} sq.m roof';

  static String ribTypeFormulaString(double planAreaSqm, double lnM) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${areaText(roofAreaFromPlan(planAreaSqm))} sq.m ÷ '
      '$ribTypeEffectiveWidthM m effective width × 1.10 lap '
      '${resultText(ribTypeLinearMetersRaw(planAreaSqm), lnM, 'ln.m')}\n'
      '(Quantity: rib-type sheet covers 1.0 m of width after the side lap, plus '
      '10% side and end lap | order as sheets cut to your rafter length)';

  static String roofTileFormulaString(double planAreaSqm, double pcs) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${areaText(roofAreaFromPlan(planAreaSqm))} sq.m × '
      '$concreteRoofTilesPerSqm pcs/sq.m × 1.05 breakage '
      '${resultText(roofTilePiecesRaw(planAreaSqm), pcs, 'pcs')}\n'
      '(Quantity: standard concrete roof tile coverage; clay tiles run about '
      '16 pcs/sq.m, so confirm the coverage printed by the supplier)';

  /// "√12.0 sq.m = 3.4641 m × 1.10 lap = 3.8105 → 4 ln.m ridge".
  static String ridgeLengthText(double planAreaSqm) =>
      '√${areaText(planAreaSqm)} sq.m = ${_trimmed(clean(math.sqrt(planAreaSqm)), 4)} m '
      '× 1.10 lap ${resultText(ridgeLengthRawM(planAreaSqm), ridgeLengthM(planAreaSqm), 'ln.m')} ridge';

  static String ridgeFormulaString(double planAreaSqm, double qty, String unit) {
    final ridge = ridgeLengthM(planAreaSqm);
    final perMeter = unit.toLowerCase().contains('pc')
        ? '\n${numText(ridge)} ln.m × $ridgeTilesPerMeter pcs/ln.m '
            '${resultText(ridge * ridgeTilesPerMeter, qty, 'pcs')}'
        : '';
    return '${ridgeLengthText(planAreaSqm)}$perMeter\n'
        '(Quantity: ridge taken from a square plan; measure the actual ridge '
        'before ordering)';
  }

  static String tekscrewFormulaString(double planAreaSqm, double pcs) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${areaText(roofAreaFromPlan(planAreaSqm))} sq.m × '
      '$tekscrewsPerSqm pcs/sq.m '
      '${resultText(roofAreaFromPlan(planAreaSqm) * tekscrewsPerSqm, pcs, 'pcs')}\n'
      '(Quantity: purlins at 600 mm, fastened every second rib)';

  static String roofSealantFormulaString(double planAreaSqm, double cans) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${areaText(roofAreaFromPlan(planAreaSqm))} sq.m ÷ '
      '$roofSqmPerSealantCan sq.m per 1 L can '
      '${resultText(roofAreaFromPlan(planAreaSqm) / roofSqmPerSealantCan, cans, 'cans')}\n'
      '(Quantity: laps, screw heads and flashing joints)';

  static String ridgeCementFormulaString(double planAreaSqm, double bags) {
    final ridge = ridgeLengthM(planAreaSqm);
    return '${ridgeLengthText(planAreaSqm)}\n'
        '${numText(ridge)} ln.m ÷ $ridgeMetersPerCementBag ln.m per 40 kg bag '
        '${resultText(ridge / ridgeMetersPerCementBag, bags, 'bags')}\n'
        '(Quantity: mortar bedding under the ridge tiles)';
  }

  // Roof drainage. A gable roof sheds water to two eaves, each taken as long as
  // the ridge, so the gutter length inherits the ridge's rough square-plan
  // assumption and its formula says to measure the eaves.

  static const double gutterPieceLengthM = 3.0;
  static const double gutterBracketSpacingM = 0.60;
  static const double gutterMetersPerDownspout = 9.0;
  static const double elbowsPerDownspout = 2.0;

  static double gutterLengthM(double planAreaSqm) =>
      2 * ridgeLengthM(planAreaSqm);

  static double calculateGutterPieces(double planAreaSqm) =>
      roundUp(gutterLengthM(planAreaSqm) / gutterPieceLengthM);

  static double calculateGutterBrackets(double planAreaSqm) =>
      roundUp(gutterLengthM(planAreaSqm) / gutterBracketSpacingM);

  static double calculateDownspouts(double planAreaSqm) => math.max(
      2.0,
      roundUp(gutterLengthM(planAreaSqm) / gutterMetersPerDownspout));

  static double calculateDownspoutElbows(double planAreaSqm) =>
      calculateDownspouts(planAreaSqm) * elbowsPerDownspout;

  static String gutterLengthLine(double planAreaSqm) =>
      '${ridgeLengthText(planAreaSqm)}\n'
      '2 eaves × ${numText(ridgeLengthM(planAreaSqm))} ln.m = '
      '${numText(gutterLengthM(planAreaSqm))} ln.m of gutter';

  static String gutterFormulaString(double planAreaSqm, double pcs) {
    final gutter = gutterLengthM(planAreaSqm);
    return '${gutterLengthLine(planAreaSqm)} ÷ $gutterPieceLengthM m per length '
        '${resultText(gutter / gutterPieceLengthM, pcs, 'pcs')}\n'
        '(Quantity: gutters along both eaves, each eave taken as the ridge length; '
        'measure the real eaves before ordering)';
  }

  static String gutterBracketFormulaString(double planAreaSqm, double pcs) {
    final gutter = gutterLengthM(planAreaSqm);
    return '${gutterLengthLine(planAreaSqm)} ÷ $gutterBracketSpacingM m spacing '
        '${resultText(gutter / gutterBracketSpacingM, pcs, 'pcs')}\n'
        '(Quantity: one bracket every 0.60 m of gutter)';
  }

  static String downspoutFormulaString(double planAreaSqm, double pcs) {
    final gutter = gutterLengthM(planAreaSqm);
    final raw = gutter / gutterMetersPerDownspout;
    final atLeastTwo = roundUp(raw) < 2 ? ', raised to the minimum of 2' : '';
    return '${gutterLengthLine(planAreaSqm)} ÷ $gutterMetersPerDownspout m per downspout '
        '= ${_trimmed(clean(raw), 4)} → ${numText(pcs)} downspouts$atLeastTwo, one 3 m length each\n'
        '(Quantity: at least 2 on a one-storey house; add a length per downspout for each extra storey)';
  }

  static String downspoutElbowFormulaString(double planAreaSqm, double pcs) =>
      '${numText(calculateDownspouts(planAreaSqm))} downspouts × '
      '${numText(elbowsPerDownspout)} elbows = ${numText(pcs)} pcs\n'
      '(Quantity: one elbow at the gutter outlet and one at the foot)';

}
