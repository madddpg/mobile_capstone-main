import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
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

/// A chat that always answers [result].
class _FakeChat extends AiMaterialConsultantService {
  _FakeChat(this.result);

  final AiConsultResult result;

  @override
  Future<AiConsultResult> consult({
    required String projectType,
    required String userMessage,
    String style = '',
    double areaSqm = 0,
    String? scope,
    List<String> ideaLog = const [],
    List<String> selectedMaterials = const [],
    String? projectNotes,
    WorkCatalogue? catalogue,
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

  group('the chat', () {
    test('is shown every work item with its kind', () {
      final payload = AiMaterialConsultantService.workItemsPayload(_bathroom);
      expect(payload.map((w) => w['id']),
          _bathroom.items.map((i) => i.id).toList());
      expect(payload.first['kind'], isNotEmpty);
    });

    test('keeps suggested work from the catalogue, once each', () {
      final ids = AiMaterialConsultantService.suggestedWorkFrom({
        'suggestedWork': ['repaint', 'install_jacuzzi', 'repaint', 'tile_walls'],
      }, _bathroom);
      expect(ids, ['repaint', 'tile_walls']);
    });

    test('an empty work answer suggests nothing, even with material names',
        () {
      final ids = AiMaterialConsultantService.suggestedWorkFrom({
        'suggestedWork': [],
        'suggestions': ['Ceramic floor tiles'],
      }, _bathroom);
      expect(ids, isEmpty);
    });

    test('matches an older server\'s material suggestions to work', () {
      final ids = AiMaterialConsultantService.suggestedWorkFrom({
        'suggestions': ['Ceramic floor tiles 600x600', 'Interior latex paint'],
      }, _bathroom);
      expect(ids, containsAll(['retile_floor', 'repaint']));
    });

    test('a reply names work, never its id', () {
      // Word for word what the AI answered on the emulator.
      const reply = 'Cracked floor tiles point to retile_floor, and a leaking '
          'faucet suggests supply_lines or plumbing updates. You may also '
          'want to consider waterproof_floor to protect the area.';
      expect(
        AiMaterialConsultantService.namesForIds(reply, _bathroom),
        'Cracked floor tiles point to “Retile the floor”, and a leaking '
        'faucet suggests “Replace the water supply lines” or plumbing '
        'updates. You may also want to consider “Waterproof the floor” to '
        'protect the area.',
      );
    });

    test('an id in quotes or code marks, or capitalised, is still named', () {
      expect(
        AiMaterialConsultantService.namesForIds(
            'Try `tile_walls` and "Retile_Floor".', _bathroom),
        'Try “Tile the walls” and “Retile the floor”.',
      );
    });

    test('plain words that are also ids stay words', () {
      const reply = 'You may want to repaint the walls after retiling.';
      expect(AiMaterialConsultantService.namesForIds(reply, _bathroom), reply);
    });

    test('a reply with no catalogue is left as it is', () {
      expect(AiMaterialConsultantService.namesForIds('retile_floor', null),
          'retile_floor');
    });
  });

  group('the chat suggestions sheet', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    // On the emulator, "Add to my list" after choosing two picks was logged
    // as "Skip suggestions": the picks lived inside the sheet's builder,
    // which runs again whenever the screen's metrics change.
    testWidgets('keeps the picks when the screen changes under it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AIConsultationScreen(
          projectName: 'Bathroom Renovation',
          service: _FakeChat(const AiConsultResult(
            success: true,
            inScope: true,
            reply: 'Retiling and a new shower fit what you describe.',
            suggestions: [],
            suggestedWork: [
              'retile_floor',
              'replace_shower',
              'waterproof_floor',
            ],
          )),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'Cracked floor tiles and a broken shower.');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Suggested work'), findsOneWidget);

      await tester.tap(find.text('Retile the floor'));
      await tester.pump();
      await tester.tap(find.text('Replace the shower'));
      await tester.pump();
      expect(find.text('Add (2)'), findsOneWidget);

      // What the keyboard closing, a rotation or TalkBack starting does.
      tester.platformDispatcher.textScaleFactorTestValue = 1.1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(find.text('Add (2)'), findsOneWidget);

      await tester.tap(find.text('Add (2)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Added 2 pieces of work to your list (2 so far)'),
        findsOneWidget,
      );
      expect(find.text('Build my BOM (2)'), findsOneWidget);
      expect(find.textContaining('Skip suggestions'), findsNothing);
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
          success: false,
          errorMessage: '${AiMaterialConsultantService.unreachableMessage} '
              '${AiMaterialConsultantService.buildMyBomHint}',
        ),
      );
      await tester.pumpAndSettle();

      // The message names a button that is really there.
      await tester.tap(find.text('Build my BOM'));
      await tester.pumpAndSettle();

      // The cosmetic starting package: a full bathroom makeover, 7 items.
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(7));
    });
  });

  // The functionality test for AI Work Recommendation quotes each message the
  // builder must see. These hold the app to those words.
  group('the functionality test messages', () {
    FirebaseFunctionsException error(String code, [String message = '']) =>
        FirebaseFunctionsException(code: code, message: message);

    test('run 3: no internet or a failing AI service is "unreachable"', () {
      // No connection arrives as `internal` on Android, `unavailable`
      // elsewhere; a model that cannot be reached is `unavailable` from the
      // server; a slow one is `deadline-exceeded`.
      for (final e in [
        error('internal', 'INTERNAL'),
        error('unavailable', 'iConstruct AI could not be reached just now.'),
        error('deadline-exceeded'),
        error('unknown'),
      ]) {
        expect(AiMaterialConsultantService.friendlyError(e),
            'The AI service is unreachable right now.',
            reason: e.code);
      }
      expect(
        '${AiMaterialConsultantService.unreachableMessage} '
        '${AiMaterialConsultantService.buildMyBomHint}',
        startsWith('The AI service is unreachable right now. You can still '
            'tap “Build my BOM” and pick the work from the checklist '
            'yourself'),
      );
    });

    test('run 3: an answer the app cannot read is the AI service failing', () {
      final result = AiMaterialConsultantService.workAnswer('garbled', _bathroom);
      expect(result.success, isFalse);
      expect(result.errorMessage,
          startsWith('The AI service is unreachable right now.'));
    });

    test('run 4: no relevant work says the AI did not pick any', () {
      const expected = 'The AI did not pick any work. Describe the work in '
          'more detail or start from the checklist instead.';
      // An off-topic description, exactly as the server answers it. Its own
      // reason used to be shown instead.
      final offTopic = AiMaterialConsultantService.workAnswer({
        'success': true,
        'inScope': false,
        'workItems': [],
        'error': 'I can only recommend work for a renovation. Describe the '
            'work you want done, or chat with the AI instead.',
      }, _bathroom);
      expect(offTopic.success, isFalse);
      expect(offTopic.errorMessage, expected);

      // In scope, but nothing it named is on the project's checklist.
      final unknown = AiMaterialConsultantService.workAnswer({
        'success': true,
        'inScope': true,
        'workItems': [
          {'id': 'install_jacuzzi', 'reason': 'Not offered'},
        ],
      }, _bathroom);
      expect(unknown.errorMessage, expected);
    });

    test('run 5: a missing server key says so', () {
      for (final e in [
        error('failed-precondition',
            'iConstruct AI has no API key configured on the server.'),
        // How an older copy of the function reports it.
        error('internal',
            'AI service is currently unavailable. Set GEMINI_API_KEY or '
                'OPENAI_API_KEY.'),
      ]) {
        expect(AiMaterialConsultantService.friendlyError(e),
            'The AI key is not configured on the server.',
            reason: e.message);
      }
    });

    testWidgets('each message shows on the Recommended Work screen as written',
        (tester) async {
      for (final message in [
        '${AiMaterialConsultantService.unreachableMessage} '
            '${AiMaterialConsultantService.buildMyBomHint}',
        AiMaterialConsultantService.noWorkPickedMessage,
        AiMaterialConsultantService.keyNotConfiguredMessage,
      ]) {
        tester.view.physicalSize = const Size(1080, 6000);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: AiRecommendationsScreen(
            key: ValueKey(message),
            projectName: 'Bathroom Renovation',
            scope: RenovationScope.cosmetic,
            description: 'The floor tiles are cracked and the toilet leaks.',
            service: _FakeService(
                AiWorkRecommendResult(success: false, errorMessage: message)),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text('Build my BOM'), findsOneWidget);
      }
    });
  });
}
