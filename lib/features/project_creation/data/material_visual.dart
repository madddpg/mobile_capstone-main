import 'package:flutter/material.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';

/// Visual + counter-identification data for every BOM line item.
///
/// Canvassing happens standing at a hardware counter, often with no signal and
/// a salesperson who knows the item by its street name, not by the BOM name.
/// A quantity alone ("18 bags cement") does not stop the two failures that
/// actually cost money on site:
///
///   1. **Wrong item bought.** Skim coat and masonry putty sit on the same
///      shelf; tile adhesive and plain cement are both grey powder in a sack;
///      Ga.26 roofing looks identical to the cheaper Ga.30.
///   2. **Under-spec item delivered.** Undersized "commercial grade" rebar and
///      thin CHB are the two most common substitutions in PH hardware supply.
///
/// So each material carries a drawn glyph (offline, no network images), the
/// words to say at the counter, how it is packed, the lookalike it gets
/// confused with, and the check to run before signing the delivery receipt.
///
/// Glyphs are vector-drawn by `MaterialSwatch` rather than photographed:
/// photos of branded PH stock would be copyrighted, would need ~60 downloads,
/// and would fail exactly where the app is used — inside a hardware store.
enum MaterialGlyph {
  tileGrid,
  bagPowder,
  pouchPack,
  paintCan,
  hollowBlock,
  rebarBar,
  wireCoil,
  gravelPile,
  sandPile,
  corrugatedSheet,
  cPurlin,
  plywoodSheet,
  lumberStick,
  nailsBox,
  bucketLiquid,
  waterCloset,
  lavatory,
  showerSet,
  faucet,
  tubeSealant,
  tapeRoll,
  spacerCross,
  rollerBrush,
  paintBrush,
  sandpaperSheet,
  wireSpool,
  plankGoods,
  pipeLength,
  cuttingDisc,
  genericBox,
}

/// Everything needed to recognise one material without a photograph.
@immutable
class MaterialVisual {
  /// Stable file-name stem for this material's photograph.
  ///
  /// A real photo at `assets/images/materials/<assetKey>.jpg` is shown when it
  /// is listed in [kBundledMaterialPhotos]; otherwise the drawn glyph renders.
  /// Photographs are preferred: a buyer matching goods on a shelf needs to see
  /// the actual product, not an interpretation of it.
  final String assetKey;

  /// Fallback shape `MaterialSwatch` draws when there is no photograph.
  final MaterialGlyph glyph;

  /// True-to-life body colour of the material as it sits on the shelf.
  final Color base;

  /// Secondary colour — bag band, tile grout line, rib shadow, label.
  final Color accent;

  /// Physical appearance: what the user is looking for on the rack.
  final String looksLike;

  /// The words to say at the counter. PH trade name first.
  final String counterCallout;

  /// How the item is actually sold, so the quantity can be ordered as packed.
  final String packaging;

  /// The item most often handed over by mistake, and how to tell them apart.
  final String? lookalike;

  /// The check to run before accepting delivery.
  final String? acceptance;

  const MaterialVisual({
    required this.assetKey,
    required this.glyph,
    required this.base,
    required this.accent,
    required this.looksLike,
    required this.counterCallout,
    required this.packaging,
    this.lookalike,
    this.acceptance,
  });

  /// Resolves the visual for a line item.
  ///
  /// [kind] comes from [classifyMaterialParts], the app's single source of
  /// truth. [name] refines within a kind where one classification covers
  /// physically different goods — `plumbingConsumable` is teflon tape, solvent
  /// cement and silicone; `genericConsumable` is sandpaper, rollers and tape.
  static MaterialVisual resolve({
    required String name,
    required MaterialKind kind,
  }) {
    final n = name.toLowerCase();
    bool has(String s) => n.contains(s);
    bool hasAny(List<String> xs) => xs.any(n.contains);

    switch (kind) {
      case MaterialKind.plumbingConsumable:
        if (hasAny(['teflon', 'threadseal', 'thread seal'])) return _teflonTape;
        if (hasAny(['silicone', 'sealant'])) return _silicone;
        if (hasAny(['solvent cement', 'pvc cement', 'blue gum'])) {
          return _solventCement;
        }
        if (hasAny(['pipe', 'elbow', 'tee', 'coupling', 'fitting'])) {
          return _pvcPipe;
        }
        return _silicone;

      case MaterialKind.plumbingFixture:
        if (hasAny(['water closet', 'toilet', 'bowl', 'bidet'])) {
          return _waterCloset;
        }
        if (hasAny(['lavatory', 'sink', 'basin'])) return _lavatory;
        if (has('shower')) return _showerSet;
        return _faucet;

      case MaterialKind.genericConsumable:
        if (hasAny(['sandpaper', 'sand paper'])) return _sandpaper;
        if (hasAny(['tape', 'masking'])) return _maskingTape;
        if (hasAny(['roller', 'tray'])) return _rollerSet;
        if (has('brush')) return _paintBrush;
        if (hasAny(['nail', 'screw', 'tekscrew', 'rivet'])) return _fasteners;
        return _generic;

      case MaterialKind.tileSpacer:
        if (hasAny(['disc', 'blade', 'cutter'])) return _cuttingDisc;
        return _tileSpacer;

      case MaterialKind.floorTile:
        return _floorTile;
      case MaterialKind.wallTile:
        return _wallTile;
      case MaterialKind.tileAdhesive:
        return _tileAdhesive;
      case MaterialKind.tileGrout:
        return _tileGrout;

      case MaterialKind.paintPrimer:
        return _primer;
      case MaterialKind.paintTopcoat:
        return _topcoat;
      case MaterialKind.skimCoat:
        return has('putty') ? _masonryPutty : _skimCoat;

      case MaterialKind.cementBedding:
        return _cementBedding;
      case MaterialKind.structuralCement:
        return _structuralCement;
      case MaterialKind.chbMortar:
        return _mortarCement;
      case MaterialKind.washedSand:
        return _washedSand;
      case MaterialKind.gravel:
        return _gravel;

      case MaterialKind.chbBlock:
        return _chb;
      case MaterialKind.rebar:
        return _rebar;
      case MaterialKind.tieWire:
        return _tieWire;

      case MaterialKind.roofingSheet:
        return _roofingSheet;
      case MaterialKind.roofPurlin:
        return _purlin;
      case MaterialKind.roofSealant:
        return _vulcaseal;

      case MaterialKind.formworkPlywood:
        return _marinePlywood;
      case MaterialKind.formworkLumber:
        return _cocoLumber;
      case MaterialKind.formworkNails:
        return _cwn;

      case MaterialKind.waterproofing:
        return _waterproofing;
      case MaterialKind.areaGoods:
        return _areaGoods;
      case MaterialKind.electrical:
        return _electrical;
      case MaterialKind.unknown:
        return _generic;
    }
  }

