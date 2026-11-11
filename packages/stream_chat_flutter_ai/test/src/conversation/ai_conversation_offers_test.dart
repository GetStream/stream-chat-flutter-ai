import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_offers.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test("offers regenerating the latest reply while the agent isn't answering", () async {
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1'), ChatMessage.reply('a1'), ChatMessage.user('u2'), ChatMessage.reply('a2')],
    );
    final conversation = conversationOver(transport);

    expect(conversation.replyActions(ChatMessage.reply('a1'), isLatestReply: false).onRegenerate, isNull);
    final latest = conversation.replyActions(ChatMessage.reply('a2'), isLatestReply: true);
    expect(latest.onRegenerate, isNotNull);

    latest.onRegenerate!();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.regenerate);
    expect(transport.lastRequest?.message?.id, 'a2');
    expect(
      conversation.replyActions(ChatMessage.reply('a2'), isLatestReply: true).onRegenerate,
      isNull,
      reason: 'the agent is answering',
    );
  });

  test('offers rating a reply, and shows its rating', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport);

    conversation.replyActions(ChatMessage.reply('a1'), isLatestReply: true).onRate!(AIMessageRating.negative);
    await settle();

    expect(
      conversation.replyActions(ChatMessage.reply('a1'), isLatestReply: true).rating,
      AIMessageRating.negative,
    );
    expect(transport.ratings.first.$2, AIMessageRating.negative);
  });

  test("offers editing the person's latest message while the agent isn't answering", () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1', 'Lisbon'),
        ChatMessage.reply('a1'),
        ChatMessage.user('u2', 'Porto'),
        ChatMessage.reply('a2'),
      ],
    );
    final conversation = conversationOver(transport);

    expect(conversation.editAction(ChatMessage.user('u1')), isNull);
    expect(conversation.editAction(ChatMessage.reply('a2')), isNull);
    expect(conversation.editAction(ChatMessage.reply('u2')), isNull, reason: 'a reply, whatever its id');
    final edit = conversation.editAction(ChatMessage.user('u2', 'Porto'));
    expect(edit, isNotNull);

    edit!();

    expect(conversation.editingMessage?.id, 'u2');
    expect(conversation.composer.text, 'Porto');

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2', text: 'Porto it is', generating: true),
    ]);

    expect(conversation.editAction(ChatMessage.user('u2')), isNull, reason: 'the agent is answering');
  });

  test("offers only what the app's actions allow", () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport, actions: AIConversationActions.rate);

    expect(conversation.replyActions(ChatMessage.reply('a1'), isLatestReply: true).onRegenerate, isNull);
    expect(conversation.replyActions(ChatMessage.reply('a1'), isLatestReply: true).onRate, isNotNull);
    expect(conversation.editAction(ChatMessage.user('u1')), isNull);
    expect(conversation.offersRegenerate(isLatestReply: true), isFalse);

    final nothing = conversationOver(transport, actions: AIConversationActions.none);

    expect(nothing.replyActions(ChatMessage.reply('a1'), isLatestReply: true).onRate, isNull);
    expect(conversationOver(transport).actions, AIConversationActions.all);
  });
}
