import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/recommendation_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const materials = [
    AiRecommendedMaterial(
      name: 'Ceramic Floor Tiles',
      category: 'Floor',
      reason: 'Replaces the old floor',
    ),
    AiRecommendedMaterial(name: 'Tile Adhesive (25 kg)'),
  ];

  Future<RecommendationCache> freshCache() async {
    SharedPreferences.setMockInitialValues({});
    return RecommendationCache(preferences: await SharedPreferences.getInstance());
  }

  test('an answered description is answered again without the model', () async {
    final cache = await freshCache();
    await cache.write(
      projectType: 'Bathroom Renovation',
      scope: 'Cosmetic',
      description: 'Retile the floor and repaint',
      materials: materials,
    );

    final hit = await cache.read(
      projectType: 'Bathroom Renovation',
      scope: 'Cosmetic',
      description: 'Retile the floor and repaint',
    );
    expect(hit, isNotNull);
    expect(hit!.map((m) => m.name), contains('Ceramic Floor Tiles'));
    expect(hit.first.reason, 'Replaces the old floor');
  });

  test('spacing and case do not make it a different question', () async {
    final cache = await freshCache();
    await cache.write(
      projectType: 'Bathroom Renovation',
      scope: 'Cosmetic',
      description: 'Retile the floor',
      materials: materials,
    );

    expect(
      await cache.read(
        projectType: 'Bathroom Renovation',
        scope: 'Cosmetic',
        description: '  RETILE   the floor ',
      ),
      isNotNull,
    );
  });

  test('a different type is a different question', () async {
    final cache = await freshCache();
    await cache.write(
      projectType: 'Bathroom Renovation',
      scope: 'Cosmetic',
      description: 'Retile the floor',
      materials: materials,
    );

    expect(
      await cache.read(
        projectType: 'Bathroom Renovation',
        scope: 'Structural',
        description: 'Retile the floor',
      ),
      isNull,
    );
  });

  test('nothing cached is a miss, not an error', () async {
    final cache = await freshCache();
    expect(
      await cache.read(
        projectType: 'Kitchen Renovation',
        scope: 'Cosmetic',
        description: 'anything',
      ),
      isNull,
    );
  });

  test('an empty answer is never cached', () async {
    final cache = await freshCache();
    await cache.write(
      projectType: 'Kitchen Renovation',
      scope: 'Cosmetic',
      description: 'nothing came back',
      materials: const [],
    );
    expect(
      await cache.read(
        projectType: 'Kitchen Renovation',
        scope: 'Cosmetic',
        description: 'nothing came back',
      ),
      isNull,
    );
  });

  test('a stale answer is not served', () async {
    SharedPreferences.setMockInitialValues({
      'ai_recommendation_cache_v1':
          '{"bathroom renovation|cosmetic|old": {"at": "2020-01-01T00:00:00.000",'
              '"materials": [{"name": "Ceramic Floor Tiles"}]}}',
    });
    final cache = RecommendationCache(
      preferences: await SharedPreferences.getInstance(),
    );

    expect(
      await cache.read(
        projectType: 'Bathroom Renovation',
        scope: 'Cosmetic',
        description: 'old',
      ),
      isNull,
    );
  });

  test('a corrupt cache reads as empty rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      'ai_recommendation_cache_v1': 'not json at all',
    });
    final cache = RecommendationCache(
      preferences: await SharedPreferences.getInstance(),
    );

    expect(
      await cache.read(
        projectType: 'Bathroom Renovation',
        scope: 'Cosmetic',
        description: 'anything',
      ),
      isNull,
    );
  });
}
