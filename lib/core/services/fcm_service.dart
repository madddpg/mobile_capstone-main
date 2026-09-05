import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:iconstruct/features/bidding/screens/quotations_screen.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';
import 'package:iconstruct/firebase_options.dart';
import 'package:iconstruct/main.dart' show navigatorKey;

/// Shown as the Android notification channel for bid / quotation pushes.
const String kBidNotificationChannelId = 'iconstruct_bids';
const String kBidNotificationChannelName = 'Supplier quotations';

/// Must be a top-level function for background isolate delivery.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background FCM: ${message.messageId} type=${message.data['type']}');
}

class FCMService {
  FCMService._internal();
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _boundUid;
  StreamSubscription? _tokenRefreshSub;
  StreamSubscription? _onMessageSub;
  StreamSubscription? _onOpenedSub;

  Future<void> initFCM(String uid) async {
    if (uid.isEmpty) return;

    try {
      await _ensureLocalNotifications();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permission denied');
        return;
      }

      // iOS: show system banners while app is open.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _messaging.getToken();
      if (token != null) {
        await saveUserToken(uid, token);
      }

      _boundUid = uid;

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        final activeUid = _boundUid;
        if (activeUid != null) {
          saveUserToken(activeUid, newToken);
        }
      });

      if (_initialized) return;
      _initialized = true;

      await _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      await _onOpenedSub?.cancel();
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        handleNotificationNavigation,
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          handleNotificationNavigation(initialMessage);
        });
      }
    } catch (e, st) {
      debugPrint('Error initializing FCM: $e\n$st');
    }
  }

  Future<void> _ensureLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          handleNotificationNavigation(
            RemoteMessage(data: data.map((k, v) => MapEntry(k, '$v'))),
          );
        } catch (e) {
          debugPrint('Failed to parse notification payload: $e');
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        kBidNotificationChannelId,
        kBidNotificationChannelName,
        description: 'Alerts when hardware shops send quotations',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title'] ??
        _foregroundTitle(message.data['type']);
    final body = notification?.body ??
        message.data['message'] ??
        message.data['body'] ??
        _foregroundBody(message.data['type']);

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kBidNotificationChannelId,
          kBidNotificationChannelName,
          channelDescription: 'Alerts when hardware shops send quotations',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> saveUserToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      debugPrint('FCM token saved for users/$uid');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Call on sign-out. Removes this device's token from the previous user's doc
  /// and deletes the local token, so the next account on this device does not
  /// keep receiving the previous user's quotation / chat pushes.
  Future<void> detachFromUser() async {
    final previousUid = _boundUid;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _boundUid = null;

    try {
      final token = await _messaging.getToken();
      if (previousUid != null && previousUid.isNotEmpty && token != null) {
        await _firestore.collection('users').doc(previousUid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
      await _messaging.deleteToken();
      debugPrint('FCM token detached from users/$previousUid');
    } catch (e) {
      debugPrint('Error detaching FCM token: $e');
    }
  }

  void handleNotificationNavigation(RemoteMessage message) {
    if (message.data.isEmpty) return;

    final type = message.data['type'];
    final postId = message.data['postId'];
    final conversationId = message.data['conversationId'];
    final notificationId = message.data['notificationId'];

    if (notificationId != null && notificationId.toString().isNotEmpty) {
      _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true})
          .catchError(
            (e) => debugPrint('Failed to mark notification read: $e'),
          );
    }

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('navigatorKey unavailable; cannot open notification target');
      return;
    }

    if ((type == 'chat_unlocked' || type == 'chat_message') &&
        conversationId != null &&
        conversationId.toString().isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            conversationId: conversationId.toString(),
          ),
        ),
      );
      return;
    }

    if (type == 'new_quotation' &&
        postId != null &&
        postId.toString().isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => QuotationsScreen(postId: postId.toString()),
        ),
      );
    }
  }

  String _foregroundTitle(dynamic type) {
    switch (type) {
      case 'chat_unlocked':
        return 'Chat unlocked';
      case 'chat_message':
        return 'New shop message';
      default:
        return 'New quotation received';
    }
  }

  String _foregroundBody(dynamic type) {
    switch (type) {
      case 'chat_unlocked':
        return 'You can now message the selected hardware shop.';
      case 'chat_message':
        return 'A hardware shop sent you a message.';
      default:
        return 'A hardware shop submitted a quotation for your estimate.';
    }
  }
}
