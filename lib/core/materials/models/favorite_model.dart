import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteModel {
  final String productId;
  final String name;
  final String category;
  final String projectType;
  final String size;
  final String imageUrl;
  final DateTime? savedAt;
  final String source;

  const FavoriteModel({
    required this.productId,
    required this.name,
    required this.category,
    required this.projectType,
    required this.size,
    required this.imageUrl,
    this.savedAt,
    this.source = 'products',
  });

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      projectType: map['projectType'] ?? '',
      size: map['size'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      savedAt: (map['savedAt'] as Timestamp?)?.toDate(),
      source: map['source'] ?? 'products',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'category': category,
      'projectType': projectType,
      'size': size,
      'imageUrl': imageUrl,
      'savedAt': FieldValue.serverTimestamp(),
      'source': source,
    };
  }
}
