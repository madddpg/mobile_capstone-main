// Offline, a brown banner covers the top of the screen. The status bar icons
// over it must be readable, and the screen under it must not leave a second
// gap for a status bar the banner already covers.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/widgets/offline_banner.dart';
import 'package:iconstruct/core/widgets/status_bar.dart';

const _check = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _changes = EventChannel('dev.fluttercommunity.plus/connectivity_status');

void main() {
  testWidgets('offline: readable icons, and no second gap under the banner',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3);
    addTearDown(tester.view.reset);

    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_check, (_) async => ['none']);
    messenger.setMockStreamHandler(
        _changes, MockStreamHandler.inline(onListen: (_, _) {}));
    addTearDown(() {
      messenger.setMockMethodCallHandler(_check, null);
      messenger.setMockStreamHandler(_changes, null);
    });

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: darkStatusBar,
        child: OfflineBannerHost(child: child!),
      ),
      home: const Scaffold(body: SafeArea(child: Text('first line'))),
    ));
    await tester.pumpAndSettle();

    final banner = find.ancestor(
      of: find.textContaining("You're offline"),
      matching: find.byType(Material),
    ).first;
    expect(banner, findsOneWidget);

    // The screen starts right under the banner. It used to add the status
    // bar's 47 again, a band of empty cream.
    expect(tester.getTopLeft(find.text('first line')).dy,
        moreOrLessEquals(tester.getBottomLeft(banner).dy, epsilon: 1));

    // Light icons over the brown banner.
    final style = tester.binding.renderViews.first.debugLayer!
        .find<SystemUiOverlayStyle>(const Offset(100, 1));
    expect(style?.statusBarIconBrightness, Brightness.light);
  });
}
