import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Builder ↔ shop thread that unlocks after a quotation is accepted.
///
/// Same Firebase project as the web shop dashboard. Conversation docs and
/// Cloud Functions are owned by the web repo — this client only reads/writes
/// messages and may create a thread if the function is slow.

/// Whether one conversation counts as unread for [uid].
///
/// Kept as a plain function over the document map so the rule can be tested
/// without a Firestore fake. Three things make a conversation unread: the last
/// message came from someone else, it has a timestamp, and the user has either
/// never opened the thread or last opened it before that message arrived.
bool conversationIsUnread(Map<String, dynamic> data, String uid) {
  if (data['lastSenderId'] == uid) return false;

  final lastAt = data['lastMessageAt'];
  if (lastAt is! Timestamp) return false;

  final readMap = data['readAt'];
  final readAt = readMap is Map ? readMap[uid] : null;
  if (readAt is! Timestamp) return true;

  return lastAt.compareTo(readAt) > 0;
}

class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static String conversationId(String projectId, String shopId) =>
      '${projectId}_$shopId';

  String? get _uid => _auth.currentUser?.uid;

  /// List my chats (builder side).
  ///
  /// The builder uid is stored inconsistently across clients — the mobile app
  /// writes both `builderId` and `userId`, but a web/function-created thread may
  /// set only `userId`. Query both and merge so those threads are not invisible.
  /// `orderBy` is dropped (no `userId + lastMessageAt` index exists) and the
  /// merged list is sorted client-side.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchMyConversations() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    final byBuilder = _db
        .collection('conversations')
        .where('builderId', isEqualTo: uid)
        .snapshots();
    final byUser = _db
        .collection('conversations')
        .where('userId', isEqualTo: uid)
        .snapshots();

    QuerySnapshot<Map<String, dynamic>>? latestBuilder;
    QuerySnapshot<Map<String, dynamic>>? latestUser;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> merge() {
      final seen = <String>{};
      final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final snap in [latestBuilder, latestUser]) {
        for (final d in snap?.docs ?? const []) {
          if (seen.add(d.id)) out.add(d);
        }
      }
      out.sort((a, b) {
        final ta = a.data()['lastMessageAt'];
        final tb = b.data()['lastMessageAt'];
        final da = ta is Timestamp ? ta.toDate() : DateTime(1970);
        final db = tb is Timestamp ? tb.toDate() : DateTime(1970);
        return db.compareTo(da);
      });
      return out;
    }

    final controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
    final subs = <StreamSubscription>[];
    subs.add(byBuilder.listen((s) {
      latestBuilder = s;
      if (!controller.isClosed) controller.add(merge());
    }, onError: controller.addError));
    subs.add(byUser.listen((s) {
      latestUser = s;
      if (!controller.isClosed) controller.add(merge());
    }, onError: controller.addError));
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }

  /// Live messages in one thread — newest 200. Ordered descending so the query
  /// window tracks the latest messages (an ascending `limit` froze the view at
  /// the oldest 200); reverse for display.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String conversationId,
  ) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConversation(
    String conversationId,
  ) {
    return _db.collection('conversations').doc(conversationId).snapshots();
  }

  /// Send as builder. Message + conversation-summary are written in one batch so
  /// the inbox preview can never drift from the last message that was stored.
  /// Marks a conversation read for the signed-in user.
  ///
  /// Stored as `readAt.<uid>` rather than a single field so the shop client
  /// can keep its own marker in the same document without the two overwriting
  /// each other. Called when a thread is opened and whenever new messages
  /// arrive while it is on screen.
  Future<void> markConversationRead(String conversationId) async {
    final uid = _uid;
    if (uid == null || conversationId.trim().isEmpty) return;
    try {
      await _db.collection('conversations').doc(conversationId).set({
        'readAt': {uid: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (_) {
      // A failed marker only means the badge lingers; never break the thread.
    }
  }

  /// Number of conversations holding a message from the other party that this
  /// user has not opened since.
  ///
  /// Derived from [watchMyConversations] rather than a separate query, so it
  /// inherits the same builderId/userId merge and needs no extra index. A
  /// conversation counts when the last message came from someone else and
  /// either was never read or arrived after the last read.
  Stream<int> watchUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream<int>.value(0);

    return watchMyConversations()
        .map((docs) =>
            docs.where((d) => conversationIsUnread(d.data(), uid)).length)
        .handleError((_) => 0);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('You have been signed out. Please sign in again.');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final capped =
        trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed;

    final convRef = _db.collection('conversations').doc(conversationId);
    final batch = _db.batch();
    batch.set(convRef.collection('messages').doc(), {
      'senderId': uid,
      'senderRole': 'builder',
      'text': capped,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      convRef,
      {
        'lastMessage': capped.length > 200 ? capped.substring(0, 200) : capped,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Fallback if Cloud Function has not created the thread yet.
  Future<String> ensureConversationAfterAccept({
    required String projectId,
    required String shopId,
    required String quotationId,
    required String projectTitle,
    String shopName = '',
    String builderName = 'Builder',
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('You have been signed out. Please sign in again.');
    }
    final id = conversationId(projectId, shopId);
    final ref = _db.collection('conversations').doc(id);
    if (await _conversationExists(ref) == true) return id;

    // merge:true so a conversation the web Cloud Function created in the race
    // window between the existence check and this write is not clobbered.
    await ref.set({
      'projectId': projectId,
      'quotationId': quotationId,
      'shopId': shopId,
      'shopName': shopName,
      'builderId': uid,
      'userId': uid,
      'builderName': builderName,
      'projectTitle': projectTitle,
      'status': 'open',
      'lastMessage': 'Quote accepted — you can now message each other.',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return id;
  }

  /// Prefer the Cloud Function thread; fall back to a client create.
  Future<String> waitOrEnsureConversation({
    required String projectId,
    required String shopId,
    required String quotationId,
    required String projectTitle,
    String shopName = '',
    String builderName = 'Builder',
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final id = conversationId(projectId, shopId);
    final ref = _db.collection('conversations').doc(id);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final exists = await _conversationExists(ref);
      if (exists == true) return id;
      if (exists == null) break;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    return ensureConversationAfterAccept(
      projectId: projectId,
      shopId: shopId,
      quotationId: quotationId,
      projectTitle: projectTitle,
      shopName: shopName,
      builderName: builderName,
    );
  }

  /// Missing-doc reads are often denied until the thread exists.
  /// Returns null when rules hide the missing document as permission-denied.
  Future<bool?> _conversationExists(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return (await ref.get()).exists;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }
}
