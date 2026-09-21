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

/// The bathroom, which has the most kinds of work of any project. Each item
/// is made of the lines the bathroom templates already carried, so a single
/// kind of work still gives the list it always did.
const WorkCatalogue _bathroomWork = WorkCatalogue(
  renovationType: 'Bathroom Renovation',
  items: [
    WorkItem(
      id: 'retile_floor',
      label: 'Retile the floor',
      detail: 'Non-slip floor tiles, with the adhesive and grout they need',
      scope: RenovationScope.cosmetic,
      materials: [RenovationTemplatesCatalog._nonSlipFloorTile],
    ),
    WorkItem(
      id: 'tile_walls',
      label: 'Tile the walls',
      detail: 'Wall tiles, up to the height you choose when measuring',
      scope: RenovationScope.cosmetic,
      materials: [RenovationTemplatesCatalog._wallTile],
    ),
    WorkItem(
      id: 'waterproof_floor',
      label: 'Waterproof the floor',
      detail: 'Two coats on the floor and a 0.30 m upturn',
      scope: RenovationScope.cosmetic,
      materials: [RenovationTemplatesCatalog._waterproofing],
    ),
    WorkItem(
      id: 'repaint',
      label: 'Repaint',
      detail: 'Primer and two coats on the walls above the tiles',
      scope: RenovationScope.cosmetic,
      materials: [
        RenovationTemplatesCatalog._primer,
        RenovationTemplatesCatalog._paint,
      ],
    ),
    WorkItem(
      id: 'replace_toilet',
      label: 'Replace the toilet',
      detail: 'A two-piece water closet',
      scope: RenovationScope.cosmetic,
      materials: [RenovationTemplatesCatalog._waterCloset],
    ),
    WorkItem(
      id: 'replace_lavatory',
      label: 'Replace the lavatory',
      detail: 'A lavatory with pedestal',
      scope: RenovationScope.cosmetic,
      materials: [RenovationTemplatesCatalog._lavatory],
    ),
    WorkItem(
      id: 'replace_shower',
      label: 'Replace the shower',
      detail: 'A shower set',
      scope: RenovationScope.cosmetic,
      materials: [RenovationTemplatesCatalog._showerSet],
    ),
    WorkItem(
      id: 'build_walls',
      label: 'Build new walls',
      detail: '4" CHB, mortar, plaster and bars for every wall of the '
          'measured room, less its doors and windows',
      scope: RenovationScope.structural,
      materials: [
        ...RenovationTemplatesCatalog._newWalls,
        ...RenovationTemplatesCatalog._formwork,
      ],
    ),
    WorkItem(
      id: 'cast_slab',
      label: 'Cast a new floor slab',
      detail: 'A 100 mm concrete slab on grade over the whole floor',
      scope: RenovationScope.structural,
      materials: [
        RenovationTemplatesCatalog._slabCement,
        RenovationTemplatesCatalog._slabSand,
        RenovationTemplatesCatalog._gravel,
        ...RenovationTemplatesCatalog._formwork,
      ],
    ),
    WorkItem(
      id: 'supply_lines',
      label: 'Replace the water supply lines',
      detail: 'PPR pipe, fittings and valves to the toilet, lavatory and shower',
      scope: RenovationScope.functional,
      materials: [
        ...RenovationTemplatesCatalog._bathroomSupplyLines,
        RenovationTemplatesCatalog._bathroomTeflon,
      ],
    ),
    WorkItem(
      id: 'drain_lines',
      label: 'Replace the drain lines',
      detail: 'Sanitary pipe, a floor drain and traps to the septic line',
      scope: RenovationScope.functional,
      materials: [
        ...RenovationTemplatesCatalog._bathroomDrainLines,
        RenovationTemplatesCatalog._solventCement,
      ],
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
