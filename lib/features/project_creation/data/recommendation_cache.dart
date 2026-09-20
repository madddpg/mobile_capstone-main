import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';

/// Remembers what the AI recommended for a description it has already seen.
///
/// The model is a shared free-tier service that answers 503 under load, and a
/// builder repeating the same description — or a panel watching the same demo
/// twice — should not depend on it being free at that moment. A hit is also
/// instant, which is the difference between a screen that feels considered and
/// one that feels like it is thinking.
///
/// Only successful answers are kept, per device, for a week.
class RecommendationCache {
  RecommendationCache({SharedPreferences? preferences})
      : _preferences = preferences;

  final SharedPreferences? _preferences;

  static const String _key = 'ai_recommendation_cache_v1';
  static const Duration maxAge = Duration(days: 7);

  /// Keeps the file small; the oldest entry goes when the list is full.
  static const int maxEntries = 20;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  /// One key per question asked, insensitive to case and stray spacing.
  static String keyFor({
    required String projectType,
    required String scope,
    required String description,
  }) {
    final normalized = description
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${projectType.toLowerCase().trim()}|'
        '${scope.toLowerCase().trim()}|$normalized';
  }

  static List<AiRecommendedMaterial> _decodeMaterials(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          AiRecommendedMaterial(
            name: (entry['name'] ?? '').toString(),
            category: (entry['category'] ?? '').toString(),
            reason: (entry['reason'] ?? '').toString(),
          ),
    ].where((m) => m.name.trim().isNotEmpty).toList();
  }

  static List<Map<String, String>> _encodeMaterials(
    List<AiRecommendedMaterial> materials,
  ) =>
      [
        for (final material in materials)
          {
            'name': material.name,
            'category': material.category,
            'reason': material.reason,
          },
      ];

  Future<Map<String, dynamic>> _read() async {
    try {
      final raw = (await _prefs).getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      // A cache that cannot be read is a cache miss, never an error the
      // builder sees.
      return {};
    }
  }

  /// The stored recommendations for this question, or null when there are
  /// none or they have gone stale.
  Future<List<AiRecommendedMaterial>?> read({
    required String projectType,
    required String scope,
    required String description,
  }) async {
    final entries = await _read();
    final entry = entries[keyFor(
      projectType: projectType,
      scope: scope,
      description: description,
    )];
    if (entry is! Map) return null;

    final savedAt = DateTime.tryParse('${entry['at'] ?? ''}');
    if (savedAt == null || DateTime.now().difference(savedAt) > maxAge) {
      return null;
    }
    final materials = _decodeMaterials(entry['materials']);
    return materials.isEmpty ? null : materials;
  }

  Future<void> write({
    required String projectType,
    required String scope,
    required String description,
    required List<AiRecommendedMaterial> materials,
  }) async {
    if (materials.isEmpty) return;
    try {
      final entries = Map<String, dynamic>.from(await _read());
      entries[keyFor(
        projectType: projectType,
        scope: scope,
        description: description,
      )] = {
        'at': DateTime.now().toIso8601String(),
        'materials': _encodeMaterials(materials),
      };

      if (entries.length > maxEntries) {
        final ordered = entries.entries.toList()
          ..sort((a, b) {
            final aAt = DateTime.tryParse('${(a.value as Map)['at'] ?? ''}');
            final bAt = DateTime.tryParse('${(b.value as Map)['at'] ?? ''}');
            return (aAt ?? DateTime(0)).compareTo(bAt ?? DateTime(0));
          });
        for (final stale in ordered.take(entries.length - maxEntries)) {
          entries.remove(stale.key);
        }
      }

      await (await _prefs).setString(_key, jsonEncode(entries));
    } catch (_) {
      // Failing to cache is not worth telling anyone about.
    }
  }
}
