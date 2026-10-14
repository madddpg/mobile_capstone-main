import 'package:cloud_firestore/cloud_firestore.dart';

/// The lifecycle state of a project's bidding period.
enum BiddingStatus {
  /// The bidding start time is in the future. Hardware shops can view the
  /// project but cannot yet submit quotations.
  scheduled,

  /// The current time is within the bidding period. Quotations are actively
  /// accepted from eligible shops.
  open,

  /// The quotation deadline has passed or bidding was explicitly closed.
  /// No new quotations are accepted. Homeowners can continue comparing
  /// quotations submitted before the deadline.
  closed;

  static BiddingStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'scheduled':
        return BiddingStatus.scheduled;
      case 'closed':
      case 'expired':
        return BiddingStatus.closed;
      case 'open':
      default:
        return BiddingStatus.open;
    }
  }

  String get label {
    switch (this) {
      case BiddingStatus.scheduled:
        return 'Scheduled';
      case BiddingStatus.open:
        return 'Bidding Open';
      case BiddingStatus.closed:
        return 'Bidding Closed';
    }
  }
}

/// Represents the bidding schedule and deadline management state for a posted estimate.
class BiddingSchedule {
  /// When quotation submissions open.
  final DateTime startsAt;

  /// The current deadline for submitting quotations.
  final DateTime endsAt;

  /// The original deadline set when the project was first posted.
  final DateTime originalEndsAt;

  /// The resolved bidding status.
  final BiddingStatus status;

  /// Number of times the deadline has been changed.
  final int deadlineChangeCount;

  /// When the deadline was last modified, if any.
  final DateTime? lastDeadlineChangedAt;

  /// The reason given for the most recent deadline change.
  final String? lastDeadlineChangeReason;

  const BiddingSchedule({
    required this.startsAt,
    required this.endsAt,
    DateTime? originalEndsAt,
    this.status = BiddingStatus.open,
    this.deadlineChangeCount = 0,
    this.lastDeadlineChangedAt,
    this.lastDeadlineChangeReason,
  }) : originalEndsAt = originalEndsAt ?? endsAt;

  /// Derives the active bidding status based on [now] and whether the post is
  /// closed explicitly or by stage.
  static BiddingStatus resolveStatus({
    required DateTime startsAt,
    required DateTime endsAt,
    String? storedStatus,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final stored = storedStatus?.toLowerCase().trim() ?? '';

    // If explicitly marked closed, cancelled, or awarded
    if (stored == 'closed' ||
        stored == 'cancelled' ||
        stored == 'canceled' ||
        stored == 'expired' ||
        stored == 'offer_accepted' ||
        stored == 'awarded') {
      return BiddingStatus.closed;
    }

    if (current.isBefore(startsAt)) {
      return BiddingStatus.scheduled;
    }

    if (current.isAfter(endsAt) || current.isAtSameMomentAs(endsAt)) {
      return BiddingStatus.closed;
    }

    return BiddingStatus.open;
  }

  /// Whether bidding is currently open for quotations.
  bool get isOpen => status == BiddingStatus.open;

  /// Whether bidding is scheduled for a future start time.
  bool get isScheduled => status == BiddingStatus.scheduled;

  /// Whether bidding has closed.
  bool get isClosed => status == BiddingStatus.closed;

  /// Whether the deadline was ever modified from its original setting.
  bool get isDeadlineChanged => deadlineChangeCount > 0;

  /// The total duration of the bidding period.
  Duration get totalDuration => endsAt.difference(startsAt);

  /// Remaining duration from [now] until [endsAt]. Returns [Duration.zero] if expired.
  Duration remainingDuration([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (current.isAfter(endsAt)) return Duration.zero;
    return endsAt.difference(current);
  }

  /// Formats a duration nicely in natural language (e.g. "3 days and 8 hours", "5 hours", "45 minutes").
  static String formatDuration(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) {
      return '0 minutes';
    }

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];
    if (days > 0) {
      parts.add('$days day${days == 1 ? '' : 's'}');
    }
    if (hours > 0) {
      parts.add('$hours hour${hours == 1 ? '' : 's'}');
    }
    if (days == 0 && minutes > 0) {
      parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
    }

    if (parts.isEmpty) {
      return 'Less than a minute';
    }
    if (parts.length == 1) {
      return parts.first;
    }
    return '${parts[0]} and ${parts[1]}';
  }

  /// User-friendly label for remaining time until the deadline.
  String remainingTimeLabel([DateTime? now]) {
    final current = now ?? DateTime.now();

    if (status == BiddingStatus.closed || current.isAfter(endsAt)) {
      return 'Bidding closed';
    }

    if (status == BiddingStatus.scheduled && current.isBefore(startsAt)) {
      final untilStart = startsAt.difference(current);
      return 'Opens in ${formatDuration(untilStart)}';
    }

    final remaining = remainingDuration(current);
    if (remaining.inDays > 1) {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      return hours > 0
          ? '$days days, $hours hrs left'
          : '$days day${days == 1 ? '' : 's'} left';
    }
    if (remaining.inHours >= 1) {
      final hours = remaining.inHours;
      final mins = remaining.inMinutes % 60;
      return mins > 0 ? '$hours hr${hours == 1 ? '' : 's'} $mins m left' : '$hours hr${hours == 1 ? '' : 's'} left';
    }
    final mins = remaining.inMinutes;
    if (mins > 0) {
      return '$mins min${mins == 1 ? '' : 's'} left';
    }
    return 'Closing soon';
  }

  /// Formats date and time into local Philippine style: "October 18, 2026 at 5:00 PM".
  static String formatDateTime(DateTime dt) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;

