class MaterialItem {
  final String? id;
  final String name;
  final String category;
  final String description;
  final String? kind;
  final List<String>? sizes;
  final List<String>? lengths;
  final List<String>? coverSizes;
  final String? type;
  final String imageUrl;

  /// Catalog list prices are not part of the builder experience. Always `0`
  /// in the client — shops quote privately during canvassing.
  final double price;

  final String unit;
  final String projectType;
  final String subType;
  final String shopId;
  final bool inStock;
  final String categoryId;
  final String projectId;
  final String projectName;

  const MaterialItem({
    this.id,
    required this.name,
    required this.category,
    required this.description,
    this.kind,
    this.sizes,
    this.lengths,
    this.coverSizes,
    this.type,
    this.imageUrl = '',
    this.price = 0.0,
    this.unit = 'per piece',
    this.projectType = '',
    this.subType = '',
    this.shopId = '',
    this.inStock = false,
    this.categoryId = '',
    this.projectId = '',
    this.projectName = '',
  });

  MaterialItem copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? kind,
    List<String>? sizes,
    List<String>? lengths,
    List<String>? coverSizes,
    String? type,
    String? imageUrl,
    double? price,
    String? unit,
    String? projectType,
    String? subType,
    String? shopId,
    bool? inStock,
    String? categoryId,
    String? projectId,
    String? projectName,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      sizes: sizes ?? this.sizes,
      lengths: lengths ?? this.lengths,
      coverSizes: coverSizes ?? this.coverSizes,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      projectType: projectType ?? this.projectType,
      subType: subType ?? this.subType,
      shopId: shopId ?? this.shopId,
      inStock: inStock ?? this.inStock,
      categoryId: categoryId ?? this.categoryId,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
    );
  }

  static List<String>? _asStringList(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    final list = value
        .map((e) => (e ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return list.isEmpty ? null : list;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase().trim() == 'true';
    }
    return false;
  }

  factory MaterialItem.fromJson(Map<String, dynamic> json, [String? docId]) {
    final rawType = json['type'] ?? json['placement'];
    final rawKind = json['kind'] ?? json['Kind'];
    final rawCategory = json['category']?.toString().trim() ?? '';

    final projectIdValue = json['projectId']?.toString().trim() ?? '';
    final projectTypeValue =
        json['projectType']?.toString().trim().isNotEmpty == true
        ? json['projectType'].toString().trim()
        : projectIdValue;

    return MaterialItem(
      id: docId ?? json['id']?.toString(),
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Unnamed Product',
      category: rawCategory.isEmpty ? 'Others' : rawCategory,
      description: json['description']?.toString() ?? '',
      kind: (rawKind ?? '').toString().trim().isEmpty
          ? null
          : (rawKind ?? '').toString().trim(),
      sizes: _asStringList(json['sizes']),
      lengths: _asStringList(json['lengths']),
      coverSizes: _asStringList(json['coverSizes'] ?? json['cover_sizes']),
      type: (rawType ?? '').toString().trim().isEmpty
          ? null
          : (rawType ?? '').toString().trim(),
      imageUrl:
          json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      // Deliberately ignore any catalog price from Firestore / APIs.
      price: 0,
      unit: json['unit']?.toString().trim().isNotEmpty == true
          ? json['unit'].toString().trim()
          : 'per piece',
      projectType: projectTypeValue,
      subType: json['subType']?.toString() ?? '',
      shopId: json['shopId']?.toString() ?? '',
      inStock: _asBool(json['inStock']),
      categoryId: json['categoryId']?.toString() ?? '',
      projectId: projectIdValue,
      projectName: json['projectName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'description': description,
      if (kind != null) 'kind': kind,
      if (sizes != null) 'sizes': sizes,
      if (lengths != null) 'lengths': lengths,
      if (coverSizes != null) 'coverSizes': coverSizes,
      if (type != null) 'type': type,
      'placement': type,
      'imageUrl': imageUrl,
      // Never serialize catalog prices into estimates, posts, or favorites.
      'unit': unit,
      'projectType': projectType,
      'subType': subType,
      'shopId': shopId,
      'inStock': inStock,
      'categoryId': categoryId,
      'projectId': projectId,
      'projectName': projectName,
    };
  }
}
