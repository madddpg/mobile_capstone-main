import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Starts App Check and remembers whether a token was accepted.
///
/// Firestore returns `permission-denied` when App Check is enforced and the
/// app cannot attest: on Android because the debug token is missing from
/// Firebase Console → App Check → Manage debug tokens, on web because the
/// build carries no reCAPTCHA site key. Call [activate] before any Firestore /
/// Functions use.
class AppCheckGate {
  static String? lastError;
  static bool tokenReady = false;

  /// reCAPTCHA v3 site key for the web build, passed at build time:
  ///
  /// ```
  /// flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=6Lxxxx
  /// ```
  ///
  /// Not a secret — any browser that loads the page can read it — but it
  /// belongs to one Firebase project, so it is supplied rather than hard-coded.
  static const String webSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

  /// Web build with no key to attest with.
  static bool get webKeyMissing => kIsWeb && webSiteKey.isEmpty;

  static Future<void> activate() async {
    lastError = null;
    tokenReady = false;

    // There is no provider to start on web without a site key, and starting
    // App Check anyway only throws. The app still works while enforcement is
    // off, so say what is missing and carry on rather than failing startup.
    if (webKeyMissing) {
      lastError =
          'No reCAPTCHA site key in this web build, so App Check cannot attest.';
      debugPrint('App Check skipped on web.\n$_webSetupSteps');
      return;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: kIsWeb ? ReCaptchaV3Provider(webSiteKey) : null,
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.deviceCheck,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

      try {
        final token = await FirebaseAppCheck.instance.getToken(true);
        if (token == null || token.isEmpty) {
          lastError = 'App Check returned an empty token.';
          debugPrint(
            'App Check token was empty.\n${kIsWeb ? _webSetupSteps : _debugTokenSteps}',
          );
          return;
        }
        tokenReady = true;
        debugPrint('App Check token was accepted by Firebase.');
      } catch (e) {
        lastError = e.toString();
        debugPrint(
          'App Check attestation failed: $e\n'
          '${kIsWeb ? _webSetupSteps : _debugTokenSteps}',
        );
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint(
        'App Check could not start: $e\n'
        '${kIsWeb ? _webSetupSteps : _debugTokenSteps}',
      );
    }
  }

  /// Force a fresh App Check token after the user registers a debug secret.
  static Future<bool> refreshToken() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      if (token == null || token.isEmpty) {
        lastError = 'App Check returned an empty token.';
        tokenReady = false;
        return false;
      }
      lastError = null;
      tokenReady = true;
      return true;
    } catch (e) {
      lastError = e.toString();
      tokenReady = false;
      return false;
    }
  }

  static const _debugTokenSteps =
      'Next steps:\n'
      '1) In Logcat / Debug Console search: DebugAppCheckProvider\n'
      '2) Copy the UUID debug secret\n'
      '3) Firebase Console → App Check → ⋮ → Manage debug tokens → Add\n'
      '4) App Check → APIs → Cloud Firestore → Monitor (not Enforce) while developing\n'
      '5) Wait a minute, then full-restart the app (not hot reload)';

  static const _webSetupSteps =
      'Next steps for the web build:\n'
      '1) Firebase Console → App Check → Apps → your Web app → reCAPTCHA v3\n'
      '2) Copy the site key it shows\n'
      '3) Rebuild: flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=<key>\n'
      '4) Until then keep App Check → APIs on Monitor, not Enforce';
}
