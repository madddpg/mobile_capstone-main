import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that a builder has already been through the intro slides so the
/// app opens straight into sign-in (or the home screen) on later launches.
class OnboardingPreferences {
  const OnboardingPreferences._();

  static const String _introSeenKey = 'onboarding_intro_seen_v1';

  static Future<bool> hasSeenIntro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_introSeenKey) ?? false;
    } catch (e) {
      // Treat storage failures as "not seen": showing the intro again is a much
      // smaller problem than blocking startup.
      debugPrint('Could not read onboarding preference: $e');
      return false;
    }
  }

  static Future<void> markIntroSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_introSeenKey, true);
    } catch (e) {
      debugPrint('Could not persist onboarding preference: $e');
    }
  }

  static String _homeGuideKey(String uid) => 'home_guide_seen_v1_$uid';

  /// First-login home tour. Empty uid is treated as already seen so the overlay
  /// never traps an unsigned session.
  static Future<bool> hasSeenHomeGuide(String uid) async {
    if (uid.isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_homeGuideKey(uid)) ?? false;
    } catch (e) {
      debugPrint('Could not read home guide preference: $e');
      return false;
    }
  }

  static Future<void> markHomeGuideSeen(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_homeGuideKey(uid), true);
    } catch (e) {
      debugPrint('Could not persist home guide preference: $e');
    }
  }

  static Future<void> clearHomeGuide(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeGuideKey(uid));
    } catch (e) {
      debugPrint('Could not clear home guide preference: $e');
    }
  }

  static String _chatGuideKey(String uid) => 'chat_guide_seen_v1_$uid';

  static Future<bool> hasSeenChatGuide(String uid) async {
    if (uid.isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chatGuideKey(uid)) ?? false;
    } catch (e) {
      debugPrint('Could not read chat guide preference: $e');
      return false;
    }
  }

  static Future<void> markChatGuideSeen(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatGuideKey(uid), true);
    } catch (e) {
      debugPrint('Could not persist chat guide preference: $e');
    }
  }

  static Future<void> clearChatGuide(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatGuideKey(uid));
    } catch (e) {
      debugPrint('Could not clear chat guide preference: $e');
    }
  }
}
