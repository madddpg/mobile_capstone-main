part of 'renovation_templates.dart';

/// One piece of work a builder can tick, in the words a client would use,
/// with the material lines it brings.
///
/// The lines carry no quantities of their own. The estimator sizes each one
/// from the measured room exactly as it sizes a template line, so a work item
/// decides what is bought and never how much.
class WorkItem {
  final String id;
  final String label;

  /// What the item covers, shown under its label.
  final String detail;
  final RenovationScope scope;
  final List<RenovationTemplateItem> materials;

  const WorkItem({
    required this.id,
    required this.label,
    required this.detail,
    required this.scope,
    required this.materials,
  });
}

/// A ready-made set of work items, so a builder with a common job picks one
/// name instead of ticking each piece.
class WorkPackage {
  final String id;
  final String label;
  final List<String> itemIds;

  const WorkPackage({
    required this.id,
    required this.label,
    required this.itemIds,
  });
}

/// The work a project can include, and how ticked work becomes a list.
class WorkCatalogue {
  final String renovationType;
  final List<WorkItem> items;
  final List<WorkPackage> packages;

  /// The package ticked to begin with for each kind of work, chosen so that a
  /// single kind starts with exactly the list its template always had.
  final Map<RenovationScope, String> startingPackages;

  const WorkCatalogue({
    required this.renovationType,
    required this.items,
    required this.packages,
    required this.startingPackages,
  });

  /// This catalogue for a particular project, whose name the list is saved
  /// under. The room catalogue serves several projects this way.
  WorkCatalogue forType(String type) => WorkCatalogue(
        renovationType: type,
        items: items,
        packages: packages,
        startingPackages: startingPackages,
      );

  /// Walls and slab first, then finishes, then pipes: the order the job is
  /// built in, and the order the materials list reads in.
  static const List<RenovationScope> _buildOrder = [
    RenovationScope.structural,
    RenovationScope.cosmetic,
    RenovationScope.functional,
  ];

  WorkItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  WorkPackage? packageById(String id) {
    for (final package in packages) {
      if (package.id == id) return package;
    }
    return null;
  }

  /// The items ticked when the builder arrives, from the kinds of work chosen
  /// on the step before.
  Set<String> startingSelection(RenovationTypes types) => {
        for (final scope in types.values)
          ...?packageById(startingPackages[scope] ?? '')?.itemIds,
      };

  /// The package [selection] is exactly, if it is one.
  WorkPackage? packageMatching(Set<String> selection) {
    for (final package in packages) {
      if (package.itemIds.length == selection.length &&
          selection.containsAll(package.itemIds)) {
        return package;
      }
    }
    return null;
  }

  List<WorkItem> _ticked(Set<String> selection) => [
        for (final scope in _buildOrder)
          for (final item in items)
            if (item.scope == scope && selection.contains(item.id)) item,
      ];

  /// The kinds of work [selection] adds up to. The ticked work, not the step
  /// before, decides this, so a job whose pipes were all unticked is no longer
  /// called functional.
  RenovationTypes typesOf(Set<String> selection) =>
      RenovationTypes([for (final item in _ticked(selection)) item.scope]);

  /// Work of the same kinds as the job that was left unticked. Told to the
  /// shop as not included, so a bathroom retiled without its walls reads as
  /// exactly that. Work of a kind the job does not include at all is not
  /// listed: no one expects new pipes from a retiling job.
  List<WorkItem> leftOut(Set<String> selection) {
    final kinds = {for (final item in _ticked(selection)) item.scope};
    return [
      for (final item in items)
        if (kinds.contains(item.scope) && !selection.contains(item.id)) item,
    ];
  }

  /// The materials list for [selection]. A line two items both need, such as
  /// the forms for new walls and a new slab, appears once.
  RenovationTemplate templateFor(Set<String> selection) {
    final ticked = _ticked(selection);
    if (ticked.isEmpty) {
      throw ArgumentError('Tick at least one work item.');
    }
    final types = typesOf(selection);
    final seen = <String>{};
    final type = RenovationTemplatesCatalog.normalizeType(renovationType);
    return RenovationTemplate(
      id: '${RenovationTemplatesCatalog._idPrefix(type)}_work',
      renovationType: type,
      scope: types.primary,
      name: '${types.label} ${RenovationTemplatesCatalog._shortType(type)}',
      description: '${ticked.map((i) => i.label).join('; ')}.',
      items: [
        for (final item in ticked)
          for (final material in item.materials)
            if (seen.add(material.name.trim().toLowerCase())) material,
      ],
      workItemIds: [for (final item in ticked) item.id],
    );
  }
}