  /// Convenience: resolve straight from raw item strings.
  static MaterialVisual forItem({
    required String name,
    String category = '',
    String unit = '',
  }) =>
      resolve(
        name: name,
        kind: classifyMaterialParts(
          name: name,
          category: category,
          unit: unit,
        ),
      );
}


/// Materials that have a real photograph bundled at
/// `assets/images/materials/<key>.jpg`.
///
/// Empty until photographs are added. Add the key here when you drop the file
/// in, and `MaterialSwatch` switches that material from the drawn glyph to the
/// photo with no other change. Keys are the `assetKey` values below.
const Set<String> kBundledMaterialPhotos = {
  'cement_bedding',
  'chb',
  'mortar_cement',
  'pvc_pipe',
  'roller_set',
  'sandpaper',
  'silicone',
  'structural_cement',
  'washed_sand',
};

/// Path a material's photograph would live at.
String materialPhotoPath(String assetKey) =>
    'assets/images/materials/$assetKey.jpg';

// ── Palette ────────────────────────────────────────────────────────────────
// Colours are the shelf colours of the real goods, not brand colours.

const _kraft = Color(0xFFC8A97E); // cement / adhesive sack paper
const _kraftDark = Color(0xFF8A6D46);
const _greyCement = Color(0xFF9BA3A9);
const _tileMatte = Color(0xFFB9B3A6);
const _tileGloss = Color(0xFFF2F0EB);
const _grout = Color(0xFF6F7A83);
const _steel = Color(0xFF8D949B);
const _rust = Color(0xFF9C6B4A);
const _concrete = Color(0xFFA9A49B);
const _sand = Color(0xFFD8C08E);
const _stone = Color(0xFF7E8489);
const _giBlue = Color(0xFF3F7FA6);
const _plywood = Color(0xFFCFA86B);
const _lumber = Color(0xFFB98C55);
const _porcelain = Color(0xFFF4F4F2);
const _white = Color(0xFFEDEAE3);
const _latex = Color(0xFF4F86C6);
const _black = Color(0xFF2B333A);
const _tealPail = Color(0xFF2E7D74);
const _pvcOrange = Color(0xFFCF7B3A);

// ── Tile works ─────────────────────────────────────────────────────────────

const _floorTile = MaterialVisual(
  assetKey: 'floor_tile',
  glyph: MaterialGlyph.tileGrid,
  base: _tileMatte,
  accent: _grout,
  looksLike:
      'Thick, heavy tile with a matte or textured face and a rough ribbed '
      'underside. Stacked flat on pallets, sold sealed by the box.',
  counterCallout:
      'Ask for non-skid floor tile in your chosen size, matte finish. Say the '
      'room so they give the right rating: CR floor needs non-skid.',
  packaging:
      'By the box. Typically 4 pcs/box at 600×600, 6 pcs/box at 400×400, '
      '11–12 pcs/box at 300×300. Confirm the box count per brand.',
  lookalike:
      'Wall tile. It is thinner, lighter and glossy, and it cracks under '
      'foot traffic. If the face is shiny and the tile feels light, it is '
      'not a floor tile.',
  acceptance:
      'Buy the whole quantity in one batch and check the shade or lot code '
      'printed on every box. Different lots fire to visibly different shades.',
);

