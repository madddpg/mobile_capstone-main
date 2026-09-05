/// Pre-defined renovation BOM templates used as **references** for planning.
///
/// Templates hold basic essential materials. Quantities scale from project area
/// (sqm). Swappable slots (e.g. tiles) expose alternatives the builder can pick.
library;

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
  final String style;
  final String name;
  final String description;
  final List<RenovationTemplateItem> items;
  final int order;
  final String? imageAsset;
  final String? imageUrl;

  const RenovationTemplate({
    required this.id,
    required this.renovationType,
    required this.style,
    required this.name,
    required this.description,
    required this.items,
    this.order = 1,
    this.imageAsset,
    this.imageUrl,
  });

  factory RenovationTemplate.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = <RenovationTemplateItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(RenovationTemplateItem.fromMap(item));
        } else if (item is Map) {
          items.add(
            RenovationTemplateItem.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return RenovationTemplate(
      id: id,
      renovationType: (data['renovationType'] ?? '').toString(),
      style: (data['style'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      items: items,
      order: (data['order'] is num) ? (data['order'] as num).toInt() : 1,
      imageAsset: data['imageAsset']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'renovationType': renovationType,
        'style': style,
        'name': name,
        'name_lower': name.toLowerCase(),
        'description': description,
        'isActive': true,
        'order': order,
        'items': items.map((e) => e.toMap()).toList(),
        if (imageAsset != null && imageAsset!.isNotEmpty) 'imageAsset': imageAsset,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      };

  RenovationTemplate copyWithItems(List<RenovationTemplateItem> newItems) {
    return RenovationTemplate(
      id: id,
      renovationType: renovationType,
      style: style,
      name: name,
      description: description,
      items: newItems,
      order: order,
      imageAsset: imageAsset,
      imageUrl: imageUrl,
    );
  }

  /// Returns a copy with [imageAsset] filled in when the template carries no
  /// artwork of its own. A template that already has a bundled asset, or a
  /// remote [imageUrl] from Firestore, is returned untouched — a curated photo
  /// always wins over the generic one for its type.
  ///
  /// Passing `null` is a no-op, so a renovation type with no bundled photo
  /// keeps an empty image slot and the picker renders its labelled card.
  RenovationTemplate withReferenceAsset(String? asset) {
    if (asset == null || asset.trim().isEmpty) return this;
    if (imageAsset != null && imageAsset!.trim().isNotEmpty) return this;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return this;
    return RenovationTemplate(
      id: id,
      renovationType: renovationType,
      style: style,
      name: name,
      description: description,
      items: items,
      order: order,
      imageAsset: asset,
      imageUrl: imageUrl,
    );
  }
}

/// Built-in essential templates — reference packages only.
class RenovationTemplatesCatalog {
  RenovationTemplatesCatalog._();

  /// The three reference styles offered for every renovation type.
  static const List<String> styles = ['modern', 'minimalist', 'traditional'];

  static String normalizeType(String renovationType) {
    return renovationType
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Maps any free-form style label onto one of [styles].
  static String styleKey(String style) {
    final value = style.toLowerCase().trim();
    if (value.contains('minimal') || value.contains('basic')) {
      return 'minimalist';
    }
    if (value.contains('tradition') ||
        value.contains('classic') ||
        value.contains('standard')) {
      return 'traditional';
    }
    return 'modern';
  }

  static String styleLabel(String style) {
    final key = styleKey(style);
    return '${key[0].toUpperCase()}${key.substring(1)}';
  }

  /// Bundled reference photo for a renovation type + style, or `null`.
  ///
  /// This used to return a `loremflickr.com` link, which is a *random* stock
  /// photo service keyed on loose tags. It put park scenery and unrelated
  /// interiors on the template picker, needed a live connection, and returned
  /// something different as the service's pool changed. A planning tool cannot
  /// show a photo that does not match the job it claims to describe.
  ///
  /// Now it only ever returns a real bundled asset. A type with no photo yet
  /// returns `null`, and the picker draws its labelled card instead — an
  /// honest blank beats a misleading picture.
  ///
  /// To add one: drop a photo at
  /// `assets/images/templates/<type>_<style>.png` and add the key below.
  /// `<type>` is the lower-cased first word of the renovation type
  /// ("Laundry Renovation" -> `laundry`), `<style>` is modern, minimalist or
  /// traditional. The folder is already declared in pubspec.yaml, so no
  /// pubspec change is needed.
  static const Set<String> _bundledTemplatePhotos = {
    'bathroom_modern',
    'bathroom_minimalist',
    'bathroom_traditional',
    'kitchen_modern',
    'kitchen_minimalist',
    'kitchen_traditional',
  };

  /// Photo key for a renovation type: the first meaningful word, lower-cased.
  /// "Laundry Renovation" -> laundry, "Roof Repair" -> roof.
  static String photoKeyForType(String renovationType) {
    final t = normalizeType(renovationType).toLowerCase();
    if (t.contains('kitchen')) return 'kitchen';
    if (t.contains('bath') || t.contains('toilet') || t.contains('cr')) {
      return 'bathroom';
    }
    if (t.contains('laundry')) return 'laundry';
    if (t.contains('living')) return 'living';
    if (t.contains('bedroom')) return 'bedroom';
    if (t.contains('dining')) return 'dining';
    if (t.contains('floor')) return 'floor';
    if (t.contains('roof')) return 'roof';
    if (t.contains('paint')) return 'painting';
    if (t.contains('wall')) return 'wall';
    if (t.contains('electric') || t.contains('wiring')) return 'electrical';
    if (t.contains('plumb') || t.contains('pipe')) return 'plumbing';
    return 'general';
  }

  static String? referenceAssetFor(String renovationType, String style) {
    final key = '${photoKeyForType(renovationType)}_${styleKey(style)}';
    if (!_bundledTemplatePhotos.contains(key)) return null;
    return 'assets/images/templates/$key.png';
  }

  static List<RenovationTemplate> forType(String renovationType) {
    final label = normalizeType(renovationType);
    final key = label.toLowerCase();
    final matched = allTemplates
        .where((t) => t.renovationType.toLowerCase() == key)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (matched.isNotEmpty) return matched;

    // Match "Bathroom" → "Bathroom Renovation", etc.
    final loose = allTemplates
        .where((t) {
          final type = t.renovationType.toLowerCase();
          return type.contains(key) || key.contains(type.split(' ').first);
        })
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (loose.isNotEmpty) return loose;

    return _generalFor(label.isEmpty ? 'Renovation' : label);
  }

  /// Exactly three templates for [renovationType] — one per entry in [styles].
  static List<RenovationTemplate> threeForType(String renovationType) {
    return threeFrom(forType(renovationType), renovationType);
  }

  /// Normalizes [candidates] into one template per style, in [styles] order.
  ///
  /// Earlier candidates win, so callers can pass remote templates ahead of the
  /// built-in ones. Missing styles are derived from whatever is available so the
  /// picker always offers the same three choices.
  static List<RenovationTemplate> threeFrom(
    List<RenovationTemplate> candidates,
    String renovationType,
  ) {
    final label = normalizeType(renovationType);
    final byStyle = <String, RenovationTemplate>{};
    final spares = <RenovationTemplate>[];

    for (final template in candidates) {
      if (template.items.isEmpty) continue;
      final key = styleKey(template.style);
      if (byStyle.containsKey(key)) {
        spares.add(template);
      } else {
        byStyle[key] = template;
      }
    }

    final pool = byStyle.values.toList()..addAll(spares);
    if (pool.isEmpty) {
      pool.addAll(_generalFor(label.isEmpty ? 'Renovation' : label));
      for (final template in pool) {
        byStyle.putIfAbsent(styleKey(template.style), () => template);
      }
    }

    final result = <RenovationTemplate>[];
    for (var i = 0; i < styles.length; i++) {
      final style = styles[i];
      final existing = byStyle[style];
      final base =
          existing ?? (spares.isNotEmpty ? spares.first : pool.first);
      if (existing == null) {
        spares.remove(base);
      }
      result.add(_asStyle(base, style, label, i + 1));
    }
    return result;
  }

  static RenovationTemplate _asStyle(
    RenovationTemplate base,
    String style,
    String renovationType,
    int order,
  ) {
    final type = renovationType.isEmpty ? base.renovationType : renovationType;
    if (styleKey(base.style) == style &&
        base.renovationType == type &&
        base.order == order) {
      return base;
    }

    final renamed = styleKey(base.style) != style;
    return RenovationTemplate(
      id: renamed ? '${_idPrefix(type)}_$style' : base.id,
      renovationType: type,
      style: style,
      name: renamed ? '${styleLabel(style)} ${_shortType(type)}' : base.name,
      description: renamed
          ? '${styleLabel(style)} take on the essentials — reference only.'
          : base.description,
      items: base.items,
      order: order,
      imageAsset:
          renamed ? referenceAssetFor(type, style) : base.imageAsset,
      imageUrl: renamed ? null : base.imageUrl,
    );
  }

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

  /// Last-resort package for renovation types without a curated template.
  static List<RenovationTemplate> _generalFor(String renovationType) {
    const items = [
      RenovationTemplateItem(
        name: 'Floor Tiles',
        category: 'Floor Surface',
        unit: 'sqm',
        defaultQuantity: 1,
        qtyPerSqm: 1.0,
        isSwappable: true,
        alternatives: _tileAlts,
      ),
      RenovationTemplateItem(
        name: 'Portland Cement',
        category: 'Masonry',
        unit: 'bags',
        defaultQuantity: 1,
        qtyPerSqm: 0.5,
      ),
      RenovationTemplateItem(
        name: 'Washed Sand',
        category: 'Masonry',
        unit: 'cu.m',
        defaultQuantity: 1,
        qtyPerSqm: 0.05,
      ),
      RenovationTemplateItem(
        name: 'Interior Paint',
        category: 'Wall Finishing',
        unit: 'gal',
        defaultQuantity: 1,
        qtyPerSqm: 0.1,
      ),
      RenovationTemplateItem(
        name: 'Assorted Fasteners',
        category: 'Installation',
        unit: 'box',
        defaultQuantity: 1,
      ),
    ];

    final prefix = _idPrefix(renovationType);
    final short = _shortType(renovationType);

    return [
      for (var i = 0; i < styles.length; i++)
        RenovationTemplate(
          id: '${prefix}_${styles[i]}',
          renovationType: renovationType,
          style: styles[i],
          name: '${styleLabel(styles[i])} $short',
          description: 'Essential materials package — reference only.',
          items: items,
          order: i + 1,
          imageAsset: referenceAssetFor(renovationType, styles[i]),
        ),
    ];
  }

  static List<RenovationTemplate> get allTemplates => [
        ..._kitchen,
        ..._bathroom,
        ..._floor,
        ..._roof,
        ..._painting,
        ..._electrical,
        ..._plumbing,
      ]
          .map((t) => t.withReferenceAsset(
                referenceAssetFor(t.renovationType, t.style),
              ))
          .toList();

  static const _tileAlts = [
    MaterialAlternative(name: 'Ceramic Floor Tiles', size: '600x600'),
    MaterialAlternative(name: 'Porcelain Floor Tiles', size: '600x600'),
    MaterialAlternative(name: 'Vinyl Flooring Planks'),
    MaterialAlternative(name: 'Non-Slip Floor Tiles', size: '300x300'),
  ];

  static const _wallTileAlts = [
    MaterialAlternative(name: 'Subway Wall Tiles', size: '75x300'),
    MaterialAlternative(name: 'Ceramic Wall Tiles', size: '300x600'),
    MaterialAlternative(name: 'Large-format Wall Tiles', size: '600x1200'),
  ];

  static const _kitchen = [
    RenovationTemplate(
      id: 'kitchen_modern',
      renovationType: 'Kitchen Renovation',
      style: 'modern',
      name: 'Modern Kitchen',
      description: 'Essential modern kitchen materials — use as a reference.',
      order: 1,
      imageAsset: 'assets/images/templates/kitchen_modern.png',
      items: [
        RenovationTemplateItem(
          name: 'Floor Tiles',
          category: 'Flooring',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          size: '600x600',
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Wall Tiles (Backsplash)',
          category: 'Wall Finishing',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 0.35,
          size: '75x300',
          isSwappable: true,
          alternatives: _wallTileAlts,
        ),
        RenovationTemplateItem(
          name: 'Countertop',
          category: 'Countertops',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 0.25,
        ),
        RenovationTemplateItem(
          name: 'Base Cabinets',
          category: 'Cabinetry',
          unit: 'set',
          defaultQuantity: 1,
          qtyPerSqm: 0.3,
        ),
        RenovationTemplateItem(
          name: 'Kitchen Sink',
          category: 'Plumbing Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Faucet',
          category: 'Plumbing Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Tile Adhesive',
          category: 'Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.25,
        ),
        RenovationTemplateItem(
          name: 'Grout',
          category: 'Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.12,
        ),
      ],
    ),
    RenovationTemplate(
      id: 'kitchen_minimalist',
      renovationType: 'Kitchen Renovation',
      style: 'minimalist',
      name: 'Minimalist Kitchen',
      description: 'Lean essential package — reference for a simple kitchen.',
      order: 2,
      imageAsset: 'assets/images/templates/kitchen_minimalist.png',
      items: [
        RenovationTemplateItem(
          name: 'Vinyl Flooring',
          category: 'Flooring',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Interior Paint',
          category: 'Wall Finishing',
          unit: 'gal',
          defaultQuantity: 1,
          qtyPerSqm: 0.08,
        ),
        RenovationTemplateItem(
          name: 'Laminate Countertop',
          category: 'Countertops',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 0.22,
        ),
        RenovationTemplateItem(
          name: 'Base Cabinets',
          category: 'Cabinetry',
          unit: 'set',
          defaultQuantity: 1,
          qtyPerSqm: 0.25,
        ),
        RenovationTemplateItem(
          name: 'Kitchen Sink',
          category: 'Plumbing Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Faucet',
          category: 'Plumbing Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
      ],
    ),
    RenovationTemplate(
      id: 'kitchen_traditional',
      renovationType: 'Kitchen Renovation',
      style: 'traditional',
      name: 'Traditional Kitchen',
      description: 'Classic essential materials — reference package.',
      order: 3,
      imageAsset: 'assets/images/templates/kitchen_traditional.png',
      items: [
        RenovationTemplateItem(
          name: 'Ceramic Floor Tiles',
          category: 'Flooring',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          size: '400x400',
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Ceramic Wall Tiles',
          category: 'Wall Finishing',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 0.4,
          isSwappable: true,
          alternatives: _wallTileAlts,
        ),
        RenovationTemplateItem(
          name: 'Granite Countertop',
          category: 'Countertops',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 0.25,
        ),
        RenovationTemplateItem(
          name: 'Base Cabinets',
          category: 'Cabinetry',
          unit: 'set',
          defaultQuantity: 1,
          qtyPerSqm: 0.3,
        ),
        RenovationTemplateItem(
          name: 'Kitchen Sink',
          category: 'Plumbing Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Faucet',
          category: 'Plumbing Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Tile Adhesive',
          category: 'Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.25,
        ),
      ],
    ),
  ];

  static const _bathroom = [
    RenovationTemplate(
      id: 'bathroom_modern',
      renovationType: 'Bathroom Renovation',
      style: 'modern',
      name: 'Modern Bathroom',
      description: 'Essential wet-area materials — reference only.',
      order: 1,
      imageAsset: 'assets/images/templates/bathroom_modern.png',
      items: [
        RenovationTemplateItem(
          name: 'Floor Tiles',
          category: 'Floor Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Wall Tiles',
          category: 'Wall Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 2.2,
          isSwappable: true,
          alternatives: _wallTileAlts,
        ),
        RenovationTemplateItem(
          name: 'Waterproofing',
          category: 'Installation',
          unit: 'L',
          defaultQuantity: 1,
          qtyPerSqm: 0.8,
        ),
        RenovationTemplateItem(
          name: 'Toilet',
          category: 'Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Lavatory Sink',
          category: 'Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Shower Set',
          category: 'Fixtures',
          unit: 'set',
          defaultQuantity: 1,
        ),
      ],
    ),
    RenovationTemplate(
      id: 'bathroom_minimalist',
      renovationType: 'Bathroom Renovation',
      style: 'minimalist',
      name: 'Minimalist Bathroom',
      description: 'Basic bathroom essentials — reference package.',
      order: 2,
      imageAsset: 'assets/images/templates/bathroom_minimalist.png',
      items: [
        RenovationTemplateItem(
          name: 'Floor Tiles',
          category: 'Floor Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Wall Tiles',
          category: 'Wall Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 2.0,
          isSwappable: true,
          alternatives: _wallTileAlts,
        ),
        RenovationTemplateItem(
          name: 'Toilet',
          category: 'Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Lavatory Sink',
          category: 'Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Shower Set',
          category: 'Fixtures',
          unit: 'set',
          defaultQuantity: 1,
        ),
      ],
    ),
    RenovationTemplate(
      id: 'bathroom_traditional',
      renovationType: 'Bathroom Renovation',
      style: 'traditional',
      name: 'Traditional Bathroom',
      description: 'Standard bathroom essentials — reference package.',
      order: 3,
      imageAsset: 'assets/images/templates/bathroom_traditional.png',
      items: [
        RenovationTemplateItem(
          name: 'Ceramic Floor Tiles',
          category: 'Floor Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Ceramic Wall Tiles',
          category: 'Wall Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 2.2,
          isSwappable: true,
          alternatives: _wallTileAlts,
        ),
        RenovationTemplateItem(
          name: 'Toilet',
          category: 'Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Lavatory Sink',
          category: 'Fixtures',
          unit: 'pcs',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Shower Valve Set',
          category: 'Fixtures',
          unit: 'set',
          defaultQuantity: 1,
        ),
        RenovationTemplateItem(
          name: 'Tile Adhesive',
          category: 'Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.4,
        ),
      ],
    ),
  ];

  static const _floor = [
    RenovationTemplate(
      id: 'floor_modern',
      renovationType: 'Floor Renovation',
      style: 'modern',
      name: 'Modern Flooring',
      description: 'Essential flooring package — reference.',
      order: 1,
      items: [
        RenovationTemplateItem(
          name: 'Floor Tiles',
          category: 'Floor Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Tile Adhesive',
          category: 'Floor Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.4,
        ),
        RenovationTemplateItem(
          name: 'Grout',
          category: 'Floor Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.15,
        ),
        RenovationTemplateItem(
          name: 'Skirting',
          category: 'Finishing',
          unit: 'lm',
          defaultQuantity: 1,
          qtyPerSqm: 1.2,
        ),
      ],
    ),
    RenovationTemplate(
      id: 'floor_minimalist',
      renovationType: 'Floor Renovation',
      style: 'minimalist',
      name: 'Minimalist Flooring',
      description: 'Basic flooring essentials — reference.',
      order: 2,
      items: [
        RenovationTemplateItem(
          name: 'Vinyl Flooring',
          category: 'Floor Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Underlayment',
          category: 'Floor Installation',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
        ),
        RenovationTemplateItem(
          name: 'Skirting',
          category: 'Finishing',
          unit: 'lm',
          defaultQuantity: 1,
          qtyPerSqm: 1.2,
        ),
      ],
    ),
    RenovationTemplate(
      id: 'floor_traditional',
      renovationType: 'Floor Renovation',
      style: 'traditional',
      name: 'Traditional Flooring',
      description: 'Standard tile flooring essentials — reference.',
      order: 3,
      items: [
        RenovationTemplateItem(
          name: 'Ceramic Floor Tiles',
          category: 'Floor Surface',
          unit: 'sqm',
          defaultQuantity: 1,
          qtyPerSqm: 1.0,
          isSwappable: true,
          alternatives: _tileAlts,
        ),
        RenovationTemplateItem(
          name: 'Tile Adhesive',
          category: 'Floor Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.4,
        ),
        RenovationTemplateItem(
          name: 'Grout',
          category: 'Floor Installation',
          unit: 'bags',
          defaultQuantity: 1,
          qtyPerSqm: 0.15,
        ),
      ],
    ),
  ];

  static const _roof = [
    RenovationTemplate(
      id: 'roof_modern',
      renovationType: 'Roof Repair',
      style: 'modern',
      name: 'Modern Roofing',
      description: 'Essential roofing materials — reference.',
      order: 1,
      items: [
        RenovationTemplateItem(name: 'Roofing Sheets', category: 'Roofing', unit: 'pcs', defaultQuantity: 12, qtyPerSqm: 0.35),
        RenovationTemplateItem(name: 'Fasteners', category: 'Installation', unit: 'box', defaultQuantity: 2),
        RenovationTemplateItem(name: 'Roof Sealant', category: 'Waterproofing', unit: 'pcs', defaultQuantity: 4),
        RenovationTemplateItem(name: 'Ridge Cap', category: 'Roofing', unit: 'pcs', defaultQuantity: 6, qtyPerSqm: 0.15),
      ],
    ),
    RenovationTemplate(
      id: 'roof_minimalist',
      renovationType: 'Roof Repair',
      style: 'minimalist',
      name: 'Minimalist Roofing',
      description: 'Basic leak-repair essentials — reference.',
      order: 2,
      items: [
        RenovationTemplateItem(name: 'Patch Sheets', category: 'Roofing', unit: 'pcs', defaultQuantity: 6),
        RenovationTemplateItem(name: 'Waterproofing Membrane', category: 'Waterproofing', unit: 'roll', defaultQuantity: 2),
        RenovationTemplateItem(name: 'Roof Sealant', category: 'Waterproofing', unit: 'pcs', defaultQuantity: 3),
      ],
    ),
    RenovationTemplate(
      id: 'roof_traditional',
      renovationType: 'Roof Repair',
      style: 'traditional',
      name: 'Traditional Roofing',
      description: 'Tile roof essentials — reference.',
      order: 3,
      items: [
        RenovationTemplateItem(name: 'Roof Tiles', category: 'Roofing', unit: 'pcs', defaultQuantity: 40, qtyPerSqm: 1.2),
        RenovationTemplateItem(name: 'Mortar Mix', category: 'Installation', unit: 'bags', defaultQuantity: 4),
        RenovationTemplateItem(name: 'Roof Sealant', category: 'Waterproofing', unit: 'pcs', defaultQuantity: 3),
      ],
    ),
  ];

  static const _painting = [
    RenovationTemplate(
      id: 'painting_modern',
      renovationType: 'Interior Painting',
      style: 'modern',
      name: 'Modern Painting',
      description: 'Essential paint package — reference.',
      order: 1,
      items: [
        RenovationTemplateItem(name: 'Primer', category: 'Paint', unit: 'gal', defaultQuantity: 1, qtyPerSqm: 0.05),
        RenovationTemplateItem(name: 'Interior Paint', category: 'Paint', unit: 'gal', defaultQuantity: 1, qtyPerSqm: 0.1),
        RenovationTemplateItem(name: 'Roller Set', category: 'Tools & Supplies', unit: 'set', defaultQuantity: 1),
        RenovationTemplateItem(name: 'Painter\'s Tape', category: 'Tools & Supplies', unit: 'pcs', defaultQuantity: 4),
      ],
    ),
    RenovationTemplate(
      id: 'painting_minimalist',
      renovationType: 'Interior Painting',
      style: 'minimalist',
      name: 'Minimalist Painting',
      description: 'Basic paint essentials — reference.',
      order: 2,
      items: [
        RenovationTemplateItem(name: 'Primer', category: 'Paint', unit: 'gal', defaultQuantity: 1, qtyPerSqm: 0.05),
        RenovationTemplateItem(name: 'Matte Interior Paint', category: 'Paint', unit: 'gal', defaultQuantity: 1, qtyPerSqm: 0.1),
        RenovationTemplateItem(name: 'Roller Set', category: 'Tools & Supplies', unit: 'set', defaultQuantity: 1),
      ],
    ),
    RenovationTemplate(
      id: 'painting_traditional',
      renovationType: 'Interior Painting',
      style: 'traditional',
      name: 'Traditional Painting',
      description: 'Standard paint essentials — reference.',
      order: 3,
      items: [
        RenovationTemplateItem(name: 'Primer', category: 'Paint', unit: 'gal', defaultQuantity: 1, qtyPerSqm: 0.05),
        RenovationTemplateItem(name: 'Interior Paint', category: 'Paint', unit: 'gal', defaultQuantity: 1, qtyPerSqm: 0.1),
        RenovationTemplateItem(name: 'Brush Set', category: 'Tools & Supplies', unit: 'set', defaultQuantity: 1),
        RenovationTemplateItem(name: 'Sandpaper Pack', category: 'Tools & Supplies', unit: 'packs', defaultQuantity: 2),
      ],
    ),
  ];

  static const _electrical = [
    RenovationTemplate(
      id: 'electrical_modern',
      renovationType: 'Electrical Installation',
      style: 'modern',
      name: 'Modern Electrical',
      description: 'Essential electrical materials — reference.',
      order: 1,
      items: [
        RenovationTemplateItem(name: 'Electrical Wire', category: 'Wiring', unit: 'm', defaultQuantity: 40, qtyPerSqm: 2.5),
        RenovationTemplateItem(name: 'Outlets', category: 'Devices', unit: 'pcs', defaultQuantity: 6, qtyPerSqm: 0.25),
        RenovationTemplateItem(name: 'Switches', category: 'Devices', unit: 'pcs', defaultQuantity: 4, qtyPerSqm: 0.15),
        RenovationTemplateItem(name: 'LED Lights', category: 'Lighting', unit: 'pcs', defaultQuantity: 4, qtyPerSqm: 0.2),
      ],
    ),
    RenovationTemplate(
      id: 'electrical_minimalist',
      renovationType: 'Electrical Installation',
      style: 'minimalist',
      name: 'Minimalist Electrical',
      description: 'Basic electrical essentials — reference.',
      order: 2,
      items: [
        RenovationTemplateItem(name: 'Electrical Wire', category: 'Wiring', unit: 'm', defaultQuantity: 30, qtyPerSqm: 2.0),
        RenovationTemplateItem(name: 'Outlets', category: 'Devices', unit: 'pcs', defaultQuantity: 4, qtyPerSqm: 0.2),
        RenovationTemplateItem(name: 'Switches', category: 'Devices', unit: 'pcs', defaultQuantity: 3, qtyPerSqm: 0.12),
        RenovationTemplateItem(name: 'Ceiling Lights', category: 'Lighting', unit: 'pcs', defaultQuantity: 3, qtyPerSqm: 0.15),
      ],
    ),
    RenovationTemplate(
      id: 'electrical_traditional',
      renovationType: 'Electrical Installation',
      style: 'traditional',
      name: 'Traditional Electrical',
      description: 'Standard electrical essentials — reference.',
      order: 3,
      items: [
        RenovationTemplateItem(name: 'Electrical Wire', category: 'Wiring', unit: 'm', defaultQuantity: 35, qtyPerSqm: 2.2),
        RenovationTemplateItem(name: 'Outlets', category: 'Devices', unit: 'pcs', defaultQuantity: 5, qtyPerSqm: 0.22),
        RenovationTemplateItem(name: 'Switches', category: 'Devices', unit: 'pcs', defaultQuantity: 4, qtyPerSqm: 0.15),
        RenovationTemplateItem(name: 'Lights', category: 'Lighting', unit: 'pcs', defaultQuantity: 4, qtyPerSqm: 0.18),
      ],
    ),
  ];

  static const _plumbing = [
    RenovationTemplate(
      id: 'plumbing_modern',
      renovationType: 'Plumbing Installation',
      style: 'modern',
      name: 'Modern Plumbing',
      description: 'Essential plumbing materials — reference.',
      order: 1,
      items: [
        RenovationTemplateItem(name: 'Pipes', category: 'Pipes', unit: 'pcs', defaultQuantity: 10, qtyPerSqm: 0.5),
        RenovationTemplateItem(name: 'Fittings', category: 'Fittings', unit: 'pcs', defaultQuantity: 20, qtyPerSqm: 1.0),
        RenovationTemplateItem(name: 'Valves', category: 'Valves', unit: 'pcs', defaultQuantity: 4),
        RenovationTemplateItem(name: 'Teflon Tape', category: 'Supplies', unit: 'pcs', defaultQuantity: 4),
      ],
    ),
    RenovationTemplate(
      id: 'plumbing_minimalist',
      renovationType: 'Plumbing Installation',
      style: 'minimalist',
      name: 'Minimalist Plumbing',
      description: 'Basic plumbing essentials — reference.',
      order: 2,
      items: [
        RenovationTemplateItem(name: 'Pipes', category: 'Pipes', unit: 'pcs', defaultQuantity: 8, qtyPerSqm: 0.4),
        RenovationTemplateItem(name: 'Fittings', category: 'Fittings', unit: 'pcs', defaultQuantity: 16, qtyPerSqm: 0.8),
        RenovationTemplateItem(name: 'Valves', category: 'Valves', unit: 'pcs', defaultQuantity: 3),
      ],
    ),
    RenovationTemplate(
      id: 'plumbing_traditional',
      renovationType: 'Plumbing Installation',
      style: 'traditional',
      name: 'Traditional Plumbing',
      description: 'Standard plumbing essentials — reference.',
      order: 3,
      items: [
        RenovationTemplateItem(name: 'PVC Pipes', category: 'Pipes', unit: 'pcs', defaultQuantity: 10, qtyPerSqm: 0.5),
        RenovationTemplateItem(name: 'PVC Fittings', category: 'Fittings', unit: 'pcs', defaultQuantity: 18, qtyPerSqm: 0.9),
        RenovationTemplateItem(name: 'Valves', category: 'Valves', unit: 'pcs', defaultQuantity: 3),
        RenovationTemplateItem(name: 'Solvent Cement', category: 'Supplies', unit: 'pcs', defaultQuantity: 2),
      ],
    ),
  ];
}
