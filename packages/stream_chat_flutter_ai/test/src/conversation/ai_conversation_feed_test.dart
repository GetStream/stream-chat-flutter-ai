import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test('connects to its transport', () {
    final transport = ConversationTransport();
    conversationOver(transport);

    expect(transport.feed, isNotNull);
  });

  test("starts with its transport's messages", () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport);

    expect(conversation.messages.ids, ['u1', 'a1']);
  });

  test('starts ready', () {
    final conversation = conversationOver(ConversationTransport());

    expect(conversation.status, AIConversationStatus.ready);
  });

  test('starts with no message on its way', () {
    final conversation = conversationOver(ConversationTransport());

    expect(conversation.pendingMessage, isNull);
  });

  test('starts without an error', () {
    final conversation = conversationOver(ConversationTransport());

    expect(conversation.error, isNull);
  });

  test('starts without older messages to load', () {
    final conversation = conversationOver(ConversationTransport());

    expect(conversation.hasOlderMessages, isFalse);
  });

  test('starts with a composer that is not generating', () {
    final conversation = conversationOver(ConversationTransport());

    expect(conversation.composer.isGenerating, isFalse);
  });

  test('keeps the composer it is given', () {
    final composer = ChatComposerController();
    addTearDown(composer.dispose);
    final conversation = conversationOver(ConversationTransport(), composer: composer);

    expect(conversation.composer, same(composer));
  });

  test('keeps the approver it is given', () {
    final approver = AIToolApprover(
      identity: const AIClientIdentity(userId: 'u_1', clientId: 'ios-1'),
      decide: (_, _) async {},
    );
    addTearDown(approver.dispose);
    final conversation = conversationOver(ConversationTransport(), approver: approver);

    expect(conversation.approver, same(approver));
  });

  test('takes the messages its transport updates', () {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1')]);

    expect(conversation.messages.ids, ['u1', 'a1']);
  });

  test('takes whether its transport has older messages to load', () {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport);

    transport.feed!.updateHasOlderMessages(true);
    expect(conversation.hasOlderMessages, isTrue);

    transport.feed!.updateHasOlderMessages(false);
    expect(conversation.hasOlderMessages, isFalse);
  });
}