const _wallTile = MaterialVisual(
  assetKey: 'wall_tile',
  glyph: MaterialGlyph.tileGrid,
  base: _tileGloss,
  accent: _grout,
  looksLike:
      'Thin, light, glossy-faced tile with clean square edges. Rings hollow '
      'when tapped compared with a floor tile.',
  counterCallout:
      'Ask for glazed wall tile in your chosen size. Name the pattern if you '
      'want subway laid horizontally.',
  packaging:
      'By the box. Subway 75×300 runs many pieces per box, so order in whole '
      'boxes and keep the offcuts for the last course.',
  lookalike:
      'Floor tile of the same face size. Floor tile is thicker and much '
      'heavier, and it overloads wall adhesive.',
  acceptance:
      'Check the same shade or lot code across all boxes, and run a straight '
      'edge across a few tiles for warping before you accept.',
);

const _tileAdhesive = MaterialVisual(
  assetKey: 'tile_adhesive',
  glyph: MaterialGlyph.bagPowder,
  base: _kraft,
  accent: _giBlue,
  looksLike:
      'Grey powder in a 25 kg paper sack, printed with a tile-and-trowel '
      'graphic. Feels finer and lighter than a cement bag.',
  counterCallout:
      'Ask for tile adhesive, 25 kg, and say whether it is for floor or for '
      'wall. Wall adhesive has more grip so tiles do not slide down.',
  packaging: '25 kg sack. One sack covers roughly 4 to 5 sq.m at 6 mm notch.',
  lookalike:
      'Portland cement. Both are grey powder in kraft sacks. Adhesive says '
      'tile adhesive or thinset on the face and is a 25 kg bag, not 40 kg.',
  acceptance:
      'Reject any sack that feels hard or lumpy through the paper. Set powder '
      'has absorbed moisture and will not bond.',
);

const _tileGrout = MaterialVisual(
  assetKey: 'tile_grout',
  glyph: MaterialGlyph.pouchPack,
  base: _white,
  accent: _grout,
  looksLike:
      'Small foil or plastic pouch of fine coloured powder, about the size of '
      'a bag of flour. Sold from a colour chart on the counter.',
  counterCallout:
      'Ask for tile grout and give the colour, then say whether your joints '
      'are narrow or wide. Wide joints need sanded grout.',
  packaging: '2 kg pouch, sometimes 5 kg. Buy one spare pouch of the colour.',
  lookalike:
      'Tile adhesive. Grout fills the joint lines, adhesive sticks the tile '
      'down. They are not interchangeable in either direction.',
  acceptance:
      'Check every pouch is the same colour code. Grout colour shifts between '
      'batches and the change shows across the floor.',
);

const _tileSpacer = MaterialVisual(
  assetKey: 'tile_spacer',
  glyph: MaterialGlyph.spacerCross,
  base: _white,
  accent: _giBlue,
  looksLike:
      'Small plastic crosses in a clear bag, usually white or yellow. Sized '
      'by joint width in millimetres.',
  counterCallout:
      'Ask for tile cross spacers and give the millimetre size. 2 mm for wall '
      'tile, 3 mm for floor tile is the usual choice.',
  packaging: 'By the bag, typically 100 to 200 pcs.',
  lookalike:
      'Wedge or levelling clips. Those are a different system and will not '
      'set your joint width on their own.',
  acceptance:
      'Match the spacer size to the grout you bought. Narrow-joint grout '
      'cracks if forced into a 5 mm gap.',
);

const _cuttingDisc = MaterialVisual(
  assetKey: 'cutting_disc',
  glyph: MaterialGlyph.cuttingDisc,
  base: _black,
  accent: _steel,
  looksLike:
      'Flat steel disc with a dark rim and a centre bore, sold in a paper '
      'sleeve. Continuous rim for tile, segmented rim for concrete.',
  counterCallout:
      'Ask for a 4 inch diamond disc for tile, continuous rim, wet or dry '
      'cut. Say tile so you are not handed a masonry disc.',
  packaging: 'Per piece. One disc handles a normal room; carry a spare.',
  lookalike:
      'Segmented masonry disc. It cuts faster but chips the glazed face of '
      'every tile.',
  acceptance:
      'Check the bore matches your grinder, and that the rim is unchipped.',
);

// ── Painting & surface prep ────────────────────────────────────────────────

const _primer = MaterialVisual(
  assetKey: 'primer',
  glyph: MaterialGlyph.paintCan,
  base: _white,
  accent: _steel,
  looksLike:
      'Metal 4 litre can with a wire handle and a pry-off lid. Contents are '
      'thin and milky white compared with topcoat.',
  counterCallout:
      'Ask for concrete primer or masonry primer, 4 litres. If the plaster is '
      'newer than about a month, ask for masonry neutraliser as well.',
  packaging: 'Gallon can of 4 litres. Larger jobs take the 16 litre pail.',
  lookalike:
      'Flat white latex. Painters sell it as a substitute, but it does not '
      'seal alkali and the topcoat will peel in patches.',
  acceptance:
      'Check the can is not dented at the seam and the lid is unopened. '
      'Skinned primer has been sitting open on the shelf.',
);

const _topcoat = MaterialVisual(
  assetKey: 'topcoat',
  glyph: MaterialGlyph.paintCan,
  base: _latex,
  accent: _steel,
  looksLike:
      'Metal 4 litre can, tinted to your colour on the counter mixer. The '
      'colour chip is stapled or printed on the lid.',
  counterCallout:
      'Ask for latex paint and name the sheen: flat, semi-gloss or gloss. '
      'Semi-gloss for kitchen and CR walls because it wipes clean.',
  packaging:
      'Gallon can of 4 litres, or a 16 litre pail. One gallon covers roughly '
      '20 to 25 sq.m per coat.',
  lookalike:
      'Quick-dry enamel. It is solvent based, needs thinner, and will not go '
      'over latex without lifting.',
  acceptance:
      'Have all your gallons tinted in one go from the same base batch, and '
      'keep the colour code. Retinting later rarely matches.',
);

