import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:iconstruct/core/firebase/app_check_gate.dart';
import 'package:iconstruct/core/layout/app_scale.dart';
import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/core/perf/perf_log.dart';
import 'package:iconstruct/core/services/fcm_service.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'firebase_options.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/offline_banner.dart';
import 'package:iconstruct/core/widgets/status_bar.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/display_screen.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      PerfLog.begin('app_launch');
      WidgetsFlutterBinding.ensureInitialized();

      // Every screen is laid out for a portrait phone — the offset panels and
      // proportional insets assume it. Lock rotation so a landscape flip cannot
      // break those layouts.
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Route framework errors somewhere visible instead of only the console.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Required so bid pushes still deliver when the app is backgrounded/killed.
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        await AppCheckGate.activate();
      } catch (e, st) {
        debugPrint('Bootstrap failed: $e\n$st');
        runApp(_BootstrapErrorApp(error: e));
        return;
      }

      UserProvider.onSessionEnded = _returnToSignIn;

      runApp(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
          child: const MyApp(),
        ),
      );
      PerfLog.screenShown('app_launch');
      PerfLog.contentReady('app_launch');
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}

/// Shown only when Firebase / App Check initialisation throws — otherwise the
/// app was a silent white screen with no way to retry.
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "iConstruct couldn't start",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection and reopen the app.',
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Firebase ended the session by itself: it expired, was revoked, or the
/// account was removed. Starting with a stale session on a phone left the
/// builder on home with every request refused, and no way back to sign-in
/// short of reinstalling. Back to sign-in, saying why.
void _returnToSignIn() {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showAppMessage(
      context,
      const SnackBar(
        content: Text('Your session has ended. Please log in again.'),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [NavigationHistory.instance],
      title: 'iConstruct',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Scales text from the screen width (times the phone's font setting,
      // capped) and centers a phone-width column on tablets. See AppScale.
      builder: (context, child) {
        // Dark status bar icons unless a screen asks for light ones: without
        // a default, a cream screen kept the light icons of a navy one.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: darkStatusBar,
          child: ResponsiveFrame(
            // Above the navigator, so a message shows over any sheet or
            // dialog.
            child: AppMessageHost(
              child: OfflineBannerHost(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
      home: const DisplayScreen(),
    );
  }
}
