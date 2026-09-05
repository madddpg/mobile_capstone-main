import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

/// Scales template BOM quantities from a project area (sqm) using Philippine DPWH/NSCP standards.
class BomQuantityEstimator {
  BomQuantityEstimator._();

  static List<RenovationTemplateItem> scaleTemplate({
    required RenovationTemplate template,
    required double areaSqm,
    RenovationScope scope = RenovationScope.fullRenovation,
  }) {
    final area = areaSqm <= 0 ? 1.0 : areaSqm;
    final items = <RenovationTemplateItem>[];

    for (final rawItem in template.items) {
      // Filter structural items if Full Renovation scope
      if (!scope.includesStructural && _isStructuralOnlyItem(rawItem)) {
        continue;
      }

      // For tiles with no explicit size, pin the assumed default size and
      // switch the unit to pieces so the shop quotes the right thing (a piece
      // count against an unstated size is a ~4x ambiguity).
      final item = _pinTileDefaults(rawItem);

      final scaledQty = estimateQuantity(item: item, areaSqm: area);
      items.add(
        ensureSwappable(
          item.copyWith(
            defaultQuantity: scaledQty,
          ),
        ),
      );
    }

    // Add Master Foreman Auxiliary Consumables if not present (skip for AI consultation templates)
    if (template.id != 'ai_consultation_bom' && !template.id.contains('consultation')) {
      _addForemanAuxiliaries(items, area, scope);
    }

    return items;
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
  static double _wallTileArea(RenovationTemplateItem item, double area) {
    final mult = item.qtyPerSqm;
    if (mult != null && mult > 0) return area * mult;
    return area * 2.2;
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

  /// Calculates material quantity according to Philippine DPWH/NSCP mathematical formulas.
  static double estimateQuantity({
    required RenovationTemplateItem item,
    required double areaSqm,
  }) {
    final area = areaSqm <= 0 ? 1.0 : areaSqm;
    final sizeKey = item.size ?? '';
    final wallArea = area * 2.2; // structural CHB/rebar default wall area

    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        return PhRenovationRates.calculateWallTilePieces(
            _wallTileArea(item, area), sizeKey);
      case MaterialKind.floorTile:
        return PhRenovationRates.calculateFloorTilePieces(area, sizeKey);
      case MaterialKind.tileAdhesive:
        return PhRenovationRates.calculateTileAdhesiveBags(area);
      case MaterialKind.tileGrout:
        return PhRenovationRates.calculateTileGroutPacks(area, sizeKey);
      case MaterialKind.paintPrimer:
        return PhRenovationRates.calculatePaintWorks(area).primerGal;
      case MaterialKind.paintTopcoat:
        // topcoat only — the Primer line is counted separately, so returning
        // totalGal here double-counts the primer coat.
        return PhRenovationRates.calculatePaintWorks(area).topcoatGal;
      case MaterialKind.skimCoat:
        return PhRenovationRates.calculatePaintWorks(area).skimCoatBags;
      case MaterialKind.structuralCement:
        return PhRenovationRates.calculateStructuralConcreteSlab(
            area, sizeKey.isEmpty ? '100mm' : sizeKey).cementBags;
      case MaterialKind.cementBedding:
        return PhRenovationRates.calculateTileBeddingMortar(area).cementBags;
      case MaterialKind.chbMortar:
        return PhRenovationRates.calculateChbMortarAndPlaster(
            wallArea, sizeKey.isEmpty ? '4"' : sizeKey).cementBags;
      case MaterialKind.washedSand:
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
  static ({double newQty, String formulaString}) recalculateForSize({
    required RenovationTemplateItem item,
    required String newSize,
    required double areaSqm,
  }) {
    final area = areaSqm <= 0 ? 1.0 : areaSqm;
    final wallArea = area * 2.2;
    final resized = item.copyWith(size: newSize);

    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        final wa = _wallTileArea(item, area);
        final pcs = PhRenovationRates.calculateWallTilePieces(wa, newSize);
        return (
          newQty: pcs,
          formulaString: PhRenovationRates.wallTileFormulaString(wa, newSize, pcs)
        );
      case MaterialKind.floorTile:
        final pcs = PhRenovationRates.calculateFloorTilePieces(area, newSize);
        return (
          newQty: pcs,
          formulaString:
              PhRenovationRates.floorTileFormulaString(area, newSize, pcs)
        );
      case MaterialKind.tileGrout:
        final packs = PhRenovationRates.calculateTileGroutPacks(area, newSize);
        return (
          newQty: packs,
          formulaString:
              PhRenovationRates.tileGroutFormulaString(area, newSize, packs)
        );
      case MaterialKind.chbBlock:
        final pcs = PhRenovationRates.calculateChbPieces(wallArea);
        return (
          newQty: pcs,
          formulaString: PhRenovationRates.chbFormulaString(wallArea, pcs)
        );
      case MaterialKind.chbMortar:
        final calc = PhRenovationRates.calculateChbMortarAndPlaster(
            wallArea, newSize.isEmpty ? '4"' : newSize);
        return (
          newQty: calc.cementBags,
          formulaString: PhRenovationRates.chbCementFormulaString(
              wallArea, newSize, calc.cementBags)
        );
      case MaterialKind.rebar:
        final calc = PhRenovationRates.calculateChbRebar(wallArea, newSize);
        return (
          newQty: calc.commercialBars.toDouble(),
          formulaString: PhRenovationRates.rebarFormulaString(
              wallArea, newSize, calc.commercialBars)
        );
      case MaterialKind.structuralCement:
        final calc =
            PhRenovationRates.calculateStructuralConcreteSlab(area, newSize);
        return (
          newQty: calc.cementBags,
          formulaString: PhRenovationRates.structuralCementFormulaString(
              area, newSize, calc.cementBags)
        );
      case MaterialKind.gravel:
        final calc =
            PhRenovationRates.calculateStructuralConcreteSlab(area, newSize);
        return (
          newQty: calc.gravelCum,
          formulaString:
              '${area.toStringAsFixed(1)} sq.m slab -> ${calc.gravelCum.toStringAsFixed(2)} m3 crushed gravel\n(Material spec: DPWH Vol. III Item 900 Reinforced Concrete | Quantity: Class A 1:2:4 mix, 1.00 m3 gravel per m3 concrete, Fajardo)'
        );
      default:
        final stdQty = estimateQuantity(item: resized, areaSqm: area);
        return (
          newQty: stdQty,
          formulaString: getFormulaString(
              item: resized, areaSqm: area, currentQty: stdQty)
        );
    }
  }

  /// Returns formula transparency string for displaying on material cards
  static String getFormulaString({
    required RenovationTemplateItem item,
    required double areaSqm,
    required double currentQty,
  }) {
    final area = areaSqm <= 0 ? 1.0 : areaSqm;
    final sizeKey = item.size ?? '';

    switch (classifyMaterial(item)) {
      case MaterialKind.wallTile:
        return PhRenovationRates.wallTileFormulaString(
            _wallTileArea(item, area), sizeKey, currentQty);
      case MaterialKind.floorTile:
        return PhRenovationRates.floorTileFormulaString(
            area, sizeKey, currentQty);
      case MaterialKind.tileAdhesive:
        return PhRenovationRates.tileAdhesiveFormulaString(area, currentQty);
      case MaterialKind.tileGrout:
        return PhRenovationRates.tileGroutFormulaString(
            area, sizeKey, currentQty);
      case MaterialKind.paintPrimer:
        return '${area.toStringAsFixed(1)} sq.m x 0.04 gal/sq.m (1 sealing coat) = ${currentQty.toInt()} gal (4L)\n(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, 1 sealing coat)';
      case MaterialKind.paintTopcoat:
        return '${area.toStringAsFixed(1)} sq.m x 0.06 gal/sq.m (2 finish coats) = ${currentQty.toInt()} gal (4L)\n(Material spec: DPWH Vol. III Item 1032 Painting, Varnishing and Other Related Works | Quantity: manufacturer spreading rate, 2 finish coats; primer counted separately)';
      case MaterialKind.skimCoat:
        return PhRenovationRates.skimCoatFormulaString(area, currentQty);
      case MaterialKind.structuralCement:
        return PhRenovationRates.structuralCementFormulaString(
            area, sizeKey.isEmpty ? '100mm' : sizeKey, currentQty);
      case MaterialKind.cementBedding:
        return PhRenovationRates.beddingCementFormulaString(area, currentQty);
      case MaterialKind.chbMortar:
        return PhRenovationRates.chbCementFormulaString(
            area * 2.2, sizeKey, currentQty);
      case MaterialKind.washedSand:
        return PhRenovationRates.beddingSandFormulaString(area, currentQty);
      case MaterialKind.chbBlock:
        return PhRenovationRates.chbFormulaString(area * 2.2, currentQty);
      case MaterialKind.rebar:
        return PhRenovationRates.rebarFormulaString(
            area * 2.2, sizeKey, currentQty.toInt());
      default:
        return '${area.toStringAsFixed(1)} sq.m x standard rate = ${_fmtQty(currentQty)} ${item.unit}\n(Quantity: Max Fajardo, Simplified Construction Estimate | see docs/material-data-sources.md)';
    }
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  /// Ensures every essential material can be drag/tap-swapped to an alternative.
  static RenovationTemplateItem ensureSwappable(RenovationTemplateItem item) {
    if (item.alternatives.isNotEmpty) {
      return item.copyWith(isSwappable: true);
    }
    final alts = defaultAlternativesFor(item);
    if (alts.isEmpty) {
      return item.copyWith(isSwappable: true, alternatives: [
        MaterialAlternative(name: item.name, size: item.size),
        MaterialAlternative(name: 'Premium ${item.name}'),
        MaterialAlternative(name: 'Economy ${item.name}'),
      ]);
    }
    return item.copyWith(isSwappable: true, alternatives: alts);
  }

  static List<MaterialAlternative> defaultAlternativesFor(RenovationTemplateItem item) {
    final name = item.name.toLowerCase();
    final cat = item.category.toLowerCase();

    if (name.contains('wall tile') || name.contains('backsplash') || cat.contains('wall surface')) {
      return const [
        MaterialAlternative(name: 'Subway Wall Tiles', size: '75x300'),
        MaterialAlternative(name: 'Ceramic Wall Tiles', size: '300x600'),
        MaterialAlternative(name: 'Large-format Wall Tiles', size: '600x1200'),
      ];
    }
    if (name.contains('tile') || name.contains('vinyl') || name.contains('flooring') || cat.contains('floor')) {
      return const [
        MaterialAlternative(name: 'Ceramic Floor Tiles', size: '600x600'),
        MaterialAlternative(name: 'Porcelain Floor Tiles', size: '600x600'),
        MaterialAlternative(name: 'Vinyl Flooring Planks'),
        MaterialAlternative(name: 'Non-Slip Floor Tiles', size: '300x300'),
      ];
    }
    if (name.contains('paint') || cat.contains('paint')) {
      return const [
        MaterialAlternative(name: 'Matte Interior Paint'),
        MaterialAlternative(name: 'Semi-Gloss Interior Paint'),
        MaterialAlternative(name: 'Eggshell Interior Paint'),
      ];
    }
    return const [];
  }

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
