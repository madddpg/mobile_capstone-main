// Renders the app's screens at small-phone, common-phone, large-phone and
// tablet sizes, with the largest font setting the app allows, and fails on
// any overflow or unbounded layout.
//
// Text in iConstruct scales with the screen (see AppScale), so a row that fit
// at one fixed size can clip on another device. This is the check that catches
// it before a builder does.
//
// Only screens that build without Firebase are listed. Login, registration,
// home, saved projects, bidding, quotations, chat, notifications, tracking and
// the AI consultant read Firebase while building, and their failed background
// calls cannot be isolated from the layout errors this test collects. Those
// screens use the same fixes and were reviewed by hand instead.
//
// A fixed-size button clips its label silently, with no overflow error, so
// this test cannot see that case. Buttons use minimum sizes instead.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/layout/app_scale.dart';
import 'package:iconstruct/features/auth/presentation/screens/change_password_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/auth/presentation/screens/edit_profile_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/terms_conditions_screen.dart';
import 'package:iconstruct/features/bidding/data/post_load_outcome.dart';
import 'package:iconstruct/features/bidding/screens/bidding_hub_screen.dart';
import 'package:iconstruct/features/bidding/widgets/estimate_unavailable_view.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/display_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/landing_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/main_display.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';
import 'package:iconstruct/features/project_creation/screens/create_project_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_planning_method_screen.dart';
import 'package:iconstruct/features/project_creation/screens/describe_project_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_renovation_type_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_work_items_screen.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';

const _sizes = <String, Size>{
  'small 320x640': Size(320, 640),
  'common 360x780': Size(360, 780),
  'large 430x932': Size(430, 932),
  'tablet 800x1280': Size(800, 1280),
};

/// The largest phone font setting AppScale honours.
const double _userTextScale = AppScale.maxUserTextScale;

bool _isLayoutError(String message) =>
    message.contains('overflowed') ||
    message.contains('was not laid out') ||
    message.contains('unbounded') ||
    message.contains('infinite size') ||
    message.contains('BoxConstraints forces an infinite');

String _describe(FlutterErrorDetails details) {
  final full = details.toString();
  final first = details.exceptionAsString().split('\n').first.trim();
  final where = RegExp(r'file:///\S*?(lib/[^\s:]+):(\d+)').firstMatch(full);
  return where == null ? first : '$first  @ ${where.group(1)}:${where.group(2)}';
}