// ── Work items shared by several projects ────────────────────────────────
//
// Each item is made of lines a template already carried, so ticking the
// starting package for a kind of work gives the list that kind always gave.

typedef _T = RenovationTemplatesCatalog;

const _retileWetFloor = WorkItem(
  id: 'retile_floor',
  label: 'Retile the floor',
  detail: 'Non-slip floor tiles, with the adhesive and grout they need',
  scope: RenovationScope.cosmetic,
  materials: [_T._nonSlipFloorTile],
);

const _retileFloor = WorkItem(
  id: 'retile_floor',
  label: 'Retile the floor',
  detail: '600x600 floor tiles, with the adhesive and grout they need',
  scope: RenovationScope.cosmetic,
  materials: [_T._floorTile],
);

const _tileWalls = WorkItem(
  id: 'tile_walls',
  label: 'Tile the walls',
  detail: 'Wall tiles, up to the height you choose when measuring',
  scope: RenovationScope.cosmetic,
  materials: [_T._wallTile],
);

const _waterproofFloor = WorkItem(
  id: 'waterproof_floor',
  label: 'Waterproof the floor',
  detail: 'Two coats on the floor and a 0.30 m upturn',
  scope: RenovationScope.cosmetic,
  materials: [_T._waterproofing],
);

const _repaintAboveTiles = WorkItem(
  id: 'repaint',
  label: 'Repaint',
  detail: 'Primer and two coats on the walls above the tiles',
  scope: RenovationScope.cosmetic,
  materials: [_T._primer, _T._paint],
);

const _repaintWalls = WorkItem(
  id: 'repaint',
  label: 'Repaint the walls',
  detail: 'Primer and two coats, with masking tape for the edges',
  scope: RenovationScope.cosmetic,
  materials: [_T._primer, _T._paint, _T._maskingTape],
);

const _skimWalls = WorkItem(
  id: 'skim_coat',
  label: 'Skim coat the walls',
  detail: 'A smooth skim coat over the old plaster before painting',
  scope: RenovationScope.cosmetic,
  materials: [_T._skimCoat],
);

const _replaceSkirting = WorkItem(
  id: 'replace_skirting',
  label: 'Replace the skirting',
  detail: 'Round the room, less the doorways',
  scope: RenovationScope.cosmetic,
  materials: [_T._skirting],
);

const _buildRoomWalls = WorkItem(
  id: 'build_walls',
  label: 'Build new walls',
  detail: '4" CHB, mortar, plaster and bars for every wall of the measured '
      'room, less its doors and windows',
  scope: RenovationScope.structural,
  materials: [..._T._newWalls, ..._T._formwork],
);

const _castSlab = WorkItem(
  id: 'cast_slab',
  label: 'Cast a new floor slab',
  detail: 'A 100 mm concrete slab on grade over the whole floor',
  scope: RenovationScope.structural,
  materials: [_T._slabCement, _T._slabSand, _T._gravel, ..._T._formwork],
);

const _rewireRoom = WorkItem(
  id: 'rewire',
  label: 'Rewire the room',
  detail: 'Outlets, switches and lights, sized from the counts you enter',
  scope: RenovationScope.functional,
  materials: _T._roomWiring,
);

// ── Catalogues ───────────────────────────────────────────────────────────

