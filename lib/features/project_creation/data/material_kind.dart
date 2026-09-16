import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

/// A single, explicit classification for a BOM line item.
///
/// Replaces the scattered `name.contains(...)` substring tests that used to live
/// in [BomQuantityEstimator]. Those collided badly:
///   * `'sand'`      matched `Sandpaper Pack`   -> priced as m3 of washed sand
///   * `'paint'`     matched `Painter's Tape`   -> priced as gallons of paint
///   * `'cement'`    matched `Solvent Cement`   -> priced as Portland cement bags
///   * `'tile'`      matched `Tile Spacers`     -> priced as floor-tile pieces
///   * `cat 'flooring'` matched `Vinyl Flooring`-> priced as 600x600 tile pieces
///
/// [classifyMaterial] resolves the kind once, in priority order, using the
/// item's name + category + unit, with deny-list short-circuits ahead of the
/// broad matches.
enum MaterialKind {
  floorTile,
  wallTile,
  tileAdhesive,
  tileGrout,
  tileSpacer,

  paintPrimer,
  paintTopcoat,
  skimCoat,

  cementBedding, // Portland cement for tile screed / mortar bedding (full reno)
  structuralCement, // slab / concrete cement (extension)
  washedSand, // bedding sand (full reno) or slab sand
  gravel, // crushed aggregate (extension)

  chbBlock, // concrete hollow blocks (extension)
  chbMortar, // mortar + plaster cement for CHB (extension)
  rebar, // deformed reinforcing steel (extension)
  tieWire, // #16 GI tie wire (extension)

  roofingSheet, // GI sheets / roof tiles / ridge cap / patch sheet
  roofPurlin, // C-purlins (extension roof framing)
  roofSealant, // vulcaseal / roof sealant

  formworkPlywood, // marine / phenolic plywood for concrete forms (extension)
  formworkLumber, // coco / form lumber (extension)
  formworkNails, // common wire nails for formwork (extension)

  areaGoods, // vinyl / laminate / underlayment — sold by m2, NOT tile pieces
  waterproofing, // liquid membrane / cementitious waterproofing

  plumbingFixture, // toilet, lavatory, shower set, faucet, sink
  plumbingConsumable, // teflon tape, solvent cement, silicone, pipes, fittings

  electrical, // wire, outlets, switches, lights, conduit, breakers

  genericConsumable, // tools, tape, sandpaper, fasteners — fixed / linear count

  unknown,
}

/// Kinds that only belong in an Extension (new-build) scope and must be filtered
/// out of a Full-Renovation BOM. Roofing is deliberately NOT here: `Roof Repair`
/// is its own renovation type, and its sheets are the primary material.
const Set<MaterialKind> kStructuralOnlyKinds = {
  MaterialKind.structuralCement,
  MaterialKind.gravel,
  MaterialKind.chbBlock,
  MaterialKind.chbMortar,
  MaterialKind.rebar,
  MaterialKind.tieWire,
  MaterialKind.roofPurlin,
  MaterialKind.formworkPlywood,
  MaterialKind.formworkLumber,
  MaterialKind.formworkNails,
};

const Set<MaterialKind> kTileKinds = {
  MaterialKind.floorTile,
  MaterialKind.wallTile,
};

const Set<MaterialKind> kPaintKinds = {
  MaterialKind.paintPrimer,
  MaterialKind.paintTopcoat,
  MaterialKind.skimCoat,
};

MaterialKind classifyMaterial(RenovationTemplateItem item) =>
    classifyMaterialParts(
      name: item.name,
      category: item.category,
      unit: item.unit,
    );