const _skimCoat = MaterialVisual(
  assetKey: 'skim_coat',
  glyph: MaterialGlyph.bagPowder,
  base: _kraft,
  accent: _white,
  looksLike:
      'White or off-white powder in a 20 kg sack. Much finer than cement, '
      'almost like plaster of paris.',
  counterCallout:
      'Ask for skim coat, 20 kg, and say interior or exterior. Exterior grade '
      'is the one that survives a wet wall.',
  packaging: '20 kg sack. One sack covers roughly 8 to 10 sq.m at a thin pass.',
  lookalike:
      'Masonry putty in a tub. Putty is for patching pinholes and small '
      'defects, not for levelling a whole wall.',
  acceptance:
      'Squeeze the sack. Any hard lump means it has taken water and it will '
      'not trowel smooth.',
);

const _masonryPutty = MaterialVisual(
  assetKey: 'masonry_putty',
  glyph: MaterialGlyph.bucketLiquid,
  base: _white,
  accent: _steel,
  looksLike:
      'Thick white paste in a plastic tub or a 4 litre can. Scoops like soft '
      'butter and does not pour.',
  counterCallout:
      'Ask for masonry putty for filling hairline cracks and pinholes before '
      'painting.',
  packaging: 'By the 4 litre can or the 20 kg tub.',
  lookalike:
      'Skim coat powder. Putty is ready-mixed and for small defects; skim '
      'coat is mixed with water and levels whole walls.',
  acceptance: 'Open and check it is still soft, not crusted at the rim.',
);

const _sandpaper = MaterialVisual(
  assetKey: 'sandpaper',
  glyph: MaterialGlyph.sandpaperSheet,
  base: _sand,
  accent: _kraftDark,
  looksLike:
      'Stiff paper sheets with a gritty face, sold flat from a rack. The grit '
      'number is printed on the back.',
  counterCallout:
      'Ask for sandpaper and give the grit: 100 for knocking down skim coat, '
      '180 for the finish pass before paint.',
  packaging: 'Per sheet. A normal room takes several of each grit.',
  lookalike:
      'Emery cloth for metal. It loads up and glazes over on plaster and wood.',
  acceptance: 'Confirm the grit number on the back matches what you asked for.',
);

const _maskingTape = MaterialVisual(
  assetKey: 'masking_tape',
  glyph: MaterialGlyph.tapeRoll,
  base: _sand,
  accent: _kraftDark,
  looksLike:
      'Cream-coloured paper tape on a cardboard core, sold from a peg by the '
      'paint counter.',
  counterCallout:
      'Ask for painter masking tape, 2 inch. Say painter tape so you get the '
      'grade that peels without lifting the finish.',
  packaging: 'By the roll, usually 20 to 50 metres.',
  lookalike:
      'Packing or duct tape. Both pull paint and plaster off the wall when '
      'removed.',
  acceptance: 'Check the roll is not dried out; old tape tears in strips.',
);

const _rollerSet = MaterialVisual(
  assetKey: 'roller_set',
  glyph: MaterialGlyph.rollerBrush,
  base: _white,
  accent: _steel,
  looksLike:
      'Fluffy cylindrical sleeve on a wire frame with a handle, usually '
      'bundled with a ribbed plastic tray.',
  counterCallout:
      'Ask for a 7 inch paint roller set with tray. Short nap for smooth '
      'walls, thick nap for rough plaster.',
  packaging: 'Per set. Keep a spare sleeve for the second coat.',
  lookalike:
      'A foam roller. It leaves bubbles in latex and is meant for enamel on '
      'smooth doors.',
  acceptance: 'Check the frame fits the sleeve and the handle takes a pole.',
);

const _paintBrush = MaterialVisual(
  assetKey: 'paint_brush',
  glyph: MaterialGlyph.paintBrush,
  base: _lumber,
  accent: _white,
  looksLike:
      'Flat bristle head in a metal ferrule on a wooden handle. Width is '
      'stamped on the ferrule.',
  counterCallout:
      'Ask for paint brushes, 2 inch for cutting in edges and 3 inch for the '
      'broader work. A stiff brush is the one for waterproofing.',
  packaging: 'Per piece.',
  lookalike:
      'A cheap chip brush. It sheds bristles into the finish coat.',
  acceptance:
      'Tug the bristles. If several come out in your fingers, take another.',
);

// ── Waterproofing ──────────────────────────────────────────────────────────

const _waterproofing = MaterialVisual(
  assetKey: 'waterproofing',
  glyph: MaterialGlyph.bucketLiquid,
  base: _tealPail,
  accent: _white,
  looksLike:
      'Plastic pail of thick liquid, often sold as two parts: a liquid pail '
      'plus a powder sack you mix into it.',
  counterCallout:
      'Ask for cementitious waterproofing for a CR floor and say it goes '
      'under tile. Confirm whether the powder comes with it or is separate.',
  packaging:
      'By the 4 litre or 16 litre pail. Two-part systems need a bag of plain '
      'cement mixed in, so buy that too.',
  lookalike:
      'Elastomeric roof paint. That is for exposed roof decks and is not '
      'rated to sit under tile adhesive.',
  acceptance:
      'Check the pail seal is unbroken and ask which cement ratio the brand '
      'wants, because it differs between them.',
);

