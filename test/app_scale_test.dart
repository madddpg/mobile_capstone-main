import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/core/layout/app_scale.dart';

void main() {
  group('AppScale.widthFactor', () {
    test('keeps written sizes at the design width', () {
      expect(AppScale.widthFactor(390), 1.0);
    });

    test('shrinks text on a small phone, but not below the floor', () {
      expect(AppScale.widthFactor(360), closeTo(0.923, 0.001));
      expect(AppScale.widthFactor(320), AppScale.minWidthFactor);
    });

    test('grows text on a large phone, but not past the ceiling', () {
      expect(AppScale.widthFactor(430), closeTo(1.103, 0.001));
      expect(AppScale.widthFactor(800), AppScale.maxWidthFactor);
    });
  });

  group('AppScale.userFactor', () {
    test('ignores a font setting smaller than normal', () {
      expect(AppScale.userFactor(const TextScaler.linear(0.8)), 1.0);
    });

    test('honours a larger font setting up to the cap', () {
      expect(AppScale.userFactor(const TextScaler.linear(1.2)),
          closeTo(1.2, 0.001));
      expect(AppScale.userFactor(const TextScaler.linear(2.0)),
          AppScale.maxUserTextScale);
    });
  });

  test('screen and font setting combine, under one ceiling', () {
    final scaler = AppScale.textScalerFor(
      width: 480,
      system: const TextScaler.linear(1.3),
    );
    // 1.2 × 1.3 = 1.56, held at 1.5 so the largest text still fits.
    expect(scaler.scale(10), closeTo(15, 0.001));
  });

  group('ResponsiveFrame', () {
    Future<MediaQueryData> frameOn(WidgetTester tester, Size size) async {
      late MediaQueryData seen;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ResponsiveFrame(
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.of(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('a phone keeps its full width', (tester) async {
      final media = await frameOn(tester, const Size(360, 780));
      expect(media.size.width, 360);
      expect(media.textScaler.scale(10), closeTo(9.23, 0.01));
    });

    testWidgets('a tablet lays out in a centered column', (tester) async {
      final media = await frameOn(tester, const Size(800, 1280));
      expect(media.size.width, AppScale.maxContentWidth);
      expect(media.size.height, 1280);
      expect(find.byType(ColoredBox), findsOneWidget);
      // The column's own width sets the text size, not the whole tablet.
      expect(media.textScaler.scale(10), closeTo(12, 0.001));
    });
  });
}
