/// Pre-defined renovation BOM templates used as **references** for planning.
///
/// Templates hold basic essential materials. Quantities scale from project area
/// (sqm). Swappable slots (e.g. tiles) expose alternatives the builder can pick.
library;

import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';

part 'work_items.dart';

class MaterialAlternative {
  final String name;
  final String? size;
  final String? notes;

  const MaterialAlternative({
    required this.name,
    this.size,
    this.notes,
  });

  factory MaterialAlternative.fromMap(Map<String, dynamic> data) {
    return MaterialAlternative(
      name: (data['name'] ?? '').toString(),
      size: data['size']?.toString(),
      notes: data['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (size != null && size!.isNotEmpty) 'size': size,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class RenovationTemplateItem {
  final String name;
  final String category;
  final String unit;

  /// Baseline quantity when [qtyPerSqm] is null (fixed count items).
  final double defaultQuantity;

  /// When set, quantity = qtyPerSqm × areaSqm (with waste for surfaces).
  final double? qtyPerSqm;

  final String? size;
  final List<String> availableSizes;
  final String? notes;
  final bool isSwappable;
  final List<MaterialAlternative> alternatives;

  const RenovationTemplateItem({
    required this.name,
    required this.category,
    required this.unit,
    required this.defaultQuantity,
    this.qtyPerSqm,
    this.size,
    this.availableSizes = const [],
    this.notes,
    this.isSwappable = false,
    this.alternatives = const [],
  });

  factory RenovationTemplateItem.fromMap(Map<String, dynamic> data) {
    final rawAlts = data['alternatives'];
    final alts = <MaterialAlternative>[];
    if (rawAlts is List) {
      for (final a in rawAlts) {
        if (a is Map<String, dynamic>) {
          alts.add(MaterialAlternative.fromMap(a));
        } else if (a is Map) {
          alts.add(MaterialAlternative.fromMap(Map<String, dynamic>.from(a)));
        }
      }
    }

    final rawSizes = data['availableSizes'];
    final sizes = <String>[];
    if (rawSizes is List) {
      for (final s in rawSizes) {
        if (s != null && s.toString().isNotEmpty) sizes.add(s.toString());
      }
    }

    return RenovationTemplateItem(
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? 'General').toString(),
      unit: (data['unit'] ?? 'pcs').toString(),
      defaultQuantity: (data['defaultQuantity'] is num)
          ? (data['defaultQuantity'] as num).toDouble()
          : double.tryParse('${data['defaultQuantity']}') ?? 1,
      qtyPerSqm: data['qtyPerSqm'] is num
          ? (data['qtyPerSqm'] as num).toDouble()
          : double.tryParse('${data['qtyPerSqm']}'),
      size: data['size']?.toString(),
      availableSizes: sizes,
      notes: data['notes']?.toString(),
      isSwappable: data['isSwappable'] == true || alts.isNotEmpty,
      alternatives: alts,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'unit': unit,
        'defaultQuantity': defaultQuantity,
        if (qtyPerSqm != null) 'qtyPerSqm': qtyPerSqm,
        if (size != null && size!.isNotEmpty) 'size': size,
        if (availableSizes.isNotEmpty) 'availableSizes': availableSizes,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'isSwappable': isSwappable,
        if (alternatives.isNotEmpty)
          'alternatives': alternatives.map((e) => e.toMap()).toList(),
      };

  RenovationTemplateItem copyWith({
    String? name,
    String? category,
    String? unit,
    double? defaultQuantity,
    double? qtyPerSqm,
    String? size,
    List<String>? availableSizes,
    String? notes,
    bool? isSwappable,
    List<MaterialAlternative>? alternatives,
  }) {
    return RenovationTemplateItem(
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      defaultQuantity: defaultQuantity ?? this.defaultQuantity,
      qtyPerSqm: qtyPerSqm ?? this.qtyPerSqm,
      size: size ?? this.size,
      availableSizes: availableSizes ?? this.availableSizes,
      notes: notes ?? this.notes,
      isSwappable: isSwappable ?? this.isSwappable,
      alternatives: alternatives ?? this.alternatives,
    );
  }
}

class RenovationTemplate {
  final String id;
  final String renovationType;

  /// Cosmetic, structural or functional. One template exists for each type a
  /// project offers.
  final RenovationScope scope;
  final String name;
  final String description;
  final List<RenovationTemplateItem> items;

  /// The work items ticked to build this list, when it was built from a
  /// [WorkCatalogue]. Empty for a template chosen by its type alone.
  ///
  /// A list built from work items holds exactly the work ticked, so measuring
  /// the room sizes its lines but never adds one back.
  final List<String> workItemIds;

  bool get isFromWorkItems => workItemIds.isNotEmpty;

  const RenovationTemplate({
    required this.id,
    required this.renovationType,
    this.scope = RenovationScope.cosmetic,
    required this.name,
    required this.description,
    required this.items,
    this.workItemIds = const [],
  });

  factory RenovationTemplate.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = <RenovationTemplateItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(
            RenovationTemplateItem.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawWork = data['workItemIds'];
    return RenovationTemplate(
      id: id,
      renovationType: (data['renovationType'] ?? '').toString(),
      scope: RenovationScope.fromString(data['scope']?.toString()),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      items: items,
      workItemIds: rawWork is List
          ? [for (final w in rawWork) if (w != null) w.toString()]
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'renovationType': renovationType,
        'scope': scope.label,
        'name': name,
        'description': description,
        'items': items.map((e) => e.toMap()).toList(),
        if (workItemIds.isNotEmpty) 'workItemIds': workItemIds,
      };

  RenovationTemplate copyWithItems(List<RenovationTemplateItem> newItems) {
    return RenovationTemplate(
      id: id,
      renovationType: renovationType,
      scope: scope,
      name: name,
      description: description,
      items: newItems,
      workItemIds: workItemIds,
    );
  }
}

/// Built-in templates: one material list for each project and renovation type.
///
/// A template is a starting list, not a survey. Quantities come later, from
/// the measured room or the entered area, and the builder can still remove any
/// line before requesting quotations.
class RenovationTemplatesCatalog {
  RenovationTemplatesCatalog._();

  /// The projects offered on the home screen, in the same order.
  static const List<String> projectTypes = [
    'Bathroom Renovation',
    'Kitchen Renovation',
    'Floor Renovation',
    'Roof Repair',
    'Interior Painting',
    'Living Room Renovation',
    'Bedroom Renovation',
    'Laundry Renovation',
    'Dining Room Renovation',
    'Wall Finishing',
  ];

  static String normalizeType(String renovationType) {
    return renovationType
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _key(String renovationType) =>
      normalizeType(renovationType).toLowerCase();

  /// Painting has nothing structural or functional to change, and a floor or a
  /// wall on its own has no plumbing or wiring. Every other project can be any
  /// of the three.
  static const Map<String, List<RenovationScope>> _scopesByType = {
    'floor renovation': [RenovationScope.cosmetic, RenovationScope.structural],
    'wall finishing': [RenovationScope.cosmetic, RenovationScope.structural],
    'interior painting': [RenovationScope.cosmetic],
  };

  /// The renovation types [renovationType] can be.
  static List<RenovationScope> scopesFor(String renovationType) =>
      _scopesByType[_key(renovationType)] ?? RenovationScope.values;

  static bool offers(String renovationType, RenovationScope scope) =>
      scopesFor(renovationType).contains(scope);

  /// Why [scope] is not offered for [renovationType].
  static String unavailableReason(
    String renovationType,
    RenovationScope scope,
  ) {
    final type = normalizeType(renovationType);
    return switch (scope) {
      RenovationScope.structural => '$type does not change the structure.',
      RenovationScope.functional => '$type has no plumbing or wiring to upgrade.',
      RenovationScope.cosmetic => '$type is not a finishing job.',
    };
  }

  /// The kind of work pre-selected for [renovationType]; the builder can add
  /// others. A roof repair is structural by default because re-sheeting and
  /// purlin work are what it usually is. Everything else starts cosmetic,
  /// which is the most common job and the only kind every project offers.
  static RenovationScope defaultTypeFor(String renovationType) {
    final offered = scopesFor(renovationType);
    final preferred = _key(renovationType).contains('roof')
        ? RenovationScope.structural
        : RenovationScope.cosmetic;
    return offered.contains(preferred) ? preferred : offered.first;
  }

  /// Every project can be done whole or in part. Only a project that can gain
  /// floor area can be an extension: a roof repair, a floor, a paint job and a
  /// wall finish all work on a room that is already there.
  static const Map<String, List<RenovationCoverage>> _coveragesByType = {
    'floor renovation': [RenovationCoverage.full, RenovationCoverage.partial],
    'wall finishing': [RenovationCoverage.full, RenovationCoverage.partial],
    'interior painting': [RenovationCoverage.full, RenovationCoverage.partial],
    'roof repair': [RenovationCoverage.full, RenovationCoverage.partial],
  };

  /// How much of the space [renovationType] can cover.
  static List<RenovationCoverage> coveragesFor(String renovationType) =>
      _coveragesByType[_key(renovationType)] ?? RenovationCoverage.values;

  static bool offersCoverage(
    String renovationType,
    RenovationCoverage coverage,
  ) =>
      coveragesFor(renovationType).contains(coverage);

  /// Why [coverage] is not offered for [renovationType].
  static String unavailableCoverageReason(
    String renovationType,
    RenovationCoverage coverage,
  ) {
    final type = normalizeType(renovationType);
    return switch (coverage) {
      RenovationCoverage.extension => '$type does not add floor area.',
      RenovationCoverage.partial => '$type is not done in parts.',
      RenovationCoverage.full => '$type is not done whole.',
    };
  }

  /// The template for [renovationType] done as a [scope] renovation.
  static RenovationTemplate forProject(
    String renovationType,
    RenovationScope scope,
  ) {
    final type = normalizeType(renovationType).isEmpty
        ? 'Renovation'
        : normalizeType(renovationType);
    final key = type.toLowerCase();
    return RenovationTemplate(
      id: '${_idPrefix(type)}_${scope.name}',
      renovationType: type,
      scope: scope,
      name: '${scope.label} ${_shortType(type)}',
      description: _descriptionFor(key, scope),
      items: _itemsFor(key, scope),
    );
  }

  /// The template for [renovationType] covering every kind of work in [types].
  ///
  /// Each kind already has its own list, so a combination is those lists put
  /// together: a cosmetic-and-functional bathroom gets the tiles and paint of
  /// the one and the pipes of the other. A material both lists carry — the
  /// finishes a structural job re-lays, say — appears once, where it first
  /// appears, so it is never ordered twice. A single kind returns exactly the
  /// template [forProject] would.
  static RenovationTemplate forProjectTypes(
    String renovationType,
    RenovationTypes types,
  ) {
    if (!types.isMultiple) return forProject(renovationType, types.primary);

    final parts = [
      for (final scope in types.values) forProject(renovationType, scope),
    ];
    final seen = <String>{};
    final items = <RenovationTemplateItem>[
      for (final part in parts)
        for (final item in part.items)
          if (seen.add(item.name.trim().toLowerCase())) item,
    ];
    final type = parts.first.renovationType;
    return RenovationTemplate(
      id: '${_idPrefix(type)}_${types.names.join('_')}',
      renovationType: type,
      scope: types.primary,
      name: '${types.label} ${_shortType(type)}',
      description: parts.map((p) => p.description).join(' '),
      items: items,
    );
  }

  /// The work items [renovationType] is estimated from, or `null` for a
  /// project still estimated from its whole template.
  static WorkCatalogue? workCatalogueFor(String renovationType) =>
      _key(renovationType).contains('bath') ? _bathroomWork : null;

  /// Every template the app offers.
  static List<RenovationTemplate> get allTemplates => [
        for (final type in projectTypes)
          for (final scope in scopesFor(type)) forProject(type, scope),
      ];

  static String _idPrefix(String renovationType) {
    return renovationType
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// "Kitchen Renovation" → "Kitchen", "Roof Repair" → "Roof".
  static String _shortType(String renovationType) {
    final trimmed = renovationType
        .replaceAll(
          RegExp(r'\b(renovation|repair|installation)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return trimmed.isEmpty ? renovationType : trimmed;
  }

  static const String _engineerNote =
      'Walls, slab and reinforcement for a changed layout or a bigger room. '
      'Structural work, including foundation repair and underpinning, follows a '
      'plan signed by a licensed civil engineer; footings, columns and beams '
      'come from that plan.';

  static const String _electricianNote =
      'Wiring, devices and a breaker for the room. Electrical work is done by a '
      'licensed electrician to the Philippine Electrical Code.';

  static String _descriptionFor(String key, RenovationScope scope) {
    if (key.contains('roof')) {
      return switch (scope) {
        RenovationScope.cosmetic =>
          'Repaint and reseal an existing metal roof.',
        RenovationScope.structural =>
          'Replace the roofing sheets and purlins. Trusses and rafters come from '
              'the structural plan.',
        RenovationScope.functional =>
          'New gutters and downspouts to carry rainwater off the roof.',
      };
    }
    if (key.contains('floor')) {
      return scope == RenovationScope.structural
          ? 'Break out and recast a damaged or uneven floor slab, then retile.'
          : 'Retile the floor and replace the skirting.';
    }
    if (key.contains('paint')) {
      return 'Skim coat, primer and two coats of paint on walls and ceiling.';
    }
    if (key.contains('wall')) {
      return scope == RenovationScope.structural
          ? 'Rebuild or add a CHB wall, then plaster and paint it. $_engineerNote'
          : 'Skim coat, primer and paint, with wall tiles if you choose them.';
    }
    final wet = key.contains('bath') || key.contains('laundry');
    return switch (scope) {
      RenovationScope.cosmetic => wet
          ? 'New tiles, waterproofing, paint and fixtures.'
          : key.contains('kitchen')
              ? 'New tiles, backsplash, countertop, paint and sink.'
              : 'New floor tiles, skirting and paint.',
      RenovationScope.structural => _engineerNote,
      RenovationScope.functional => key.contains('bath')
          ? 'New water supply and drainage lines for one water closet, one '
              'lavatory and one shower.'
          : key.contains('kitchen') || key.contains('laundry')
              ? 'New water and drain lines, plus wiring for appliances. '
                  '$_electricianNote'
              : _electricianNote,
    };
  }

  static List<RenovationTemplateItem> _itemsFor(
    String key,
    RenovationScope scope,
  ) {
    if (key.contains('roof')) {
      return switch (scope) {
        RenovationScope.cosmetic => _roofRepaint,
        RenovationScope.structural => _roofReplacement,
        RenovationScope.functional => _roofDrainage,
      };
    }
    if (key.contains('floor')) {
      return scope == RenovationScope.structural
          ? _floorSlabRepair
          : const [_floorTile, _skirting];
    }
    if (key.contains('paint')) return _painting;
    if (key.contains('wall')) {
      return scope == RenovationScope.structural
          ? const [..._newWalls, _skimCoat, _primer, _paint]
          : const [_skimCoat, _primer, _paint, _maskingTape];
    }
    if (key.contains('bath')) {
      return switch (scope) {
        RenovationScope.cosmetic => const [
            ..._wetFinishes,
            _waterCloset,
            _lavatory,
            _showerSet,
          ],
        RenovationScope.structural => const [..._newRoom, ..._wetFinishes],
        RenovationScope.functional => _bathroomPlumbing,
      };
    }
    if (key.contains('laundry')) {
      return switch (scope) {
        RenovationScope.cosmetic => _wetFinishes,
        RenovationScope.structural => const [..._newRoom, ..._wetFinishes],
        RenovationScope.functional => const [
            ..._laundryPlumbing,
            ..._roomWiring,
          ],
      };
    }
    if (key.contains('kitchen')) {
      return switch (scope) {
        RenovationScope.cosmetic => const [
            _floorTile,
            _backsplashTile,
            _countertop,
            _primer,
            _paint,
            _kitchenSink,
            _sinkFaucet,
          ],
        RenovationScope.structural => const [
            ..._newRoom,
            _floorTile,
            _backsplashTile,
            _primer,
            _paint,
          ],
        RenovationScope.functional => const [
            ..._kitchenPlumbing,
            ..._roomWiring,
            ..._kitchenAppliances,
          ],
      };
    }
    // Living room, bedroom, dining room, and any other room.
    return switch (scope) {
      RenovationScope.cosmetic => _dryFinishes,
      RenovationScope.structural => const [
          ..._newRoom,
          _floorTile,
          _skimCoat,
          _primer,
          _paint,
        ],
      RenovationScope.functional => _roomWiring,
    };
  }

  // ── Finishes ─────────────────────────────────────────────────────────────

  static const _floorTile = RenovationTemplateItem(
    name: 'Ceramic Floor Tiles',
    category: 'Floor Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '600x600',
  );

  static const _nonSlipFloorTile = RenovationTemplateItem(
    name: 'Non-Slip Floor Tiles',
    category: 'Floor Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '300x300',
    notes: 'Non-slip for a wet floor',
  );

  static const _wallTile = RenovationTemplateItem(
    name: 'Ceramic Wall Tiles',
    category: 'Wall Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '300x600',
  );

  static const _backsplashTile = RenovationTemplateItem(
    name: 'Subway Wall Tiles',
    category: 'Wall Surface',
    unit: 'pcs',
    defaultQuantity: 1,
    size: '75x300',
    notes: 'Backsplash along the counter',
  );

  static const _waterproofing = RenovationTemplateItem(
    name: 'Cementitious Waterproofing',
    category: 'Waterproofing',
    unit: 'L',
    defaultQuantity: 1,
    qtyPerSqm: 0.8,
    notes: 'Two coats on the floor and a 0.30 m upturn',
  );

  static const _skimCoat = RenovationTemplateItem(
    name: 'Skim Coat (20 kg)',
    category: 'Wall Finishing',
    unit: 'bags',
    defaultQuantity: 1,
  );

  static const _primer = RenovationTemplateItem(
    name: 'Concrete Primer (4 L)',
    category: 'Wall Finishing',
    unit: 'gal',
    defaultQuantity: 1,
  );

  static const _paint = RenovationTemplateItem(
    name: 'Interior Latex Paint (4 L)',
    category: 'Wall Finishing',
    unit: 'gal',
    defaultQuantity: 1,
  );

  static const _maskingTape = RenovationTemplateItem(
    name: 'Masking Tape (1")',
    category: 'Painting Supplies',
    unit: 'rolls',
    defaultQuantity: 3,
  );

  static const _skirting = RenovationTemplateItem(
    name: 'Skirting',
    category: 'Floor Finishing',
    unit: 'lm',
    defaultQuantity: 1,
    qtyPerSqm: 1.2,
  );

  static const _countertop = RenovationTemplateItem(
    name: 'Granite Countertop',
    category: 'Countertops',
    unit: 'sqm',
    defaultQuantity: 1,
    qtyPerSqm: 0.25,
  );

  static const _wetFinishes = [
    _nonSlipFloorTile,
    _wallTile,
    _waterproofing,
    _primer,
    _paint,
  ];

  static const _dryFinishes = [
    _floorTile,
    _skirting,
    _skimCoat,
    _primer,
    _paint,
    _maskingTape,
  ];

  static const _painting = [
    _skimCoat,
    _primer,
    _paint,
    _maskingTape,
    RenovationTemplateItem(
      name: 'Paint Brush (2")',
      category: 'Painting Supplies',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
  ];

  // ── Fixtures ─────────────────────────────────────────────────────────────

  static const _waterCloset = RenovationTemplateItem(
    name: 'Water Closet (Two-piece)',
    category: 'Plumbing Fixtures',
    unit: 'set',
    defaultQuantity: 1,
  );

  static const _lavatory = RenovationTemplateItem(
    name: 'Lavatory with Pedestal',
    category: 'Plumbing Fixtures',
    unit: 'set',
    defaultQuantity: 1,
  );

  static const _showerSet = RenovationTemplateItem(
    name: 'Shower Set',
    category: 'Plumbing Fixtures',
    unit: 'set',
    defaultQuantity: 1,
  );

  static const _kitchenSink = RenovationTemplateItem(
    name: 'Stainless Kitchen Sink (Single Bowl)',
    category: 'Plumbing Fixtures',
    unit: 'pcs',
    defaultQuantity: 1,
  );

  static const _sinkFaucet = RenovationTemplateItem(
    name: 'Sink Faucet (Gooseneck)',
    category: 'Plumbing Fixtures',
    unit: 'pcs',
    defaultQuantity: 1,
  );

  // ── Structure ────────────────────────────────────────────────────────────

  static const _newWalls = [
    RenovationTemplateItem(
      name: 'Concrete Hollow Block (CHB)',
      category: 'Masonry',
      unit: 'pcs',
      defaultQuantity: 1,
      size: '4"',
      notes: 'New or rebuilt walls',
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

  static const _slabCement = RenovationTemplateItem(
    name: 'Portland Cement - Slab (40 kg)',
    category: 'Concrete Slab',
    unit: 'bags',
    defaultQuantity: 1,
    notes: 'Class A 1:2:4 concrete, 100 mm slab on grade',
  );

  static const _slabSand = RenovationTemplateItem(
    name: 'Washed Sand - Slab',
    category: 'Concrete Slab',
    unit: 'cu.m',
    defaultQuantity: 1,
    notes: 'Class A 1:2:4 concrete, 100 mm slab on grade',
  );

  static const _gravel = RenovationTemplateItem(
    name: 'Crushed Gravel 3/4"',
    category: 'Concrete Slab',
    unit: 'cu.m',
    defaultQuantity: 1,
    notes: 'Class A 1:2:4 concrete, 100 mm slab on grade',
  );

  static const _formwork = [
    RenovationTemplateItem(
      name: 'Marine Plywood 1/2" (4\'x8\')',
      category: 'Formwork',
      unit: 'sheets',
      defaultQuantity: 2,
      qtyPerSqm: 0.2,
      notes: 'Forms for slab edges, lintels and columns',
    ),
    RenovationTemplateItem(
      name: 'Coco Lumber (2"x2" & 2"x3")',
      category: 'Formwork',
      unit: 'bd.ft',
      defaultQuantity: 30,
      qtyPerSqm: 2.5,
      notes: 'Form joists and shoring',
    ),
    RenovationTemplateItem(
      name: 'Common Wire Nails (CWN Assorted)',
      category: 'Formwork',
      unit: 'kg',
      defaultQuantity: 2,
      qtyPerSqm: 0.15,
      notes: 'Formwork assembly',
    ),
  ];

  /// New walls, a new slab and the forms for them: a bigger room or a
  /// changed layout.
  static const _newRoom = [
    ..._newWalls,
    _slabCement,
    _slabSand,
    _gravel,
    ..._formwork,
  ];

  static const _floorSlabRepair = [
    _slabCement,
    _slabSand,
    _gravel,
    RenovationTemplateItem(
      name: 'Welded Mesh Reinforcement 6"x6" (Ga.10)',
      category: 'Slab Reinforcement',
      unit: 'sqm',
      defaultQuantity: 1,
      qtyPerSqm: 1.1,
      notes: 'Laid mid-depth in the new slab, with a 150 mm lap',
    ),
    _floorTile,
    _skirting,
  ];

  // ── Roof ─────────────────────────────────────────────────────────────────

  static const _roofSealant = RenovationTemplateItem(
    name: 'Roof Sealant (1 L can)',
    category: 'Roofing',
    unit: 'cans',
    defaultQuantity: 1,
  );

  static const _metalPrimer = RenovationTemplateItem(
    name: 'Metal Primer (Red Oxide, 4 L)',
    category: 'Roof Painting',
    unit: 'gal',
    defaultQuantity: 1,
  );

  static const _roofRepaint = [
    _metalPrimer,
    RenovationTemplateItem(
      name: 'Roof Paint (4 L)',
      category: 'Roof Painting',
      unit: 'gal',
      defaultQuantity: 1,
    ),
    _roofSealant,
    RenovationTemplateItem(
      name: 'Steel Brush (for rust removal)',
      category: 'Painting Supplies',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
  ];

  static const _roofReplacement = [
    // Rib-type is cut to order and sold by the linear metre, so a piece count
    // with no length is not something a shop can quote.
    RenovationTemplateItem(
      name: 'Pre-painted Rib-type Roofing Ga.26',
      category: 'Roofing',
      unit: 'ln.m',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'Ridge Roll (Pre-painted)',
      category: 'Roofing',
      unit: 'ln.m',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'C-Purlin 2" x 4" x 1.5 mm (6 m length)',
      category: 'Roof Framing',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.32,
      notes: 'Purlins at 600 mm on centre',
    ),
    RenovationTemplateItem(
      name: 'Tekscrew with Rubber Washer',
      category: 'Roof Installation',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'Welding Rod 1/8" (E6013)',
      category: 'Roof Framing',
      unit: 'kg',
      defaultQuantity: 1,
      qtyPerSqm: 0.05,
    ),
    _roofSealant,
  ];

  static const _roofDrainage = [
    RenovationTemplateItem(
      name: 'Pre-painted Roof Gutter Ga.24 (3 m length)',
      category: 'Roof Drainage',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'Along both eaves',
    ),
    RenovationTemplateItem(
      name: 'Gutter Bracket',
      category: 'Roof Drainage',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'One every 0.60 m of gutter',
    ),
    RenovationTemplateItem(
      name: 'PVC Downspout Pipe 3" (3 m length)',
      category: 'Roof Drainage',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'One downspout per 9 m of gutter, one storey high',
    ),
    RenovationTemplateItem(
      name: 'PVC Downspout Elbow 3"',
      category: 'Roof Drainage',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'Two per downspout',
    ),
    RenovationTemplateItem(
      name: 'Blind Rivets 1/8" (box of 100)',
      category: 'Roof Drainage',
      unit: 'box',
      defaultQuantity: 1,
    ),
    _roofSealant,
  ];

  // ── Plumbing ─────────────────────────────────────────────────────────────

  static const _solventCement = RenovationTemplateItem(
    name: 'PVC Solvent Cement (100 cc)',
    category: 'Plumbing Supplies',
    unit: 'cans',
    defaultQuantity: 1,
  );

  static const _bathroomPlumbing = [
    ..._bathroomSupplyLines,
    ..._bathroomDrainLines,
    _solventCement,
    _bathroomTeflon,
  ];

  static const _bathroomTeflon = RenovationTemplateItem(
    name: 'Teflon Threadseal Tape (3/4")',
    category: 'Plumbing Supplies',
    unit: 'rolls',
    defaultQuantity: 3,
  );

  static const _bathroomSupplyLines = [
    RenovationTemplateItem(
      name: 'PPR Pipe 1/2" (4 m length)',
      category: 'Water Supply Pipes',
      unit: 'pcs',
      defaultQuantity: 3,
      notes: 'Cold water to the water closet, lavatory and shower',
    ),
    RenovationTemplateItem(
      name: 'PPR Elbow 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 8,
    ),
    RenovationTemplateItem(
      name: 'PPR Tee 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 3,
    ),
    RenovationTemplateItem(
      name: 'PPR Female Adapter 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 3,
    ),
    RenovationTemplateItem(
      name: 'PPR Gate Valve 1/2"',
      category: 'Valves',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'Shut-off for the whole bathroom',
    ),
    RenovationTemplateItem(
      name: 'Angle Valve 1/2"',
      category: 'Valves',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
  ];

  static const _bathroomDrainLines = [
    RenovationTemplateItem(
      name: 'PVC Sanitary Pipe 4" (3 m length)',
      category: 'Drainage Pipes',
      unit: 'pcs',
      defaultQuantity: 2,
      notes: 'Water closet to the septic line',
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Pipe 2" (3 m length)',
      category: 'Drainage Pipes',
      unit: 'pcs',
      defaultQuantity: 2,
      notes: 'Lavatory and floor drain',
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Wye 4" x 2"',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Elbow 2"',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 3,
    ),
    RenovationTemplateItem(
      name: 'Floor Drain 4" x 4" (Stainless)',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'P-Trap 1-1/4" (Lavatory)',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
  ];

  static const _kitchenPlumbing = [
    RenovationTemplateItem(
      name: 'PPR Pipe 1/2" (4 m length)',
      category: 'Water Supply Pipes',
      unit: 'pcs',
      defaultQuantity: 2,
      notes: 'Cold water to the sink',
    ),
    RenovationTemplateItem(
      name: 'PPR Elbow 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 6,
    ),
    RenovationTemplateItem(
      name: 'PPR Tee 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
    RenovationTemplateItem(
      name: 'PPR Female Adapter 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
    RenovationTemplateItem(
      name: 'Angle Valve 1/2"',
      category: 'Valves',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Pipe 2" (3 m length)',
      category: 'Drainage Pipes',
      unit: 'pcs',
      defaultQuantity: 2,
      notes: 'Sink drain to the grease trap',
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Elbow 2"',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 3,
    ),
    RenovationTemplateItem(
      name: 'P-Trap 1-1/2" (Sink)',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    _solventCement,
    RenovationTemplateItem(
      name: 'Teflon Threadseal Tape (3/4")',
      category: 'Plumbing Supplies',
      unit: 'rolls',
      defaultQuantity: 2,
    ),
  ];

  static const _laundryPlumbing = [
    RenovationTemplateItem(
      name: 'PPR Pipe 1/2" (4 m length)',
      category: 'Water Supply Pipes',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'Cold water to the washing machine',
    ),
    RenovationTemplateItem(
      name: 'PPR Elbow 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 4,
    ),
    RenovationTemplateItem(
      name: 'PPR Female Adapter 1/2"',
      category: 'Water Supply Fittings',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'Hose Bibb Faucet 1/2"',
      category: 'Plumbing Fixtures',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Pipe 2" (3 m length)',
      category: 'Drainage Pipes',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'PVC Sanitary Elbow 2"',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 2,
    ),
    RenovationTemplateItem(
      name: 'Floor Drain 4" x 4" (Stainless)',
      category: 'Drainage Fittings',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    _solventCement,
  ];

  // ── Electrical ───────────────────────────────────────────────────────────

  static const _roomWiring = [
    RenovationTemplateItem(
      name: 'THHN Stranded Wire 3.5 mm² (#12)',
      category: 'Wiring',
      unit: 'm',
      defaultQuantity: 1,
      qtyPerSqm: 3.0,
      notes: 'Convenience outlet circuit, line and neutral',
    ),
    RenovationTemplateItem(
      name: 'THHN Stranded Wire 2.0 mm² (#14)',
      category: 'Wiring',
      unit: 'm',
      defaultQuantity: 1,
      qtyPerSqm: 2.0,
      notes: 'Lighting circuit, line and neutral',
    ),
    RenovationTemplateItem(
      name: 'PVC Electrical Conduit 1/2" (3 m length)',
      category: 'Wiring',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.5,
    ),
    RenovationTemplateItem(
      name: 'PVC Conduit Coupling 1/2"',
      category: 'Wiring',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.5,
    ),
    RenovationTemplateItem(
      name: 'Utility Box 2" x 4"',
      category: 'Wiring Devices',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.35,
    ),
    RenovationTemplateItem(
      name: 'Duplex Convenience Outlet',
      category: 'Wiring Devices',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.25,
    ),
    RenovationTemplateItem(
      name: 'One-Gang Light Switch',
      category: 'Wiring Devices',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.1,
    ),
    RenovationTemplateItem(
      name: 'LED Ceiling Light (12 W)',
      category: 'Lighting',
      unit: 'pcs',
      defaultQuantity: 1,
      qtyPerSqm: 0.12,
    ),
    RenovationTemplateItem(
      name: 'Circuit Breaker 20 A (Plug-in)',
      category: 'Wiring Devices',
      unit: 'pcs',
      defaultQuantity: 1,
    ),
    RenovationTemplateItem(
      name: 'Electrical Tape',
      category: 'Wiring',
      unit: 'rolls',
      defaultQuantity: 2,
    ),
  ];

  static const _kitchenAppliances = [
    RenovationTemplateItem(
      name: 'THHN Stranded Wire 5.5 mm² (#10)',
      category: 'Wiring',
      unit: 'm',
      defaultQuantity: 1,
      qtyPerSqm: 1.5,
      notes: 'Dedicated circuit for the range or oven',
    ),
    RenovationTemplateItem(
      name: 'Circuit Breaker 30 A (Plug-in)',
      category: 'Wiring Devices',
      unit: 'pcs',
      defaultQuantity: 1,
      notes: 'Range or oven circuit',
    ),
  ];
}
