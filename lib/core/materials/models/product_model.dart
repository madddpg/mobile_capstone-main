import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String? id;
  final String name;
  final String description;
  final String projectType;
  final String category;
  final String type;
  final num price;
  final String unit;
  final String currency;
  final bool available;
  final String shopId;
  final String shopName;
  final String? imageBase64;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const ProductModel({
    this.id,
    required this.name,
    required this.description,
    required this.projectType,
    required this.category,
    required this.type,
    required this.price,
    required this.unit,
    required this.currency,
    required this.available,
    required this.shopId,
    required this.shopName,
    this.imageBase64,
    this.createdAt,
    this.updatedAt,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? projectType,
    String? category,
    String? type,
    num? price,
    String? unit,
    String? currency,
    bool? available,
    String? shopId,
    String? shopName,
    String? imageBase64,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      projectType: projectType ?? this.projectType,
      category: category ?? this.category,
      type: type ?? this.type,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      currency: currency ?? this.currency,
      available: available ?? this.available,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      imageBase64: imageBase64 ?? this.imageBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json, [String? id]) {
    return ProductModel(
      id: id ?? json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      projectType: json['projectType']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      // Catalog prices stay private to shops; builders only see quotations.
      price: 0,
      unit: json['unit']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      available: json['available'] as bool? ?? false,
      shopId: json['shopId']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      imageBase64: json['imageBase64']?.toString(),
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductModel.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'projectType': projectType,
      'category': category,
      'type': type,
      'unit': unit,
      'currency': currency,
      'available': available,
      'shopId': shopId,
      'shopName': shopName,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
