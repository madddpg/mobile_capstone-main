import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Starts App Check and remembers whether a token was accepted.
///
/// Firestore returns `permission-denied` when App Check is enforced and the
/// debug token is missing from Firebase Console → App Check → Manage debug
/// tokens. Call [activate] before any Firestore / Functions use.
class AppCheckGate {
  static String? lastError;
  static bool tokenReady = false;

  static Future<void> activate() async {
    lastError = null;
    tokenReady = false;

    try {
      await FirebaseAppCheck.instance.activate(
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
            'App Check token was empty.\n$_debugTokenSteps',
          );
          return;
        }
        tokenReady = true;
        debugPrint('App Check token was accepted by Firebase.');
      } catch (e) {
        lastError = e.toString();
        debugPrint('App Check attestation failed: $e\n$_debugTokenSteps');
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('App Check could not start: $e\n$_debugTokenSteps');
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
}
