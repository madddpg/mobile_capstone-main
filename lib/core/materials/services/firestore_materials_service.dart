import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/material_category.dart';
import '../models/material_item.dart';

class FirestoreMaterialsService {
  final FirebaseFirestore _firestore;

  FirestoreMaterialsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  String _normalizeProjectQuery(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  String _projectIdFromQuery(String projectQuery) {
    final normalized = _normalizeProjectQuery(projectQuery);

    if (normalized == 'bathroom renovation' || normalized == 'bathroom') {
      return 'bathroom_renovation';
    }

    return normalized
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  Future<List<MaterialCategory>> fetchMaterialsForProject(
    String projectQuery,
  ) async {
    final projectId = _projectIdFromQuery(projectQuery);

    QuerySnapshot<Map<String, dynamic>> snap;

    try {
      snap = await _firestore
          .collection('products')
          .where('projectId', isEqualTo: projectId)
          .where('inStock', isEqualTo: true)
          .get();
    } on FirebaseException catch (e) {
      final message = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : e.code;

      throw Exception('Failed to load products from Firestore. $message');
    }

    if (snap.docs.isEmpty) {
      return const <MaterialCategory>[];
    }

    final productItems = snap.docs
        .map((doc) => MaterialItem.fromJson(doc.data(), doc.id))
        .where((item) => item.inStock)
        .toList();

    productItems.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final categoryMap = <String, List<MaterialItem>>{};

    for (final item in productItems) {
      final categoryTitle = item.category.trim().isNotEmpty
          ? item.category.trim()
          : 'Others';

      categoryMap.putIfAbsent(categoryTitle, () => <MaterialItem>[]);
      categoryMap[categoryTitle]!.add(item);
    }

    final categories = categoryMap.entries.map((entry) {
      return MaterialCategory(title: entry.key, items: entry.value);
    }).toList();

    categories.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    return categories;
  }
}
