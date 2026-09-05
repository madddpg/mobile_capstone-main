import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/fcm_service.dart';
import '../../../firebase_options.dart';
import 'auth_login_error.dart';

class EmailSendOtpResult {
  final bool success;
  final String message;

  const EmailSendOtpResult({required this.success, required this.message});
}

class EmailOtpVerificationResult {
  final bool success;
  final String message;
  final String? verificationToken;

  const EmailOtpVerificationResult({
    required this.success,
    required this.message,
    this.verificationToken,
  });
}

class EmailApiException implements Exception {
  final String message;
  final int? statusCode;

  const EmailApiException(this.message, {this.statusCode});

  @override
  String toString() => statusCode == null
      ? 'EmailApiException: $message'
      : 'EmailApiException($statusCode): $message';
}

/// Thrown when credentials are correct but the email was never verified.
///
/// Carries the identifiers the UI needs to reopen the OTP step so the builder
/// can verify immediately instead of being locked out.
class EmailNotVerifiedException implements Exception {
  final String email;
  final String uid;
  final String message;

  const EmailNotVerifiedException({
    required this.email,
    required this.uid,
    this.message =
        'Please verify your email to continue. We sent you a new code.',
  });

  @override
  String toString() => 'EmailNotVerifiedException: $message';
}

class EmailService {
  static const _functionsRegion = 'us-central1';

  final FirebaseAuth _auth;
  final http.Client _http;

  EmailService({FirebaseAuth? auth, http.Client? httpClient})
    : _auth = auth ?? FirebaseAuth.instance,
      _http = httpClient ?? http.Client();

  /// Calls a public OTP function over HTTP so a failed App Check debug token
  /// is not attached (the Functions SDK always tries to send one).
  Future<Map<String, dynamic>> _invokeAuthCallable(
    String name,
    Map<String, dynamic> data, {
    required String action,
    bool withIdToken = false,
  }) async {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final uri = Uri.https(
      '$_functionsRegion-$projectId.cloudfunctions.net',
      '/$name',
    );
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withIdToken) {
      final token = await _auth.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final http.Response response;
    try {
      response = await _http.post(
        uri,
        headers: headers,
        body: jsonEncode({'data': data}),
      );
    } catch (_) {
      throw EmailApiException(
        callableUserMessage('unavailable', action: action),
      );
    }

    debugPrint(
      'Auth callable $name status=${response.statusCode} body=${response.body}',
    );
    return _decodeCallableResponse(response, action: action);
  }

