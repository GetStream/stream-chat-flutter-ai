import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test('waits until the reply starts', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..send('And the restaurants?');

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'And the restaurants?'),
    ]);

    expect(conversation.pendingMessage, isNotNull, reason: 'kept until its reply starts');
    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2', text: '', generating: true),
    ]);

    expect(conversation.pendingMessage, isNotNull, reason: "a reply that shows nothing hasn't started");
    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2', text: 'Try', generating: true),
    ]);

    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.streaming);
    expect(conversation.composer.isGenerating, isTrue);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2', text: 'Try Taberna da Rua'),
    ]);

    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.composer.isGenerating, isFalse);
    expect(conversation.messages.ids, ['u1', 'a1', 'u2', 'a2']);
  });

  test('ends the wait when the reply arrives finished', () {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport)..send('Hi');

    transport.update([ChatMessage.user('u1', 'Hi'), ChatMessage.reply('a1', text: 'Hello!')]);

    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('ends the wait when a reply finishes with nothing in it', () {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport)..send('Hi');

    transport.update([ChatMessage.user('u1', 'Hi'), ChatMessage.reply('a1', text: '')]);

    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('sent while a reply is written, waits for its own reply', () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    );
    final conversation = conversationOver(transport);
    expect(conversation.status, AIConversationStatus.streaming);

    conversation.send('Make it three days');
    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one, day two', generating: true)]);

    expect(conversation.pendingMessage, isNotNull);
    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1', text: 'Day one, day two'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2', text: 'Three days', generating: true),
    ]);

    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('streams a reply that started before the transport returned', () async {
    final transport = ConversationTransport()..holdsSends = true;
    final conversation = conversationOver(transport)..send('Hi');
    await settle();
    transport
      ..update([ChatMessage.user('u1', 'Hi'), ChatMessage.reply('a1', text: 'Hello', generating: true)])
      ..finishSend(0);
    await settle();

    expect(conversation.status, AIConversationStatus.streaming);
    expect(conversation.pendingMessage, isNull);
  });
}
