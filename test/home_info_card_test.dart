// The home screen's hardware shops: three to a page, so the screen is short
// to scroll. "How iConstruct Works" was taken off the home screen.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/screens/main_home_screen.dart';

List<RankedShop> _shops(int count) => [
      for (var i = 1; i <= count; i++)
        RankedShop(
          uid: 'shop-$i',
          shopName: 'Hardware $i',
          address: 'Rizal Street',
          barangay: 'Real',
          city: 'Calamba',
          quotationCount: i,
        ),
    ];

Future<void> _pumpHome(WidgetTester tester, List<RankedShop> shops) async {
  tester.view.physicalSize = const Size(390, 2400) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: MaterialApp(
        home: MainHomeScreen(loadShops: () async => shops),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadFonts() async {
  Future<void> load(String family, String asset) =>
      (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  const poppins = 'assets/fonts/Poppins-Light.ttf';
  const inter = 'assets/fonts/Inter-VariableFont_opsz,wght.ttf';
  await load('Poppins', poppins);
  await load('Inter', inter);
  for (final variant in [
    'regular',
    for (var w = 100; w <= 900; w += 100) '$w',
  ]) {
    await load('Poppins_$variant', poppins);
    await load('Inter_$variant', inter);
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('the welcome has its tagline and no paragraph under it',
      (tester) async {
    await _pumpHome(tester, _shops(2));
    expect(find.text('Welcome to iConstruct!'), findsOneWidget);
    expect(find.text('Where builders connect to smarter solutions.'),
        findsOneWidget);
    expect(find.textContaining('Plan the materials for your home'),
        findsNothing);
  });

  testWidgets('shops show three to a page, with page controls',
      (tester) async {
    await _pumpHome(tester, _shops(7));

    expect(find.text('Hardware 1'), findsOneWidget);
    expect(find.text('Hardware 3'), findsOneWidget);
    expect(find.text('Hardware 4'), findsNothing);
    expect(find.textContaining('Page 1 of 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Hardware 1'), findsNothing);
    expect(find.text('Hardware 4'), findsOneWidget);
    expect(find.text('Hardware 6'), findsOneWidget);
    expect(find.textContaining('Shops 4–6 of 7'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Hardware 7'), findsOneWidget);
    expect(find.textContaining('Page 3 of 3'), findsOneWidget);
    // The last page has no next.
    final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
    expect(next.onPressed, isNull);

    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('Hardware 4'), findsOneWidget);
  });

  testWidgets('three shops or fewer need no page controls', (tester) async {
    await _pumpHome(tester, _shops(3));
    expect(find.text('Hardware 3'), findsOneWidget);
    expect(find.byTooltip('Next page'), findsNothing);
  });

  testWidgets('How iConstruct Works is no longer on the home screen',
      (tester) async {
    await _pumpHome(tester, _shops(4));

    // Neither the tab nor its steps.
    expect(find.text('How It Works'), findsNothing);
    expect(find.textContaining('How iConstruct Works'), findsNothing);
    expect(find.text('Estimate your materials'), findsNothing);
    expect(find.text('Compare and choose'), findsNothing);

    // The shops stand alone under their own heading, with no tab to tap.
    expect(find.text('Hardware Shops'), findsOneWidget);
    expect(find.text('Hardware 1'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Hardware Shops'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });
}
