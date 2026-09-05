import 'material_item.dart';

class MaterialCategory {
  final String title;
  final List<MaterialItem> items;

  const MaterialCategory({required this.title, required this.items});

  factory MaterialCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = (rawItems is List)
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(MaterialItem.fromJson)
              .toList(growable: false)
        : const <MaterialItem>[];

    return MaterialCategory(
      title: (json['title'] ?? '').toString(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'items': items.map((e) => e.toJson()).toList(growable: false),
    };
  }
}
