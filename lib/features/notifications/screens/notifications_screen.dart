import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/features/bidding/screens/posted_project_details_screen.dart';
import 'package:iconstruct/features/bidding/screens/quotations_screen.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF648DB6), Color(0xFFE0D7C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: currentUser == null
                    ? Center(
                        child: Text(
                          "Please log in to see notifications.",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      )
                    : _buildNotificationsList(currentUser.uid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4E7CB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF2F3E4F),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notifications",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Stay updated with project activity",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      // No `orderBy` on the query: the `recipientId + createdAt` composite index
      // is not deployed on the shared project, so ordering server-side throws
      // FAILED_PRECONDITION. Sort client-side instead (same approach as the
      // unread-badge stream).
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF4E7CB)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                firestoreUserMessage(
                  snapshot.error!,
                  action: 'load your notifications',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>?)?['createdAt'];
            final bd = (b.data() as Map<String, dynamic>?)?['createdAt'];
            final at = ad is Timestamp ? ad.toDate() : DateTime(1970);
            final bt = bd is Timestamp ? bd.toDate() : DateTime(1970);
            return bt.compareTo(at);
          });

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return NotificationCard(id: doc.id, data: data);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Color(0xFFF4E7CB),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No notifications yet",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll see updates here when activity happens",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class NotificationBadge extends StatelessWidget {
  final String projectType;

  const NotificationBadge({super.key, required this.projectType});

  String _formatProjectType(String type) {
    if (type.isEmpty) return 'Unknown Project';
    return type
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C3E50).withValues(alpha: 0.2)),
      ),
      child: Text(
        _formatProjectType(projectType),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2C3E50),
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const NotificationCard({super.key, required this.id, required this.data});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} mins ago';
    } else {
      return 'Just now';
    }
  }

  void _handleTap(BuildContext context) {
    final bool isRead = data['isRead'] ?? false;
    final String type = data['type'] ?? '';
    final String postId = data['postId'] ?? '';

    // Mark as read in Firestore if not already read
    if (!isRead) {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(id)
          .update({'isRead': true})
          .catchError((_) {/* offline / not owned — non-fatal */});
    }

    // Navigate based on type
    if (type == 'new_project_post' && postId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostedProjectDetailsScreen(postId: postId),
        ),
      );
    } else if (type == 'new_quotation' && postId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuotationsScreen(postId: postId),
        ),
      );
    } else if ((type == 'chat_unlocked' || type == 'chat_message') &&
        (data['conversationId'] ?? '').toString().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatThreadScreen(
            conversationId: data['conversationId'].toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = data['title'] ?? 'Notification';
    final String message = data['message'] ?? '';
    final bool isRead = data['isRead'] ?? false;
    final String projectType = data['projectType'] ?? '';
    final Timestamp? createdAt =
        data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
    final String timeFormatted = _formatTimestamp(createdAt);

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4E7CB),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Read/Unread Indicator
            Container(
              margin: const EdgeInsets.only(top: 6, right: 16),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRead ? Colors.grey.shade400 : const Color(0xFF2C3E50),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      Text(
                        timeFormatted,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF2C3E50).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  if (projectType.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    NotificationBadge(projectType: projectType),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
