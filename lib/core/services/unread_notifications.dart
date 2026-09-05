import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Live unread in-app notification count for the signed-in builder.
Stream<int> unreadNotificationCountStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream<int>.value(0);
  }

  // Filter isRead client-side so we don't depend on a composite index deploy.
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .snapshots()
      .map(
        (snap) => snap.docs
            .where((doc) => (doc.data()['isRead'] ?? false) != true)
            .length,
      )
      .handleError((_) => 0);
}

/// Small red count badge over a child (nav icon, bell, etc.).
class UnreadBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final double offset;

  const UnreadBadge({
    super.key,
    required this.child,
    required this.count,
    this.offset = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final label = count > 9 ? '9+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -offset,
          top: -offset,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Listens for unread notifications and wraps [child] with [UnreadBadge].
class UnreadNotificationsBadge extends StatelessWidget {
  final Widget child;
  final double offset;

  const UnreadNotificationsBadge({
    super.key,
    required this.child,
    this.offset = 2,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: unreadNotificationCountStream(),
      builder: (context, snapshot) {
        return UnreadBadge(
          count: snapshot.data ?? 0,
          offset: offset,
          child: child,
        );
      },
    );
  }
}
