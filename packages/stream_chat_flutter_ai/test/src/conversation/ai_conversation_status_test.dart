import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  for (final (status, isAnswering) in [
    (AIConversationStatus.submitted, true),
    (AIConversationStatus.streaming, true),
    (AIConversationStatus.ready, false),
    (AIConversationStatus.error, false),
    (const AIConversationStatus('paused'), false),
  ]) {
    test('AIConversationStatus $status ${isAnswering ? 'is' : 'is not'} answering', () {
      expect(status.isAnswering, isAnswering);
    });
  }

  test('AIConversationStatus knows the statuses of this package', () {
    expect(AIConversationStatus.values.every((status) => status.isKnown), isTrue);
  });

  test('AIConversationStatus keeps a status it does not know as it is', () {
    const status = AIConversationStatus('paused');

    expect(status.isKnown, isFalse);
    expect(status, 'paused');
  });

  test('AIConversationStatus compares equal to its raw value', () {
    expect(AIConversationStatus.streaming, 'streaming');
  });

  test('status follows the latest reply', () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: '', generating: true),
      ],
    );
    final conversation = conversationOver(transport);

    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day', generating: true)]);
    expect(conversation.status, AIConversationStatus.streaming);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one')]);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('status is streaming while a reply that has only steps is written', () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply(
          'a1',
          text: '',
          generating: true,
          parts: [AIMessagePart.fromReasoning(const AIReasoningPart(id: 'r1', summary: 'Weighing'))],
        ),
      ],
    );
    final conversation = conversationOver(transport);

    expect(conversation.status, AIConversationStatus.streaming);
  });

  test("status ignores what the person's message says about generating", () {
    final transport = ConversationTransport(
      messages: [ChatMessage('u1', AIMessageRole.user, 'Plan Lisbon', isGenerating: true)],
    );
    final conversation = conversationOver(transport);

    expect(conversation.status, AIConversationStatus.ready);
  });

  test("status sets the composer's generating state only when the status changes", () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day', generating: true),
      ],
    );
    final conversation = conversationOver(transport);
    var changes = 0;
    conversation.composer.addListener(() => changes += 1);

    transport
      ..update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one', generating: true)])
      ..update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one, day two', generating: true)])
      ..update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one, day two')]);

    expect(changes, 1);
    expect(conversation.composer.isGenerating, isFalse);
  });
}
