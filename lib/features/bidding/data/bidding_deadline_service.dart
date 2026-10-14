import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:iconstruct/features/bidding/data/bidding_schedule.dart';
import 'package:iconstruct/features/bidding/data/quotation_accept_service.dart';

/// Represents an audit trail entry for a change to the quotation deadline.
class DeadlineHistoryEntry {
  final String id;
  final String changedBy;
  final DateTime previousDeadline;
  final DateTime newDeadline;
  final String reason;
  final String? note;
  final DateTime changedAt;

  const DeadlineHistoryEntry({
    required this.id,
    required this.changedBy,
    required this.previousDeadline,
    required this.newDeadline,
    required this.reason,
    this.note,
    required this.changedAt,
  });

  factory DeadlineHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return DeadlineHistoryEntry(
      id: doc.id,
      changedBy: data['changedBy']?.toString() ?? '',
      previousDeadline: parseDate(data['previousDeadline']),
      newDeadline: parseDate(data['newDeadline']),
      reason: data['reason']?.toString() ?? '',
      note: data['note']?.toString(),
      changedAt: parseDate(data['changedAt']),
    );
  }
}

/// Service managing bidding deadlines, extensions, prior-notice validations,
/// audit history, and shop notifications.
class BiddingDeadlineService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  BiddingDeadlineService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  static final BiddingDeadlineService instance = BiddingDeadlineService();

  /// Default prior notice policy requirement for shortening deadlines (24 hours).
  static const Duration defaultPriorNotice = Duration(hours: 24);

  /// Requests a change to the quotation deadline.
  ///
  /// First attempts the server-authoritative Cloud Function `changeBiddingDeadline`
  /// so that push notifications and audit trails are executed server-side.
  /// If Cloud Functions are unavailable or offline, executes a resilient Firestore transaction.
  Future<void> changeDeadline({
    required String postId,
    required DateTime newDeadline,
    required String reason,
    String? note,
    Duration priorNotice = defaultPriorNotice,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to change the deadline.');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Please specify a reason for changing the quotation deadline.');
    }

    // Try Cloud Function first for server-authoritative processing and notification fan-out
    try {
      final callable = _functions.httpsCallable('changeBiddingDeadline');
      await callable.call(<String, dynamic>{
        'postId': postId,
        'newDeadline': newDeadline.toIso8601String(),
        'reason': trimmedReason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
      return;
    } catch (e) {
      debugPrint('Cloud Function changeBiddingDeadline not available or failed: $e. Using Firestore transaction.');
    }

    // Client-side fallback transaction
    final postRef = _firestore.collection('projectPosts').doc(postId);

    await _firestore.runTransaction((txn) async {
      final postSnap = await txn.get(postRef);
      if (!postSnap.exists) {
        throw Exception('Posted project not found.');
      }

      final postData = postSnap.data() ?? <String, dynamic>{};
      if (!isPostedEstimateOwner(postData, user.uid)) {
        throw Exception('You do not have permission to modify this project.');
      }

      final schedule = BiddingSchedule.fromMap(postData);
      final now = DateTime.now();

      final validationError = BiddingSchedule.validateDeadlineChange(
        currentEndsAt: schedule.endsAt,
        newEndsAt: newDeadline,
        startsAt: schedule.startsAt,
        now: now,
        priorNoticeRequired: priorNotice,
      );

      if (validationError != null) {
        throw Exception(validationError);
      }

      final newStatus = BiddingSchedule.resolveStatus(
        startsAt: schedule.startsAt,
        endsAt: newDeadline,
        storedStatus: postData['status']?.toString(),
        now: now,
      );

      final changeCount = schedule.deadlineChangeCount + 1;

      // Update post document
      txn.update(postRef, {
        'biddingEndsAt': Timestamp.fromDate(newDeadline),
        if (!postData.containsKey('originalBiddingEndsAt'))
          'originalBiddingEndsAt': Timestamp.fromDate(schedule.endsAt),
        'biddingStatus': newStatus.name,
        'deadlineChangeCount': changeCount,
        'lastDeadlineChangedAt': FieldValue.serverTimestamp(),
        'lastDeadlineChangeReason': trimmedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write to biddingDeadlineHistory subcollection
      final historyRef = postRef.collection('biddingDeadlineHistory').doc();
      txn.set(historyRef, {
        'changedBy': user.uid,
        'previousDeadline': Timestamp.fromDate(schedule.endsAt),
        'newDeadline': Timestamp.fromDate(newDeadline),
        'reason': trimmedReason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'changedAt': FieldValue.serverTimestamp(),
      });
    });

    // Notify participating shops who submitted quotations
    _notifyShopsOfDeadlineChange(
      postId: postId,
      newDeadline: newDeadline,
      reason: trimmedReason,
    ).catchError((e) {
      debugPrint('Failed to send shop notifications: $e');
    });
  }

  /// Notifies shops that have submitted quotations or are involved with this project.
  Future<void> _notifyShopsOfDeadlineChange({
    required String postId,
    required DateTime newDeadline,
    required String reason,
  }) async {
    try {
      final postDoc = await _firestore.collection('projectPosts').doc(postId).get();
      final postData = postDoc.data() ?? {};
      final projectName = postData['projectName'] ?? 'renovation project';

      final quotations = await _firestore
          .collection('projectPosts')
          .doc(postId)
          .collection('quotations')
          .get();

      if (quotations.docs.isEmpty) return;

      final formattedDeadline = BiddingSchedule.formatDateTime(newDeadline);
      final title = 'Bidding Deadline Updated';
      final message = 'The quotation deadline for "$projectName" was updated to $formattedDeadline. Reason: $reason.';

      final batch = _firestore.batch();
      final notifiedShopUids = <String>{};

      for (final doc in quotations.docs) {
        final data = doc.data();
        final shopId = data['shopId']?.toString().trim() ?? doc.id;
        if (shopId.isEmpty || notifiedShopUids.contains(shopId)) continue;
        notifiedShopUids.add(shopId);

        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'type': 'bidding_deadline_changed',
          'postId': postId,
          'recipientId': shopId,
          'recipientType': 'shop',
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error notifying shops: $e');
    }
  }

  /// Streams the deadline change history for a given project.
  Stream<List<DeadlineHistoryEntry>> streamDeadlineHistory(String postId) {
    return _firestore
        .collection('projectPosts')
        .doc(postId)
        .collection('biddingDeadlineHistory')
        .orderBy('changedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeadlineHistoryEntry.fromDoc(doc))
            .toList());
  }
}
