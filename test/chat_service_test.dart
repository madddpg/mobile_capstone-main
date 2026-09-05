import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/chat/data/chat_service.dart';

void main() {
  test('conversation id is always postId_shopId', () {
    expect(ChatService.conversationId('postA', 'shopB'), 'postA_shopB');
  });
}
