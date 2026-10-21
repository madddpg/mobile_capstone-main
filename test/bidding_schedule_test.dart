import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/bidding_schedule.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';

void main() {
  group('BiddingSchedule Model and Serialization', () {
    test('parses from Firestore map with Timestamp fields', () {
      final now = DateTime.now();
      final starts = now.subtract(const Duration(hours: 2));
      final ends = now.add(const Duration(days: 3));

      final map = {
        'biddingStartsAt': Timestamp.fromDate(starts),
        'biddingEndsAt': Timestamp.fromDate(ends),
        'biddingOriginalEndsAt': Timestamp.fromDate(ends),
        'biddingStatus': 'open',
        'deadlineChangeCount': 1,
        'lastDeadlineChangedAt': Timestamp.fromDate(starts),
        'lastDeadlineChangeReason': 'Homeowner requested more shop quotes',
      };

      final schedule = BiddingSchedule.fromMap(map);
      expect(schedule, isNotNull);
      expect(
        schedule!.startsAt.millisecondsSinceEpoch,
        equals(starts.millisecondsSinceEpoch),
      );
      expect(
        schedule.endsAt.millisecondsSinceEpoch,
        equals(ends.millisecondsSinceEpoch),
      );
      expect(schedule.status, equals(BiddingStatus.open));
      expect(schedule.deadlineChangeCount, equals(1));
      expect(schedule.isDeadlineChanged, isTrue);
      expect(
        schedule.lastDeadlineChangeReason,
        equals('Homeowner requested more shop quotes'),
      );
    });

    test('falls back gracefully on legacy map without schedule fields', () {
      final map = <String, dynamic>{'projectName': 'Kitchen Renovation'};

      final schedule = BiddingSchedule.fromMap(map);
      expect(schedule, isNotNull);
      expect(schedule!.deadlineChangeCount, equals(0));
      expect(schedule.isDeadlineChanged, isFalse);
    });

    test('serializes to Firestore map correctly', () {
      final starts = DateTime(2026, 10, 15, 9, 0);
      final ends = DateTime(2026, 10, 18, 17, 0);

      final schedule = BiddingSchedule(
        startsAt: starts,
        endsAt: ends,
        status: BiddingStatus.open,
      );

      final map = schedule.toMap();
      expect(map['biddingStartsAt'], isA<Timestamp>());
      expect(map['biddingEndsAt'], isA<Timestamp>());
      expect(map['biddingStatus'], equals('open'));
      expect(map['deadlineChangeCount'], equals(0));
    });
  });

  group('BiddingStatus Lifecycle Resolution', () {
    final startsAt = DateTime(2026, 10, 15, 9, 0);
    final endsAt = DateTime(2026, 10, 18, 17, 0);

    test('returns scheduled when now is before start time', () {
      final beforeStart = DateTime(2026, 10, 14, 12, 0);
      final status = BiddingSchedule.resolveStatus(
        startsAt: startsAt,
        endsAt: endsAt,
        storedStatus: 'scheduled',
        now: beforeStart,
      );
      expect(status, equals(BiddingStatus.scheduled));
    });

    test('returns open when now is between start and end time', () {
      final duringBidding = DateTime(2026, 10, 16, 12, 0);
      final status = BiddingSchedule.resolveStatus(
        startsAt: startsAt,
        endsAt: endsAt,
        storedStatus: 'open',
        now: duringBidding,
      );
      expect(status, equals(BiddingStatus.open));
    });

    test('returns closed when now is after end time', () {
      final afterDeadline = DateTime(2026, 10, 18, 17, 1);
      final status = BiddingSchedule.resolveStatus(
        startsAt: startsAt,
        endsAt: endsAt,
        storedStatus: 'open',
        now: afterDeadline,
      );
      expect(status, equals(BiddingStatus.closed));
    });

    test('respects explicit closed stored status even if time not reached', () {
      final duringBidding = DateTime(2026, 10, 16, 12, 0);
      final status = BiddingSchedule.resolveStatus(
        startsAt: startsAt,
        endsAt: endsAt,
        storedStatus: 'closed',
        now: duringBidding,
      );
      expect(status, equals(BiddingStatus.closed));
    });
  });

  group('Duration Formatting and Countdown Labels', () {
    test('formats duration in natural language', () {
      expect(
        BiddingSchedule.formatDuration(
          const Duration(days: 3, hours: 8, minutes: 30),
        ),
        equals('3 days and 8 hours'),
      );

      expect(
        BiddingSchedule.formatDuration(
          const Duration(days: 1, hours: 0, minutes: 0),
        ),
        equals('1 day'),
      );

      expect(
        BiddingSchedule.formatDuration(const Duration(hours: 4, minutes: 15)),
        equals('4 hours and 15 minutes'),
      );

      expect(
        BiddingSchedule.formatDuration(const Duration(minutes: 45)),
        equals('45 minutes'),
      );
    });

    test('computes remaining time labels accurately', () {
      final starts = DateTime(2026, 10, 15, 9, 0);
      final ends = DateTime(2026, 10, 18, 9, 0);
      final schedule = BiddingSchedule(startsAt: starts, endsAt: ends);

      // 2 days remaining
      final twoDaysBefore = DateTime(2026, 10, 16, 9, 0);
      expect(schedule.remainingTimeLabel(twoDaysBefore), equals('2 days left'));

      // 5 hours remaining
      final fiveHoursBefore = DateTime(2026, 10, 18, 4, 0);
      expect(
        schedule.remainingTimeLabel(fiveHoursBefore),
        equals('5 hrs left'),
      );

      // 25 minutes remaining
      final twentyFiveMinsBefore = DateTime(2026, 10, 18, 8, 35);
      expect(
        schedule.remainingTimeLabel(twentyFiveMinsBefore),
        equals('25 mins left'),
      );

      // Past deadline
      final pastDeadline = DateTime(2026, 10, 18, 9, 1);
      expect(
        schedule.remainingTimeLabel(pastDeadline),
        equals('Bidding closed'),
      );
    });
  });

  group('Initial Schedule Validation', () {
    final now = DateTime(2026, 10, 15, 10, 0);

    test('validates correct schedule', () {
      final starts = DateTime(2026, 10, 15, 10, 0);
      final ends = DateTime(2026, 10, 18, 17, 0);
      final error = BiddingSchedule.validateSchedule(
        startsAt: starts,
        endsAt: ends,
        now: now,
      );
      expect(error, isNull);
    });

    test('rejects start time significantly in the past', () {
      final startsInPast = DateTime(2026, 10, 15, 8, 0);
      final ends = DateTime(2026, 10, 18, 17, 0);
      final error = BiddingSchedule.validateSchedule(
        startsAt: startsInPast,
        endsAt: ends,
        now: now,
      );
      expect(error, contains('Bidding start time cannot be in the past'));
    });

    test('rejects quotation deadline before or at start time', () {
      final starts = DateTime(2026, 10, 15, 10, 0);
      final endsBeforeStarts = DateTime(2026, 10, 15, 9, 0);
      final error = BiddingSchedule.validateSchedule(
        startsAt: starts,
        endsAt: endsBeforeStarts,
        now: now,
      );
      expect(
        error,
        contains('Quotation deadline must be after the bidding start time'),
      );
    });

    test('rejects quotation period shorter than 1 hour', () {
      final starts = DateTime(2026, 10, 15, 10, 0);
      final endsTooShort = DateTime(2026, 10, 15, 10, 30);
      final error = BiddingSchedule.validateSchedule(
        startsAt: starts,
        endsAt: endsTooShort,
        now: now,
      );
      expect(error, contains('Bidding period must be at least 1 hour'));
    });
  });

  group('Deadline Change Prior-Notice Policy', () {
    final now = DateTime(2026, 10, 16, 12, 0);
    final startsAt = DateTime(2026, 10, 15, 9, 0);
    final currentEndsAt = DateTime(2026, 10, 20, 17, 0);

    test('allows deadline extensions without 24-hour notice constraint', () {
      final extendedEndsAt = DateTime(2026, 10, 25, 17, 0);
      final error = BiddingSchedule.validateDeadlineChange(
        currentEndsAt: currentEndsAt,
        newEndsAt: extendedEndsAt,
        startsAt: startsAt,
        now: now,
      );
      expect(error, isNull);
    });

    test('rejects new deadline in the past or immediately present', () {
      final pastEndsAt = DateTime(2026, 10, 16, 11, 0);
      final error = BiddingSchedule.validateDeadlineChange(
        currentEndsAt: currentEndsAt,
        newEndsAt: pastEndsAt,
        startsAt: startsAt,
        now: now,
      );
      expect(error, contains('The new deadline must be in the future'));
    });

    test('rejects new deadline before project start time', () {
      final futureBeforeStart = DateTime(2026, 10, 17, 10, 0);
      final startsLater = DateTime(2026, 10, 18, 9, 0);
      final error = BiddingSchedule.validateDeadlineChange(
        currentEndsAt: currentEndsAt,
        newEndsAt: futureBeforeStart,
        startsAt: startsLater,
        now: now,
      );
      expect(
        error,
        contains('The new deadline must be after the bidding start time'),
      );
    });

    test('rejects shortening deadline when notice is under 24 hours', () {
      // Shortening from Oct 20 to Oct 17 00:00 (12 hours from now) -> under 24 hours!
      final shortenedUnder24h = DateTime(2026, 10, 17, 0, 0);
      final error = BiddingSchedule.validateDeadlineChange(
        currentEndsAt: currentEndsAt,
        newEndsAt: shortenedUnder24h,
        startsAt: startsAt,
        now: now,
      );
      expect(error, contains('at least 24 hours prior notice'));
    });

    test('allows shortening deadline when notice is 24 hours or greater', () {
      // Shortening from Oct 20 to Oct 18 12:00 (48 hours from now) -> valid!
      final shortenedOver24h = DateTime(2026, 10, 18, 12, 0);
      final error = BiddingSchedule.validateDeadlineChange(
        currentEndsAt: currentEndsAt,
        newEndsAt: shortenedOver24h,
        startsAt: startsAt,
        now: now,
      );
      expect(error, isNull);
    });
  });

  group('Project Post Payload with Schedule', () {
    test('carries bidding schedule fields when provided', () {
      final starts = DateTime(2026, 10, 15, 9, 0);
      final ends = DateTime(2026, 10, 18, 17, 0);

      final payload = projectPostFields(
        postId: 'post-101',
        userId: 'builder-1',
        projectId: 'proj-1',
        projectName: 'Balcony Renovation',
        projectType: 'Balcony',
        projectScope: 'Full',
        ownerName: 'Juan Dela Cruz',
        materials: const [
          {'name': 'Decking tiles', 'quantity': 20, 'unit': 'pcs'},
        ],
        totalAreaSqm: 12.0,
        budget: 'medium',
        biddingStartsAt: starts,
        biddingEndsAt: ends,
        biddingStatus: 'open',
      );

      expect(payload['biddingStartsAt'], isA<Timestamp>());
      expect(payload['biddingEndsAt'], isA<Timestamp>());
      expect(payload['biddingStatus'], equals('open'));
      expect(payload['deadlineChangeCount'], equals(0));
    });
  });

  group('hasStoredDeadline', () {
    test('is true when the post stores a deadline under any known key', () {
      final ends = Timestamp.fromDate(DateTime(2026, 10, 23, 17));
      expect(
        BiddingSchedule.hasStoredDeadline({'biddingEndsAt': ends}),
        isTrue,
      );
      expect(BiddingSchedule.hasStoredDeadline({'deadline': ends}), isTrue);
      expect(
        BiddingSchedule.hasStoredDeadline({'closingDate': '2026-10-23'}),
        isTrue,
      );
    });

    test('is false for a legacy post with no deadline', () {
      // fromMap would invent "posted + 3 days" here; a card must not show it.
      expect(
        BiddingSchedule.hasStoredDeadline({
          'postedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'status': 'open',
        }),
        isFalse,
      );
      expect(
        BiddingSchedule.hasStoredDeadline({'biddingEndsAt': null}),
        isFalse,
      );
      expect(
        BiddingSchedule.hasStoredDeadline({'deadline': 'not a date'}),
        isFalse,
      );
    });
  });
}