// ── Cement, sand, aggregate ────────────────────────────────────────────────

const _cementBedding = MaterialVisual(
  assetKey: 'cement_bedding',
  glyph: MaterialGlyph.bagPowder,
  base: _kraft,
  accent: _greyCement,
  looksLike:
      'Standard 40 kg kraft sack of grey powder, stacked on pallets away from '
      'the door. Heavy and firm, not loose.',
  counterCallout:
      'Ask for Portland cement, 40 kg, Type 1P. That is the blended type used '
      'for plaster, mortar and tile bedding.',
  packaging: '40 kg bag. Roughly 9 bags fill a cubic metre of mixed concrete.',
  lookalike:
      'Tile adhesive at 25 kg. Check the printed weight on the sack before '
      'loading, because the sacks look alike on a pallet.',
  acceptance:
      'Reject any bag with hard lumps or a torn face. Store off the ground on '
      'pallets and cover it, because a wet slab ruins a whole stack.',
);

const _structuralCement = MaterialVisual(
  assetKey: 'structural_cement',
  glyph: MaterialGlyph.bagPowder,
  base: _kraft,
  accent: _black,
  looksLike:
      'Same 40 kg grey sack as ordinary cement. The type marking on the face '
      'is the only visible difference.',
  counterCallout:
      'Ask for Portland cement for a structural slab and confirm the type. '
      'Where the plan calls for Type 1, do not accept 1P as a swap.',
  packaging: '40 kg bag. About 9 bags per cubic metre of Class A concrete.',
  lookalike:
      'Masonry or plaster cement. It is not rated for structural concrete '
      'even though the sack looks the same.',
  acceptance:
      'Read the type marking on the sack itself, not the delivery receipt, '
      'and check the bags are recent and still loose.',
);

const _mortarCement = MaterialVisual(
  assetKey: 'mortar_cement',
  glyph: MaterialGlyph.bagPowder,
  base: _kraft,
  accent: _concrete,
  looksLike: '40 kg grey sack, same as bedding cement.',
  counterCallout:
      'Ask for Portland cement, 40 kg, Type 1P for CHB laying and plastering.',
  packaging: '40 kg bag.',
  lookalike:
      'Tile adhesive. Different weight, different job. Read the sack weight.',
  acceptance: 'Same check as any cement: no hard lumps, sacks kept dry.',
);

const _washedSand = MaterialVisual(
  assetKey: 'washed_sand',
  glyph: MaterialGlyph.sandPile,
  base: _sand,
  accent: _kraftDark,
  looksLike:
      'Clean pale grains that pour freely and leave little dust on the hand. '
      'Delivered loose by the truck.',
  counterCallout:
      'Order washed sand by the cubic metre and say it is for plaster and '
      'mortar. Ask for fine washed, not the coarse fill grade.',
  packaging:
      'By the cubic metre. Small volumes come by the sack, larger ones by '
      'mini-dump or elf truck.',
  lookalike:
      'Unwashed or lahar sand. It carries silt and clay, and mortar made from '
      'it cracks and dusts off.',
  acceptance:
      'Squeeze a handful. If it stains your palm brown and clumps, it is not '
      'washed. Check the truck bed volume against what you paid for.',
);

const _gravel = MaterialVisual(
  assetKey: 'gravel',
  glyph: MaterialGlyph.gravelPile,
  base: _stone,
  accent: _black,
  looksLike:
      'Angular crushed stone, roughly thumbnail sized, grey and sharp edged. '
      'Delivered loose.',
  counterCallout:
      'Order 3/4 inch crushed gravel by the cubic metre for concrete. Say G1 '
      'if the plan calls for a graded base.',
  packaging: 'By the cubic metre, delivered by truck.',
  lookalike:
      'River-run pebbles. Rounded stone does not interlock and gives weaker '
      'concrete than crushed aggregate.',
  acceptance:
      'Look for uniform size and clean faces. A load heavy with fines and mud '
      'is short on actual stone.',
);

// ── Masonry & steel ────────────────────────────────────────────────────────

const _chb = MaterialVisual(
  assetKey: 'chb',
  glyph: MaterialGlyph.hollowBlock,
  base: _concrete,
  accent: _black,
  looksLike:
      'Grey rectangular block with two hollow cells, stacked in the yard. '
      'Rings solid when tapped if it is properly cured.',
  counterCallout:
      'Ask for CHB and give the thickness: 4 inch for partitions, 6 inch for '
      'load-bearing walls. Ask whether they are load-bearing grade.',
  packaging:
      'Per piece, delivered by the hundred. Roughly 12.5 pcs cover a square '
      'metre of wall.',
  lookalike:
      'Undersized blocks. A nominal 4 inch block is often moulded thinner to '
      'save cement, and the wall ends up weaker than designed.',
  acceptance:
      'Measure the actual thickness of several blocks, not one, against the '
      'nominal size. Scratch a face with a nail: if it crumbles to sand, the '
      'mix is under-cemented and will not meet PNS ASTM C90.',
);

