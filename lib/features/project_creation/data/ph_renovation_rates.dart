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
  // 1. FLOOR TILES (Footprint Area based, Non-Slip / Matt)
  // ---------------------------------------------------------------------------

  /// Standard floor tile sizes available in Philippine hardware stores.
  static const List<({String value, String label, double widthM, double lengthM})> floorTileSizes = [
    (value: '300x300', label: '300 × 300 mm (12"×12")', widthM: 0.30, lengthM: 0.30),
    (value: '400x400', label: '400 × 400 mm (16"×16")', widthM: 0.40, lengthM: 0.40),
    (value: '600x600', label: '600 × 600 mm (24"×24")', widthM: 0.60, lengthM: 0.60),
  ];

  /// DPWH Item 1018: Tile pieces formula = (Area / (W * L)) * 1.08
  static double calculateFloorTilePieces(double areaSqm, String sizeKey) {
    final size = floorTileSizes.firstWhere(
      (s) => s.value == sizeKey,
      orElse: () => floorTileSizes[2], // Default to 600x600
    );
    final tileArea = size.widthM * size.lengthM;
    final rawPcs = (areaSqm / tileArea) * (1.0 + tileWasteFactor);
    return rawPcs.ceilToDouble();
  }

  /// DPWH Item 1018 formula transparency string for floor tiles
  static String floorTileFormulaString(double areaSqm, String sizeKey, double resultPcs) {
    final size = floorTileSizes.firstWhere(
      (s) => s.value == sizeKey,
      orElse: () => floorTileSizes[2],
    );
    final tileArea = size.widthM * size.lengthM;
    return '(${areaSqm.toStringAsFixed(1)} sq.m ÷ [${size.widthM}m × ${size.lengthM}m = ${tileArea.toStringAsFixed(3)}m²]) × 1.08 waste = ${resultPcs.toInt()} pcs\n(Material spec: DPWH Vol. III Item 1018 Ceramic/Granite Tiles | Quantity: tile face geometry + 8% cutting waste, Fajardo)';
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

  /// DPWH Item 1018: Wall tile pieces formula = (Wall Area / (W * L)) * 1.08
  static double calculateWallTilePieces(double wallAreaSqm, String sizeKey) {
    final size = wallTileSizes.firstWhere(
      (s) => s.value == sizeKey,
      orElse: () => wallTileSizes[1], // Default to 300x600
    );
    final tileArea = size.widthM * size.lengthM;
    final rawPcs = (wallAreaSqm / tileArea) * (1.0 + tileWasteFactor);
    return rawPcs.ceilToDouble();
  }

  /// DPWH Item 1018 formula transparency string for wall tiles
  static String wallTileFormulaString(double wallAreaSqm, String sizeKey, double resultPcs) {
    final size = wallTileSizes.firstWhere(
      (s) => s.value == sizeKey,
      orElse: () => wallTileSizes[1],
    );
    final tileArea = size.widthM * size.lengthM;
    return '(${wallAreaSqm.toStringAsFixed(1)} sq.m wall ÷ [${size.widthM}m × ${size.lengthM}m = ${tileArea.toStringAsFixed(3)}m²]) × 1.08 waste = ${resultPcs.toInt()} pcs\n(Material spec: DPWH Vol. III Item 1018 Ceramic/Granite Tiles | Quantity: tile face geometry + 8% cutting waste, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 3. TILE ADHESIVE & TILE GROUT CONSUMPTION
  // ---------------------------------------------------------------------------

  /// DPWH Item 1018: Tile adhesive 25kg bags (1 bag covers approx 4.5 sqm)
  static double calculateTileAdhesiveBags(double areaSqm) {
    final bags = areaSqm * 0.22;
    return math.max(1.0, bags.ceilToDouble());
  }

  static String tileAdhesiveFormulaString(double areaSqm, double resultBags) {
    return '${areaSqm.toStringAsFixed(1)} sq.m × 0.22 bags/sq.m = ${resultBags.toInt()} bags (25kg Heavy-Duty Adhesive)\n(Material spec: DPWH Vol. III Item 1018 | Quantity: manufacturer coverage, 25 kg bag per 4.5 sq.m at 6 mm notch)';
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
    return math.max(1.0, (kg / 2.0).ceilToDouble());
  }

  static String tileGroutFormulaString(double areaSqm, String sizeKey, double resultPacks) {
    return '${areaSqm.toStringAsFixed(1)} sq.m × grout joint factor = ${(resultPacks * 2).toStringAsFixed(1)} kg → ${resultPacks.toInt()} packs (2kg pack)\n(Material spec: DPWH Vol. III Item 1018 | Quantity: joint volume from tile size, manufacturer coverage)';
  }

  /// Cement & Sand for Floor Screed / Tile Mortar Bedding (25mm thick Class B 1:3 mix)
  static ({double cementBags, double sandCum}) calculateTileBeddingMortar(double areaSqm) {
    final cementBags = math.max(1.0, (areaSqm * 0.25).ceilToDouble());
    final sandCum = double.parse((areaSqm * 0.025).toStringAsFixed(2));
    return (cementBags: cementBags, sandCum: math.max(0.25, sandCum));
  }

  static String beddingCementFormulaString(double areaSqm, double bags) {
    return '${areaSqm.toStringAsFixed(1)} sq.m × 0.25 bags/sq.m = ${bags.toInt()} bags (40kg Portland Cement for screed/bedding)\n(Material spec: DPWH Vol. III Item 1018 | Quantity: 25 mm Class B 1:3 bedding, Fajardo)';
  }

  static String beddingSandFormulaString(double areaSqm, double sandCum) {
    return '${areaSqm.toStringAsFixed(1)} sq.m × 0.025 m³/sq.m = ${sandCum.toStringAsFixed(2)} m³ Washed Sand\n(Material spec: DPWH Vol. III Item 1018 | Quantity: 25 mm Class B 1:3 bedding, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 4. PAINTING WORKS (DPWH Vol. III Item 1032 — 3-Coat System)
  // ---------------------------------------------------------------------------

  /// Calculates Paint (4L Gallons), Skim Coat (20kg bags), and Masonry Putty (4L)
  static ({double primerGal, double topcoatGal, double totalGal, double skimCoatBags}) calculatePaintWorks(double areaSqm) {
    final primer = math.max(1.0, (areaSqm * 0.04).ceilToDouble()); // 1 coat primer
    final topcoat = math.max(1.0, (areaSqm * 0.06).ceilToDouble()); // 2 coats topcoat
    final totalPaint = primer + topcoat;
    final skimCoat = math.max(1.0, (areaSqm * 0.09).ceilToDouble()); // 20kg bag covers 10-12 sqm
    return (
      primerGal: primer,
      topcoatGal: topcoat,
      totalGal: totalPaint,
      skimCoatBags: skimCoat,
    );
  }

  static String paintFormulaString(double areaSqm, double totalGal) {
    return '${areaSqm.toStringAsFixed(1)} sq.m × 0.10 gal/sq.m (1 coat primer + 2 topcoats) = ${totalGal.toInt()} gal (4L Gallon)\n(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, Fajardo)';
  }

  static String skimCoatFormulaString(double areaSqm, double bags) {
    return '${areaSqm.toStringAsFixed(1)} sq.m × 0.09 bags/sq.m = ${bags.toInt()} bags (20kg Skim Coat)\n(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer coverage, 20 kg bag per 10 sq.m)';
  }

  // ---------------------------------------------------------------------------
  // 5. MASONRY / CHB WALLS (DPWH Vol. III Item 1046 / 1027 — Extension Scope)
  // ---------------------------------------------------------------------------

  static const List<({String value, String label, double thicknessM})> chbSizes = [
    (value: '4"', label: '4" CHB (100 × 200 × 400 mm) - Partition', thicknessM: 0.10),
    (value: '6"', label: '6" CHB (150 × 200 × 400 mm) - Load-Bearing', thicknessM: 0.15),
  ];

  /// Block count formula = Wall Area * 12.5 pcs/sqm * 1.05 waste
  static double calculateChbPieces(double wallAreaSqm) {
    final raw = wallAreaSqm * 12.5 * (1.0 + chbWasteFactor);
    return raw.ceilToDouble();
  }

  static String chbFormulaString(double wallAreaSqm, double resultPcs) {
    return '${wallAreaSqm.toStringAsFixed(1)} sq.m wall × 12.5 pcs/sq.m × 1.05 waste = ${resultPcs.toInt()} pcs CHB\n(Material spec: DPWH Vol. III Item 1046 Masonry Works; units to PNS ASTM C90/C129:2019 | Quantity: 400x200 mm block face + 5% breakage)';
  }

  /// CHB Mortar & 2-Side Plastering Cement (40kg bag) and Sand (m³)
  static ({double cementBags, double sandCum}) calculateChbMortarAndPlaster(double wallAreaSqm, String chbSizeKey) {
    final isSixInch = chbSizeKey.contains('6');
    final mortarCementRate = isSixInch ? 1.02 : 0.52;
    final mortarSandRate = isSixInch ? 0.084 : 0.044;
    const plasterCementRate = 0.38; // 2-face 16mm plaster
    const plasterSandRate = 0.032;

    final totalCementRate = mortarCementRate + plasterCementRate; // 0.90 for 4", 1.40 for 6"
    final totalSandRate = mortarSandRate + plasterSandRate; // 0.076 for 4", 0.116 for 6"

    final cementBags = math.max(1.0, (wallAreaSqm * totalCementRate).ceilToDouble());
    final sandCum = double.parse((wallAreaSqm * totalSandRate).toStringAsFixed(2));

    return (cementBags: cementBags, sandCum: math.max(0.25, sandCum));
  }

  static String chbCementFormulaString(double wallAreaSqm, String chbSizeKey, double bags) {
    final isSixInch = chbSizeKey.contains('6');
    final rate = isSixInch ? 1.40 : 0.90;
    return '${wallAreaSqm.toStringAsFixed(1)} sq.m wall × $rate bags/sq.m (Mortar + 2-Side Plaster) = ${bags.toInt()} bags (40kg Cement)\n(Material spec: DPWH Vol. III Item 1046 Masonry Works and Item 1027 Cement Plaster Finish | Quantity: Class B 1:3 mortar + 16 mm two-face plaster, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 6. STRUCTURAL CONCRETE SLAB (DPWH Vol. III Item 900 Class A 1:2:4 — Extension Scope)
  // ---------------------------------------------------------------------------

  static const List<({String value, String label, double thicknessM})> slabThicknesses = [
    (value: '100mm', label: '100 mm (4") Slab on Grade', thicknessM: 0.10),
    (value: '125mm', label: '125 mm (5") Reinforced Slab', thicknessM: 0.125),
    (value: '150mm', label: '150 mm (6") Heavy Suspended Slab', thicknessM: 0.15),
  ];

  static ({double cementBags, double sandCum, double gravelCum}) calculateStructuralConcreteSlab(double areaSqm, String thicknessKey) {
    final thickness = slabThicknesses.firstWhere(
      (t) => t.value == thicknessKey,
      orElse: () => slabThicknesses[0],
    );
    final volumeCum = areaSqm * thickness.thicknessM;

    // Class A (1:2:4 Mix): 9.0 bags cement, 0.50 m³ sand, 1.00 m³ gravel per m³ concrete
    final cementBags = math.max(1.0, (volumeCum * 9.0).ceilToDouble());
    final sandCum = double.parse((volumeCum * 0.50).toStringAsFixed(2));
    final gravelCum = double.parse((volumeCum * 1.00).toStringAsFixed(2));

    return (
      cementBags: cementBags,
      sandCum: math.max(0.25, sandCum),
      gravelCum: math.max(0.50, gravelCum),
    );
  }

  static String structuralCementFormulaString(double areaSqm, String thicknessKey, double bags) {
    final thickness = slabThicknesses.firstWhere(
      (t) => t.value == thicknessKey,
      orElse: () => slabThicknesses[0],
    );
    final vol = areaSqm * thickness.thicknessM;
    return 'Volume: ${areaSqm.toStringAsFixed(1)} sq.m × ${thickness.thicknessM}m = ${vol.toStringAsFixed(2)} m³ × 9.0 bags/m³ = ${bags.toInt()} bags (40kg Cement)\n(Material spec: DPWH Vol. III Item 900 Reinforced Concrete | Quantity: Class A 1:2:4 mix, 9.0 bags + 0.50 m3 sand + 1.00 m3 gravel per m3, Fajardo)';
  }

  // ---------------------------------------------------------------------------
  // 7. STEEL REINFORCEMENT (DPWH Vol. III Item 902 / PNS 49:2020 — Extension Scope)
  // ---------------------------------------------------------------------------

  static const List<({String value, String label, int diameterMm, double kgPerMeter})> rebarSizes = [
    (value: '10mm', label: '10 mm Ø Deformed Rebar', diameterMm: 10, kgPerMeter: 0.617),
    (value: '12mm', label: '12 mm Ø Deformed Rebar', diameterMm: 12, kgPerMeter: 0.888),
    (value: '16mm', label: '16 mm Ø Deformed Rebar', diameterMm: 16, kgPerMeter: 1.578),
  ];

  /// Rebar Nominal Weight Formula W = (D² / 162.2) * L
  static double calculateRebarWeightPerMeter(int diameterMm) {
    return double.parse(((diameterMm * diameterMm) / 162.2).toStringAsFixed(3));
  }

  /// Calculates total 6.0-meter commercial rebar lengths for CHB wall reinforcement
  static ({double totalKg, int commercialBars, double tieWireKg}) calculateChbRebar(double wallAreaSqm, String rebarKey) {
    final rebarSpec = rebarSizes.firstWhere(
      (r) => r.value == rebarKey,
      orElse: () => rebarSizes[0], // Default to 10mm
    );
    // Standard CHB reinforcement spacing @ 60cm vertical + every 3 layers horizontal = 4.28 linear meters per sqm
    final totalMeters = wallAreaSqm * 4.28 * (1.0 + rebarWasteFactor);
    final totalKg = totalMeters * rebarSpec.kgPerMeter;
    final commercialBars = (totalMeters / 6.0).ceil(); // 6.0m commercial bar length in PH
    final tieWireKg = math.max(0.5, double.parse((wallAreaSqm * 0.025).toStringAsFixed(2)));

    return (
      totalKg: double.parse(totalKg.toStringAsFixed(1)),
      commercialBars: math.max(1, commercialBars),
      tieWireKg: tieWireKg,
    );
  }

  static String rebarFormulaString(double wallAreaSqm, String rebarKey, int bars) {
    final rebarSpec = rebarSizes.firstWhere(
      (r) => r.value == rebarKey,
      orElse: () => rebarSizes[0],
    );
    return '${wallAreaSqm.toStringAsFixed(1)} sq.m wall × 4.28 m/sq.m = ${(wallAreaSqm * 4.28).toStringAsFixed(1)} lm ÷ 6.0m bar = $bars pcs (${rebarSpec.label} - 6.0m Commercial Length)\n(Material spec: DPWH Vol. III Item 902 Reinforcing Steel; bars to PNS 49:2020 | Quantity: W = D²/162.2 nominal mass, spacing per NSCP detailing)';
  }

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

  /// Ridge length, taking the plan as square, plus lap. Rough by nature: the
  /// formula text tells the builder to measure the real ridge.
  static double ridgeLengthM(double planAreaSqm) =>
      (math.sqrt(planAreaSqm) * (1.0 + roofingWasteFactor)).ceilToDouble();

  static double calculateRibTypeLinearMeters(double planAreaSqm) =>
      (roofAreaFromPlan(planAreaSqm) /
              ribTypeEffectiveWidthM *
              (1.0 + roofingWasteFactor))
          .ceilToDouble();

  static double calculateRoofTilePieces(double planAreaSqm) =>
      (roofAreaFromPlan(planAreaSqm) *
              concreteRoofTilesPerSqm *
              (1.0 + roofTileBreakageFactor))
          .ceilToDouble();

  static double calculateRidgeTilePieces(double planAreaSqm) =>
      (ridgeLengthM(planAreaSqm) * ridgeTilesPerMeter).ceilToDouble();

  static double calculateTekscrews(double planAreaSqm) =>
      (roofAreaFromPlan(planAreaSqm) * tekscrewsPerSqm).ceilToDouble();

  static double calculateRoofSealantCans(double planAreaSqm) => math.max(
      1.0, (roofAreaFromPlan(planAreaSqm) / roofSqmPerSealantCan).ceilToDouble());

  static double calculateRidgeCementBags(double planAreaSqm) => math.max(
      1.0, (ridgeLengthM(planAreaSqm) / ridgeMetersPerCementBag).ceilToDouble());

  static String roofAreaLine(double planAreaSqm) =>
      '${planAreaSqm.toStringAsFixed(1)} sq.m floor × $roofSlopeFactor slope '
      'factor (about 30° pitch) = '
      '${roofAreaFromPlan(planAreaSqm).toStringAsFixed(1)} sq.m roof';

  static String ribTypeFormulaString(double planAreaSqm, double lnM) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${roofAreaFromPlan(planAreaSqm).toStringAsFixed(1)} sq.m ÷ '
      '$ribTypeEffectiveWidthM m effective width × 1.10 lap = ${lnM.toInt()} ln.m\n'
      '(Quantity: rib-type sheet covers 1.0 m of width after the side lap, plus '
      '10% side and end lap | order as sheets cut to your rafter length)';

  static String roofTileFormulaString(double planAreaSqm, double pcs) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${roofAreaFromPlan(planAreaSqm).toStringAsFixed(1)} sq.m × '
      '$concreteRoofTilesPerSqm pcs/sq.m × 1.05 breakage = ${pcs.toInt()} pcs\n'
      '(Quantity: standard concrete roof tile coverage; clay tiles run about '
      '16 pcs/sq.m, so confirm the coverage printed by the supplier)';

  static String ridgeFormulaString(double planAreaSqm, double qty, String unit) {
    final ridge = ridgeLengthM(planAreaSqm);
    final perMeter = unit.toLowerCase().contains('pc')
        ? ' × $ridgeTilesPerMeter pcs/ln.m = ${qty.toInt()} pcs'
        : '';
    return '√${planAreaSqm.toStringAsFixed(1)} sq.m × 1.10 lap = '
        '${ridge.toInt()} ln.m ridge$perMeter\n'
        '(Quantity: ridge taken from a square plan; measure the actual ridge '
        'before ordering)';
  }

  static String tekscrewFormulaString(double planAreaSqm, double pcs) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${roofAreaFromPlan(planAreaSqm).toStringAsFixed(1)} sq.m × '
      '$tekscrewsPerSqm pcs/sq.m = ${pcs.toInt()} pcs\n'
      '(Quantity: purlins at 600 mm, fastened every second rib)';

  static String roofSealantFormulaString(double planAreaSqm, double cans) =>
      '${roofAreaLine(planAreaSqm)}\n'
      '${roofAreaFromPlan(planAreaSqm).toStringAsFixed(1)} sq.m ÷ '
      '$roofSqmPerSealantCan sq.m per 1 L can = ${cans.toInt()} cans\n'
      '(Quantity: laps, screw heads and flashing joints)';

  static String ridgeCementFormulaString(double planAreaSqm, double bags) =>
      '${ridgeLengthM(planAreaSqm).toInt()} ln.m ridge ÷ '
      '$ridgeMetersPerCementBag ln.m per 40 kg bag = ${bags.toInt()} bags\n'
      '(Quantity: mortar bedding under the ridge tiles)';

  // ---------------------------------------------------------------------------
  // 8. MASTER FOREMAN AUXILIARY & CONSUMABLE ITEMS
  // ---------------------------------------------------------------------------

  /// Calculates Master Foreman auxiliary items (Spacers, Teflon, Silicone, Sandpaper, Roller Sets, Formwork)
  static Map<String, dynamic> calculateForemanAuxiliaries({
    required double areaSqm,
    required bool isExtension,
    double wallAreaSqm = 0.0,
  }) {
    final tileSpacersPacks = math.max(1.0, (areaSqm / 10.0).ceilToDouble()); // 1 pack per 10 sqm
    final teflonTapeRolls = math.max(2.0, (areaSqm / 6.0).ceilToDouble()); // 1 roll per fixture/6 sqm
    final siliconeTubes = math.max(1.0, (areaSqm / 12.0).ceilToDouble()); // 1 tube 300ml per 12 sqm
    final sandpaperSheets = math.max(4.0, (areaSqm * 0.25).ceilToDouble()); // 1 sheet per 4 sqm
    final maskingTapeRolls = math.max(2.0, (areaSqm / 10.0).ceilToDouble()); // 2" rolls
    final rollerSets = math.max(1.0, (areaSqm / 30.0).ceilToDouble()); // 7" roller set

    if (!isExtension) {
      return {
        'tileSpacersPacks': tileSpacersPacks,
        'teflonTapeRolls': teflonTapeRolls,
        'siliconeTubes': siliconeTubes,
        'sandpaperSheets': sandpaperSheets,
        'maskingTapeRolls': maskingTapeRolls,
        'rollerSets': rollerSets,
      };
    }

    // Extension structural formwork auxiliaries
    final marinePlywoodSheets = math.max(2.0, (areaSqm / 5.0).ceilToDouble()); // 1/2" Marine Plywood 4'x8'
    final cocoLumberBdFt = math.max(30.0, (areaSqm * 2.5).ceilToDouble()); // 2x2 / 2x3 Coco Lumber
    final cwnNailsKg = math.max(2.0, (areaSqm * 0.15).ceilToDouble()); // Common Wire Nails CWN 2", 3", 4"
    final vulcasealTubes = math.max(1.0, (areaSqm / 15.0).ceilToDouble()); // Roof sealant

    return {
      'tileSpacersPacks': tileSpacersPacks,
      'teflonTapeRolls': teflonTapeRolls,
      'siliconeTubes': siliconeTubes,
      'sandpaperSheets': sandpaperSheets,
      'maskingTapeRolls': maskingTapeRolls,
      'rollerSets': rollerSets,
      'marinePlywoodSheets': marinePlywoodSheets,
      'cocoLumberBdFt': cocoLumberBdFt,
      'cwnNailsKg': cwnNailsKg,
      'vulcasealTubes': vulcasealTubes,
    };
  }
}