  Map<String, dynamic> _decodeCallableResponse(
    http.Response response, {
    required String action,
  }) {
    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        decoded = Map<String, dynamic>.from(body);
      }
    } catch (_) {
      decoded = null;
    }

    if (decoded != null && decoded['error'] != null) {
      final parsed = parseCallableHttpError(decoded['error']);
      debugPrint(
        'Callable HTTP error code=${parsed.code} message=${parsed.message}',
      );
      throw EmailApiException(
        callableUserMessage(
          parsed.code,
          message: parsed.message,
          action: action,
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmailApiException(
        callableUserMessage('unavailable', action: action),
      );
    }

    final result = decoded?['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return <String, dynamic>{};
  }

  /// Starts signup without creating a Firebase Auth user.
  ///
  /// The email is only an iConstruct account after [completeVerifiedRegistration]
  /// runs (correct OTP). That way a wrong code or a cancelled dialog does not
  /// lock the email as "already registered".
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty ||
        password.isEmpty ||
        firstName.isEmpty ||
        lastName.trim().isEmpty) {
      throw const EmailApiException('All fields are required.');
    }

    try {
      debugPrint('================ REGISTRATION FLOW ================');
      debugPrint('Sending OTP before creating Auth user: $trimmedEmail');

      await _invokeAuthCallable(
        'sendEmailOtp',
        {'email': trimmedEmail},
        action: 'send the code',
      );

      debugPrint('OTP send success (account not created yet)');
      debugPrint('================ REGISTRATION OTP SENT ================');
    } on EmailApiException {
      rethrow;
    } catch (e) {
      throw EmailApiException('Could not start registration. $e');
    }
  }

  /// Creates the Auth user + profile only after a correct OTP.
  ///
  /// If an earlier build already created an unverified Auth user for this
  /// email, sign in with the same password and finish verification instead
  /// of failing as "already registered".
  Future<void> completeVerifiedRegistration({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String verificationToken,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty ||
        password.isEmpty ||
        firstName.isEmpty ||
        verificationToken.isEmpty) {
      throw const EmailApiException(
        'Could not finish registration. Request a new code.',
      );
    }

    try {
      UserCredential credential;
      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          throw EmailApiException(
            authLoginErrorMessage(e.code, fallback: e.message),
          );
        }
        try {
          credential = await _auth.signInWithEmailAndPassword(
            email: trimmedEmail,
            password: password,
          );
        } on FirebaseAuthException catch (signInError) {
          throw EmailApiException(
            signInError.code == 'wrong-password' ||
                    signInError.code == 'invalid-credential'
                ? 'This email already has an account. Please sign in.'
                : authLoginErrorMessage(
                    signInError.code,
                    fallback: signInError.message,
                  ),
          );
        }
      }

      final user = credential.user;
      if (user == null) {
        throw const EmailApiException(
          'Could not finish registration. Please try again.',
        );
      }

      await user.reload();
      if (user.emailVerified) {
        await _auth.signOut();
        throw const EmailApiException(
          'This email already has an account. Please sign in.',
        );
      }

      await _invokeAuthCallable(
        'finalizeEmailOtpRegistration',
        {
          'email': trimmedEmail,
          'verificationToken': verificationToken,
        },
        action: 'finish registration',
        withIdToken: true,
      );

      await createUserDocument(
        uid: user.uid,
        firstName: firstName,
        lastName: lastName,
        email: trimmedEmail,
        isVerified: true,
      );

      await _auth.signOut();
    } on EmailApiException {
      await _auth.signOut();
      rethrow;
    } catch (e) {
      await _auth.signOut();
      throw EmailApiException('Could not finish registration. $e');
    }
  }

  /// Helper method to create a clean user document ensuring duplicates are avoided
  Future<void> createUserDocument({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    bool isVerified = false,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await userRef.set(
      {
        'firebaseUid': uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'isVerified': isVerified,
        'created_at': FieldValue.serverTimestamp(),
        'verified_at': isVerified ? FieldValue.serverTimestamp() : null,
      },
      SetOptions(merge: true),
    );
  }

  Future<EmailOtpVerificationResult> verifyOtp({
    required String email,
    required String otp,
    String? uid,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedOtp = otp.replaceAll(RegExp(r'\D'), '');

    if (trimmedEmail.isEmpty || trimmedOtp.isEmpty) {
      throw const EmailApiException('Email and OTP are required.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(trimmedOtp)) {
      throw const EmailApiException('Enter the 6-digit OTP code.');
    }

    try {
      final data = await _invokeAuthCallable(
        'confirmBuilderEmailOtp',
        {
          'email': trimmedEmail,
          'otp': trimmedOtp,
        },
        action: 'verify the code',
      );

      // confirmBuilderEmailOtp marks the account verified server-side. The
      // client is signed out at this point, so it cannot write users/{uid}.
      debugPrint('OTP verified for ${uid ?? trimmedEmail}.');

      return EmailOtpVerificationResult(
        success: true,
        message: data['message'] ?? 'Email verified successfully.',
        verificationToken: data['verificationToken']?.toString(),
      );
    } on EmailApiException {
      rethrow;
    } catch (e) {
      throw EmailApiException('Failed to verify the OTP code. $e');
    }
  }

  Future<EmailSendOtpResult> sendOtp({
    required String email,
    bool isPasswordReset = false,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty) {
      throw const EmailApiException('Email is required.');
    }

    try {
      if (isPasswordReset) {
        await _invokeAuthCallable(
          'sendEmailOtp',
          {
            'email': trimmedEmail,
            'purpose': 'password_reset',
          },
          action: 'send the code',
        );

        return const EmailSendOtpResult(
          success: true,
          message: 'OTP sent. Please check your inbox.',
        );
      }

      await _invokeAuthCallable(
        'sendEmailOtp',
        {'email': trimmedEmail},
        action: 'send the code',
      );

      return const EmailSendOtpResult(
        success: true,
        message: 'OTP sent. Please check your inbox.',
      );
    } on EmailApiException {
      rethrow;
    } catch (e) {
      throw EmailApiException('Failed to send OTP email. $e');
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw const EmailApiException('Email and password are required.');
    }

    try {
      debugPrint('================ LOGIN FLOW ================');
      debugPrint('Attempting login for email: $trimmedEmail');

      // 1. Authenticate with Firebase Auth explicitly
      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final uid = credential.user?.uid;

      if (uid == null) {
        throw const EmailApiException('Login failed: User UID is null.');
      }

      debugPrint('Firebase Auth UID: $uid');
      debugPrint('Auth Email: ${credential.user?.email}');

      // Ensure the Auth ID token is ready before any Firestore call.
      await credential.user!.getIdToken(true);

      // 2. Fetch profile ONLY with user's UID
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      DocumentSnapshot<Map<String, dynamic>> userDoc;
      try {
        userDoc = await userDocRef.get(const GetOptions(source: Source.server));
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          // Prefer a cached profile when the device is offline so builders are
          // not locked out of estimates they already have on this phone.
          userDoc = await userDocRef.get(
            const GetOptions(source: Source.cache),
          );
        } else if (e.code == 'permission-denied') {
          throw const EmailApiException(
            'Could not load your profile. Sign in again, or try in a moment.',
          );
        } else {
          rethrow;
        }
      }

      debugPrint('Fetched Firestore doc ID: ${userDocRef.id}');
      debugPrint('Firestore doc exists: ${userDoc.exists}');

      // 3. Auto-create missing profile with merge-safe defaults
      if (!userDoc.exists) {
        debugPrint(
          'Profile missing! Auto-creating Firestore document for $uid',
        );
        await userDocRef.set({
          'firebaseUid': uid,
          'email': trimmedEmail,
          'firstName': '', // Defaults
          'lastName': '', // Defaults
          'isVerified': credential.user?.emailVerified ?? false,
          'created_at': FieldValue.serverTimestamp(),
          'verified_at': null,
        }, SetOptions(merge: true));
      }

      // 4. Refuse to hand out a session to an unverified account. A fresh code
      // is sent so the caller can surface the OTP step right away.
      final profileVerified = userDoc.data()?['isVerified'] == true;
      final authVerified = credential.user?.emailVerified ?? false;
      if (!profileVerified && !authVerified) {
        debugPrint('Login blocked: email not verified for $uid');
        await _auth.signOut();
        try {
          await sendOtp(email: trimmedEmail);
        } catch (e) {
          debugPrint('Could not resend verification OTP: $e');
        }
        throw EmailNotVerifiedException(email: trimmedEmail, uid: uid);
      }

      // Initialize FCM and store the push notification token securely into users/{uid}.fcmTokens
      // Fire-and-forget or await depending on strictness. Using await to ensure token saves before proceeding.
      await FCMService().initFCM(uid);

      debugPrint('================ LOGIN COMPLETE ================');

      return credential;
    } on FirebaseAuthException catch (e) {
      throw EmailApiException(
        authLoginErrorMessage(e.code, fallback: e.message),
      );
    } catch (e) {
      if (e is EmailApiException || e is EmailNotVerifiedException) rethrow;
      throw EmailApiException('Login failed. $e');
    }
  }

  Future<void> resetPassword({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty ||
        verificationToken.isEmpty ||
        newPassword.isEmpty) {
      throw const EmailApiException('Missing fields for password reset.');
    }

    try {
      await _invokeAuthCallable(
        'resetPasswordWithToken',
        {
          'email': trimmedEmail,
          // The callable reads `verificationToken`; `token` is kept only for
          // backward compatibility with an older deployment.
          'verificationToken': verificationToken,
          'token': verificationToken,
          'newPassword': newPassword,
        },
        action: 'reset your password',
      );
    } on EmailApiException {
      rethrow;
    } catch (e) {
      throw EmailApiException('Failed to reset password. $e');
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<EmailSendOtpResult> sendCurrentUserOtp() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailApiException('No signed-in user found.');
    }
    return sendOtp(email: user.email ?? '');
  }

  User? get currentUser => _auth.currentUser;
}