    final hour24 = dt.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$month $day, $year at $hour12:$minute $ampm';
  }

  /// Compact date: "10/18/26" or "10/18/2026".
  static String formatDateCompact(DateTime dt, {bool fourDigitYear = false}) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final year = fourDigitYear
        ? dt.year.toString()
        : (dt.year % 100).toString().padLeft(2, '0');
    return '$month/$day/$year';
  }

  /// Compact time: "5:00 PM".
  static String formatTimeCompact(DateTime dt) {
    final hour24 = dt.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $ampm';
  }

  /// Validates a schedule before posting. Returns null if valid, or an error message.
  static String? validateSchedule({
    required DateTime startsAt,
    required DateTime endsAt,
    DateTime? now,
    Duration minDuration = const Duration(hours: 1),
    Duration maxDuration = const Duration(days: 30),
  }) {
    final current = now ?? DateTime.now();

    // Allow a small 5-minute clock-skew buffer for "open immediately" start times
    final bufferStart = current.subtract(const Duration(minutes: 5));
    if (startsAt.isBefore(bufferStart)) {
      return 'Bidding start time cannot be in the past.';
    }

    if (endsAt.isBefore(startsAt) || endsAt.isAtSameMomentAs(startsAt)) {
      return 'Quotation deadline must be after the bidding start time.';
    }

    final duration = endsAt.difference(startsAt);
    if (duration < minDuration) {
      return 'Bidding period must be at least ${minDuration.inHours} hour${minDuration.inHours == 1 ? '' : 's'}.';
    }

    if (duration > maxDuration) {
      return 'Bidding period cannot exceed ${maxDuration.inDays} days.';
    }

    return null;
  }

  /// Validates a proposed deadline change under the prior-notice policy.
  ///
  /// Shortening a deadline requires at least [priorNoticeRequired] (default 24h)
  /// before the new deadline takes effect, ensuring participating shops are not
  /// cut off without warning. Extensions are generally permitted as long as the
  /// project is not already closed.
  static String? validateDeadlineChange({
    required DateTime currentEndsAt,
    required DateTime newEndsAt,
    required DateTime startsAt,
    DateTime? now,
    Duration priorNoticeRequired = const Duration(hours: 24),
  }) {
    final current = now ?? DateTime.now();

    if (current.isAfter(currentEndsAt)) {
      return 'Cannot change the deadline because bidding has already closed.';
    }

    if (newEndsAt.isBefore(current)) {
      return 'The new deadline must be in the future.';
    }

    if (newEndsAt.isBefore(startsAt) || newEndsAt.isAtSameMomentAs(startsAt)) {
      return 'The new deadline must be after the bidding start time.';
    }

    if (newEndsAt.isAtSameMomentAs(currentEndsAt)) {
      return 'The new deadline is identical to the current deadline.';
    }

    final isShortening = newEndsAt.isBefore(currentEndsAt);
    if (isShortening) {
      // Prior notice rule: when shortening, the new deadline must be at least
      // [priorNoticeRequired] ahead of the current time.
      final minimumAllowed = current.add(priorNoticeRequired);
      if (newEndsAt.isBefore(minimumAllowed)) {
        final hours = priorNoticeRequired.inHours;
        return 'To protect participating shops, shortening the deadline requires at least $hours hours prior notice. The earliest allowed new deadline is ${formatDateTime(minimumAllowed)}.';
      }
    }

    // Maximum cap: 60 days from original start
    if (newEndsAt.difference(startsAt) > const Duration(days: 60)) {
      return 'The deadline cannot be extended beyond 60 days from the bidding start date.';
    }

    return null;
  }

  /// Parses schedule fields from a `projectPosts` document data map.
  factory BiddingSchedule.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final now = DateTime.now();
    final postedAt = parseDate(data['postedAt'], now);

    final startsAt = parseDate(data['biddingStartsAt'], postedAt);
    final endsAt = parseDate(
      data['biddingEndsAt'],
      startsAt.add(const Duration(days: 3)),
    );
    final originalEndsAt = parseDate(
      data['originalBiddingEndsAt'],
      endsAt,
    );

    final rawStatus = data['biddingStatus']?.toString() ?? data['status']?.toString();
    final status = resolveStatus(
      startsAt: startsAt,
      endsAt: endsAt,
      storedStatus: rawStatus,
      now: now,
    );

    final changeCount = (data['deadlineChangeCount'] is num)
        ? (data['deadlineChangeCount'] as num).toInt()
        : 0;

    DateTime? lastChangedAt;
    if (data['lastDeadlineChangedAt'] is Timestamp) {
      lastChangedAt = (data['lastDeadlineChangedAt'] as Timestamp).toDate();
    }

    return BiddingSchedule(
      startsAt: startsAt,
      endsAt: endsAt,
      originalEndsAt: originalEndsAt,
      status: status,
      deadlineChangeCount: changeCount,
      lastDeadlineChangedAt: lastChangedAt,
      lastDeadlineChangeReason: data['lastDeadlineChangeReason']?.toString(),
    );
  }

  /// Converts this schedule into Firestore field updates.
  Map<String, dynamic> toMap() {
    return {
      'biddingStartsAt': Timestamp.fromDate(startsAt),
      'biddingEndsAt': Timestamp.fromDate(endsAt),
      'originalBiddingEndsAt': Timestamp.fromDate(originalEndsAt),
      'biddingStatus': status.name,
      'deadlineChangeCount': deadlineChangeCount,
      if (lastDeadlineChangedAt != null)
        'lastDeadlineChangedAt': Timestamp.fromDate(lastDeadlineChangedAt!),
      if (lastDeadlineChangeReason != null)
        'lastDeadlineChangeReason': lastDeadlineChangeReason,
    };
  }
}