const _rebar = MaterialVisual(
  assetKey: 'rebar',
  glyph: MaterialGlyph.rebarBar,
  base: _rust,
  accent: _steel,
  looksLike:
      'Steel bar with raised ribs along its length, sold in 6 metre lengths '
      'and bundled in tens. Surface rust is normal, flaking is not.',
  counterCallout:
      'Ask for deformed bar, give the diameter in millimetres and the grade. '
      'Say deformed, not round bar, and confirm it is 6 metres.',
  packaging:
      'Per 6 metre length. Standard weights are 3.7 kg at 10 mm, 5.3 kg at '
      '12 mm and 9.5 kg at 16 mm.',
  lookalike:
      'Commercial-grade or undersized bar. A bar sold as 10 mm is often '
      'rolled at 9 mm or less, which is a real loss of steel area.',
  acceptance:
      'Weigh one bar or caliper the core between ribs. A 6 m bar sold as '
      '10 mm should weigh about 3.7 kg; well under that is under-rolled and '
      'fails PNS 49. Reject bars that flake rust in sheets.',
);

const _tieWire = MaterialVisual(
  assetKey: 'tie_wire',
  glyph: MaterialGlyph.wireCoil,
  base: _steel,
  accent: _black,
  looksLike:
      'Dull grey soft wire wound in a heavy coil or roll, sold by weight.',
  counterCallout:
      'Ask for number 16 GI tie wire by the kilo, for tying rebar.',
  packaging: 'By the kilo, in coils or small rolls.',
  lookalike:
      'Stiffer gauges such as number 14. They do not twist tight by hand and '
      'slow the whole rebar crew down.',
  acceptance:
      'Bend a length by hand. Proper tie wire folds easily and stays folded.',
);

// ── Roofing ────────────────────────────────────────────────────────────────

const _roofingSheet = MaterialVisual(
  assetKey: 'roofing_sheet',
  glyph: MaterialGlyph.corrugatedSheet,
  base: _giBlue,
  accent: _steel,
  looksLike:
      'Long pre-painted steel sheet with trapezoidal ribs, coloured on the '
      'top face and pale on the underside. Cut to your length at the shop.',
  counterCallout:
      'Ask for pre-painted rib-type roofing, gauge 26, and give your length in '
      'linear metres plus the colour.',
  packaging:
      'By the linear metre, cut to order. Rib-type covers about 1 metre of '
      'width per sheet after the side lap.',
  lookalike:
      'A thinner gauge. The gauge number runs backwards: Ga.26 is thicker '
      'than Ga.30. A Ga.30 sheet dents underfoot and is cheaper for a reason.',
  acceptance:
      'Press the middle of a sheet with your thumb. Real Ga.26 barely gives. '
      'Check the paint film for scuffs before it leaves the shop.',
);

const _purlin = MaterialVisual(
  assetKey: 'purlin',
  glyph: MaterialGlyph.cPurlin,
  base: _steel,
  accent: _black,
  looksLike:
      'Steel bar bent into a C-shaped channel, 6 metres long, usually black '
      'or primer-red. Stacked nested in the steel rack.',
  counterCallout:
      'Ask for C-purlins, give the section size and the thickness in '
      'millimetres, in 6 metre lengths.',
  packaging: 'Per 6 metre length.',
  lookalike:
      'A thinner wall at the same section size. Two purlins can read 2×3 and '
      'still differ in thickness, which is where the strength is.',
  acceptance:
      'Caliper the wall thickness at a cut end. Check for twisted or bowed '
      'lengths before loading.',
);

const _vulcaseal = MaterialVisual(
  assetKey: 'vulcaseal',
  glyph: MaterialGlyph.bucketLiquid,
  base: _black,
  accent: _rust,
  looksLike:
      'Thick black bituminous liquid in a metal can. Strong solvent smell, '
      'brushes on like tar.',
  counterCallout:
      'Ask for roof sealant for lapped GI sheets and screw heads, and say '
      'whether you want the black or the aluminium finish.',
  packaging: 'By the 1 litre, 4 litre or 16 litre can.',
  lookalike:
      'Silicone sealant in a cartridge. That is for joints, not for sealing '
      'roof laps over an area.',
  acceptance:
      'Check the can is sealed and the contents still stir. Old stock sets '
      'solid in the tin.',
);

// ── Formwork ───────────────────────────────────────────────────────────────

const _marinePlywood = MaterialVisual(
  assetKey: 'marine_plywood',
  glyph: MaterialGlyph.plywoodSheet,
  base: _plywood,
  accent: _kraftDark,
  looksLike:
      'Large 4 by 8 foot sheet with visible layered plies at the cut edge and '
      'a smooth face. Heavier than ordinary plywood.',
  counterCallout:
      'Ask for marine plywood, half inch, 4 by 8. Say it is for concrete '
      'formwork so you get the grade that survives wet pours.',
  packaging: 'Per 4 by 8 foot sheet.',
  lookalike:
      'Ordinary or ply-board. It delaminates on the first wet pour and the '
      'form face fails.',
  acceptance:
      'Look at the cut edge for gaps and voids between plies, and check the '
      'sheet is not already bowed in the stack.',
);

