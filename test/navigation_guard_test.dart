// Back navigation and the "you'll lose progress" warnings.
//
// Back should land on the screen the builder came from, or home when there is
// nothing under the current screen, and should ask before it throws away
// estimate work: a typed description, the AI chat, edited quantities.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/core/navigation/progress_guard.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/describe_project_screen.dart';

const _warning = LeaveWarning(
  title: 'Lose it?',
  message: 'Your work goes.',
  confirmLabel: 'Leave',
  cancelLabel: 'Stay',
);

/// A launcher with a button that pushes [screen] over it.
Widget _launcher(Widget Function() screen) {
  return MaterialApp(
    navigatorObservers: [NavigationHistory.instance],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen())),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Widget _guarded({LeaveWarning? Function()? onBack}) {
  return ProgressGuard(
    onBack: onBack,
    child: const Scaffold(body: SafeArea(child: OffsetBackButton())),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('ProgressGuard', () {
    testWidgets('back with nothing to lose pops at once', (tester) async {
      await tester.pumpWidget(_launcher(() => _guarded(onBack: () => null)));
      await _open(tester);

      await tester.tap(find.byType(OffsetBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('back with work to lose asks, and Stay keeps the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _launcher(() => _guarded(onBack: () => _warning)),
      );
      await _open(tester);

      await tester.tap(find.byType(OffsetBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Lose it?'), findsOneWidget);
      expect(find.text('Your work goes.'), findsOneWidget);

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(OffsetBackButton), findsOneWidget);
    });

    testWidgets('confirming the warning goes back', (tester) async {
      await tester.pumpWidget(
        _launcher(() => _guarded(onBack: () => _warning)),
      );
      await _open(tester);

      await tester.tap(find.byType(OffsetBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(OffsetBackButton), findsNothing);
    });

    testWidgets('Android system back goes through the same warning', (
      tester,
    ) async {
      await tester.pumpWidget(
        _launcher(() => _guarded(onBack: () => _warning)),
      );
      await _open(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Lose it?'), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('leaving the flow asks the topmost guard', (tester) async {
      late BuildContext top;
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressGuard(
            onExit: () => null,
            child: ProgressGuard(
              onExit: () => const LeaveWarning.exitEstimate(),
              child: Builder(
                builder: (context) {
                  top = context;
                  return const Scaffold();
                },
              ),
            ),
          ),
        ),
      );

      final answer = ProgressGuard.confirmExit(top);
      await tester.pumpAndSettle();
      expect(find.text('Leave this estimate?'), findsOneWidget);

      await tester.tap(find.text('Keep planning'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('leaving is allowed when no guard is mounted', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold();
            },
          ),
        ),
      );
      expect(await ProgressGuard.confirmExit(ctx), isTrue);
    });
  });

  group('AppNav', () {
    testWidgets('back on a root screen goes to its fallback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => AppNav.back(
                  context,
                  rootFallback: (_) => const Text('fallback'),
                ),
                child: const Text('back'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      expect(find.text('fallback'), findsOneWidget);
    });

    testWidgets('system back on a root sign-in screen goes to the fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RootBackFallback(
            fallback: (_) => const Text('landing'),
            child: const Scaffold(body: Text('sign in')),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('landing'), findsOneWidget);
    });

    testWidgets('the history knows whether home is in the stack', (
      tester,
    ) async {
      await tester.pumpWidget(_launcher(() => const Text('screen')));
      expect(NavigationHistory.instance.hasHome, isFalse);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (_) => const Text('home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(NavigationHistory.instance.hasHome, isTrue);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(NavigationHistory.instance.hasHome, isFalse);
    });
  });

  group('estimate screens', () {
    Widget app(Widget Function() screen) => ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: _launcher(screen),
    );

    testWidgets('describe: back without a description does not ask', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          () => const DescribeProjectScreen(
            projectName: 'Bathroom Renovation',
            scope: RenovationScope.cosmetic,
            method: PlanningMethod.template,
          ),
        ),
      );
      await _open(tester);

      await tester.tap(find.byType(OffsetBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('describe: back with a description warns it will be cleared', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          () => const DescribeProjectScreen(
            projectName: 'Bathroom Renovation',
            scope: RenovationScope.cosmetic,
            method: PlanningMethod.template,
          ),
        ),
      );
      await _open(tester);

      await tester.enterText(find.byType(TextField), 'Retile the floor');
      await tester.tap(find.byType(OffsetBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Clear your description?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Retile the floor'), findsOneWidget);
    });

    testWidgets('BOM review has a back button, and warns after an edit', (
      tester,
    ) async {
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
        app(
          () => CostEstimationScreen(
            projectName: 'Bathroom Renovation',
            template: bom,
            projectAreaSqm: 12,
          ),
        ),
      );
      await _open(tester);

      expect(find.byType(OffsetBackButton), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '99');
      await tester.pump();
      await tester.tap(find.byType(OffsetBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Undo your material list edits?'), findsOneWidget);
      expect(find.textContaining('1 quantity you typed'), findsOneWidget);

      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('swapping a type asks before replacing a typed quantity', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
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
      final rows = bom.items.map(BomQuantityEstimator.ensureSwappable).toList();
      final index = rows.indexWhere(
        (item) => item.alternatives.any((alt) => alt.name != item.name),
      );
      expect(index, isNonNegative, reason: 'the bathroom BOM has a swap');
      final row = rows[index];
      final alternative = row.alternatives.firstWhere(
        (alt) => alt.name != row.name,
      );

      await tester.pumpWidget(
        app(
          () => CostEstimationScreen(
            projectName: 'Bathroom Renovation',
            template: bom,
            projectAreaSqm: 12,
          ),
        ),
      );
      await _open(tester);

      await tester.enterText(find.byType(TextField).at(index), '77');
      await tester.pump();
      await tester.tap(find.text(alternative.name).first);
      await tester.pumpAndSettle();

      expect(find.text('Recalculate quantities you typed?'), findsOneWidget);
      expect(find.textContaining('${row.name} (you typed 77)'), findsOneWidget);

      await tester.tap(find.text('Keep my quantities'));
      await tester.pumpAndSettle();
      expect(find.text('77'), findsOneWidget);
    });
  });
}