/// String-level classifier, also used by the AI-consultation path where a full
/// [RenovationTemplateItem] does not exist yet.
MaterialKind classifyMaterialParts({
  required String name,
  String category = '',
  String unit = '',
}) {
  final n = name.toLowerCase().trim();
  final c = category.toLowerCase().trim();
  final u = unit.toLowerCase().trim();

  bool has(String s) => n.contains(s);
  bool hasAny(List<String> xs) => xs.any(n.contains);

  final unitIsArea = u == 'sqm' || u == 'm2' || u == 'm²' || u == 'sq.m';
  final unitIsVolume = u.contains('cu') || u == 'm3' || u == 'm³';

  // ── Deny-list short-circuits (must run before the broad matches) ──────────
  if (hasAny(['sandpaper', 'sand paper'])) return MaterialKind.genericConsumable;
  if (hasAny([
    'masking tape',
    "painter's tape",
    'painters tape',
    'paint roller',
    'roller set',
    'paint brush',
    'brush set',
    'paint tray',
    'drop cloth',
  ])) {
    return MaterialKind.genericConsumable;
  }
  if (hasAny([
    'tile spacer',
    'cross spacer',
    'tile cutting',
    'cutting disc',
    'diamond disc',
    'diamond blade',
    'tile cutter',
    'notched trowel',
  ])) {
    return MaterialKind.tileSpacer;
  }
  if (hasAny(['teflon', 'threadseal', 'thread seal', 'thread tape'])) {
    return MaterialKind.plumbingConsumable;
  }
  if (hasAny(['solvent cement', 'pvc cement', 'pvc solvent', 'blue gum'])) {
    return MaterialKind.plumbingConsumable;
  }
  if (hasAny(['silicone', 'acrylic sealant', 'sanitary sealant'])) {
    return MaterialKind.plumbingConsumable;
  }

  // ── Tile consumables ────────────────────────────────────────────────────
  if (has('grout')) return MaterialKind.tileGrout;
  if (hasAny(['adhesive', 'thinset', 'tile bond', 'tile mortar'])) {
    return MaterialKind.tileAdhesive;
  }

  // ── Area goods that are NOT tiles ───────────────────────────────────────
  if (hasAny([
    'vinyl',
    'laminate',
    'plank',
    'underlayment',
    'carpet',
    'parquet',
    'engineered wood',
  ])) {
    return MaterialKind.areaGoods;
  }

  // Clay and concrete roof tiles contain 'tile', and without this guard they
  // were counted as 600x600 floor tile, with adhesive, grout and spacers.
  if (hasAny(['roof tile', 'roofing tile', 'ridge tile'])) {
    return MaterialKind.roofingSheet;
  }

  // ── Tiles (priced as pieces) ───────────────────────────────────────────
  final looksLikeTile = has('tile') ||
      c.contains('wall surface') ||
      c.contains('floor surface');
  if (has('wall tile') ||
      (looksLikeTile &&
          (c.contains('wall') || has('backsplash') || has('subway')))) {
    return MaterialKind.wallTile;
  }
  if (has('floor tile') ||
      (looksLikeTile && (c.contains('floor') || c.contains('flooring')))) {
    return MaterialKind.floorTile;
  }
  if (looksLikeTile) return MaterialKind.floorTile;

  // ── Paint & surface prep ──────────────────────────────────────────────
  if (hasAny(['skim coat', 'skimcoat', 'skimming'])) return MaterialKind.skimCoat;
  if (has('masonry putty') || (has('putty') && u.contains('gal'))) {
    return MaterialKind.skimCoat;
  }
  // 'Pre-painted GI roofing sheet' contains 'paint' as a substring of
  // 'pre-painted'. Without this guard it classified as paintTopcoat and a
  // roofing sheet was estimated and priced as gallons of latex. Falling
  // through instead lets the roofing block below claim it.
  final prePainted = hasAny(['pre-painted', 'prepainted', 'pre painted']);

  if (has('primer')) return MaterialKind.paintPrimer;
  if ((has('paint') && !prePainted) ||
      c == 'paint' ||
      ((c.contains('wall finish') || c.contains('wall surface')) &&
          u.contains('gal'))) {
    return MaterialKind.paintTopcoat;
  }

  // ── Waterproofing ─────────────────────────────────────────────────────
  if (has('waterproof') || c.contains('waterproof') || has('plexibond')) {
    return MaterialKind.waterproofing;
  }

  // ── Roofing (own renovation type — not structural-only) ───────────────
  if (has('purlin')) return MaterialKind.roofPurlin;
  if (has('vulcaseal') ||
      has('roof sealant') ||
      (has('roof') && has('seal'))) {
    return MaterialKind.roofSealant;
  }
  if (hasAny([
        'roofing sheet',
        'gi sheet',
        'rib type',
        'rib-type',
        'roof tile',
        'ridge cap',
        'patch sheet',
        'roofing membrane',
      ]) ||
      c.contains('roofing')) {
    return MaterialKind.roofingSheet;
  }

  // ── Structural concrete / masonry (Extension scope only) ──────────────
  if (hasAny(['tie wire', '#16 wire', 'gi tie'])) return MaterialKind.tieWire;
  if (hasAny(['rebar', 'reinforcing steel', 'reinforcement bar', 'deformed bar'])) {
    return MaterialKind.rebar;
  }
  if (hasAny(['chb', 'hollow block', 'concrete block'])) {
    return MaterialKind.chbBlock;
  }
  if (hasAny(['gravel', 'crushed stone', 'crushed rock', 'aggregate', '3/4 stone'])) {
    return MaterialKind.gravel;
  }
  if (has('washed sand') ||
      has('river sand') ||
      (has('sand') && unitIsVolume)) {
    return MaterialKind.washedSand;
  }
  // At the start of a word only: "reinforcement" ends in "cement", and welded
  // mesh reinforcement was being sized as bags of bedding cement.
  if (RegExp(r'\bcement').hasMatch(n) || has('portland')) {
    if (c.contains('concrete') || c.contains('structural') || has('slab')) {
      return MaterialKind.structuralCement;
    }
    if (has('mortar') || has('chb') || c.contains('masonry')) {
      return MaterialKind.chbMortar;
    }
    return MaterialKind.cementBedding;
  }

  // ── Formwork (Extension scope only) ──────────────────────────────────
  if (has('marine plywood') ||
      has('phenolic') ||
      (has('plywood') && (has('form') || c.contains('formwork')))) {
    return MaterialKind.formworkPlywood;
  }
  if (has('coco lumber') || has('form lumber') || has('good lumber')) {
    return MaterialKind.formworkLumber;
  }
  if (hasAny(['cwn', 'common wire nail', 'wire nail']) ||
      (has('nail') && c.contains('formwork'))) {
    return MaterialKind.formworkNails;
  }

  // ── Plumbing / electrical / fixtures ─────────────────────────────────
  final plumbingCtx = c.contains('plumb') ||
      c.contains('pipe') ||
      c.contains('fitting') ||
      c.contains('valve') ||
      c.contains('fixture');
  if (plumbingCtx ||
      hasAny([
        'faucet',
        'lavatory',
        'water closet',
        'toilet',
        'shower',
        'bidet',
        'sink',
        'pipe',
        'fitting',
        'valve',
      ])) {
    if (hasAny([
      'faucet',
      'lavatory',
      'water closet',
      'toilet',
      'shower',
      'bidet',
      'sink',
    ])) {
      return MaterialKind.plumbingFixture;
    }
    return MaterialKind.plumbingConsumable;
  }
  if (c.contains('wiring') ||
      c.contains('electric') ||
      c.contains('device') ||
      c.contains('lighting') ||
      hasAny([
        'wire',
        'outlet',
        'switch',
        'breaker',
        'panel board',
        'conduit',
        'utility box',
        'led light',
        'ceiling light',
      ])) {
    return MaterialKind.electrical;
  }

  // ── Fallback ────────────────────────────────────────────────────────
  if (unitIsArea) return MaterialKind.areaGoods;
  return MaterialKind.genericConsumable;
}

/// Area goods laid as the floor finish, such as vinyl, SPC or laminate
/// planks. Countertops and underlayment are also sold by the sq.m but are not
/// a floor finish and cannot stand in for one.
bool isFloorFinishGoods(RenovationTemplateItem item) {
  if (classifyMaterial(item) != MaterialKind.areaGoods) return false;
  final name = item.name.toLowerCase();
  return ['vinyl', 'plank', 'spc', 'laminate floor', 'flooring']
          .any(name.contains) &&
      !name.contains('counter');
}