const _cocoLumber = MaterialVisual(
  assetKey: 'coco_lumber',
  glyph: MaterialGlyph.lumberStick,
  base: _lumber,
  accent: _kraftDark,
  looksLike:
      'Rough-sawn dark fibrous lumber, unplaned, in long sticks. Splinters '
      'readily and is noticeably heavy when green.',
  counterCallout:
      'Ask for coco lumber and give the section and length, for formwork and '
      'bracing.',
  packaging:
      'By the piece or by board foot. Common sections are 2×2 and 2×3 in '
      '12 foot lengths.',
  lookalike:
      'Good lumber, which costs much more. For temporary forms coco lumber is '
      'the correct call.',
  acceptance:
      'Sight down each stick for bow and twist, and reject soft or insect '
      'bored pieces.',
);

const _cwn = MaterialVisual(
  assetKey: 'cwn',
  glyph: MaterialGlyph.nailsBox,
  base: _steel,
  accent: _black,
  looksLike:
      'Bright steel nails with flat heads, loose in a bin or in a plastic bag, '
      'sold by weight.',
  counterCallout:
      'Ask for common wire nails by the kilo and give the length in inches. '
      'Formwork usually wants a mix of 2, 3 and 4 inch.',
  packaging: 'By the kilo.',
  lookalike:
      'Finishing nails or concrete nails. Finishing nails have small heads '
      'that pull straight through form lumber.',
  acceptance: 'Check for straight shanks and no rust bloom in the bag.',
);

const _fasteners = MaterialVisual(
  assetKey: 'fasteners',
  glyph: MaterialGlyph.nailsBox,
  base: _steel,
  accent: _giBlue,
  looksLike:
      'Small metal fasteners boxed or bagged by size. Roofing tekscrews carry '
      'a rubber washer under the head.',
  counterCallout:
      'Give the type, the length and the quantity. For roofing say tekscrews '
      'with rubber washers.',
  packaging: 'By the box, the kilo or the piece depending on the type.',
  lookalike:
      'Tekscrews without washers. Every screw hole then leaks at the first '
      'heavy rain.',
  acceptance:
      'Check the washers are present and still soft, not hardened and cracked.',
);

// ── Plumbing ───────────────────────────────────────────────────────────────

const _waterCloset = MaterialVisual(
  assetKey: 'water_closet',
  glyph: MaterialGlyph.waterCloset,
  base: _porcelain,
  accent: _steel,
  looksLike:
      'White ceramic bowl and tank, displayed on the showroom floor and boxed '
      'in the stockroom with the fittings inside.',
  counterCallout:
      'Ask for a water closet and give the rough-in distance from the finished '
      'wall to the drain centre. Confirm the flush fittings are included.',
  packaging:
      'Per set. Ask whether the seat cover, flush valve and angle valve come '
      'with it, because they often do not.',
  lookalike:
      'A bowl with a different rough-in. If the rough-in does not match your '
      'drain, the unit will not sit against the wall.',
  acceptance:
      'Unbox and inspect for hairline cracks before it leaves the store, and '
      'check the bowl sits flat with no rock.',
);

const _lavatory = MaterialVisual(
  assetKey: 'lavatory',
  glyph: MaterialGlyph.lavatory,
  base: _porcelain,
  accent: _steel,
  looksLike:
      'White ceramic basin, either wall-hung with a pedestal or shaped to drop '
      'into a counter.',
  counterCallout:
      'Ask for a lavatory and say wall-hung, pedestal or counter-top. Confirm '
      'whether the faucet hole is pre-drilled.',
  packaging: 'Per piece. The P-trap and angle valve are usually separate.',
  lookalike:
      'A counter-top basin bought for a wall-hung position. The mounting is '
      'completely different.',
  acceptance:
      'Check for chips at the rim and confirm the drain hole size matches '
      'your trap.',
);

const _showerSet = MaterialVisual(
  assetKey: 'shower_set',
  glyph: MaterialGlyph.showerSet,
  base: _steel,
  accent: _porcelain,
  looksLike:
      'Chrome head, arm and mixer, boxed as a set with a wall flange and '
      'sometimes a hose.',
  counterCallout:
      'Ask for a shower set and say whether it is hot and cold or cold only. '
      'Confirm the inlet thread size.',
  packaging: 'Per set.',
  lookalike:
      'A hot-and-cold mixer bought for a cold-only line, which leaves an '
      'unused inlet to cap.',
  acceptance:
      'Open the box and check the flange, washers and mounting screws are all '
      'inside before leaving.',
);

const _faucet = MaterialVisual(
  assetKey: 'faucet',
  glyph: MaterialGlyph.faucet,
  base: _steel,
  accent: _porcelain,
  looksLike:
      'Chrome or stainless spout with a threaded inlet, carded or boxed on a '
      'display peg.',
  counterCallout:
      'Ask for the faucet by mounting type: wall, deck or sink. Give the '
      'thread size, commonly half inch.',
  packaging: 'Per piece.',
  lookalike:
      'A wall faucet bought for a deck-mounted basin. The thread matches but '
      'the geometry does not.',
  acceptance:
      'Turn the handle in the store to feel for a gritty or stiff cartridge.',
);

