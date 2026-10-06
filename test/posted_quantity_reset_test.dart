// A quantity cleared to 0 and then typed again must be the number shops get.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/auth/presentation/screens/material_estimator.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('postedLineQuantity', () {
    test('a later positive number replaces a stored 0', () {
      expect(postedLineQuantity(stored: 0, typedText: '6'), 6);
      expect(postedLineQuantity(stored: 0, typedText: '1'), 1);
      expect(postedLineQuantity(stored: 0, typedText: ' 15 '), 15);
    });

    test('an explicit 0 stays 0 so the post can be refused', () {
      expect(postedLineQuantity(stored: 18, typedText: '0'), 0);
      expect(postedLineQuantity(stored: 18, typedText: ''), 0);
      expect(postedLineQuantity(stored: 18, typedText: 'nope'), 0);
    });

    test('a saved line with no text field keeps its stored quantity', () {
      expect(postedLineQuantity(stored: 18), 18);
      expect(postedLineQuantity(stored: 0), 0);
    });
  });

  group('savedMaterialLines', () {
    test('keeps the quantity the builder typed, including after a 0', () {
      final lines = savedMaterialLines(const [
        {
          'name': 'Portland Cement',
          'quantity': 18,
          'unit': 'bags',
          'category': 'Masonry',
        },
      ]);
      expect(lines.single.quantity, 18);
      expect(lines.single.name, 'Portland Cement');
      expect(legacyMaterialNames(const ['Masking Tape']), ['Masking Tape']);
    });
  });

  testWidgets('typing 0 then a positive number is what review receives', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bathroom = RenovationTemplatesCatalog.forProject(
      'Bathroom Renovation',
      RenovationScope.cosmetic,
    );
    final bom = bathroom.copyWithItems(
      BomQuantityEstimator.scaleTemplate(
        template: bathroom,
        areaSqm: 12,
        scope: RenovationScope.cosmetic,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: MaterialApp(
          home: CostEstimationScreen(
            projectName: 'Bathroom Renovation',
            template: bom,
            projectAreaSqm: 12,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextField).first;
    final initial = tester.widget<TextField>(field).controller!.text;
    expect(double.parse(initial), isNot(99));

    await tester.enterText(field, '0');
    await tester.pump();
    final estimateNow = find.widgetWithText(ElevatedButton, 'Estimate Now');
    expect(tester.widget<ElevatedButton>(estimateNow).onPressed, isNull);

    await tester.enterText(field, '99');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(estimateNow).onPressed, isNotNull);

    await tester.ensureVisible(estimateNow);
    await tester.tap(estimateNow);
    await tester.pumpAndSettle();

    final review = tester.widget<MaterialEstimatorScreen>(
      find.byType(MaterialEstimatorScreen),
    );
    final line = review.plumbingMaterials.first;
    expect(line.quantity, 99);
    expect(
      postedLineQuantity(
        stored: line.quantity,
        typedText: line.qtyController.text,
      ),
      99,
    );
    expect(find.textContaining('Quantity: 99'), findsWidgets);
  });

  testWidgets('review posts the typed number when the stored quantity is 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final cement = AddedPlumbingSelection(
      categoryTitle: 'Masonry',
      kind: '',
      materialName: 'Portland Cement',
      unit: 'bags',
      quantity: 0,
    );
    cement.qtyController.text = '6';
    cement.quantity = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: MaterialApp(
          home: MaterialEstimatorScreen(
            projectName: 'Bathroom Renovation',
            customProjectName: 'Ground floor bath',
            plumbingMaterials: [cement],
            aiProjectArea: 12,
            lockEstimateDetails: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Quantity: 6'), findsWidgets);
    expect(
      postedLineQuantity(
        stored: cement.quantity,
        typedText: cement.qtyController.text,
      ),
      6,
    );
  });

  testWidgets('a reopened estimate keeps the saved quantity', (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final project = ProjectModel(
      id: 'draft-1',
      projectName: 'Ground floor bath',
      projectType: 'Bathroom Renovation',
      materialCount: 1,
      projectArea: 12,
      costLevel: 'medium',
      materials: const [
        {
          'name': 'Portland Cement',
          'quantity': 18,
          'unit': 'bags',
          'category': 'Masonry',
        },
      ],
      status: 'draft',
      lastUpdated: DateTime(2026, 10, 6),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: MaterialApp(
          home: MaterialEstimatorScreen(
            projectName: 'Bathroom Renovation',
            existingProject: project,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Portland Cement'), findsWidgets);
    expect(find.textContaining('Quantity: 18'), findsWidgets);
    expect(find.textContaining('Quantity: Not set'), findsNothing);
  });
}
