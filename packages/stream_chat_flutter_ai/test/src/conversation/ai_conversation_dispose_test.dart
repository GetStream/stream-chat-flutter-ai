import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test('its feed goes nowhere once it is disposed', () {
    final transport = ConversationTransport();
    final conversation = AIConversation(transport: transport);

    expect(transport.feed!.isConnected, isTrue);
    conversation.dispose();

    expect(transport.feed!.isConnected, isFalse);
    transport
      ..update([ChatMessage.user('u1')])
      ..updateActivity(const AIAgentActivity(state: AIAgentActivityState.thinking));
    transport.feed!.updateHasOlderMessages(true);
    expect(conversation.messages, isEmpty);
  });

  test('disconnects from the transport once it is disposed', () {
    final transport = ConversationTransport();
    final conversation = AIConversation(transport: transport);

    expect(transport.disconnects, 0);
    conversation.dispose();

    expect(transport.disconnects, 1);
  });

  test('requests that finish after it is disposed change nothing', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = AIConversation(transport: transport)
      ..send('Hello')
      ..rate(ChatMessage.reply('a1'), AIMessageRating.positive)
      ..dispose();

    await settle();

    expect(transport.requests, hasLength(1));
    expect(transport.ratings, isEmpty);
    expect(conversation.status, AIConversationStatus.submitted);
  });

  final afterDispose = <String, void Function(AIConversation<ChatMessage> conversation)>{
    'send': (conversation) => conversation.send('Hi'),
    'stop': (conversation) => conversation.stop(),
    'retry': (conversation) => conversation.retry(),
    'regenerate': (conversation) => conversation.regenerate(ChatMessage.reply('a1')),
    'rate': (conversation) => conversation.rate(ChatMessage.reply('a1'), AIMessageRating.positive),
    'clearError': (conversation) => conversation.clearError(),
    'edit': (conversation) => conversation.edit(ChatMessage.user('u1')),
    'cancelEditing': (conversation) => conversation.cancelEditing(),
  };

  for (final MapEntry(key: name, value: act) in afterDispose.entries) {
    test('$name does nothing once it is disposed', () async {
      final transport = ConversationTransport(
        messages: [
          ChatMessage.user('u1'),
          ChatMessage.reply('a1', text: 'Day one', generating: true),
        ],
      )..sendError = const TransportError();
      final conversation = AIConversation(transport: transport)..send('Hello');
      await settle();
      conversation.edit(ChatMessage.user('u1'));
      final requests = transport.requests.length;
      conversation.dispose();

      expect(() => act(conversation), returnsNormally);
      await settle();

      expect(transport.requests, hasLength(requests));
      expect(transport.stops, 0);
      expect(transport.ratings, isEmpty);
    });
  }
}
