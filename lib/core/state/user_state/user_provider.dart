import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/core/services/fcm_service.dart';
import 'user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserProvider() {
    _initListener();
  }

  String? _fcmBoundUid;

  /// The one way to sign out of the app.
  ///
  /// This device's push token is removed from users/{uid} first, while the
  /// session can still write that document. Removing it after sign-out, as
  /// the auth listener used to, was always refused by the rules' owner check,
  /// so the token stayed on the profile.
  ///
  /// The removal gets [detachTimeout] at most. Offline, a Firestore write
  /// can wait a long time for the server, and the Log out button must not
  /// wait with it; the write is then sent the next time this account signs
  /// in here. [auth] and [detachDevice] are for tests.
  static Future<void> signOut({
    FirebaseAuth? auth,
    Future<void> Function()? detachDevice,
    Duration detachTimeout = const Duration(seconds: 5),
  }) async {
    try {
      await (detachDevice ?? FCMService().detachFromUser)()
          .timeout(detachTimeout);
    } catch (e) {
      // A detach that fails or times out must never keep the user signed in.
      debugPrint('Push token not detached before sign-out: $e');
    }
    await (auth ?? FirebaseAuth.instance).signOut();
  }

  void _initListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        _subscribeToUserData(user.uid);
        // Register the device token once per signed-in uid (authStateChanges
        // also fires on token refresh / app resume).
        if (_fcmBoundUid != user.uid) {
          _fcmBoundUid = user.uid;
          await FCMService().initFCM(user.uid);
        }
      } else {
        // Signed out: clear local state only. The token was detached before
        // sign-out by [signOut]; nothing can write users/{uid} from here.
        _fcmBoundUid = null;
        _userSubscription?.cancel();
        _currentUser = null;
        notifyListeners();
        // A session that ended without [signOut] (expired or revoked) still
        // has its token on this device. Delete it locally so the next account
        // here does not get this one's pushes.
        final fcm = FCMService();
        if (fcm.isBound) await fcm.releaseDevice();
      }
    });
  }

  void _subscribeToUserData(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data() as Map<String, dynamic>;
              // Use user.email from auth if the doc doesn't have an email field yet
              if (!data.containsKey('email')) {
                data['email'] = _auth.currentUser?.email ?? '';
              }
              _currentUser = UserModel.fromMap(uid, data);
              notifyListeners();
            }
          },
          onError: (error) {
            debugPrint('Error listening to user data: $error');
          },
        );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
