import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';

/// The rule behind the chat tab's badge.
///
/// A badge that overcounts is worse than none, because it trains people to
/// ignore it. These cases pin down exactly when a conversation is unread.
void main() {
  const me = 'builder-uid';
  const shop = 'shop-uid';

  Timestamp at(int minute) =>
      Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, minute));

  group('conversationIsUnread', () {
    test('a message from the shop that was never opened is unread', () {
      expect(
        conversationIsUnread({
          'lastSenderId': shop,
          'lastMessageAt': at(10),
        }, me),
        isTrue,
      );
    });

    test('my own last message is never unread', () {
      expect(
        conversationIsUnread({
          'lastSenderId': me,
          'lastMessageAt': at(10),
        }, me),
        isFalse,
      );
    });

    test('opened after the message arrived is read', () {
      expect(
        conversationIsUnread({
          'lastSenderId': shop,
          'lastMessageAt': at(10),
          'readAt': {me: at(15)},
        }, me),
        isFalse,
      );
    });

    test('a message arriving after the last open is unread again', () {
      expect(
        conversationIsUnread({
          'lastSenderId': shop,
          'lastMessageAt': at(20),
          'readAt': {me: at(15)},
        }, me),
        isTrue,
      );
    });

    test('the other party reading it does not clear my badge', () {
      expect(
        conversationIsUnread({
          'lastSenderId': shop,
          'lastMessageAt': at(20),
          'readAt': {shop: at(25)},
        }, me),
        isTrue,
      );
    });

    test('a thread with no messages yet is not unread', () {
      expect(conversationIsUnread({'lastSenderId': shop}, me), isFalse);
    });

    test('a malformed timestamp does not count', () {
      expect(
        conversationIsUnread({
          'lastSenderId': shop,
          'lastMessageAt': 'not-a-timestamp',
        }, me),
        isFalse,
      );
    });

    test('an equal timestamp counts as read, not unread', () {
      // Opening a thread writes a marker at or after the message time. Treating
      // equality as unread would leave a badge on a thread just closed.
      expect(
        conversationIsUnread({
          'lastSenderId': shop,
          'lastMessageAt': at(10),
          'readAt': {me: at(10)},
        }, me),
        isFalse,
      );
    });
  });
}