/// Bathroom: the most kinds of work of any project.
const WorkCatalogue _bathroomWork = WorkCatalogue(
  renovationType: 'Bathroom Renovation',
  items: [
    _retileWetFloor,
    _tileWalls,
    _waterproofFloor,
    _repaintAboveTiles,
    WorkItem(
      id: 'replace_toilet',
      label: 'Replace the toilet',
      detail: 'A two-piece water closet',
      scope: RenovationScope.cosmetic,
      materials: [_T._waterCloset],
    ),
    WorkItem(
      id: 'replace_lavatory',
      label: 'Replace the lavatory',
      detail: 'A lavatory with pedestal',
      scope: RenovationScope.cosmetic,
      materials: [_T._lavatory],
    ),
    WorkItem(
      id: 'replace_shower',
      label: 'Replace the shower',
      detail: 'A shower set',
      scope: RenovationScope.cosmetic,
      materials: [_T._showerSet],
    ),
    _buildRoomWalls,
    _castSlab,
    WorkItem(
      id: 'supply_lines',
      label: 'Replace the water supply lines',
      detail: 'PPR pipe, fittings and valves to the toilet, lavatory and shower',
      scope: RenovationScope.functional,
      materials: [..._T._bathroomSupplyLines, _T._bathroomTeflon],
    ),
    WorkItem(
      id: 'drain_lines',
      label: 'Replace the drain lines',
      detail: 'Sanitary pipe, a floor drain and traps to the septic line',
      scope: RenovationScope.functional,
      materials: [..._T._bathroomDrainLines, _T._solventCement],
    ),
  ],
  packages: [
    WorkPackage(
      id: 'full_makeover',
      label: 'Full makeover',
      itemIds: [
        'retile_floor',
        'tile_walls',
        'waterproof_floor',
        'repaint',
        'replace_toilet',
        'replace_lavatory',
        'replace_shower',
      ],
    ),
    WorkPackage(
      id: 'retile_only',
      label: 'Retile only',
      itemIds: ['retile_floor', 'tile_walls', 'waterproof_floor'],
    ),
    WorkPackage(
      id: 'fixture_swap',
      label: 'Fixture swap',
      itemIds: ['replace_toilet', 'replace_lavatory', 'replace_shower'],
    ),
    WorkPackage(
      id: 'repaint_only',
      label: 'Repaint only',
      itemIds: ['repaint'],
    ),
    WorkPackage(
      id: 'new_pipes',
      label: 'New pipes',
      itemIds: ['supply_lines', 'drain_lines'],
    ),
    WorkPackage(
      id: 'build_new',
      label: 'Build new',
      itemIds: [
        'build_walls',
        'cast_slab',
        'retile_floor',
        'tile_walls',
        'waterproof_floor',
        'repaint',
      ],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'full_makeover',
    RenovationScope.structural: 'build_new',
    RenovationScope.functional: 'new_pipes',
  },
);

/// Laundry: a wet room like the bathroom, with a washer instead of fixtures.
const WorkCatalogue _laundryWork = WorkCatalogue(
  renovationType: 'Laundry Renovation',
  items: [
    _retileWetFloor,
    _tileWalls,
    _waterproofFloor,
    _repaintAboveTiles,
    _buildRoomWalls,
    _castSlab,
    WorkItem(
      id: 'washer_plumbing',
      label: 'Plumb in the washing machine',
      detail: 'A water line, faucet, drain and floor drain for the washer',
      scope: RenovationScope.functional,
      materials: _T._laundryPlumbing,
    ),
    _rewireRoom,
  ],
  packages: [
    WorkPackage(
      id: 'full_makeover',
      label: 'Full makeover',
      itemIds: ['retile_floor', 'tile_walls', 'waterproof_floor', 'repaint'],
    ),
    WorkPackage(
      id: 'retile_only',
      label: 'Retile only',
      itemIds: ['retile_floor', 'tile_walls', 'waterproof_floor'],
    ),
    WorkPackage(
      id: 'repaint_only',
      label: 'Repaint only',
      itemIds: ['repaint'],
    ),
    WorkPackage(
      id: 'washer_hookup',
      label: 'Washer hookup',
      itemIds: ['washer_plumbing'],
    ),
    WorkPackage(
      id: 'new_pipes_wiring',
      label: 'New pipes and wiring',
      itemIds: ['washer_plumbing', 'rewire'],
    ),
    WorkPackage(
      id: 'build_new',
      label: 'Build new',
      itemIds: [
        'build_walls',
        'cast_slab',
        'retile_floor',
        'tile_walls',
        'waterproof_floor',
        'repaint',
      ],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'full_makeover',
    RenovationScope.structural: 'build_new',
    RenovationScope.functional: 'new_pipes_wiring',
  },
);

/// Kitchen: floor, backsplash, counter and sink, and its own circuits.
const WorkCatalogue _kitchenWork = WorkCatalogue(
  renovationType: 'Kitchen Renovation',
  items: [
    _retileFloor,
    WorkItem(
      id: 'tile_backsplash',
      label: 'Tile the backsplash',
      detail: 'Subway tiles along the counter, sized from the counter length',
      scope: RenovationScope.cosmetic,
      materials: [_T._backsplashTile],
    ),
    WorkItem(
      id: 'replace_countertop',
      label: 'Replace the countertop',
      detail: 'Granite at a 0.60 m depth, sized from the counter length',
      scope: RenovationScope.cosmetic,
      materials: [_T._countertop],
    ),
    _repaintAboveTiles,
    WorkItem(
      id: 'replace_sink',
      label: 'Replace the sink',
      detail: 'A single-bowl stainless sink and a gooseneck faucet',
      scope: RenovationScope.cosmetic,
      materials: [_T._kitchenSink, _T._sinkFaucet],
    ),
    _buildRoomWalls,
    _castSlab,
    WorkItem(
      id: 'sink_plumbing',
      label: 'Replace the sink pipes',
      detail: 'PPR water line to the sink and a drain to the grease trap',
      scope: RenovationScope.functional,
      materials: _T._kitchenPlumbing,
    ),
    _rewireRoom,
    WorkItem(
      id: 'appliance_circuit',
      label: 'Add a range or oven circuit',
      detail: 'A dedicated 30 A circuit from the panel',
      scope: RenovationScope.functional,
      materials: _T._kitchenAppliances,
    ),
  ],
  packages: [
    WorkPackage(
      id: 'full_makeover',
      label: 'Full makeover',
      itemIds: [
        'retile_floor',
        'tile_backsplash',
        'replace_countertop',
        'repaint',
        'replace_sink',
      ],
    ),
    WorkPackage(
      id: 'retile_only',
      label: 'Retile only',
      itemIds: ['retile_floor', 'tile_backsplash'],
    ),
    WorkPackage(
      id: 'counter_and_sink',
      label: 'Counter and sink',
      itemIds: ['replace_countertop', 'replace_sink'],
    ),
    WorkPackage(
      id: 'repaint_only',
      label: 'Repaint only',
      itemIds: ['repaint'],
    ),
    WorkPackage(
      id: 'new_pipes_wiring',
      label: 'New pipes and wiring',
      itemIds: ['sink_plumbing', 'rewire', 'appliance_circuit'],
    ),
    WorkPackage(
      id: 'build_new',
      label: 'Build new',
      itemIds: [
        'build_walls',
        'cast_slab',
        'retile_floor',
        'tile_backsplash',
        'repaint',
      ],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'full_makeover',
    RenovationScope.structural: 'build_new',
    RenovationScope.functional: 'new_pipes_wiring',
  },
);

/// Living room, bedroom, dining room and any other dry room.
const WorkCatalogue _roomWork = WorkCatalogue(
  renovationType: 'Room Renovation',
  items: [
    _retileFloor,
    _replaceSkirting,
    _skimWalls,
    _repaintWalls,
    _tileWalls,
    _buildRoomWalls,
    _castSlab,
    _rewireRoom,
  ],
  packages: [
    WorkPackage(
      id: 'full_makeover',
      label: 'Full makeover',
      itemIds: ['retile_floor', 'replace_skirting', 'skim_coat', 'repaint'],
    ),
    WorkPackage(
      id: 'new_floor',
      label: 'New floor',
      itemIds: ['retile_floor', 'replace_skirting'],
    ),
    WorkPackage(
      id: 'repaint_only',
      label: 'Repaint only',
      itemIds: ['skim_coat', 'repaint'],
    ),
    WorkPackage(
      id: 'rewire',
      label: 'Rewire',
      itemIds: ['rewire'],
    ),
    WorkPackage(
      id: 'build_new',
      label: 'Build new',
      itemIds: [
        'build_walls',
        'cast_slab',
        'retile_floor',
        'skim_coat',
        'repaint',
      ],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'full_makeover',
    RenovationScope.structural: 'build_new',
    RenovationScope.functional: 'rewire',
  },
);

/// Floor renovation: the floor and its skirting, or a new slab under them.
const WorkCatalogue _floorWork = WorkCatalogue(
  renovationType: 'Floor Renovation',
  items: [
    _retileFloor,
    _replaceSkirting,
    WorkItem(
      id: 'recast_slab',
      label: 'Recast the floor slab',
      detail: 'Break out a damaged or uneven slab and cast a new 100 mm one '
          'with welded mesh',
      scope: RenovationScope.structural,
      materials: [
        _T._slabCement,
        _T._slabSand,
        _T._gravel,
        _T._weldedMesh,
      ],
    ),
  ],
  packages: [
    WorkPackage(
      id: 'retile',
      label: 'Retile',
      itemIds: ['retile_floor', 'replace_skirting'],
    ),
    WorkPackage(
      id: 'tiles_only',
      label: 'Tiles only',
      itemIds: ['retile_floor'],
    ),
    WorkPackage(
      id: 'recast_and_retile',
      label: 'Recast and retile',
      itemIds: ['recast_slab', 'retile_floor', 'replace_skirting'],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'retile',
    RenovationScope.structural: 'recast_and_retile',
  },
);

/// Interior painting: walls and ceiling only.
const WorkCatalogue _paintingWork = WorkCatalogue(
  renovationType: 'Interior Painting',
  items: [
    _skimWalls,
    WorkItem(
      id: 'repaint',
      label: 'Repaint the walls',
      detail: 'Primer and two coats, with tape and brushes for the edges',
      scope: RenovationScope.cosmetic,
      materials: [_T._primer, _T._paint, _T._maskingTape, _T._paintBrush],
    ),
  ],
  packages: [
    WorkPackage(
      id: 'full_repaint',
      label: 'Skim and repaint',
      itemIds: ['skim_coat', 'repaint'],
    ),
    WorkPackage(
      id: 'paint_only',
      label: 'Paint only',
      itemIds: ['repaint'],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'full_repaint',
  },
);

/// Wall finishing: refinish a wall, tile it, or build it new.
const WorkCatalogue _wallWork = WorkCatalogue(
  renovationType: 'Wall Finishing',
  items: [
    _skimWalls,
    _repaintWalls,
    _tileWalls,
    // No formwork: the wall-finishing template never carried any.
    WorkItem(
      id: 'build_walls',
      label: 'Build new walls',
      detail: '4" CHB, mortar, plaster and bars for the measured walls, less '
          'their doors and windows',
      scope: RenovationScope.structural,
      materials: _T._newWalls,
    ),
  ],
  packages: [
    WorkPackage(
      id: 'refinish',
      label: 'Skim and repaint',
      itemIds: ['skim_coat', 'repaint'],
    ),
    WorkPackage(
      id: 'tile_only',
      label: 'Tile the walls',
      itemIds: ['tile_walls'],
    ),
    WorkPackage(
      id: 'build_new',
      label: 'Build new',
      itemIds: ['build_walls', 'skim_coat', 'repaint'],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'refinish',
    RenovationScope.structural: 'build_new',
  },
);

/// Roof repair: repaint, re-roof, or new gutters.
const WorkCatalogue _roofWork = WorkCatalogue(
  renovationType: 'Roof Repair',
  items: [
    WorkItem(
      id: 'repaint_roof',
      label: 'Repaint the roof',
      detail: 'Wire-brush the rust, then red oxide primer and roof paint',
      scope: RenovationScope.cosmetic,
      materials: [_T._metalPrimer, _T._roofPaint, _T._steelBrush],
    ),
    WorkItem(
      id: 'seal_leaks',
      label: 'Seal the leaks',
      detail: 'Roof sealant at laps, screws and flashing',
      scope: RenovationScope.cosmetic,
      materials: [_T._roofSealant],
    ),
    WorkItem(
      id: 'replace_sheets',
      label: 'Replace the roofing sheets',
      detail: 'Rib-type sheets by the metre, ridge roll and tekscrews',
      scope: RenovationScope.structural,
      materials: [_T._ribRoofing, _T._ridgeRoll, _T._tekscrew, _T._roofSealant],
    ),
    WorkItem(
      id: 'replace_purlins',
      label: 'Replace the purlins',
      detail: 'C-purlins at 600 mm on centre, welded to the trusses',
      scope: RenovationScope.structural,
      materials: [_T._cPurlin, _T._weldingRod],
    ),
    WorkItem(
      id: 'gutters',
      label: 'Put up new gutters',
      detail: 'Pre-painted gutters along both eaves, on brackets',
      scope: RenovationScope.functional,
      materials: [
        _T._gutter,
        _T._gutterBracket,
        _T._blindRivets,
        _T._roofSealant,
      ],
    ),
    WorkItem(
      id: 'downspouts',
      label: 'Put up new downspouts',
      detail: 'PVC downspouts with elbows, one per 9 m of gutter',
      scope: RenovationScope.functional,
      materials: [_T._downspout, _T._downspoutElbow],
    ),
  ],
  packages: [
    WorkPackage(
      id: 'repaint_reseal',
      label: 'Repaint and reseal',
      itemIds: ['repaint_roof', 'seal_leaks'],
    ),
    WorkPackage(
      id: 'seal_only',
      label: 'Seal leaks only',
      itemIds: ['seal_leaks'],
    ),
    WorkPackage(
      id: 'reroof',
      label: 'Re-roof',
      itemIds: ['replace_sheets', 'replace_purlins'],
    ),
    WorkPackage(
      id: 'new_gutters',
      label: 'New gutters',
      itemIds: ['gutters', 'downspouts'],
    ),
  ],
  startingPackages: {
    RenovationScope.cosmetic: 'repaint_reseal',
    RenovationScope.structural: 'reroof',
    RenovationScope.functional: 'new_gutters',
  },
);
