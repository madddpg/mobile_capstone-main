import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/chat/widgets/message_list.dart';

/// The grouping rule behind the Messenger-style thread.
///
/// Getting this wrong is what makes a chat look broken: a burst of replies
/// split into separate blocks, or two people's messages merged into one run.
void main() {
  const me = 'builder-uid';
  const shop = 'shop-uid';

  Timestamp at(int hour, int minute) =>
      Timestamp.fromDate(DateTime(2026, 9, 5, hour, minute));

  Map<String, dynamic> from(String who, Timestamp when) => {
        'senderId': who,
        'senderRole': who == me ? 'builder' : 'shop',
        'text': 'hello',
        'createdAt': when,
      };

  Map<String, dynamic> system(Timestamp when) => {
        'senderId': '',
        'senderRole': 'system',
        'text': 'Quotation accepted.',
        'createdAt': when,
      };

  bool starts(Map<String, dynamic>? prev, Map<String, dynamic> cur) =>
      MessengerMessageList.startsNewRun(
        previous: prev,
        current: cur,
        uid: me,
      );

  group('startsNewRun', () {
    test('the first message always starts a run', () {
      expect(starts(null, from(shop, at(9, 0))), isTrue);
    });

    test('the same sender moments later continues the run', () {
      expect(starts(from(shop, at(9, 0)), from(shop, at(9, 2))), isFalse);
    });

    test('a different sender starts a new run', () {
      expect(starts(from(shop, at(9, 0)), from(me, at(9, 1))), isTrue);
    });

    test('the same sender after an hour starts a new run', () {
      expect(starts(from(shop, at(9, 0)), from(shop, at(10, 0))), isTrue);
    });

    test('just under an hour still continues the run', () {
      expect(starts(from(shop, at(9, 0)), from(shop, at(9, 59))), isFalse);
    });

    test('a system message breaks the run on either side', () {
      expect(starts(from(shop, at(9, 0)), system(at(9, 1))), isTrue);
      expect(starts(system(at(9, 0)), from(shop, at(9, 1))), isTrue);
    });

    test('a message with no timestamp does not split a run', () {
      // Firestore returns null for createdAt until the server stamps it, so a
      // message the user just sent must not flicker into its own run.
      final pending = {
        'senderId': me,
        'senderRole': 'builder',
        'text': 'sending',
        'createdAt': null,
      };
      expect(starts(from(me, at(9, 0)), pending), isFalse);
    });
  });

  group('separatorLabel', () {
    test('a time today prints as a bare clock', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 5);
      expect(MessengerMessageList.separatorLabel(today), '2:05 PM');
    });

    test('midnight and noon read correctly', () {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day, 0, 7);
      final noon = DateTime(now.year, now.month, now.day, 12, 0);
      expect(MessengerMessageList.separatorLabel(midnight), '12:07 AM');
      expect(MessengerMessageList.separatorLabel(noon), '12:00 PM');
    });

    test('yesterday is named rather than dated', () {
      final yesterday =
          DateTime.now().subtract(const Duration(days: 1));
      final label = MessengerMessageList.separatorLabel(
        DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 30),
      );
      expect(label, startsWith('Yesterday, '));
    });

    test('older than a week falls back to a date', () {
      final label = MessengerMessageList.separatorLabel(
        DateTime(2020, 3, 9, 16, 45),
      );
      expect(label, 'Mar 9, 4:45 PM');
    });
  });
}
