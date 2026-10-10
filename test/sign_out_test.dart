// Signing out removes this device's push token from users/{uid} first, while
// the session can still write it, and only then signs out. Removing it from
// the auth listener, after sign-out, was always refused by the rules.
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/services/fcm_service.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';

class _FakeUser extends Fake implements User {}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.log);

  final List<String> log;
  User? _user = _FakeUser();

  @override
  User? get currentUser => _user;

  @override
  Future<void> signOut() async {
    log.add('signOut');
    _user = null;
  }
}

void main() {
  group('UserProvider.signOut', () {
    test('detaches the push token first, while still signed in', () async {
      final log = <String>[];
      final auth = _FakeAuth(log);
      await UserProvider.signOut(
        auth: auth,
        detachDevice: () async {
          // The profile write needs the session: it must still be there.
          expect(auth.currentUser, isNotNull);
          log.add('detach');
        },
      );
      expect(log, ['detach', 'signOut']);
      expect(auth.currentUser, isNull);
    });

    test('a detach that never finishes does not keep the user signed in',
        () async {
      final log = <String>[];
      final auth = _FakeAuth(log);
      await UserProvider.signOut(
        auth: auth,
        detachDevice: () => Completer<void>().future,
        detachTimeout: const Duration(milliseconds: 20),
      );
      expect(log, ['signOut']);
    });

    test('a detach that fails does not keep the user signed in', () async {
      final log = <String>[];
      await UserProvider.signOut(
        auth: _FakeAuth(log),
        detachDevice: () async => throw StateError('offline'),
      );
      expect(log, ['signOut']);
    });
  });

  group('FCMService.detachDevice', () {
    test('removes the token from the profile, then deletes it locally',
        () async {
      final log = <String>[];
      await FCMService.detachDevice(
        uid: 'builder-1',
        getToken: () async => 'token-1',
        removeFromProfile: (uid, token) async => log.add('remove $uid $token'),
        deleteLocalToken: () async => log.add('delete'),
      );
      expect(log, ['remove builder-1 token-1', 'delete']);
    });

    test('deletes the local token even when the profile write is refused',
        () async {
      // They used to share one try, so a refused write skipped the delete and
      // left the device with a live token still listed on the old account.
      final log = <String>[];
      await FCMService.detachDevice(
        uid: 'builder-1',
        getToken: () async => 'token-1',
        removeFromProfile: (uid, token) async =>
            throw FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        deleteLocalToken: () async => log.add('delete'),
      );
      expect(log, ['delete']);
    });

    test('with no account bound, only the local token is deleted', () async {
      final log = <String>[];
      await FCMService.detachDevice(
        uid: null,
        getToken: () async => 'token-1',
        removeFromProfile: (uid, token) async => log.add('remove'),
        deleteLocalToken: () async => log.add('delete'),
      );
      expect(log, ['delete']);
    });
  });

  test('every sign-out in the app goes through UserProvider.signOut', () {
    // A direct FirebaseAuth sign-out skips the token detach.
    final direct = RegExp(r'(FirebaseAuth\.instance|\b_?auth)\s*\.signOut\(');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('core/state/user_state/user_provider.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (direct.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
