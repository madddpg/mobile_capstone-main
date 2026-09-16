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
  static List<RenovationTemplateItem> scaleTemplate({
    required RenovationTemplate template,
    required double areaSqm,
    RenovationScope scope = RenovationScope.fullRenovation,
    SiteTakeoff? takeoff,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    final isConsultation = template.id.contains('consultation');
    final items = <RenovationTemplateItem>[];

    // An AI BOM is exactly what the builder confirmed, so a measured room
    // sizes its lines but never adds or removes any.
    final source = takeoff == null || isConsultation
        ? template.items
        : fitToRoom(template.items, takeoff);

    for (final rawItem in source) {
      // Filter structural items if Full Renovation scope
      if (!scope.includesStructural && _isStructuralOnlyItem(rawItem)) {
        continue;
      }

      // For tiles with no explicit size, pin the assumed default size and
      // switch the unit to pieces so the shop quotes the right thing (a piece
      // count against an unstated size is a ~4x ambiguity).
      final item = _pinTileDefaults(rawItem);

      final scaledQty =
          estimateQuantity(item: item, areaSqm: area, takeoff: takeoff);
      items.add(
        ensureSwappable(
          item.copyWith(
            defaultQuantity: scaledQty,
          ),
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
      _addForemanAuxiliaries(items, area, scope, takeoff);
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
  static ({double floorSqm, double wallSqm, double groutKg})? tileSettingBasis(
    List<RenovationTemplateItem> items,
    double areaSqm, {
    SiteTakeoff? takeoff,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    RenovationTemplateItem? floor;
    RenovationTemplateItem? measuredWall;
    var wallSqm = 0.0;
    var groutKg = 0.0;

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
          groutKg += sqm * PhRenovationRates.groutKgPerSqm(item.size ?? '');
        default:
          break;
      }
    }

    if (takeoff != null && measuredWall != null) {
      wallSqm = takeoff.wallTileSqm;
      groutKg +=
          wallSqm * PhRenovationRates.groutKgPerSqm(measuredWall.size ?? '');
    }

    if (floor == null && wallSqm == 0) return null;
    final floorSqm = floor == null ? 0.0 : area;
    if (floor != null) {
      groutKg += floorSqm * PhRenovationRates.groutKgPerSqm(floor.size ?? '');
    }
    return (floorSqm: floorSqm, wallSqm: wallSqm, groutKg: groutKg);
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

    final bags = PhRenovationRates.calculateTileAdhesiveBags(
        basis.floorSqm + basis.wallSqm);
    final packs = PhRenovationRates.groutPacksForKg(basis.groutKg);
    return [
      for (final item in items)
        switch (classifyMaterial(item)) {
          MaterialKind.tileAdhesive =>
            item.copyWith(defaultQuantity: bags, unit: 'bags'),
          MaterialKind.tileGrout =>
            item.copyWith(defaultQuantity: packs, unit: 'packs'),
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
    double areaSqm,
    RenovationScope scope,
    SiteTakeoff? takeoff,
  ) {
    final names = items.map((i) => i.name.toLowerCase()).toSet();
    final kinds = items.map(classifyMaterial).toSet();
    final hasTiling = kinds.any(kTileKinds.contains) ||
        kinds.contains(MaterialKind.tileAdhesive) ||
        kinds.contains(MaterialKind.tileGrout);
    final hasPlumbing = kinds.contains(MaterialKind.plumbingFixture);
    final hasPainting = kinds.any(kPaintKinds.contains);
    final aux = PhRenovationRates.calculateForemanAuxiliaries(
      areaSqm: areaSqm,
      isExtension: scope.includesStructural,
    );

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

    if (scope.includesStructural) {
      _addExtensionStructure(items, areaSqm, takeoff);
      if (!names.any((n) => n.contains('plywood'))) {
        items.add(
          RenovationTemplateItem(
            name: 'Marine Plywood 1/2" (4\'x8\')',
            category: 'Formwork & Structural',
            unit: 'sheets',
            defaultQuantity: aux['marinePlywoodSheets'] as double? ?? 2.0,
            notes: 'Foreman essential — slab & column concrete formwork',
          ),
        );
      }
      if (!names.any((n) => n.contains('coco lumber'))) {
        items.add(
          RenovationTemplateItem(
            name: 'Coco Lumber (2"x2" & 2"x3")',
            category: 'Formwork & Structural',
            unit: 'bd.ft',
            defaultQuantity: aux['cocoLumberBdFt'] as double? ?? 30.0,
            notes: 'Foreman essential — form joists & vertical shoring',
          ),
        );
      }
      if (!names.any((n) => n.contains('nail'))) {
        items.add(
          RenovationTemplateItem(
            name: 'Common Wire Nails (CWN Assorted)',
            category: 'Formwork & Structural',
            unit: 'kg',
            defaultQuantity: aux['cwnNailsKg'] as double? ?? 2.0,
            notes: 'Foreman essential — formwork assembly nails',
          ),
        );
      }
    }
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
  static double _paintArea(double area, SiteTakeoff? takeoff) =>
      takeoff?.paintSqm ?? area;

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
    final lm = (takeoff.skirtingM * 1.05).ceilToDouble();
    return lm < 1 ? 1.0 : lm;
  }

  /// Counter top at a standard 0.60 m depth, plus 8% for cutting.
  static double _countertopQuantity(SiteTakeoff takeoff) {
    final sqm = (takeoff.countertopSqm * 1.08).ceilToDouble();
    return sqm < 1 ? 1.0 : sqm;
  }

  /// Generic fixed-count / rate-based scaling for items with no dedicated
  /// DPWH formula (fixtures, tools, linear goods, area goods).
  static double _scaleByRate(RenovationTemplateItem item, double area) {
    if (item.qtyPerSqm == null || item.qtyPerSqm! <= 0) {
      return item.defaultQuantity <= 0 ? 1 : item.defaultQuantity;
    }
    final raw = item.qtyPerSqm! * area;
    final withWaste = raw * 1.08;
    return withWaste < 1 ? 1.0 : withWaste.ceilToDouble();
  }

  /// Shown with an Extension BOM. The package covers what can be sized from
  /// the floor area alone; structural members need the engineer's plan.
  static const String extensionCoverageNote =
      'Extension covers the floor slab and new CHB walls only, assuming a '
      '100 mm slab on grade and new wall area of 2.2 × floor area in 4" CHB. '
      'Footings, columns, beams and roofing are not included; take those from '
      'the structural plan.';

  /// [extensionCoverageNote], restated for a measured room.
  static String extensionCoverageNoteFor(SiteTakeoff? takeoff) {
    if (takeoff == null || takeoff.netWallSqm <= 0) {
      return extensionCoverageNote;
    }
    return 'Extension covers the floor slab and new CHB walls only: a 100 mm '
        'slab on grade over the measured ${takeoff.floorSqm.toStringAsFixed(1)} sq.m '
        'floor and 4" CHB over the measured ${takeoff.netWallSqm.toStringAsFixed(1)} sq.m '
        'of wall, less doors and windows. Footings, columns, beams and roofing '
        'are not included; take those from the structural plan.';
  }

  /// Slab and CHB wall materials an Extension adds. Quantities come from
  /// [estimateQuantity] when the rows are added.
  ///
  /// The Extension scope used to promise concrete, CHB and rebar but add only
  /// formwork: plywood, lumber and nails with nothing to pour into them.
  static const List<RenovationTemplateItem> _extensionStructureRows = [
    RenovationTemplateItem(
      name: 'Portland Cement - Slab (40 kg)',
      category: 'Concrete Slab',
      unit: 'bags',
      defaultQuantity: 1,
      notes: 'Class A 1:2:4 concrete, 100 mm slab on grade',
    ),
    RenovationTemplateItem(
      name: 'Washed Sand - Slab',
      category: 'Concrete Slab',
      unit: 'cu.m',
      defaultQuantity: 1,
      notes: 'Class A 1:2:4 concrete, 100 mm slab on grade',
    ),
    RenovationTemplateItem(
      name: 'Crushed Gravel 3/4"',
      category: 'Concrete Slab',
      unit: 'cu.m',
      defaultQuantity: 1,
      notes: 'Class A 1:2:4 concrete, 100 mm slab on grade',
    ),
    RenovationTemplateItem(
      name: 'Concrete Hollow Block (CHB)',
      category: 'Masonry',
      unit: 'pcs',
      defaultQuantity: 1,
      size: '4"',
      notes: 'New wall area assumed at 2.2 × floor area',
    ),
    RenovationTemplateItem(
      name: 'Portland Cement - Masonry & Plaster (40 kg)',
      category: 'Masonry',
      unit: 'bags',
      defaultQuantity: 1,
      notes: 'CHB laying mortar plus 16 mm plaster on both faces',
    ),
    RenovationTemplateItem(
      name: 'Washed Sand - Masonry & Plaster',
      category: 'Masonry',
      unit: 'cu.m',
      defaultQuantity: 1,
      notes: 'CHB laying mortar plus 16 mm plaster on both faces',
    ),
    RenovationTemplateItem(
      name: 'Deformed Bar (6 m length)',
      category: 'Reinforcement',
      unit: 'pcs',
      defaultQuantity: 1,
      size: '10mm',
      notes: 'CHB wall reinforcement, vertical and horizontal',
    ),
    RenovationTemplateItem(
      name: 'G.I. Tie Wire #16',
      category: 'Reinforcement',
      unit: 'kg',
      defaultQuantity: 1,
      notes: 'For tying the wall reinforcement',
    ),
  ];

  /// Adds the slab and CHB wall package, skipping any line the template
  /// already covers so the same material is never ordered twice.
  static void _addExtensionStructure(
    List<RenovationTemplateItem> items,
    double area,
    SiteTakeoff? takeoff,
  ) {
    final measuredWalls = takeoff != null && takeoff.netWallSqm > 0;
    final present = items.map(_structuralRole).whereType<String>().toSet();
    for (final row in _extensionStructureRows) {
      if (!present.add(_structuralRole(row)!)) continue;
      items.add(
        row.copyWith(
          defaultQuantity:
              estimateQuantity(item: row, areaSqm: area, takeoff: takeoff),
          notes: measuredWalls && classifyMaterial(row) == MaterialKind.chbBlock
              ? 'Measured wall area, less doors and windows'
              : null,
        ),
      );
    }
  }

  /// The slot a line fills in the Extension package, or `null` if none.
  static String? _structuralRole(RenovationTemplateItem item) {
    final kind = classifyMaterial(item);
    if (kind == MaterialKind.washedSand) {
      if (_isSlabSand(item)) return 'slabSand';
      if (_isMasonrySand(item)) return 'masonrySand';
      return null;
    }
    return kStructuralOnlyKinds.contains(kind) ? kind.name : null;
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
  }) {
    final area = _baseArea(areaSqm, takeoff);
    final sizeKey = item.size ?? '';
    final wallArea = _newWallArea(area, takeoff);
    final paintArea = _paintArea(area, takeoff);

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
        return _scaleByRate(item, area);
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
  }) {
    final resized = item.copyWith(size: newSize);
    final qty =
        estimateQuantity(item: resized, areaSqm: areaSqm, takeoff: takeoff);
    return (
      newQty: qty,
      formulaString: getFormulaString(
        item: resized,
        areaSqm: areaSqm,
        currentQty: qty,
        takeoff: takeoff,
      ),
    );
  }

  static String _tiledAreaLine(
          ({double floorSqm, double wallSqm, double groutKg}) tiled) =>
      'Tiled area: ${tiled.floorSqm.toStringAsFixed(1)} sq.m floor + '
      '${tiled.wallSqm.toStringAsFixed(1)} sq.m wall';

  /// Returns formula transparency string for displaying on material cards.
  ///
  /// [bom] is the whole list the line sits in. Adhesive and grout are sized
  /// from the tiles in it, so their formula needs it to show the real basis.
  static String getFormulaString({
    required RenovationTemplateItem item,
    required double areaSqm,
    required double currentQty,
    List<RenovationTemplateItem> bom = const [],
    SiteTakeoff? takeoff,
  }) {
    final area = _baseArea(areaSqm, takeoff);
    final sizeKey = item.size ?? '';
    final wallArea = _newWallArea(area, takeoff);
    final paintArea = _paintArea(area, takeoff);

    // A measured room states its measurement first, so the builder can check
    // the room before checking the rate.
    final floorLine = takeoff?.floorLine;
    final wallLine =
        takeoff == null || takeoff.netWallSqm <= 0 ? null : takeoff.wallLine;
    final paintLine = takeoff?.paintLine;
    String measured(String? line, String formula) =>
        line == null ? formula : '$line\n$formula';

    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        return measured(
          takeoff?.wallTileLine,
          PhRenovationRates.wallTileFormulaString(
              _wallTileArea(item, area, takeoff), sizeKey, currentQty),
        );
      case MaterialKind.floorTile:
        return measured(
          floorLine,
          PhRenovationRates.floorTileFormulaString(area, sizeKey, currentQty),
        );
      case MaterialKind.tileAdhesive:
        final adhesiveBasis = tileSettingBasis(bom, area, takeoff: takeoff);
        if (adhesiveBasis == null) {
          return PhRenovationRates.tileAdhesiveFormulaString(area, currentQty);
        }
        return '${_tiledAreaLine(adhesiveBasis)}\n'
            '${PhRenovationRates.tileAdhesiveFormulaString(adhesiveBasis.floorSqm + adhesiveBasis.wallSqm, currentQty)}';
      case MaterialKind.tileGrout:
        final groutBasis = tileSettingBasis(bom, area, takeoff: takeoff);
        if (groutBasis == null) {
          return PhRenovationRates.tileGroutFormulaString(
              area, sizeKey, currentQty);
        }
        return '${_tiledAreaLine(groutBasis)}\n'
            '${(groutBasis.floorSqm + groutBasis.wallSqm).toStringAsFixed(1)} sq.m × grout joint factor by tile face = '
            '${groutBasis.groutKg.toStringAsFixed(1)} kg → ${_fmtQty(currentQty)} packs (2kg pack)\n'
            '(Material spec: DPWH Vol. III Item 1018 | Quantity: joint volume from tile size, manufacturer coverage)';
      case MaterialKind.paintPrimer:
        return measured(paintLine,
            '${paintArea.toStringAsFixed(1)} sq.m x 0.04 gal/sq.m (1 sealing coat) = ${currentQty.toInt()} gal (4L)\n(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, 1 sealing coat)');
      case MaterialKind.paintTopcoat:
        return measured(paintLine,
            '${paintArea.toStringAsFixed(1)} sq.m x 0.06 gal/sq.m (2 finish coats) = ${currentQty.toInt()} gal (4L)\n(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, 2 finish coats; primer counted separately)');
      case MaterialKind.skimCoat:
        return measured(paintLine,
            PhRenovationRates.skimCoatFormulaString(paintArea, currentQty));
      case MaterialKind.structuralCement:
        return measured(
          floorLine,
          PhRenovationRates.structuralCementFormulaString(
              area, sizeKey.isEmpty ? '100mm' : sizeKey, currentQty),
        );
      case MaterialKind.waterproofing
          when takeoff != null &&
              takeoff.waterproofingSqm > 0 &&
              (item.qtyPerSqm ?? 0) > 0:
        return '${takeoff.waterproofingLine}\n'
            '${takeoff.waterproofingSqm.toStringAsFixed(1)} sq.m × ${item.qtyPerSqm} ${item.unit}/sq.m × 1.08 = ${_fmtQty(currentQty)} ${item.unit}\n'
            '(Quantity: manufacturer coverage for two coats plus 8% allowance | see docs/material-data-sources.md)';
      case MaterialKind.areaGoods
          when takeoff != null &&
              _isCountertop(item) &&
              takeoff.countertopSqm > 0:
        return '${takeoff.countertopLine}\n'
            '${takeoff.countertopSqm.toStringAsFixed(2)} sq.m × 1.08 cutting allowance = ${_fmtQty(currentQty)} ${item.unit}\n'
            '(Quantity: standard 0.60 m counter depth plus 8% allowance)';
      case MaterialKind.areaGoods
          when takeoff != null &&
              (isFloorFinishGoods(item) || _isUnderlayment(item)) &&
              (item.qtyPerSqm ?? 0) > 0:
        return '${takeoff.floorLine}\n'
            '${area.toStringAsFixed(1)} sq.m × ${item.qtyPerSqm} × 1.08 cutting allowance = ${_fmtQty(currentQty)} ${item.unit}\n'
            '(Quantity: laid area plus 8% cutting waste, Fajardo)';
      case MaterialKind.genericConsumable
          when takeoff != null && _isSkirting(item) && takeoff.skirtingM > 0:
        return '${takeoff.skirtingLine}\n'
            '${takeoff.skirtingM.toStringAsFixed(2)} m × 1.05 cutting allowance = ${_fmtQty(currentQty)} ${item.unit}\n'
            '(Quantity: room perimeter less doorways plus 5% for mitred corners)';
      case MaterialKind.roofingSheet when _roofingPart(item) != null:
        return switch (_roofingPart(item)) {
          'roofTile' =>
            PhRenovationRates.roofTileFormulaString(area, currentQty),
          'sheet' => PhRenovationRates.ribTypeFormulaString(area, currentQty),
          _ => PhRenovationRates.ridgeFormulaString(area, currentQty, item.unit),
        };
      case MaterialKind.roofSealant:
        return PhRenovationRates.roofSealantFormulaString(area, currentQty);
      case MaterialKind.genericConsumable when _isTekscrew(item):
        return PhRenovationRates.tekscrewFormulaString(area, currentQty);
      case MaterialKind.cementBedding when _isRidgeBedding(item):
        return PhRenovationRates.ridgeCementFormulaString(area, currentQty);
      case MaterialKind.cementBedding:
        return measured(floorLine,
            PhRenovationRates.beddingCementFormulaString(area, currentQty));
      case MaterialKind.chbMortar:
        return measured(
          wallLine,
          PhRenovationRates.chbCementFormulaString(
              wallArea, sizeKey, currentQty),
        );
      case MaterialKind.washedSand:
        if (_isSlabSand(item)) {
          final slab = PhRenovationRates.slabThicknesses.firstWhere(
            (t) => t.value == sizeKey,
            orElse: () => PhRenovationRates.slabThicknesses[0],
          );
          final volume = area * slab.thicknessM;
          return '${floorLine == null ? '' : '$floorLine\n'}Volume: ${area.toStringAsFixed(1)} sq.m × ${slab.thicknessM}m = ${volume.toStringAsFixed(2)} m³ × 0.50 m³ sand/m³ = ${_fmtQty(currentQty)} cu.m washed sand\n(Material spec: DPWH Vol. III Item 900 Reinforced Concrete | Quantity: Class A 1:2:4 mix, 9.0 bags + 0.50 m3 sand + 1.00 m3 gravel per m3, Fajardo)';
        }
        if (_isMasonrySand(item)) {
          return '${wallLine == null ? '' : '$wallLine\n'}${wallArea.toStringAsFixed(1)} sq.m wall × 0.076 cu.m/sq.m (Mortar + 2-Side Plaster) = ${_fmtQty(currentQty)} cu.m washed sand\n(Material spec: DPWH Vol. III Item 1046 Masonry Works and Item 1027 Cement Plaster Finish | Quantity: Class B 1:3 mortar + 16 mm two-face plaster, Fajardo)';
        }
        return measured(floorLine,
            PhRenovationRates.beddingSandFormulaString(area, currentQty));
      case MaterialKind.gravel:
        final slab = PhRenovationRates.slabThicknesses.firstWhere(
          (t) => t.value == sizeKey,
          orElse: () => PhRenovationRates.slabThicknesses[0],
        );
        final volume = area * slab.thicknessM;
        return '${floorLine == null ? '' : '$floorLine\n'}Volume: ${area.toStringAsFixed(1)} sq.m × ${slab.thicknessM}m = ${volume.toStringAsFixed(2)} m³ × 1.00 m³ gravel/m³ = ${_fmtQty(currentQty)} cu.m crushed gravel\n(Material spec: DPWH Vol. III Item 900 Reinforced Concrete | Quantity: Class A 1:2:4 mix, 1.00 m3 gravel per m3 concrete, Fajardo)';
      case MaterialKind.tieWire:
        return '${wallLine == null ? '' : '$wallLine\n'}${wallArea.toStringAsFixed(1)} sq.m wall × 0.025 kg/sq.m = ${_fmtQty(currentQty)} kg #16 G.I. tie wire\n(Material spec: DPWH Vol. III Item 902 Reinforcing Steel | Quantity: tie wire for CHB wall reinforcement, Fajardo)';
      case MaterialKind.chbBlock:
        return measured(
            wallLine, PhRenovationRates.chbFormulaString(wallArea, currentQty));
      case MaterialKind.rebar:
        return measured(
          wallLine,
          PhRenovationRates.rebarFormulaString(
              wallArea, sizeKey, currentQty.toInt()),
        );
      default:
        return '${area.toStringAsFixed(1)} sq.m x standard rate = ${_fmtQty(currentQty)} ${item.unit}\n(Quantity: Max Fajardo, Simplified Construction Estimate | see docs/material-data-sources.md)';
    }
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

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
  static List<RenovationTemplateItem> fitToRoom(
    List<RenovationTemplateItem> items,
    SiteTakeoff takeoff,
  ) {
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
    size: '300x300',
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
    if (RenovationScope.fromString(projectType) == RenovationScope.extension) {
      return RenovationScope.extension;
    }
    final structural = materialNames.any((n) =>
        kStructuralOnlyKinds.contains(classifyMaterialParts(name: n)));
    return structural
        ? RenovationScope.extension
        : RenovationScope.fullRenovation;
  }

  static RenovationTemplate buildConsultationTemplate({
    required String projectType,
    required String style,
    required double areaSqm,
    required List<String> materialNames,
    RenovationScope? scope,
    // AI BOMs are exactly what the user chose in consultation — don't offer
    // "Premium/Economy" swap alternatives on the review screen.
    bool allowSwaps = false,
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

    // Resolve the scope so structural materials the user explicitly confirmed
    // (CHB, rebar, gravel, plywood, wire nails) are NOT silently filtered out.
    final resolvedScope = scope ?? inferScope(projectType, names);

    final items = names.map((raw) {
      final detail = _splitNameAndDetail(raw);
      final name = detail.name;
      final lower = name.toLowerCase();
      final isSurface = lower.contains('tile') || lower.contains('paint') || lower.contains('floor') || lower.contains('vinyl') || lower.contains('waterproof');
      final unit = lower.contains('paint') || lower.contains('primer') ? 'gal' : (lower.contains('adhesive') || lower.contains('grout') || lower.contains('cement')) ? 'bags' : isSurface ? 'pcs' : 'pcs';

      final base = RenovationTemplateItem(
        name: name,
        category: _guessCategory(name),
        unit: unit,
        defaultQuantity: 1,
        qtyPerSqm: 1.0,
        size: detail.size,
        notes: detail.notes,
      );
      return allowSwaps ? ensureSwappable(base) : base;
    }).toList();

    final scaled = scaleTemplate(
      template: RenovationTemplate(
        id: 'ai_consultation_bom',
        renovationType: projectType,
        style: style.isEmpty ? 'custom' : style,
        name: 'AI Essential BOM',
        description: 'Built from materials you confirmed in consultation.',
        items: items,
      ),
      areaSqm: areaSqm,
      scope: resolvedScope,
    );

    // scaleTemplate re-runs ensureSwappable internally; strip the fabricated
    // alternatives back off when the caller wants a fixed list.
    final finalItems = allowSwaps
        ? scaled
        : scaled
            .map((i) => i.copyWith(isSwappable: false, alternatives: const []))
            .toList();

    return RenovationTemplate(
      id: 'ai_consultation_bom',
      renovationType: projectType,
      style: style.isEmpty ? 'custom' : style,
      name: 'AI Essential BOM',
      description: 'Built from materials you confirmed in consultation.',
      items: finalItems,
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
