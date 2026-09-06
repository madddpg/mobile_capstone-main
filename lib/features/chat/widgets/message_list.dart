import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';

/// Messenger-style thread.
///
/// The conventions people already know from chat apps, and each one earns its
/// place: consecutive messages from one sender collapse into a run so a burst
/// reads as one turn rather than five; only the last incoming bubble in a run
/// carries the avatar, which keeps the left edge quiet; a printed time appears
/// only where there is a real gap, instead of stamping every line; and the
/// sender's own last message reports whether the shop has opened the thread
/// since it arrived.
class MessengerMessageList extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final String? uid;
  final String shopName;
  final Map<String, dynamic>? conversation;
  final ScrollController controller;

  const MessengerMessageList({
    super.key,
    required this.docs,
    required this.uid,
    required this.shopName,
    required this.conversation,
    required this.controller,
  });

  /// A gap at least this long breaks a run and prints a time.
  static const Duration _runGap = Duration(minutes: 60);

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static DateTime? _sentAt(Map<String, dynamic> m) {
    final v = m['createdAt'];
    return v is Timestamp ? v.toDate() : null;
  }

  static bool _isSystem(Map<String, dynamic> m) =>
      (m['senderRole'] ?? '').toString() == 'system';

  bool _isMine(Map<String, dynamic> m) => _senderIsBuilder(m, uid);

  static String _clock(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Times read relative to today, the way a person would say them.
  static String separatorLabel(DateTime t) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfThat = DateTime(t.year, t.month, t.day);
    final daysAgo = startOfToday.difference(startOfThat).inDays;

    if (daysAgo == 0) return _clock(t);
    if (daysAgo == 1) return 'Yesterday, ${_clock(t)}';
    if (daysAgo < 7) return '${_weekday(t)}, ${_clock(t)}';
    return '${_months[t.month - 1]} ${t.day}, ${_clock(t)}';
  }

  static String _weekday(DateTime t) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(t.weekday - 1).clamp(0, 6)];
  }

  /// True when this message starts a new run: first overall, a different
  /// sender than the one before, or far enough after it in time.
  ///
  /// Pure and static so the grouping rule can be tested without rendering the
  /// widget, which pulls in a network-fetched font.
  static bool startsNewRun({
    required Map<String, dynamic>? previous,
    required Map<String, dynamic> current,
    required String? uid,
  }) {
    if (previous == null) return true;
    if (_isSystem(previous) != _isSystem(current)) return true;
    if (_senderIsBuilder(previous, uid) != _senderIsBuilder(current, uid)) {
      return true;
    }

    final before = _sentAt(previous);
    final now = _sentAt(current);
    if (before == null || now == null) return false;
    return now.difference(before) >= _runGap;
  }

  static bool _senderIsBuilder(Map<String, dynamic> m, String? uid) {
    final sender = (m['senderId'] ?? '').toString();
    if (uid != null && sender.isNotEmpty) return sender == uid;
    return (m['senderRole'] ?? '').toString() == 'builder';
  }

  bool _startsRun(int i) => startsNewRun(
        previous: i == 0 ? null : docs[i - 1],
        current: docs[i],
        uid: uid,
      );

  bool _endsRun(int i) => i == docs.length - 1 || _startsRun(i + 1);

  /// Whether the shop has opened the thread since the builder's last message.
  bool get _seenByShop {
    final conv = conversation;
    if (conv == null) return false;

    final shopId = (conv['shopId'] ?? '').toString();
    if (shopId.isEmpty) return false;

    final readMap = conv['readAt'];
    final readAt = readMap is Map ? readMap[shopId] : null;
    if (readAt is! Timestamp) return false;

    final lastAt = conv['lastMessageAt'];
    if (lastAt is! Timestamp) return false;

    return readAt.compareTo(lastAt) >= 0;
  }

  /// Index of the builder's most recent message, which is the only one that
  /// carries a delivery line.
  int get _lastMineIndex {
    for (var i = docs.length - 1; i >= 0; i--) {
      final m = docs[i];
      if (!_isSystem(m) && _isMine(m)) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final maxBubble = MediaQuery.sizeOf(context).width * 0.68;
    final lastMine = _lastMineIndex;

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final msg = docs[i];
        final text = (msg['text'] ?? '').toString();
        final startsRun = _startsRun(i);
        final endsRun = _endsRun(i);

        if (_isSystem(msg)) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.cream.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          );
        }

        final mine = _isMine(msg);
        final sentAt = _sentAt(msg);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsRun && sentAt != null) _timeSeparator(sentAt),
            _bubbleRow(
              text: text,
              mine: mine,
              startsRun: startsRun,
              endsRun: endsRun,
              maxWidth: maxBubble,
            ),
            if (i == lastMine) _deliveryLine(),
          ],
        );
      },
    );
  }

  Widget _timeSeparator(DateTime t) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        separatorLabel(t),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: AppColors.cream.withValues(alpha: 0.45),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _bubbleRow({
    required String text,
    required bool mine,
    required bool startsRun,
    required bool endsRun,
    required double maxWidth,
  }) {
    // Tight inside a run, looser between runs, so the grouping is legible
    // without any divider.
    final topGap = startsRun ? 0.0 : 2.0;

    final bubble = Container(
      margin: EdgeInsets.only(top: topGap),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: mine ? IConstructPanel.midBlue : AppColors.cream,
        borderRadius: _radius(mine: mine, startsRun: startsRun, endsRun: endsRun),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: mine ? Colors.white : AppColors.textDark,
          fontSize: 13.5,
          height: 1.35,
        ),
      ),
    );

    if (mine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [Flexible(child: bubble)],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The avatar sits only on the run's final bubble; earlier bubbles keep
        // an equal indent so the column edge stays straight.
        SizedBox(
          width: 30,
          child: endsRun ? _avatar() : const SizedBox.shrink(),
        ),
        const SizedBox(width: 6),
        Flexible(child: bubble),
      ],
    );
  }

  Widget _avatar() {
    final initial = shopName.trim().isEmpty
        ? '?'
        : shopName.trim().characters.first.toUpperCase();

    return Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(bottom: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.45)),
      ),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          color: AppColors.cream,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _deliveryLine() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 2),
      child: Text(
        _seenByShop ? 'Seen' : 'Sent',
        textAlign: TextAlign.right,
        style: GoogleFonts.poppins(
          color: AppColors.cream.withValues(alpha: 0.55),
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// A run reads as one shape: the outer corners stay round and the corners
  /// facing the neighbouring bubble tighten.
  BorderRadius _radius({
    required bool mine,
    required bool startsRun,
    required bool endsRun,
  }) {
    const round = Radius.circular(17);
    const tight = Radius.circular(5);

    if (mine) {
      return BorderRadius.only(
        topLeft: round,
        bottomLeft: round,
        topRight: startsRun ? round : tight,
        bottomRight: endsRun ? round : tight,
      );
    }
    return BorderRadius.only(
      topRight: round,
      bottomRight: round,
      topLeft: startsRun ? round : tight,
      bottomLeft: endsRun ? round : tight,
    );
  }
}
