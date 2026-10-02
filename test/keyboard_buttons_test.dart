// Focused fields stay on screen when the keyboard opens, and the screen's
// main button stays above the keyboard, next to that field.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/layout/app_scale.dart';
import 'package:iconstruct/core/widgets/app_buttons.dart';
import 'package:iconstruct/core/widgets/keyboard_form.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/landing_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/main_display.dart';

const _phone = Size(390, 844);
const _keyboard = 300.0;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await _loadAppFonts();
  });

  testWidgets('primary and secondary buttons share size and do not clip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(AppScale.maxUserTextScale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppPrimaryButton(label: 'Get Started', onPressed: () {}),
                  const SizedBox(height: 12),
                  AppSecondaryButton(label: 'Login', onPressed: () {}),
                  const SizedBox(height: 12),
                  const AppPrimaryButton(
                    label: 'Request quotations from nearby hardware shops',
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final primary = tester.getSize(
      find.widgetWithText(ElevatedButton, 'Get Started'),
    );
    final secondary = tester.getSize(
      find.widgetWithText(OutlinedButton, 'Login'),
    );
    expect(primary.height, greaterThanOrEqualTo(AppButtons.minHeight));
    expect(secondary.height, primary.height);
    expect(primary.width, secondary.width);
    expect(primary.width, lessThanOrEqualTo(320 - 32));

    final long = tester.getSize(
      find.widgetWithText(
        ElevatedButton,
        'Request quotations from nearby hardware shops',
      ),
    );
    expect(long.width, lessThanOrEqualTo(320 - 32));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard form keeps the field and the action above the keyboard',
    (tester) async {
      await _setPhone(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: KeyboardForm(
                  alignFieldsAboveAction: true,
                  action: AppPrimaryButton(label: 'Login', onPressed: () {}),
                  child: const Column(
                    children: [
                      TextField(decoration: InputDecoration(hintText: 'Email')),
                      SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(hintText: 'Password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EditableText).last);
      await tester.pump();
      _openKeyboard(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectFieldAndButtonAboveKeyboard(
        tester,
        button: find.widgetWithText(ElevatedButton, 'Login'),
      );
    },
  );

  testWidgets('login keeps the password field and Login above the keyboard', (
    tester,
  ) async {
    await _setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ResponsiveFrame(child: child!),
        home: const LoginScreen(),
      ),
    );

    await tester.tap(find.byType(EditableText).last);
    await tester.pump();
    _openKeyboard(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectFieldAndButtonAboveKeyboard(
      tester,
      button: find.widgetWithText(ElevatedButton, 'Login'),
    );
  });

  testWidgets('landing and intro use the same full-width action buttons', (
    tester,
  ) async {
    await _setPhone(tester, keyboard: false);

    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    await tester.pump();

    final started = tester.getSize(
      find.widgetWithText(ElevatedButton, 'Get Started'),
    );
    final login = tester.getSize(find.widgetWithText(OutlinedButton, 'Login'));
    expect(started.height, greaterThanOrEqualTo(AppButtons.minHeight));
    expect(login.height, started.height);
    expect((started.width - login.width).abs(), lessThan(1));

    await _shoot(tester, 'landing');

    await tester.pumpWidget(const MaterialApp(home: MainDisplayScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final next = tester.getSize(find.widgetWithText(ElevatedButton, 'Next'));
    expect(next.height, greaterThanOrEqualTo(AppButtons.minHeight));
    expect(next.width, greaterThan(_phone.width * 0.7));
    expect(started.width, greaterThan(_phone.width * 0.5));
    await _shoot(tester, 'intro-carousel');
  });

  testWidgets('login screenshot with the keyboard open', (tester) async {
    await _setPhone(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          builder: (context, child) => ResponsiveFrame(child: child!),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.tap(find.byType(EditableText).last);
    await tester.pump();
    _openKeyboard(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _shoot(tester, 'login-keyboard');
  });
}

void _expectFieldAndButtonAboveKeyboard(
  WidgetTester tester, {
  required Finder button,
}) {
  final field = tester.getRect(find.byType(EditableText).last);
  final action = tester.getRect(button);
  final visibleBottom = _phone.height - _keyboard;

  expect(field.bottom, lessThanOrEqualTo(visibleBottom));
  expect(action.bottom, lessThanOrEqualTo(visibleBottom));
  expect(action.top, greaterThanOrEqualTo(field.bottom - 1));
  expect(action.bottom, greaterThan(visibleBottom - 120));
  expect(tester.takeException(), isNull);
}

Future<void> _setPhone(WidgetTester tester, {bool keyboard = true}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (!keyboard) {
    addTearDown(tester.view.resetViewInsets);
  }
}

void _openKeyboard(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('/opt/cursor/artifacts/screenshots');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _loadAppFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  const poppins = 'assets/fonts/Poppins-Light.ttf';
  await load('Poppins', poppins);
  await load('Inter', 'assets/fonts/Inter-VariableFont_opsz,wght.ttf');
  await load('Bungee-Regular', 'assets/fonts/Bungee-Regular.ttf');
}
