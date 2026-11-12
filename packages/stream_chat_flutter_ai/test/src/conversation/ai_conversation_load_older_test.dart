import 'package:flutter_test/flutter_test.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test('loadOlderMessages asks the transport only while there are any', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport);

    await conversation.loadOlderMessages();
    expect(transport.loads, 0);

    transport.feed!.updateHasOlderMessages(true);
    await conversation.loadOlderMessages();
    expect(transport.loads, 1);
  });

  test('loadOlderMessages loads once at a time', () async {
    final transport = ConversationTransport()..holdsLoads = true;
    final conversation = conversationOver(transport);
    transport.feed!.updateHasOlderMessages(true);

    final first = conversation.loadOlderMessages();
    final second = conversation.loadOlderMessages();
    await settle();
    transport.finishLoads();
    await Future.wait([first, second]);

    expect(transport.loads, 1);

    transport.holdsLoads = false;
    await conversation.loadOlderMessages();

    expect(transport.loads, 2);
  });

  test('loadOlderMessages reports a failure of the transport, and can load again', () async {
    final errors = captureErrors();
    final transport = ConversationTransport()..loadError = const TransportError();
    final conversation = conversationOver(transport);
    transport.feed!.updateHasOlderMessages(true);

    await conversation.loadOlderMessages();
    await conversation.loadOlderMessages();

    expect(transport.loads, 2);
    expect(conversation.error, isNull, reason: "not a request of the person's");
    expect([for (final e in errors) e.exception], [const TransportError(), const TransportError()]);
  });

  test('loadOlderMessages loads nothing when the transport does not load older messages', () async {
    final transport = MinimalTransport();
    final conversation = conversationOver(transport);
    transport.feed!.updateHasOlderMessages(true);

    await expectLater(conversation.loadOlderMessages(), completes);
  });
}