const _teflonTape = MaterialVisual(
  assetKey: 'teflon_tape',
  glyph: MaterialGlyph.tapeRoll,
  base: _white,
  accent: _giBlue,
  looksLike:
      'Small roll of thin white film on a plastic spool, in a clear sleeve. '
      'Stretches rather than tears.',
  counterCallout:
      'Ask for teflon tape, three quarter inch, for threaded pipe joints.',
  packaging: 'By the roll. Buy several, they are consumed fast.',
  lookalike:
      'Masking tape or electrical tape. Neither seals a threaded water joint.',
  acceptance:
      'Check the film is not brittle. Old tape shreds instead of stretching.',
);

const _silicone = MaterialVisual(
  assetKey: 'silicone',
  glyph: MaterialGlyph.tubeSealant,
  base: _white,
  accent: _giBlue,
  looksLike:
      'Rigid plastic cartridge with a tapered nozzle, loaded into a caulking '
      'gun. Contents are a clear or white gel.',
  counterCallout:
      'Ask for sanitary silicone sealant, neutral cure, for wet areas. Say '
      'sanitary so you get the mould-resistant grade.',
  packaging:
      'By the 300 ml cartridge. You need a caulking gun to use it, sold '
      'separately.',
  lookalike:
      'Acetic cure silicone, which smells of vinegar. It corrodes metal '
      'fixtures and is the wrong choice against chrome and steel.',
  acceptance:
      'Check the expiry date on the cartridge. Expired silicone never fully '
      'cures.',
);

const _solventCement = MaterialVisual(
  assetKey: 'solvent_cement',
  // A tin of glue, not a caulking cartridge — the can glyph is the closer read.
  glyph: MaterialGlyph.bucketLiquid,
  base: _pvcOrange,
  accent: _black,
  looksLike:
      'Small metal or plastic tin of thin blue or clear glue, with a brush '
      'fixed inside the cap. Strong solvent smell.',
  counterCallout:
      'Ask for PVC solvent cement for pipe joints and give the tin size.',
  packaging: 'By the 100 cc or larger tin.',
  lookalike:
      'PPR pipe, which cannot be solvent welded at all. PPR is joined by heat '
      'fusion, so check which pipe material you actually have.',
  acceptance:
      'Check the tin is sealed and the cement still runs freely. Thickened '
      'cement does not weld the joint.',
);

const _pvcPipe = MaterialVisual(
  assetKey: 'pvc_pipe',
  glyph: MaterialGlyph.pipeLength,
  base: _pvcOrange,
  accent: _white,
  looksLike:
      'Rigid plastic tube in fixed lengths. Orange marks sanitary drain pipe, '
      'blue or white marks pressure water line.',
  counterCallout:
      'Give the diameter, the series and the use. Say sanitary for drains or '
      'blue for pressure, because they are not interchangeable.',
  packaging: 'Per length, commonly 3 metres. Fittings are sold separately.',
  lookalike:
      'Thin-wall drain pipe used on a pressure line. It splits under mains '
      'pressure.',
  acceptance:
      'Check the printed series marking along the pipe and that the ends are '
      'round, not crushed from the stack.',
);

// ── Other ──────────────────────────────────────────────────────────────────

const _areaGoods = MaterialVisual(
  assetKey: 'area_goods',
  glyph: MaterialGlyph.plankGoods,
  base: _lumber,
  accent: _kraftDark,
  looksLike:
      'Wood-look planks in a flat carton, or a roll of sheet flooring. Light '
      'to carry compared with tile.',
  counterCallout:
      'Ask for the flooring by square metre coverage, not by piece, and ask '
      'whether underlayment is included.',
  packaging:
      'By the box, each box stating its square metre coverage. Order by area '
      'plus a cutting allowance.',
  lookalike:
      'A different plank thickness or lock system. Boxes from different runs '
      'will not click together.',
  acceptance:
      'Check all boxes carry the same batch and pattern code, and that the '
      'planks are flat, not cupped.',
);

const _electrical = MaterialVisual(
  assetKey: 'electrical',
  glyph: MaterialGlyph.wireSpool,
  base: _giBlue,
  accent: _kraft,
  looksLike:
      'Coloured insulated wire wound on a spool or in a boxed roll, with the '
      'size and type printed along the insulation.',
  counterCallout:
      'Give the wire size, the number of conductors and the type. Ask for a '
      'brand carrying the PS mark, or the ICC sticker if it is imported.',
  packaging:
      'By the box or roll, commonly 150 metres, or cut by the metre.',
  lookalike:
      'Undersized or aluminium-cored wire sold at the same gauge label. It '
      'runs hot on the same load.',
  acceptance:
      'Look for the PS mark or ICC sticker, and the size printed on the '
      'insulation itself, not just on the box.',
);

const _generic = MaterialVisual(
  assetKey: 'generic',
  glyph: MaterialGlyph.genericBox,
  base: _kraft,
  accent: _kraftDark,
  looksLike: 'Boxed or bagged item on the hardware shelf.',
  counterCallout:
      'Read out the full item name, the size and the quantity, and have the '
      'salesperson confirm the packing before quoting.',
  packaging: 'Confirm the selling unit before ordering.',
  lookalike: null,
  acceptance: 'Check the item against your list before it is loaded.',
);
