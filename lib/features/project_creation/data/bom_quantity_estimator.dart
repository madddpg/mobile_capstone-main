import 'dart:math' as math;

import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// Scales template BOM quantities from a project area (sqm) using Philippine DPWH/NSCP standards.
class BomQuantityEstimator {
  BomQuantityEstimator._();

  /// [takeoff], when the room was measured, sizes each material from the
  /// surface it covers and fits the template's lines to the room. Without it
  /// every quantity starts from [areaSqm], as before.
  ///
  /// [counts], for a functional room, sizes the wiring devices and their wire
  /// and conduit from how many the builder actually asked for, rather than
  /// from the room's floor area — a wiring job is sized by the devices it
  /// installs, not by the room they happen to sit in.
  static List<RenovationTemplateItem> scaleTemplate({
    required RenovationTemplate template,
    required double areaSqm,
    RenovationScope scope = RenovationScope.cosmetic,
    RenovationTypes? types,
    SiteTakeoff? takeoff,
    FunctionalCounts? counts,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    final isConsultation = template.id.contains('consultation');
    final items = <RenovationTemplateItem>[];

    // Every question below is asked of the whole combination: a cosmetic and
    // functional job changes finishes, and a job with any structural work in it
    // keeps structural materials.
    final kinds = types ?? RenovationTypes.only(scope);

    // An AI BOM is exactly what the builder confirmed, so a measured room
    // sizes its lines but never adds or removes any. Purely functional work
    // replaces pipes and wiring, not finishes, so its lines are left as they
    // are too. Fitting only ever adds or drops finish lines, so the pipes and
    // wiring of a combined job pass through it untouched.
    final source = takeoff == null || isConsultation || !kinds.changesFinishes
        ? template.items
        : fitToRoom(template.items, takeoff,
            addMissing: !template.isFromWorkItems);

    for (final rawItem in source) {
      // Structural-only materials belong only when structural work is chosen.
      if (!kinds.includesStructural && _isStructuralOnlyItem(rawItem)) {
        continue;
      }

      // For tiles with no explicit size, pin the assumed default size and
      // switch the unit to pieces so the shop quotes the right thing (a piece
      // count against an unstated size is a ~4x ambiguity).
      final item = _pinTileDefaults(rawItem);

      // A device the builder asked for none of needs no wire to it either.
      // Dropped here rather than shown at a quantity of 0, which would block
      // the review screen's "every line needs a quantity" check.
      if (counts != null && _isUnneededWiring(item, counts)) continue;

      final scaledQty = estimateQuantity(
          item: item, areaSqm: area, takeoff: takeoff, counts: counts);
      items.add(
        item.copyWith(
          defaultQuantity: scaledQty,
          isSwappable: false,
          alternatives: const [],
        ),
      );
    }

    // Tiles cannot be set without adhesive and grout, and every tiled face
    // consumes both, walls included. An AI BOM is exactly what the builder
    // confirmed, so its lines are resized but none are added.
    _settleTileSetting(items, area,
        addMissing: !isConsultation, takeoff: takeoff);

    // Add Master Foreman Auxiliary Consumables if not present (skip for AI consultation templates)
    if (!isConsultation) {
      _addForemanAuxiliaries(items);
      // The spacer line is added above at one pack; size it from the tiled
      // face, as the adhesive and grout are.
      final settled = requantifyTileSetting(items, area, takeoff: takeoff);
      items
        ..clear()
        ..addAll(settled);
    }

    return items;
  }

  /// Whether changing [item] changes how much adhesive and grout the BOM needs.
  static bool affectsTileSetting(RenovationTemplateItem item) =>
      kTileKinds.contains(classifyMaterial(item));

  /// The tiled surface of a BOM, which is what adhesive and grout are sized
  /// from. `null` when the BOM has no floor or wall tile.
  ///
  /// Adhesive and grout used to be sized from the floor area alone. A 20 sq.m
  /// bathroom also carries about 44 sq.m of wall tile, so the BOM asked for
  /// 5 bags of adhesive against roughly 64 sq.m of tiling.
  static ({
    double floorSqm,
    double wallSqm,
    double groutKg,
    List<({String surface, double sqm, String size})> groutParts,
  })? tileSettingBasis(
    List<RenovationTemplateItem> items,
    double areaSqm, {
    SiteTakeoff? takeoff,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    RenovationTemplateItem? floor;
    RenovationTemplateItem? measuredWall;
    var wallSqm = 0.0;
    final parts = <({String surface, double sqm, String size})>[];

    for (final item in items) {
      switch (classifyMaterial(item)) {
        case MaterialKind.floorTile:
          // A second floor-tile line is another choice for the same floor, not
          // more floor.
          floor ??= item;
        case MaterialKind.wallTile when takeoff != null:
          // A measured room has one tiled wall surface, however many lines
          // offer tiles for it.
          measuredWall ??= item;
        case MaterialKind.wallTile:
          final sqm = _wallTileArea(item, area);
          wallSqm += sqm;
          parts.add((surface: 'wall', sqm: sqm, size: item.size ?? ''));
        default:
          break;
      }
    }

    if (takeoff != null && measuredWall != null) {
      wallSqm = takeoff.wallTileSqm;
      parts.add(
          (surface: 'wall', sqm: wallSqm, size: measuredWall.size ?? ''));
    }

    if (floor == null && wallSqm == 0) return null;
    final floorSqm = floor == null ? 0.0 : area;
    if (floor != null) {
      parts.insert(0, (surface: 'floor', sqm: floorSqm, size: floor.size ?? ''));
    }
    final groutKg = parts.fold(
        0.0,
        (sum, p) =>
            sum + p.sqm * PhRenovationRates.groutKgPerSqm(p.size));
    return (
      floorSqm: floorSqm,
      wallSqm: wallSqm,
      groutKg: groutKg,
      groutParts: parts,
    );
  }

  /// Tile spacers per sq.m of tile, before the 8% allowance: one pack per
  /// 10 sq.m of tiled face.
  static const double spacerPacksPerSqm = 0.10;

  static bool _isTileSpacer(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('spacer');

  /// Spacer packs for [tiledSqm] of tile, plus 8%, at least one pack.
  static double spacerPacks(double tiledSqm, [double? perSqm]) {
    final rate = perSqm != null && perSqm > 0 ? perSqm : spacerPacksPerSqm;
    return math.max(1.0, PhRenovationRates.roundUp(tiledSqm * rate * 1.08));
  }

  /// Re-sizes the adhesive and grout lines from the tiles currently in
  /// [items]. Adds nothing and removes nothing; a BOM without tiles is
  /// returned unchanged.
  static List<RenovationTemplateItem> requantifyTileSetting(
    List<RenovationTemplateItem> items,
    double areaSqm, {
    SiteTakeoff? takeoff,
  }) {
    final basis = tileSettingBasis(items, areaSqm, takeoff: takeoff);
    if (basis == null) return List.of(items);

    final tiledSqm = basis.floorSqm + basis.wallSqm;
    final bags = PhRenovationRates.calculateTileAdhesiveBags(tiledSqm);
    final packs = PhRenovationRates.groutPacksForKg(basis.groutKg);
    return [
      for (final item in items)
        switch (classifyMaterial(item)) {
          MaterialKind.tileAdhesive =>
            item.copyWith(defaultQuantity: bags, unit: 'bags'),
          MaterialKind.tileGrout =>
            item.copyWith(defaultQuantity: packs, unit: 'packs'),
          // Spacers sit in every joint, wall as well as floor. They used to
          // stay at the one pack they were added with, whatever the area.
          _ when _isTileSpacer(item) => item.copyWith(
              defaultQuantity: spacerPacks(tiledSqm, item.qtyPerSqm)),
          _ => item,
        },
    ];
  }

  /// Gives a tiled BOM exactly one adhesive and one grout line, sized from the
  /// whole tiled surface.
  static void _settleTileSetting(
    List<RenovationTemplateItem> items,
    double area, {
    required bool addMissing,
    SiteTakeoff? takeoff,
  }) {
    if (tileSettingBasis(items, area, takeoff: takeoff) == null) return;

    // A second adhesive or grout line would order the same material twice.
    for (final kind in const [MaterialKind.tileAdhesive, MaterialKind.tileGrout]) {
      var kept = false;
      items.removeWhere((item) {
        if (classifyMaterial(item) != kind) return false;
        if (!kept) return !(kept = true);
        return true;
      });
    }

    if (addMissing) {
      final kinds = items.map(classifyMaterial).toList();
      // Right after the tiles, so the setting materials read as part of them.
      var insertAt = kinds.lastIndexWhere((k) =>
              kTileKinds.contains(k) ||
              k == MaterialKind.tileAdhesive ||
              k == MaterialKind.tileGrout) +
          1;
      if (!kinds.contains(MaterialKind.tileAdhesive)) {
        items.insert(
          insertAt++,
          const RenovationTemplateItem(
            name: 'Tile Adhesive (25 kg)',
            category: 'Tile Setting',
            unit: 'bags',
            defaultQuantity: 1,
            notes: 'Sized from floor and wall tile area',
          ),
        );
      }
      if (!kinds.contains(MaterialKind.tileGrout)) {
        items.insert(
          insertAt,
          const RenovationTemplateItem(
            name: 'Tile Grout (2 kg)',
            category: 'Tile Setting',
            unit: 'packs',
            defaultQuantity: 1,
            notes: 'Sized from floor and wall tile area and tile face size',
          ),
        );
      }
    }

    final settled = requantifyTileSetting(items, area, takeoff: takeoff);
    items
      ..clear()
      ..addAll(settled);
  }

  static bool _isStructuralOnlyItem(RenovationTemplateItem item) {
    return kStructuralOnlyKinds.contains(classifyMaterial(item));
  }

  /// Tiles are priced per piece. If the template left [size] unset we assume a
  /// standard size (600x600 floor / 300x600 wall); pin it explicitly and set the
  /// unit to `pcs` so the number the shop sees is unambiguous, and so the
  /// "View Formula" text matches the piece count.
  static RenovationTemplateItem _pinTileDefaults(RenovationTemplateItem item) {
    final kind = classifyMaterial(item);
    if (kind != MaterialKind.floorTile && kind != MaterialKind.wallTile) {
      return item;
    }
    final assumedSize = (item.size == null || item.size!.trim().isEmpty)
        ? (kind == MaterialKind.wallTile ? '300x600' : '600x600')
        : item.size!;
    final unit = item.unit.toLowerCase() == 'pcs' ? item.unit : 'pcs';
    if (assumedSize == item.size && unit == item.unit) return item;
    return item.copyWith(size: assumedSize, unit: unit);
  }

  /// Appends Master Foreman auxiliary items (Spacers, Teflon Tape, Silicone, Sandpaper, Roller Sets)
  static void _addForemanAuxiliaries(
    List<RenovationTemplateItem> items,
  ) {
    final names = items.map((i) => i.name.toLowerCase()).toSet();
    final kinds = items.map(classifyMaterial).toSet();
    final hasTiling = kinds.any(kTileKinds.contains) ||
        kinds.contains(MaterialKind.tileAdhesive) ||
        kinds.contains(MaterialKind.tileGrout);
    final hasPlumbing = kinds.contains(MaterialKind.plumbingFixture);
    final hasPainting = kinds.any(kPaintKinds.contains);

    if (hasTiling && !names.any((n) => n.contains('spacer'))) {
      items.add(
        const RenovationTemplateItem(
          name: 'Tile Cross Spacers (2mm/3mm)',
          category: 'Installation & Auxiliaries',
          unit: 'packs',
          defaultQuantity: 1,
          qtyPerSqm: 0.10,
          notes: 'Foreman essential — keeps tile joint lines uniform',
        ),
      );
    }

    if (hasPlumbing && !names.any((n) => n.contains('teflon'))) {
      items.add(
        const RenovationTemplateItem(
          name: 'Teflon Threadseal Tape (3/4")',
          category: 'Plumbing Supplies',
          unit: 'rolls',
          defaultQuantity: 2,
          notes: 'Foreman essential — prevents faucet & valve thread leaks',
        ),
      );
    }

    if (hasPlumbing && !names.any((n) => n.contains('silicone'))) {
      items.add(
        const RenovationTemplateItem(
          name: 'Sanitary Silicone Sealant (300ml)',
          category: 'Plumbing Supplies',
          unit: 'tubes',
          defaultQuantity: 1,
          notes: 'Foreman essential — seals sink rim & toilet base',
        ),
      );
    }

    if ((hasPainting || hasTiling) &&
        !names.any((n) => n.contains('sandpaper'))) {
      items.add(
        const RenovationTemplateItem(
          name: 'Assorted Sandpaper (Grit 100/180)',
          category: 'Painting Supplies',
          unit: 'sheets',
          defaultQuantity: 4,
          notes: 'Foreman essential — for smoothing skim coat & putty',
        ),
      );
    }

    if (hasPainting && !names.any((n) => n.contains('roller'))) {
      items.add(
        const RenovationTemplateItem(
          name: 'Paint Roller Set (7") with Tray',
          category: 'Painting Supplies',
          unit: 'set',
          defaultQuantity: 1,
          notes: 'Foreman essential — for latex wall painting',
        ),
      );
    }

    // Structural templates list their own walls, slab and forms. Adding a
    // slab and CHB walls to every structural job put a slab under a roof
    // replacement and walls into a floor repair.
  }

  /// Wall surface area for a wall-*tile* item. Honours the template's own
  /// `qtyPerSqm` as the floor->wall multiplier when present (a kitchen backsplash
  /// carries 0.35, a full bathroom wall carries 2.2); otherwise the DPWH 2.2x
  /// default. This is what stops a backsplash being estimated at 2.2 m2 of
  /// subway tile per m2 of floor.
  ///
  /// A measured room replaces the multiplier with the tiled wall it measured.
  static double _wallTileArea(
    RenovationTemplateItem item,
    double area, [
    SiteTakeoff? takeoff,
  ]) {
    if (takeoff != null) return takeoff.wallTileSqm;
    final mult = item.qtyPerSqm;
    if (mult != null && mult > 0) return area * mult;
    return area * 2.2;
  }

  /// The floor area quantities start from: the measured floor when there is
  /// one, otherwise the area the builder entered.
  static double _baseArea(double areaSqm, SiteTakeoff? takeoff) {
    if (takeoff != null && takeoff.floorSqm > 0) return takeoff.floorSqm;
    return areaSqm <= 0 ? 1.0 : areaSqm;
  }

  /// Wall and ceiling left for paint. Unmeasured, paint is sized from the
  /// floor area, as it always was.
  ///
  /// Roof paint covers the sloped roof, not the plan it was measured from.
  static double _paintArea(
    double area,
    SiteTakeoff? takeoff, [
    RenovationTemplateItem? item,
  ]) {
    if (item != null && _isRoofWork(item)) {
      return PhRenovationRates.roofAreaFromPlan(area);
    }
    return takeoff?.paintSqm ?? area;
  }

  static bool _isRoofWork(RenovationTemplateItem item) =>
      '${item.name} ${item.category}'.toLowerCase().contains('roof');

  /// Which gutter-and-downspout line [item] is, or `null` if it is not one.
  static String? _drainagePart(RenovationTemplateItem item) {
    if (!_isRoofWork(item) ||
        !item.category.toLowerCase().contains('drainage')) {
      return null;
    }
    final name = item.name.toLowerCase();
    if (name.contains('bracket')) return 'bracket';
    if (name.contains('gutter')) return 'gutter';
    if (name.contains('downspout')) {
      return name.contains('elbow') ? 'elbow' : 'downspout';
    }
    return null;
  }

  static double? _roofDrainageQuantity(
    RenovationTemplateItem item,
    double area,
  ) =>
      switch (_drainagePart(item)) {
        'gutter' => PhRenovationRates.calculateGutterPieces(area),
        'bracket' => PhRenovationRates.calculateGutterBrackets(area),
        'downspout' => PhRenovationRates.calculateDownspouts(area),
        'elbow' => PhRenovationRates.calculateDownspoutElbows(area),
        _ => null,
      };

  static String? _roofDrainageFormula(
    RenovationTemplateItem item,
    double area,
    double qty,
  ) =>
      switch (_drainagePart(item)) {
        'gutter' => PhRenovationRates.gutterFormulaString(area, qty),
        'bracket' => PhRenovationRates.gutterBracketFormulaString(area, qty),
        'downspout' => PhRenovationRates.downspoutFormulaString(area, qty),
        'elbow' => PhRenovationRates.downspoutElbowFormulaString(area, qty),
        _ => null,
      };

  /// Wall area for new CHB walls: the measured walls less their doors and
  /// windows, otherwise the 2.2 × floor assumption.
  static double _newWallArea(double area, SiteTakeoff? takeoff) =>
      takeoff != null && takeoff.netWallSqm > 0
          ? takeoff.netWallSqm
          : area * 2.2;

  static bool _isSkirting(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('skirting');

  static bool _isUnderlayment(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('underlayment');

  static bool _isCountertop(RenovationTemplateItem item) {
    final name = item.name.toLowerCase();
    return name.contains('countertop') || name.contains('counter top');
  }

  static bool _isBeddingCement(RenovationTemplateItem item) =>
      classifyMaterial(item) == MaterialKind.cementBedding &&
      !_isRidgeBedding(item);

  static bool _isBeddingSand(RenovationTemplateItem item) =>
      classifyMaterial(item) == MaterialKind.washedSand &&
      !_isSlabSand(item) &&
      !_isMasonrySand(item);

  /// Skirting runs round the room less its doorways, plus 5% for mitred
  /// corners and cut ends.
  static double _skirtingQuantity(SiteTakeoff takeoff) {
    final lm = PhRenovationRates.roundUp(takeoff.skirtingM * 1.05);
    return lm < 1 ? 1.0 : lm;
  }

  /// Counter top at a standard 0.60 m depth, plus 8% for cutting.
  static double _countertopQuantity(SiteTakeoff takeoff) {
    final sqm = PhRenovationRates.roundUp(takeoff.countertopSqm * 1.08);
    return sqm < 1 ? 1.0 : sqm;
  }

  // ── Functional wiring (Functional scope only) ──────────────────────────
  //
  // Outlets, switches, lights, and the wire and conduit that serve them, used
  // to scale off the room's floor area. A 39 sq.m living room and a 12 sq.m
  // bedroom got wiring proportional to their floors, whichever number of
  // outlets the builder actually wanted. These size instead from the device
  // counts a builder enters on the measuring step — [FunctionalCounts].

  static bool _isOutletDevice(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('convenience outlet');

  static bool _isLightSwitchDevice(RenovationTemplateItem item) =>
      item.category.toLowerCase().contains('wiring devices') &&
      item.name.toLowerCase().contains('switch');

  static bool _isCeilingLightDevice(RenovationTemplateItem item) =>
      item.category.toLowerCase() == 'lighting' &&
      item.name.toLowerCase().contains('light');

  static bool _isUtilityBoxDevice(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('utility box');

  static bool _isOutletCircuitWire(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('3.5 mm');

  static bool _isLightingCircuitWire(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('2.0 mm');

  /// The kitchen's dedicated appliance circuit — one run to one appliance,
  /// not something that scales with how many outlets the rest of the room has.
  static bool _isApplianceCircuitWire(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('5.5 mm');

  static bool _isElectricalConduit(RenovationTemplateItem item) {
    final name = item.name.toLowerCase();
    return name.contains('conduit') && !name.contains('coupling');
  }

  static bool _isConduitCoupling(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('coupling');

  /// Average wire run from a circuit's loop to one device. An outlet usually
  /// sits further from the loop than a switch or a light does.
  static const double kOutletRunM = 3.0;
  static const double kLightingRunM = 2.5;

  /// One run from the panel to the appliance location — fixed, because a
  /// dedicated circuit does not get longer with more outlets in the room.
  static const double kApplianceCircuitRunM = 8.0;

  static double _outletCircuitRunM(FunctionalCounts counts) =>
      counts.outlets * kOutletRunM;

  static double _lightingCircuitRunM(FunctionalCounts counts) =>
      (counts.switches + counts.lights) * kLightingRunM;

  /// A count-driven electrical line the builder asked for none of — no
  /// outlets requested, so no outlet-circuit wire either. The line is dropped
  /// rather than shown at a quantity of 0.
  static bool _isUnneededWiring(
      RenovationTemplateItem item, FunctionalCounts counts) {
    if (classifyMaterial(item) != MaterialKind.electrical) return false;
    final wiring = _functionalWiringQuantity(item, counts);
    return wiring != null && wiring <= 0;
  }

  /// Quantity for one of the lines [FunctionalCounts] drives, or `null` when
  /// [item] is not one of them — a circuit breaker and electrical tape are
  /// electrical too, but are fixed counts unrelated to how many devices the
  /// builder asked for, so they fall through to [_scaleByRate] as before.
  static double? _functionalWiringQuantity(
    RenovationTemplateItem item,
    FunctionalCounts counts,
  ) {
    // The name tests below are loose ("coupling"), so a PPR coupling in a
    // combined plumbing and wiring job must not be sized as conduit.
    if (classifyMaterial(item) != MaterialKind.electrical) return null;
    if (_isOutletDevice(item)) return counts.outlets.toDouble();
    if (_isLightSwitchDevice(item)) return counts.switches.toDouble();
    if (_isCeilingLightDevice(item)) return counts.lights.toDouble();
    if (_isUtilityBoxDevice(item)) return counts.deviceCount.toDouble();
    if (_isOutletCircuitWire(item)) {
      final m = _outletCircuitRunM(counts);
      return m <= 0 ? 0.0 : PhRenovationRates.roundUp(m * 1.08);
    }
    if (_isLightingCircuitWire(item)) {
      final m = _lightingCircuitRunM(counts);
      return m <= 0 ? 0.0 : PhRenovationRates.roundUp(m * 1.08);
    }
    if (_isApplianceCircuitWire(item)) {
      return PhRenovationRates.roundUp(kApplianceCircuitRunM * 1.08);
    }
    if (_isElectricalConduit(item) || _isConduitCoupling(item)) {
      final totalRunM = _outletCircuitRunM(counts) + _lightingCircuitRunM(counts);
      return totalRunM <= 0 ? 0.0 : PhRenovationRates.roundUp(totalRunM / 3.0);
    }
    return null;
  }

  /// [_functionalWiringQuantity]'s formula string, for the "View Formula"
  /// panel, worked out to [qty]. `null` for the lines that function leaves
  /// unmatched.
  static String? _functionalWiringFormula(
    RenovationTemplateItem item,
    FunctionalCounts counts,
    double qty,
  ) {
    String devicePlural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
    String n(double v) => PhRenovationRates.numText(v);
    final unit = item.unit;

    if (classifyMaterial(item) != MaterialKind.electrical) return null;
    if (_isOutletDevice(item)) {
      return '${devicePlural(counts.outlets, 'outlet')} requested = '
          '${n(qty)} $unit\n'
          '(Quantity: set by the builder, not scaled from the room)';
    }
    if (_isLightSwitchDevice(item)) {
      return '${devicePlural(counts.switches, 'switch')} requested = '
          '${n(qty)} $unit\n'
          '(Quantity: set by the builder, not scaled from the room)';
    }
    if (_isCeilingLightDevice(item)) {
      return '${devicePlural(counts.lights, 'light')} requested = '
          '${n(qty)} $unit\n'
          '(Quantity: set by the builder, not scaled from the room)';
    }
    if (_isUtilityBoxDevice(item)) {
      return '${devicePlural(counts.outlets, 'outlet')} + '
          '${devicePlural(counts.switches, 'switch')} + '
          '${devicePlural(counts.lights, 'light')} = '
          '${n(qty)} $unit\n'
          '(Quantity: one utility box per device)';
    }
    if (_isOutletCircuitWire(item)) {
      final run = _outletCircuitRunM(counts);
      return '${devicePlural(counts.outlets, 'outlet')} × $kOutletRunM m per run '
          '= ${n(run)} m × 1.08 waste '
          '${PhRenovationRates.resultText(run * 1.08, qty, unit)}\n'
          '(Quantity: app assumption of an average outlet run off the circuit '
          'loop, plus 8% waste — a wiring diagram may call for more or less)';
    }
    if (_isLightingCircuitWire(item)) {
      final devices = counts.switches + counts.lights;
      final run = _lightingCircuitRunM(counts);
      return '${devicePlural(devices, 'switch or light')} × $kLightingRunM m per '
          'run = ${n(run)} m × 1.08 waste '
          '${PhRenovationRates.resultText(run * 1.08, qty, unit)}\n'
          '(Quantity: app assumption of an average lighting-circuit run, plus '
          '8% waste)';
    }
    if (_isApplianceCircuitWire(item)) {
      return '1 dedicated circuit × $kApplianceCircuitRunM m × 1.08 waste '
          '${PhRenovationRates.resultText(kApplianceCircuitRunM * 1.08, qty, unit)}\n'
          '(Quantity: app assumption of one run from the panel to the '
          'appliance location)';
    }
    if (_isElectricalConduit(item) || _isConduitCoupling(item)) {
      final outletRun = _outletCircuitRunM(counts);
      final lightingRun = _lightingCircuitRunM(counts);
      final totalRunM = outletRun + lightingRun;
      final per = _isConduitCoupling(item)
          ? 'one coupling per 3 m conduit length'
          : 'conduit in 3 m lengths';
      return '${n(outletRun)} m outlet run + ${n(lightingRun)} m lighting run '
          '= ${n(totalRunM)} m of circuit run ÷ 3 m per length '
          '${PhRenovationRates.resultText(totalRunM / 3.0, qty, unit)}\n'
          '(Quantity: outlet and lighting runs share one raceway, $per; the '
          'run is measured before the 8% wire allowance)';
    }
    return null;
  }

  static bool _isDeviceLine(RenovationTemplateItem item) =>
      classifyMaterial(item) == MaterialKind.electrical &&
      (_isOutletDevice(item) ||
          _isLightSwitchDevice(item) ||
          _isCeilingLightDevice(item));

  /// The device counts once the builder types [quantity] on [item] in the
  /// review, or `null` when [item] is not an outlet, switch or light line.
  static FunctionalCounts? countsAfterEdit(
    RenovationTemplateItem item,
    double quantity,
    FunctionalCounts counts,
  ) {
    if (!_isDeviceLine(item)) return null;
    final n = quantity.isFinite ? quantity.round().clamp(0, 999) : 0;
    if (_isOutletDevice(item)) return counts.copyWith(outlets: n);
    if (_isLightSwitchDevice(item)) return counts.copyWith(switches: n);
    return counts.copyWith(lights: n);
  }

  /// Re-sizes the wire, conduit, couplings and utility boxes that [counts]
  /// drive, after a device count changed in the review.
  ///
  /// Typing 4 on the outlet line used to leave the outlet wire at the 10 m it
  /// had for 3 outlets, so the list no longer matched its own formula. The
  /// device lines keep the quantity typed on them, a line that would drop to
  /// nothing keeps its quantity, and every other line is returned as it is.
  static List<RenovationTemplateItem> requantifyWiring(
    List<RenovationTemplateItem> items,
    FunctionalCounts counts,
  ) =>
      [
        for (final item in items)
          if (_isDeviceLine(item))
            item
          else
            switch (_functionalWiringQuantity(item, counts)) {
              final qty? when qty > 0 && qty != item.defaultQuantity =>
                item.copyWith(defaultQuantity: qty),
              _ => item,
            },
      ];

  /// Generic fixed-count / rate-based scaling for items with no dedicated
  /// DPWH formula (fixtures, tools, linear goods, area goods).
  static double _scaleByRate(RenovationTemplateItem item, double area) {
    if (item.qtyPerSqm == null || item.qtyPerSqm! <= 0) {
      return item.defaultQuantity <= 0 ? 1 : item.defaultQuantity;
    }
    final raw = item.qtyPerSqm! * area;
    final withWaste = raw * 1.08;
    return withWaste < 1 ? 1.0 : PhRenovationRates.roundUp(withWaste);
  }

  /// Shown with a structural BOM. What can be sized from a room is listed;
  /// structural members need the engineer's plan.
  static const String structuralNote =
      'Structural quantities assume a 100 mm slab on grade and new wall area of '
      '2.2 × floor area in 4" CHB. Footings, columns, beams, roof framing and '
      'underpinning are not included; take those from a plan signed by a '
      'licensed civil engineer.';

  /// [structuralNote], restated for a measured room.
  static String structuralNoteFor(SiteTakeoff? takeoff) {
    if (takeoff == null || takeoff.netWallSqm <= 0) return structuralNote;
    return 'Structural quantities use the measured '
        '${PhRenovationRates.areaText(takeoff.floorSqm)} sq.m of floor for a 100 mm slab '
        'and the measured ${PhRenovationRates.areaText(takeoff.netWallSqm)} sq.m of wall, '
        'less doors and windows, for 4" CHB. Footings, columns, beams, roof '
        'framing and underpinning are not included; take those from a plan '
        'signed by a licensed civil engineer.';
  }

  /// Sand for slab concrete. Slab and wall work take far more sand per sq.m
  /// than a tile bedding screed, so each is sized from its own rate.
  static bool _isSlabSand(RenovationTemplateItem item) {
    final text = '${item.name} ${item.category}'.toLowerCase();
    return text.contains('slab') || text.contains('concrete');
  }

  /// Sand for CHB laying mortar and wall plaster.
  static bool _isMasonrySand(RenovationTemplateItem item) {
    if (_isSlabSand(item)) return false;
    final text = '${item.name} ${item.category}'.toLowerCase();
    return text.contains('plaster') ||
        text.contains('mortar') ||
        text.contains('chb');
  }

  /// Calculates material quantity according to Philippine DPWH/NSCP mathematical formulas.
  static double estimateQuantity({
    required RenovationTemplateItem item,
    required double areaSqm,
    SiteTakeoff? takeoff,
    FunctionalCounts? counts,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    final sizeKey = item.size ?? '';
    final wallArea = _newWallArea(area, takeoff);
    final paintArea = _paintArea(area, takeoff, item);

    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        return PhRenovationRates.calculateWallTilePieces(
            _wallTileArea(item, area, takeoff), sizeKey);
      case MaterialKind.floorTile:
        return PhRenovationRates.calculateFloorTilePieces(area, sizeKey);
      case MaterialKind.tileAdhesive:
        return PhRenovationRates.calculateTileAdhesiveBags(area);
      case MaterialKind.tileGrout:
        return PhRenovationRates.calculateTileGroutPacks(area, sizeKey);
      case MaterialKind.paintPrimer:
        return PhRenovationRates.calculatePaintWorks(paintArea).primerGal;
      case MaterialKind.paintTopcoat:
        // topcoat only — the Primer line is counted separately, so returning
        // totalGal here double-counts the primer coat.
        return PhRenovationRates.calculatePaintWorks(paintArea).topcoatGal;
      case MaterialKind.skimCoat:
        return PhRenovationRates.calculatePaintWorks(paintArea).skimCoatBags;
      case MaterialKind.waterproofing
          when takeoff != null &&
              takeoff.waterproofingSqm > 0 &&
              (item.qtyPerSqm ?? 0) > 0:
        return _scaleByRate(item, takeoff.waterproofingSqm);
      case MaterialKind.areaGoods
          when takeoff != null &&
              _isCountertop(item) &&
              takeoff.countertopSqm > 0:
        return _countertopQuantity(takeoff);
      case MaterialKind.genericConsumable
          when takeoff != null && _isSkirting(item) && takeoff.skirtingM > 0:
        return _skirtingQuantity(takeoff);
      case MaterialKind.structuralCement:
        return PhRenovationRates.calculateStructuralConcreteSlab(
            area, sizeKey.isEmpty ? '100mm' : sizeKey).cementBags;
      case MaterialKind.roofingSheet:
        return _roofingQuantity(item, area);
      case MaterialKind.roofSealant:
        return PhRenovationRates.calculateRoofSealantCans(area);
      case MaterialKind.genericConsumable when _isTekscrew(item):
        return PhRenovationRates.calculateTekscrews(area);
      case MaterialKind.cementBedding when _isRidgeBedding(item):
        return PhRenovationRates.calculateRidgeCementBags(area);
      case MaterialKind.cementBedding:
        return PhRenovationRates.calculateTileBeddingMortar(area).cementBags;
      case MaterialKind.chbMortar:
        return PhRenovationRates.calculateChbMortarAndPlaster(
            wallArea, sizeKey.isEmpty ? '4"' : sizeKey).cementBags;
      case MaterialKind.washedSand:
        if (_isSlabSand(item)) {
          return PhRenovationRates.calculateStructuralConcreteSlab(
              area, sizeKey.isEmpty ? '100mm' : sizeKey).sandCum;
        }
        if (_isMasonrySand(item)) {
          return PhRenovationRates.calculateChbMortarAndPlaster(
              wallArea, sizeKey.isEmpty ? '4"' : sizeKey).sandCum;
        }
        return PhRenovationRates.calculateTileBeddingMortar(area).sandCum;
      case MaterialKind.gravel:
        return PhRenovationRates.calculateStructuralConcreteSlab(
            area, sizeKey.isEmpty ? '100mm' : sizeKey).gravelCum;
      case MaterialKind.chbBlock:
        return PhRenovationRates.calculateChbPieces(wallArea);
      case MaterialKind.rebar:
        return PhRenovationRates.calculateChbRebar(
                wallArea, sizeKey.isEmpty ? '10mm' : sizeKey)
            .commercialBars
            .toDouble();
      case MaterialKind.tieWire:
        return PhRenovationRates.calculateChbRebar(
            wallArea, sizeKey.isEmpty ? '10mm' : sizeKey).tieWireKg;
      default:
        if (counts != null) {
          final wiring = _functionalWiringQuantity(item, counts);
          if (wiring != null) return wiring;
        }
        return _roofDrainageQuantity(item, area) ?? _scaleByRate(item, area);
    }
  }

  /// Recalculates quantity live when user picks a different size in the BOM review.
  ///
  /// The size changes the quantity through the same rules that set it, so a
  /// resized line and a freshly estimated one can never disagree.
  static ({double newQty, String formulaString}) recalculateForSize({
    required RenovationTemplateItem item,
    required String newSize,
    required double areaSqm,
    SiteTakeoff? takeoff,
    FunctionalCounts? counts,
  }) {
    final resized = item.copyWith(size: newSize);
    final qty = estimateQuantity(
        item: resized, areaSqm: areaSqm, takeoff: takeoff, counts: counts);
    return (
      newQty: qty,
      formulaString: getFormulaString(
        item: resized,
        areaSqm: areaSqm,
        currentQty: qty,
        takeoff: takeoff,
        counts: counts,
      ),
    );
  }

  static String _tiledAreaLine(double floorSqm, double wallSqm) =>
      'Tiled area: ${PhRenovationRates.areaText(floorSqm)} sq.m floor + '
      '${PhRenovationRates.areaText(wallSqm)} sq.m wall = '
      '${PhRenovationRates.areaText(floorSqm + wallSqm)} sq.m';

  /// The quantity [item]'s measurements give, worked out exactly as the list
  /// was built. Adhesive, grout and spacers come from the tiles in [bom].
  static double computedQuantity({
    required RenovationTemplateItem item,
    required double areaSqm,
    List<RenovationTemplateItem> bom = const [],
    SiteTakeoff? takeoff,
    FunctionalCounts? counts,
  }) {
    final basis = tileSettingBasis(bom, areaSqm, takeoff: takeoff);
    switch (classifyMaterial(item)) {
      case MaterialKind.tileAdhesive when basis != null:
        return PhRenovationRates.calculateTileAdhesiveBags(
            basis.floorSqm + basis.wallSqm);
      case MaterialKind.tileGrout when basis != null:
        return PhRenovationRates.groutPacksForKg(basis.groutKg);
      default:
        if (basis != null && _isTileSpacer(item)) {
          return spacerPacks(basis.floorSqm + basis.wallSqm, item.qtyPerSqm);
        }
        return estimateQuantity(
            item: item, areaSqm: areaSqm, takeoff: takeoff, counts: counts);
    }
  }

  /// Returns formula transparency string for displaying on material cards.
  ///
  /// The working always arrives at the quantity the measurements give, so
  /// every figure in it can be checked by hand. When the builder typed a
  /// different quantity, that is said underneath rather than written in as
  /// the result of a sum that does not produce it.
  ///
  /// [bom] is the whole list the line sits in. Adhesive, grout and spacers
  /// are sized from the tiles in it, so their formula needs it.
  static String getFormulaString({
    required RenovationTemplateItem item,
    required double areaSqm,
    required double currentQty,
    List<RenovationTemplateItem> bom = const [],
    SiteTakeoff? takeoff,
    FunctionalCounts? counts,
  }) {
    final qty = computedQuantity(
        item: item,
        areaSqm: areaSqm,
        bom: bom,
        takeoff: takeoff,
        counts: counts);
    final formula = _formulaFor(
        item: item,
        areaSqm: areaSqm,
        qty: qty,
        bom: bom,
        takeoff: takeoff,
        counts: counts);
    final same = (PhRenovationRates.clean(currentQty) -
                PhRenovationRates.clean(qty))
            .abs() <
        1e-9;
    if (same) return formula;
    return '$formula\nYou changed this line to ${_fmtQty(currentQty)} '
        '${item.unit}. The working above is the quantity the measurements '
        'give.';
  }

  static String _formulaFor({
    required RenovationTemplateItem item,
    required double areaSqm,
    required double qty,
    required List<RenovationTemplateItem> bom,
    SiteTakeoff? takeoff,
    FunctionalCounts? counts,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    final sizeKey = item.size ?? '';
    final slabKey = sizeKey.isEmpty ? '100mm' : sizeKey;
    final wallArea = _newWallArea(area, takeoff);
    final paintArea = _paintArea(area, takeoff, item);
    String n(double v) => PhRenovationRates.numText(v);
    String sqm(double v) => PhRenovationRates.areaText(v);
    String result(double raw) =>
        PhRenovationRates.resultText(raw, qty, item.unit);

    // A measured room states its measurement first, so the builder can check
    // the room before checking the rate.
    final floorLine = takeoff?.floorLine;
    final wallLine =
        takeoff == null || takeoff.netWallSqm <= 0 ? null : takeoff.wallLine;
    final paintLine = _isRoofWork(item)
        ? PhRenovationRates.roofAreaLine(area)
        : takeoff?.paintLine;
    String measured(String? line, String formula) =>
        line == null ? formula : '$line\n$formula';

    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        return measured(
          takeoff?.wallTileLine,
          PhRenovationRates.wallTileFormulaString(
              _wallTileArea(item, area, takeoff), sizeKey, qty),
        );
      case MaterialKind.floorTile:
        return measured(
          floorLine,
          PhRenovationRates.floorTileFormulaString(area, sizeKey, qty),
        );
      case MaterialKind.tileAdhesive:
        final basis = tileSettingBasis(bom, area, takeoff: takeoff);
        if (basis == null) {
          return PhRenovationRates.tileAdhesiveFormulaString(area, qty);
        }
        return '${_tiledAreaLine(basis.floorSqm, basis.wallSqm)}\n'
            '${PhRenovationRates.tileAdhesiveFormulaString(basis.floorSqm + basis.wallSqm, qty)}';
      case MaterialKind.tileGrout:
        final basis = tileSettingBasis(bom, area, takeoff: takeoff);
        if (basis == null) {
          return PhRenovationRates.tileGroutFormulaString(area, sizeKey, qty);
        }
        final parts = [
          for (final p in basis.groutParts)
            PhRenovationRates.groutPartText(p.sqm, p.size, surface: p.surface),
        ].join(' + ');
        return '$parts ${PhRenovationRates.groutPacksText(basis.groutKg, qty)}\n'
            '(Material spec: DPWH Vol. III Item 1018 | Quantity: grout by tile face, 0.12 to 0.30 kg per sq.m; manufacturer coverage)';
      case MaterialKind.paintPrimer:
        return measured(
            paintLine, PhRenovationRates.primerFormulaString(paintArea, qty));
      case MaterialKind.paintTopcoat:
        return measured(
            paintLine, PhRenovationRates.topcoatFormulaString(paintArea, qty));
      case MaterialKind.skimCoat:
        return measured(
            paintLine, PhRenovationRates.skimCoatFormulaString(paintArea, qty));
      case MaterialKind.structuralCement:
        return measured(
          floorLine,
          PhRenovationRates.structuralCementFormulaString(area, slabKey, qty),
        );
      case MaterialKind.waterproofing
          when takeoff != null &&
              takeoff.waterproofingSqm > 0 &&
              (item.qtyPerSqm ?? 0) > 0:
        final rate = item.qtyPerSqm!;
        return '${takeoff.waterproofingLine}\n'
            '${sqm(takeoff.waterproofingSqm)} sq.m × ${n(rate)} ${item.unit}/sq.m × 1.08 '
            '${result(takeoff.waterproofingSqm * rate * 1.08)}\n'
            '(Quantity: manufacturer coverage for two coats plus 8% allowance | see docs/material-data-sources.md)';
      case MaterialKind.areaGoods
          when takeoff != null &&
              _isCountertop(item) &&
              takeoff.countertopSqm > 0:
        return '${takeoff.countertopLine}\n'
            '${sqm(takeoff.countertopSqm)} sq.m × 1.08 cutting allowance '
            '${result(takeoff.countertopSqm * 1.08)}\n'
            '(Quantity: standard 0.60 m counter depth plus 8% allowance, ordered in whole sq.m)';
      case MaterialKind.genericConsumable
          when takeoff != null && _isSkirting(item) && takeoff.skirtingM > 0:
        return '${takeoff.skirtingLine}\n'
            '${n(takeoff.skirtingM)} m × 1.05 cutting allowance '
            '${result(takeoff.skirtingM * 1.05)}\n'
            '(Quantity: room perimeter less doorways plus 5% for mitred corners)';
      case MaterialKind.roofingSheet when _roofingPart(item) != null:
        return switch (_roofingPart(item)) {
          'roofTile' => PhRenovationRates.roofTileFormulaString(area, qty),
          'sheet' => PhRenovationRates.ribTypeFormulaString(area, qty),
          _ => PhRenovationRates.ridgeFormulaString(area, qty, item.unit),
        };
      case MaterialKind.roofSealant:
        return PhRenovationRates.roofSealantFormulaString(area, qty);
      case MaterialKind.genericConsumable when _isTekscrew(item):
        return PhRenovationRates.tekscrewFormulaString(area, qty);
      case MaterialKind.cementBedding when _isRidgeBedding(item):
        return PhRenovationRates.ridgeCementFormulaString(area, qty);
      case MaterialKind.cementBedding:
        return measured(floorLine,
            PhRenovationRates.beddingCementFormulaString(area, qty));
      case MaterialKind.chbMortar:
        return measured(
          wallLine,
          PhRenovationRates.chbCementFormulaString(wallArea, sizeKey, qty),
        );
      case MaterialKind.washedSand:
        if (_isSlabSand(item)) {
          return measured(floorLine,
              PhRenovationRates.slabSandFormulaString(area, slabKey, qty));
        }
        if (_isMasonrySand(item)) {
          return measured(wallLine,
              PhRenovationRates.chbSandFormulaString(wallArea, sizeKey, qty));
        }
        return measured(
            floorLine, PhRenovationRates.beddingSandFormulaString(area, qty));
      case MaterialKind.gravel:
        return measured(floorLine,
            PhRenovationRates.slabGravelFormulaString(area, slabKey, qty));
      case MaterialKind.tieWire:
        return measured(
            wallLine, PhRenovationRates.tieWireFormulaString(wallArea, qty));
      case MaterialKind.chbBlock:
        return measured(
            wallLine, PhRenovationRates.chbFormulaString(wallArea, qty));
      case MaterialKind.rebar:
        return measured(
          wallLine,
          PhRenovationRates.rebarFormulaString(wallArea, sizeKey, qty.toInt()),
        );
      default:
        if (counts != null) {
          final wiring = _functionalWiringFormula(item, counts, qty);
          if (wiring != null) return wiring;
        }
        final drainage = _roofDrainageFormula(item, area, qty);
        if (drainage != null) return drainage;
        if (_isTileSpacer(item)) {
          final basis = tileSettingBasis(bom, area, takeoff: takeoff);
          if (basis != null) {
            final tiled = basis.floorSqm + basis.wallSqm;
            final rate = (item.qtyPerSqm ?? 0) > 0
                ? item.qtyPerSqm!
                : spacerPacksPerSqm;
            return '${_tiledAreaLine(basis.floorSqm, basis.wallSqm)}\n'
                '${sqm(tiled)} sq.m × ${n(rate)} packs/sq.m × 1.08 '
                '${result(tiled * rate * 1.08)}\n'
                '(Quantity: one pack per 10 sq.m of tiled face plus 8%, at least one pack)';
          }
        }
        final rate = item.qtyPerSqm;
        if (rate != null && rate > 0) {
          return measured(
            floorLine,
            '${sqm(area)} sq.m × ${n(rate)} ${item.unit}/sq.m × 1.08 '
            '${result(area * rate * 1.08)}\n'
            '(Quantity: template rate per sq.m of floor plus 8% allowance, at least 1 | see docs/material-data-sources.md)',
          );
        }
        return 'Fixed allowance: ${_fmtQty(qty)} ${item.unit} for this job, '
            'not sized from the measurements\n'
            '(Quantity: app allowance for one job of this kind; change it if '
            'your job needs more or less)';
    }
  }

  static String _fmtQty(double q) => PhRenovationRates.numText(q);

  static const Set<String> _linearUnits = {'ln.m', 'lm', 'l.m', 'm', 'linear m'};

  /// Which roofing line [item] is: 'ridgeTile', 'ridgeRoll', 'roofTile',
  /// 'sheet' (sold by the linear metre), or `null` for a piece-counted patch
  /// that keeps the template's own count.
  static String? _roofingPart(RenovationTemplateItem item) {
    final name = item.name.toLowerCase();
    final linear = _linearUnits.contains(item.unit.toLowerCase().trim());
    if (name.contains('ridge')) {
      if (name.contains('tile')) return 'ridgeTile';
      return linear ? 'ridgeRoll' : null;
    }
    if (name.contains('roof tile') || name.contains('roofing tile')) {
      return 'roofTile';
    }
    return linear ? 'sheet' : null;
  }

  /// Roofing quantities start from the plan area and apply the slope factor;
  /// see the roofing section of [PhRenovationRates].
  static double _roofingQuantity(RenovationTemplateItem item, double area) {
    switch (_roofingPart(item)) {
      case 'ridgeTile':
        return PhRenovationRates.calculateRidgeTilePieces(area);
      case 'ridgeRoll':
        return PhRenovationRates.ridgeLengthM(area);
      case 'roofTile':
        return PhRenovationRates.calculateRoofTilePieces(area);
      case 'sheet':
        return PhRenovationRates.calculateRibTypeLinearMeters(area);
      default:
        return _scaleByRate(item, area);
    }
  }

  static bool _isTekscrew(RenovationTemplateItem item) {
    final name = item.name.toLowerCase();
    return name.contains('tekscrew') || name.contains('tek screw');
  }

  /// Cement for bedding ridge tiles, sized from the ridge rather than from a
  /// floor screed.
  static bool _isRidgeBedding(RenovationTemplateItem item) =>
      item.name.toLowerCase().contains('ridge');

  /// Settles which "Available types" chips a BOM line offers.
  ///
  /// A chip replaces the line's material, so it may only offer the same kind
  /// of material: floor tile offers floor tile, flooring planks offer planks,
  /// topcoat offers topcoat. This used to match on loose substrings, so any
  /// name containing "tile" or any category containing "floor" got the
  /// floor-tile list. Tile Adhesive, Grout, Tile Spacers and a "Floor
  /// Installation" waterproofing membrane all offered "Ceramic Floor Tiles",
  /// and one tap turned 5 bags of adhesive into 61 bags of tiles.
  ///
  /// Lines with no genuine alternative used to get "Premium X" / "Economy X"
  /// chips. No shop can quote those, so such lines now offer no chips.
  ///
  /// The template's own alternatives come first; the standard list for the
  /// kind tops them up when fewer than two survive the kind check.
  static RenovationTemplateItem ensureSwappable(RenovationTemplateItem item) {
    final kind = classifyMaterial(item);
    bool fits(MaterialAlternative alt) =>
        alt.name.trim().isNotEmpty &&
        classifyMaterialParts(
              name: alt.name,
              category: item.category,
              unit: item.unit,
            ) ==
            kind;

    final alts = item.alternatives.where(fits).toList();
    if (alts.length < 2) {
      final seen = alts.map((a) => a.name.toLowerCase()).toSet();
      for (final alt in defaultAlternativesFor(item)) {
        if (fits(alt) && seen.add(alt.name.toLowerCase())) alts.add(alt);
      }
    }
    return item.copyWith(isSwappable: alts.isNotEmpty, alternatives: alts);
  }

  /// Standard alternatives for [item]'s material kind, or none.
  static List<MaterialAlternative> defaultAlternativesFor(
      RenovationTemplateItem item) {
    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        return const [
          MaterialAlternative(name: 'Subway Wall Tiles', size: '75x300'),
          MaterialAlternative(name: 'Ceramic Wall Tiles', size: '300x600'),
          MaterialAlternative(name: 'Large-format Wall Tiles', size: '600x1200'),
        ];
      case MaterialKind.floorTile:
        return const [
          MaterialAlternative(name: 'Ceramic Floor Tiles', size: '600x600'),
          MaterialAlternative(name: 'Porcelain Floor Tiles', size: '600x600'),
          MaterialAlternative(name: 'Non-Slip Floor Tiles', size: '300x300'),
        ];
      case MaterialKind.areaGoods:
        // Area goods also covers countertops and underlayment, which are not
        // interchangeable with a floor finish.
        if (!isFloorFinishGoods(item)) return const [];
        return const [
          MaterialAlternative(name: 'Vinyl Flooring Planks'),
          MaterialAlternative(name: 'SPC Flooring Planks'),
          MaterialAlternative(name: 'Laminate Flooring'),
        ];
      case MaterialKind.paintTopcoat when _isRoofWork(item):
        return const [
          MaterialAlternative(name: 'Acrylic Roof Paint'),
          MaterialAlternative(name: 'Elastomeric Roof Paint'),
        ];
      case MaterialKind.paintTopcoat:
        return const [
          MaterialAlternative(name: 'Matte Interior Paint'),
          MaterialAlternative(name: 'Semi-Gloss Interior Paint'),
          MaterialAlternative(name: 'Eggshell Interior Paint'),
        ];
      default:
        return const [];
    }
  }

  /// Replaces [item]'s material with [alternative], as a type chip does on the
  /// BOM review, and re-estimates the quantity for the new size.
  static RenovationTemplateItem applyAlternative({
    required RenovationTemplateItem item,
    required MaterialAlternative alternative,
    required double areaSqm,
    SiteTakeoff? takeoff,
  }) {
    final swapped = ensureSwappable(
      _pinTileDefaults(
        item.copyWith(
          name: alternative.name,
          size: alternative.size ?? item.size,
        ),
      ),
    );
    return swapped.copyWith(
      defaultQuantity: estimateQuantity(
          item: swapped, areaSqm: areaSqm, takeoff: takeoff),
    );
  }

  /// Fits a template's lines to a measured room, before quantities are set.
  ///
  /// A template is a style, not a survey. It cannot know that this bathroom is
  /// tiled to half height, that this bedroom's ceiling is painted, or that the
  /// old floor tiles are coming off. The measured room does:
  /// - a job with no floor loses its floor finish, bedding and skirting;
  /// - wall tile goes when the builder chose none, and is added when they chose
  ///   some and the template had none;
  /// - paint goes when no wall or ceiling is left bare, and paint with its
  ///   primer is added when some is;
  /// - a wet room gets waterproofing when the template left it out;
  /// - hacking off old tiles adds cement and sand for a new screed.
  ///
  /// Nothing else is touched, so fixtures, cabinets and countertops stay.
  ///
  /// With [addMissing] false, as for a list built from ticked work items,
  /// lines the room has no surface for are still dropped but none is added:
  /// a builder who left the walls untiled meant it. The screed still follows
  /// hacked-off tiles, since it is part of retiling the floor.
  static List<RenovationTemplateItem> fitToRoom(
    List<RenovationTemplateItem> items,
    SiteTakeoff takeoff, {
    bool addMissing = true,
  }) {
    final job = takeoff.job;
    bool ofKind(RenovationTemplateItem item, MaterialKind kind) =>
        classifyMaterial(item) == kind;
    bool isFloorFinish(RenovationTemplateItem item) =>
        ofKind(item, MaterialKind.floorTile) || isFloorFinishGoods(item);
    bool isFloorLine(RenovationTemplateItem item) =>
        isFloorFinish(item) ||
        _isUnderlayment(item) ||
        _isSkirting(item) ||
        _isBeddingCement(item) ||
        _isBeddingSand(item);

    final out = [
      for (final item in items)
        if (!(isFloorLine(item) && !job.hasFloor) &&
            !(ofKind(item, MaterialKind.wallTile) && takeoff.wallTileSqm <= 0) &&
            !(kPaintKinds.contains(classifyMaterial(item)) &&
                takeoff.paintSqm <= 0))
          item,
    ];
    int after(bool Function(RenovationTemplateItem) test) =>
        out.lastIndexWhere(test) + 1;

    if (!addMissing) {
      if (job.hasFloor &&
          takeoff.details.removeOldTiles &&
          out.any(isFloorFinish)) {
        final at = after(isFloorFinish);
        if (!out.any(_isBeddingSand)) out.insert(at, _screedSandRow);
        if (!out.any(_isBeddingCement)) out.insert(at, _screedCementRow);
      }
      return out;
    }

    if (job.hasFloor && !out.any(isFloorFinish)) {
      out.insert(
          0, job == RoomJob.wetRoom ? _nonSlipFloorTileRow : _floorTileRow);
    }
    if (takeoff.wallTileSqm > 0 &&
        !out.any((i) => ofKind(i, MaterialKind.wallTile))) {
      out.insert(
        after(isFloorFinish),
        takeoff.details.wallTileHeight == WallTileHeight.backsplash
            ? _backsplashTileRow
            : _wallTileRow,
      );
    }
    if (job.hasWaterproofing &&
        !out.any((i) => ofKind(i, MaterialKind.waterproofing))) {
      out.insert(after((i) => kTileKinds.contains(classifyMaterial(i))),
          _waterproofingRow);
    }
    if (takeoff.paintSqm > 0) {
      if (!out.any((i) => ofKind(i, MaterialKind.paintTopcoat))) {
        out.add(_paintRow);
      }
      if (!out.any((i) => ofKind(i, MaterialKind.paintPrimer))) {
        out.insert(
          out.indexWhere((i) => ofKind(i, MaterialKind.paintTopcoat)),
          _primerRow,
        );
      }
    }
    if (job.hasFloor && takeoff.details.removeOldTiles) {
      final at = after(isFloorFinish);
      if (!out.any(_isBeddingSand)) out.insert(at, _screedSandRow);
      if (!out.any(_isBeddingCement)) out.insert(at, _screedCementRow);
    }
    return out;
  }

  static const _floorTileRow = RenovationTemplateItem(
    name: 'Ceramic Floor Tiles',
    category: 'Floor Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '600x600',
    notes: 'Sized from the measured floor',
  );

  static const _nonSlipFloorTileRow = RenovationTemplateItem(
    name: 'Non-Slip Floor Tiles',
    category: 'Floor Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '600x600',
    notes: 'Non-slip for a wet floor',
  );

  static const _wallTileRow = RenovationTemplateItem(
    name: 'Ceramic Wall Tiles',
    category: 'Wall Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '300x600',
    notes: 'Sized from the measured tiled wall',
  );

  static const _backsplashTileRow = RenovationTemplateItem(
    name: 'Subway Wall Tiles',
    category: 'Wall Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '75x300',
    notes: 'Backsplash along the counter',
  );

  static const _waterproofingRow = RenovationTemplateItem(
    name: 'Cementitious Waterproofing',
    category: 'Waterproofing',
    unit: 'L',
    defaultQuantity: 1,
    qtyPerSqm: 0.8,
    notes: 'Two coats on the floor and a 0.30 m upturn',
  );

  static const _primerRow = RenovationTemplateItem(
    name: 'Concrete Primer (4 L)',
    category: 'Wall Finishing',
    unit: 'gal',
    defaultQuantity: 1,
    notes: 'Sealer coat under the paint',
  );

  static const _paintRow = RenovationTemplateItem(
    name: 'Interior Latex Paint (4 L)',
    category: 'Wall Finishing',
    unit: 'gal',
    defaultQuantity: 1,
    notes: 'Two finish coats on the bare walls and ceiling',
  );

  static const _screedCementRow = RenovationTemplateItem(
    name: 'Portland Cement - Floor Screed (40 kg)',
    category: 'Floor Preparation',
    unit: 'bags',
    defaultQuantity: 1,
    notes: 'New 25 mm screed once the old tiles are off',
  );

  static const _screedSandRow = RenovationTemplateItem(
    name: 'Washed Sand - Floor Screed',
    category: 'Floor Preparation',
    unit: 'cu.m',
    defaultQuantity: 1,
    notes: 'New 25 mm screed once the old tiles are off',
  );

  /// Best-effort scope guess for the AI consultation path, which never asks the
  /// user for a scope: Extension when the renovation type or any confirmed
  /// material implies new structure (CHB, rebar, gravel, formwork).
  static RenovationScope inferScope(
      String projectType, Iterable<String> materialNames) {
    if (RenovationScope.fromString(projectType) == RenovationScope.structural) {
      return RenovationScope.structural;
    }
    final structural = materialNames.any((n) =>
        kStructuralOnlyKinds.contains(classifyMaterialParts(name: n)));
    return structural
        ? RenovationScope.structural
        : RenovationScope.cosmetic;
  }

  /// The id every AI material list carries, so it is never reshaped.
  static const String consultationTemplateId = 'ai_consultation_bom';

  /// Removes type chips from an AI list, which holds exactly what the builder
  /// chose.
  static List<RenovationTemplateItem> fixedList(
          List<RenovationTemplateItem> items) =>
      items
          .map((i) => i.copyWith(isSwappable: false, alternatives: const []))
          .toList();

  /// The builder's AI picks as a template with no quantities yet, so the room
  /// can be measured before anything is sized.
  static RenovationTemplate consultationTemplate({
    required String projectType,
    required List<String> materialNames,
    RenovationScope scope = RenovationScope.cosmetic,
  }) {
    final names = <String>[];
    final seen = <String>{};
    for (final raw in materialNames) {
      for (final name in expandVagueMaterialName(raw.trim())) {
        if (name.isEmpty) continue;
        if (seen.add(name.toLowerCase())) names.add(name);
      }
    }

    if (names.isEmpty) {
      names.addAll(_defaultBasicsForType(projectType));
    }

    final items = names.map((raw) {
      final detail = _splitNameAndDetail(raw);
      final name = detail.name;
      final lower = name.toLowerCase();
      final isSurface = lower.contains('tile') || lower.contains('paint') || lower.contains('floor') || lower.contains('vinyl') || lower.contains('waterproof');
      final unit = lower.contains('paint') || lower.contains('primer') ? 'gal' : (lower.contains('adhesive') || lower.contains('grout') || lower.contains('cement')) ? 'bags' : isSurface ? 'pcs' : 'pcs';

      return RenovationTemplateItem(
        name: name,
        category: _guessCategory(name),
        unit: unit,
        defaultQuantity: 1,
        qtyPerSqm: 1.0,
        size: detail.size,
        notes: detail.notes,
      );
    }).toList();

    return RenovationTemplate(
      id: consultationTemplateId,
      renovationType: projectType,
      scope: scope,
      name: 'AI Material List',
      description: 'Built from materials you confirmed with the AI.',
      items: items,
    );
  }

  /// [consultationTemplate], sized for [areaSqm].
  static RenovationTemplate buildConsultationTemplate({
    required String projectType,
    required double areaSqm,
    required List<String> materialNames,
    RenovationScope? scope,
  }) {
    final unscaled = consultationTemplate(
      projectType: projectType,
      materialNames: materialNames,
    );
    // Resolve the scope so structural materials the user explicitly confirmed
    // (CHB, rebar, gravel, plywood, wire nails) are NOT silently filtered out.
    final resolvedScope =
        scope ?? inferScope(projectType, unscaled.items.map((i) => i.name));

    final scaled = scaleTemplate(
      template: unscaled,
      areaSqm: areaSqm,
      scope: resolvedScope,
    );

    return RenovationTemplate(
      id: consultationTemplateId,
      renovationType: projectType,
      scope: resolvedScope,
      name: unscaled.name,
      description: unscaled.description,
      // The review screen keeps the type already chosen. Type chips are not
      // attached, even when an older caller asked for swaps.
      items: fixedList(scaled),
    );
  }

  static ({String name, String? size, String? notes}) _splitNameAndDetail(String raw) {
    final match = RegExp(r'^(.*?)\s*\(([^)]*)\)\s*$').firstMatch(raw.trim());
    if (match == null) return (name: raw.trim(), size: null, notes: null);
    final name = match.group(1)?.trim() ?? '';
    final detail = match.group(2)?.trim() ?? '';

    final parts = detail.split(',');
    if (parts.length > 1) {
      final size = parts[0].trim();
      final notes = parts.sublist(1).join(',').trim();
      return (
        name: name.isEmpty ? raw.trim() : name,
        size: size.isEmpty ? null : size,
        notes: notes.isEmpty ? null : notes,
      );
    }

    return (name: name.isEmpty ? raw.trim() : name, size: detail.isEmpty ? null : detail, notes: null);
  }

  static List<String> expandVagueMaterialName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'flooring' ||
        lower == 'tile' ||
        lower == 'tiles' ||
        lower.contains('essential materials for flooring')) {
      return const ['Ceramic floor tiles', 'Tile adhesive', 'Tile grout'];
    }
    if (lower == 'painting' ||
        lower == 'paint' ||
        lower.contains('essential materials for painting')) {
      return const ['Interior wall paint', 'Wall primer', 'Paint roller set'];
    }
    return [raw];
  }

  static List<String> _defaultBasicsForType(String projectType) {
    return const ['Ceramic floor tiles', 'Tile adhesive', 'Tile grout', 'Interior wall paint'];
  }

  static String _guessCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tile') || lower.contains('floor')) return 'Floor Surface';
    if (lower.contains('paint') || lower.contains('wall')) return 'Wall Finishing';
    return 'General';
  }
}
