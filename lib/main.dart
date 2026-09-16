import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:iconstruct/core/firebase/app_check_gate.dart';
import 'package:iconstruct/core/layout/app_scale.dart';
import 'package:iconstruct/core/services/fcm_service.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'firebase_options.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/offline_banner.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/display_screen.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
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
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await AppCheckGate.activate();
    } catch (e, st) {
      debugPrint('Bootstrap failed: $e\n$st');
      runApp(_BootstrapErrorApp(error: e));
      return;
    }

    runApp(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'iConstruct',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Scales text from the screen width (times the phone's font setting,
      // capped) and centers a phone-width column on tablets. See AppScale.
      builder: (context, child) {
        return ResponsiveFrame(
          child: OfflineBannerHost(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const DisplayScreen(),
    );
  }
}
