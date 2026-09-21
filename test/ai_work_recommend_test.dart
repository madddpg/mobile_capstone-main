import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/ai_recommendations_screen.dart';

/// The AI picks work from the project's catalogue instead of naming
/// materials. These lock in that nothing outside the catalogue gets through,
/// that an older server's materials answer still lands on sensible work, and
/// that the picks open the checklist ticked.

final _bathroom =
    RenovationTemplatesCatalog.workCatalogueFor('Bathroom Renovation');

Iterable<String> _ids(List<AiWorkPick> picks) => picks.map((p) => p.id);

class _FakeService extends AiMaterialConsultantService {
  _FakeService(this.result);

  final AiWorkRecommendResult result;

  @override
  Future<AiWorkRecommendResult> recommendWork({
    required String projectType,
    required String scope,
    required String description,
    required WorkCatalogue catalogue,
  }) async =>
      result;
}

void main() {
  group('a work answer', () {
    test('keeps picks from the catalogue, once each, with their reasons', () {
      final picks = AiMaterialConsultantService.workPicksFrom([
        {'id': 'retile_floor', 'reason': 'Old tiles are cracked'},
        {'id': 'install_jacuzzi', 'reason': 'Not in the catalogue'},
        {'id': 'retile_floor', 'reason': 'again'},
        'repaint',
      ], _bathroom);
      expect(_ids(picks), ['retile_floor']);
      expect(picks.single.reason, 'Old tiles are cracked');
    });

    test('that is not a list picks nothing', () {
      expect(AiMaterialConsultantService.workPicksFrom(null, _bathroom),
          isEmpty);
    });
  });

  group('a materials answer from a server without work items', () {
    test('picks the work that brings those kinds of material', () {
      final picks = AiMaterialConsultantService.workPicksFromMaterials([
        {'name': 'Ceramic floor tiles 600x600', 'reason': 'New floor'},
        {'name': 'Water closet (two-piece)', 'reason': 'Replace the toilet'},
      ], _bathroom);
      expect(_ids(picks), containsAll(['retile_floor', 'replace_toilet']));
      expect(_ids(picks), isNot(contains('build_walls')));
      expect(
          picks.firstWhere((p) => p.id == 'retile_floor').reason, 'New floor');
    });

    test('ignores materials too general to point at any work', () {
      final picks = AiMaterialConsultantService.workPicksFromMaterials([
        {'name': 'Masking tape'},
      ], _bathroom);
      expect(_ids(picks), isNot(contains('build_walls')));
      expect(_ids(picks), isNot(contains('retile_floor')));
    });
  });

  group('the recommendations screen', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pumpScreen(
        WidgetTester tester, AiWorkRecommendResult result) {
      // A tall phone, so the whole checklist is laid out and findable.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(MaterialApp(
          home: AiRecommendationsScreen(
            projectName: 'Bathroom Renovation',
            scope: RenovationScope.cosmetic,
            description: 'The floor tiles are cracked and the toilet leaks.',
            service: _FakeService(result),
          ),
        ));
    }

    testWidgets('opens the checklist with the picks ticked and explained',
        (tester) async {
      await pumpScreen(
        tester,
        const AiWorkRecommendResult(success: true, picks: [
          AiWorkPick(id: 'retile_floor', reason: 'Tiles are cracked'),
          AiWorkPick(id: 'replace_toilet', reason: 'Toilet leaks'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI: Tiles are cracked'), findsOneWidget);
      expect(find.text('AI: Toilet leaks'), findsOneWidget);
      // Ticked work shows a filled check; the other nine items do not.
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    });

    testWidgets('offers the checklist when the AI cannot answer',
        (tester) async {
      await pumpScreen(
        tester,
        const AiWorkRecommendResult(
            success: false, errorMessage: 'The AI is busy right now.'),
      );
      await tester.pumpAndSettle();

      expect(find.text('The AI is busy right now.'), findsOneWidget);
      await tester.tap(find.text('Pick the work from the checklist instead'));
      await tester.pumpAndSettle();

      // The cosmetic starting package: a full bathroom makeover, 7 items.
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(7));
    });
  });
}
