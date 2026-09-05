import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/core/materials/models/material_item.dart';
import 'package:iconstruct/core/materials/models/favorite_model.dart';

class FavoritesService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FavoritesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;

  /// Get the user's favorites collection reference. Returns null if not logged in.
  CollectionReference<Map<String, dynamic>>? get _favoritesRef {
    final userId = uid;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('favorites');
  }

  /// Generate a consistent product ID if one isn't explicitly given
  String _extractProductId(MaterialItem item) {
    if (item.id != null && item.id!.isNotEmpty) {
      return item.id!.replaceAll('/', '_').replaceAll('..', '_');
    }
    // Fallback mechanism based on material attributes
    return '${item.category}_${item.name}'
        .replaceAll(RegExp(r'[\\/\s]+'), '_')
        .toLowerCase();
  }

  /// Add a material to the favorites list
  Future<void> addFavorite(
    MaterialItem item, {
    String projectType = 'Default Project',
  }) async {
    final ref = _favoritesRef;
    if (ref == null) return;

    final productId = _extractProductId(item);

    final favorite = FavoriteModel(
      productId: productId,
      name: item.name,
      category: item.category,
      projectType: projectType,
      size:
          '', // Size is intentionally removed from favorites as per requirement
      imageUrl: item.imageUrl,
    );

    await ref.doc(productId).set(favorite.toMap(), SetOptions(merge: true));
  }

  /// Remove a material from the favorites list
  Future<void> removeFavorite(MaterialItem item) async {
    final ref = _favoritesRef;
    if (ref == null) return;

    final productId = _extractProductId(item);
    await ref.doc(productId).delete();
  }

  /// Stream to listen if a specific material is favorited
  Stream<bool> isFavorite(MaterialItem item) {
    final ref = _favoritesRef;
    if (ref == null) return Stream.value(false);

    final productId = _extractProductId(item);
    return ref.doc(productId).snapshots().map((doc) => doc.exists);
  }

  /// Stream all user's favorite materials, ordered by most recent first
  Stream<List<FavoriteModel>> streamFavorites() {
    final ref = _favoritesRef;
    if (ref == null) return Stream.value([]);

    return ref.orderBy('savedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FavoriteModel.fromMap(doc.data()))
          .toList();
    });
  }
}