/// Loads the app's bundled fonts under the names the screens ask for.
///
/// Without this every glyph renders in the test font, a solid square as wide
/// as the font size, which is far wider than Poppins and reports overflows
/// that never happen on a phone. google_fonts registers each weight as its own
/// family (`Poppins_700`), so each of those names is pointed at the bundled
/// file. Only Poppins Light is bundled, which runs a little narrower than the
/// bold weights, so the check is close to the device rather than exact.
Future<void> _loadAppFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  const poppins = 'assets/fonts/Poppins-Light.ttf';
  const inter = 'assets/fonts/Inter-VariableFont_opsz,wght.ttf';
  await load('Poppins', poppins);
  await load('Inter', inter);
  await load('Bungee-Regular', 'assets/fonts/Bungee-Regular.ttf');
  await load('Boldonse-Regular', 'assets/fonts/Boldonse-Regular.ttf');

  final variants = <String>[
    'regular',
    'italic',
    for (var weight = 100; weight <= 900; weight += 100) ...[
      '$weight',
      '${weight}italic',
    ],
  ];
  for (final variant in variants) {
    await load('Poppins_$variant', poppins);
    await load('Inter_$variant', inter);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Tests have no network, and the fonts are loaded from the bundle below.
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  final bathroom =
      RenovationTemplatesCatalog.forProject(
          'Bathroom Renovation', RenovationScope.structural);
  final extensionBom = bathroom.copyWithItems(
    BomQuantityEstimator.scaleTemplate(
      template: bathroom,
      areaSqm: 20,
      scope: RenovationScope.structural,
    ),
  );
  final measuredTakeoff = SiteTakeoff.from(
    const SiteDetails(
      job: RoomJob.wetRoom,
      lengthM: 2.0,
      widthM: 1.5,
      heightM: 2.4,
      doors: [Opening(widthM: 0.70, heightM: 2.10)],
      windows: [Opening(widthM: 0.60, heightM: 0.60)],
      wallTileHeight: WallTileHeight.wainscot,
      removeOldTiles: true,
      paintCeiling: true,
    ),
  );
  final measuredBom = bathroom.copyWithItems(
    BomQuantityEstimator.scaleTemplate(
      template: bathroom,
      areaSqm: measuredTakeoff.floorSqm,
      takeoff: measuredTakeoff,
    ),
  );
  final kitchen =
      RenovationTemplatesCatalog.forProject(
          'Kitchen Renovation', RenovationScope.cosmetic);

  final screens = <String, Widget Function()>{
    'DisplayScreen': () => const DisplayScreen(),
    'LandingScreen': () => const LandingScreen(),
    'MainDisplayScreen': () => const MainDisplayScreen(),
    'TermsConditionsScreen': () => const TermsConditionsScreen(),
    'ChangePasswordScreen': () => const ChangePasswordScreen(),
    'EditProfileScreen': () => const EditProfileScreen(
          firstName: 'Juan Miguel',
          lastName: 'Dela Cruz',
        ),
    'HomeScreen': () => const HomeScreen(),
    'CreateProjectScreen': () =>
        const CreateProjectScreen(renovationType: 'Bathroom Renovation'),
    'SelectPlanningMethodScreen': () =>
        const SelectPlanningMethodScreen(projectName: 'Bathroom Renovation'),
    'SelectRenovationTypeScreen': () => const SelectRenovationTypeScreen(
          renovationType: 'Interior Painting',
        ),
    // Structural is ticked by default here, so the disclaimer renders.
    'SelectRenovationTypeScreen (structural ticked)': () =>
        const SelectRenovationTypeScreen(renovationType: 'Roof Repair'),
    'DescribeProjectScreen (AI)': () => const DescribeProjectScreen(
          projectName: 'Bathroom Renovation',
          scope: RenovationScope.functional,
          method: PlanningMethod.ai,
        ),
    'TemplateAreaScreen (functional)': () => TemplateAreaScreen(
          template: RenovationTemplatesCatalog.forProject(
              'Kitchen Renovation', RenovationScope.functional),
          projectName: 'Kitchen Renovation',
          scope: RenovationScope.functional,
        ),
    'TemplateAreaScreen': () => TemplateAreaScreen(
          template: bathroom,
          projectName: 'Bathroom Renovation',
        ),
    'CostEstimationScreen': () => CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: extensionBom,
          projectAreaSqm: 20,
          scope: RenovationScope.structural,
        ),
    'TemplateAreaScreen (kitchen site details)': () => TemplateAreaScreen(
          template: kitchen,
          projectName: 'Kitchen Renovation',
        ),
    'TemplateAreaScreen (partial)': () => TemplateAreaScreen(
          template: kitchen,
          projectName: 'Kitchen Renovation',
          coverage: RenovationCoverage.partial,
        ),
    'TemplateAreaScreen (roof area)': () => TemplateAreaScreen(
          template:
              RenovationTemplatesCatalog.forProject(
              'Roof Repair', RenovationScope.cosmetic),
          projectName: 'Roof Repair',
        ),
    'CostEstimationScreen (measured room)': () => CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: measuredBom,
          projectAreaSqm: measuredTakeoff.floorSqm,
          takeoff: measuredTakeoff,
        ),
    // Structural work ticked from the start, so the disclaimer renders too.
    'SelectWorkItemsScreen': () => SelectWorkItemsScreen(
          catalogue: RenovationTemplatesCatalog.workCatalogueFor(
              'Bathroom Renovation')!,
          projectName: 'Bathroom Renovation',
          types: RenovationTypes([
            RenovationScope.cosmetic,
            RenovationScope.structural,
            RenovationScope.functional,
          ]),
        ),
    'TemplateAreaScreen (work items)': () => TemplateAreaScreen(
          template: RenovationTemplatesCatalog.workCatalogueFor(
                  'Bathroom Renovation')!
              .templateFor({'retile_floor', 'replace_toilet'}),
          projectName: 'Bathroom Renovation',
        ),
    'BiddingHubScreen': () => const BiddingHubScreen(),
    'EstimateUnavailableView': () => Scaffold(
          body: EstimateUnavailableView(
            outcome: PostLoadOutcome.unavailable,
            postId: 'post-1',
            onRetry: () {},
            showBackButton: true,
          ),
        ),
  };

  for (final screen in screens.entries) {
    group(screen.key, () {
      for (final size in _sizes.entries) {
        testWidgets('fits on ${size.key}', (tester) async {
          tester.view.physicalSize = size.value * 3;
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = _userTextScale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final layout = <String>{};
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final message = _describe(details);
            if (_isLayoutError(message)) {
              layout.add(message);
            } else {
              previous?.call(details);
            }
          };

          try {
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                builder: (context, child) =>
                    ResponsiveFrame(child: child ?? const SizedBox.shrink()),
                home: screen.value(),
              ),
            );
            await tester.pump(const Duration(milliseconds: 600));

            // Let animations and delayed navigation finish before disposal.
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 30));
          } finally {
            FlutterError.onError = previous;
          }

          for (final message in layout) {
            // ignore: avoid_print
            print('LAYOUT ${screen.key} [${size.key}]: $message');
          }
          expect(layout, isEmpty,
              reason: '${screen.key} does not fit on ${size.key}');
        });
      }
    });
  }
}
