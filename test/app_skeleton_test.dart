import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/widgets/app_skeleton.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSkeleton(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('a circle bone matches the avatar size it stands in for', (
    tester,
  ) async {
    await pumpSkeleton(
      tester,
      const Center(child: AppSkeleton.circle(size: 40)),
    );

    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(tester.getSize(find.byType(AppSkeleton)), const Size(40, 40));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a card list renders one placeholder per row', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpSkeleton(tester, const AppSkeletonCardList(count: 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppSkeletonCard), findsNWidgets(3));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    handle.dispose();
  });

  testWidgets('chat, profile, and estimate layouts share the shimmer', (
    tester,
  ) async {
    for (final child in const [
      AppSkeletonChatThread(),
      AppSkeletonProfile(),
      AppSkeletonChecklist(count: 4),
      AppSkeletonEstimateBody(),
    ]) {
      await pumpSkeleton(tester, child);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AppSkeleton), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('phone skeleton screenshot when SKELETON_SHOT is set', (
    tester,
  ) async {
    // Capturing more than one image in a single widget-test process stalls
    // the raster thread on this toolchain, so each shot is a separate run.
    // The suite skips this unless the env var names one preview.
    final shot = Platform.environment['SKELETON_SHOT'];
    if (shot == null || shot.isEmpty) return;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    final preview = switch (shot) {
      'home-shops-skeleton' => const _HomeShopsSkeletonPreview(),
      'notification-list-skeleton' => const _NotificationListSkeletonPreview(),
      'estimate-detail-skeleton' => const _EstimateDetailSkeletonPreview(),
      _ => throw StateError('Unknown SKELETON_SHOT $shot'),
    };

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: true,
              padding: const EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: child!,
          );
        },
        home: RepaintBoundary(
          key: const ValueKey('skeleton-shot'),
          child: preview,
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('skeleton-shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/opt/cursor/artifacts/screenshots/$shot.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    exit(0);
  });
}

class _HomeShopsSkeletonPreview extends StatelessWidget {
  const _HomeShopsSkeletonPreview();

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEBE0CC);
    const darkBlue = Color(0xFF2C3E50);
    const midBlue = Color(0xFF648DB6);

    return Scaffold(
      backgroundColor: cream,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [darkBlue, midBlue],
                  stops: [0.3, 1],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                children: [
                  const SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: darkBlue,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: cream,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Welcome to iConstruct!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C3E50),
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Where builders connect to smarter solutions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: darkBlue,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 30,
                            offset: Offset(0, 15),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  color: cream,
                                  size: 28,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Hardware Shops',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      color: cream,
                                    ),
                                  ),
                                ),
                                Text(
                                  'View All',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cream,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            AppSkeletonCardList(
                              count: 3,
                              scrollable: false,
                              cardColor: Colors.white,
                              cardRadius: 18,
                              cardPadding: EdgeInsets.all(14),
                              cardMargin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.zero,
                              leadingCircle: true,
                              leadingSize: 34,
                              textLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _PreviewPill(active: 'Home'),
        ],
      ),
    );
  }
}

class _NotificationListSkeletonPreview extends StatelessWidget {
  const _NotificationListSkeletonPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF648DB6), Color(0xFFE0D7C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4E7CB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF2F3E4F),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Stay updated with project activity',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: AppSkeletonCardList(
                  count: 5,
                  cardColor: Color(0xFFF4E7CB),
                  cardRadius: 20,
                  cardPadding: EdgeInsets.all(16),
                  cardMargin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leadingCircle: true,
                  leadingSize: 12,
                  textLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String active;

  const _PreviewPill({required this.active});

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEDE4D4);
    const navy = Color(0xFF2C3E50);

    Widget slot(IconData icon, String label) {
      final on = label == active;
      return Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: on ? navy : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: on ? cream : navy),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: on ? cream : navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cream,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                slot(Icons.home_rounded, 'Home'),
                slot(Icons.construction_rounded, 'Bidding'),
                slot(Icons.chat_bubble_rounded, 'Chat'),
                slot(Icons.folder_rounded, 'Files'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstimateDetailSkeletonPreview extends StatelessWidget {
  const _EstimateDetailSkeletonPreview();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF648DB6),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2C3E50), Color(0xFF648DB6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          AppSkeletonEstimateBody(),
          _PreviewPill(active: 'Bidding'),
        ],
      ),
    );
  }
}
