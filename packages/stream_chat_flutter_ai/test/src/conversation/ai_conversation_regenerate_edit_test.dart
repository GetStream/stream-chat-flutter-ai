import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

final _photo = XFile('/tmp/alfama.jpg');

void main() {
  test('regenerate asks for a new reply in place of the old', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1', 'Lisbon?'),
        ChatMessage.reply('a1'),
        ChatMessage.user('u2', 'Porto?'),
        ChatMessage.reply('a2'),
      ],
    );
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('a2'));
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.regenerate);
    expect(transport.lastRequest?.text, 'Porto?', reason: 'a transport that can only send messages asks again');
    expect(transport.lastRequest?.message?.id, 'a2');
    expect(conversation.messages.ids, ['u1', 'a1', 'u2']);
    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.submitted);
  });

  test('regenerate sends the reply as the conversation has it', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'The latest text'),
      ],
    );
    conversationOver(transport).regenerate(ChatMessage.reply('a1', text: 'What a view once showed'));
    await settle();

    expect(transport.lastRequest?.message?.text, 'The latest text');
  });

  test('regenerate of an earlier reply, leaves out those after it', () {
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1'), ChatMessage.reply('a1'), ChatMessage.user('u2'), ChatMessage.reply('a2')],
    );
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('a1'));

    expect(conversation.messages.ids, ['u1']);
  });

  test('regenerate shows the new reply once it starts', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('a1'));
    transport.update([ChatMessage.user('u1')]);

    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a2', text: 'Another plan', generating: true)]);

    expect(conversation.messages.ids, ['u1', 'a2']);
    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('regenerate shows the reply rewritten in place once it shows something', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('a1'));
    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: '', generating: true)]);

    expect(conversation.messages.ids, ['u1']);
    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Another', generating: true)]);

    expect(conversation.messages.ids, ['u1', 'a1']);
    expect(conversation.messages.last.text, 'Another');
    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('regenerate brings the reply back when the transport fails', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..sendError = const TransportError();
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('a1'));
    await settle();

    expect(conversation.messages.ids, ['u1', 'a1']);
    expect(conversation.status, AIConversationStatus.error);

    transport.sendError = null;
    conversation.retry();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.regenerate);
    expect(transport.lastRequest?.message?.id, 'a1');
  });

  test("regenerate ignores the person's messages", () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..regenerate(ChatMessage.user('u1'));
    await settle();

    expect(transport.requests, isEmpty);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('regenerate ignores a reply that is not in the conversation', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('gone'));
    await settle();

    expect(transport.requests, isEmpty);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('regenerate asks again with no text for a reply with no message before it', () async {
    final transport = ConversationTransport(messages: [ChatMessage.reply('a0', text: 'Hi! How can I help?')]);
    conversationOver(transport).regenerate(ChatMessage.reply('a0'));
    await settle();

    expect(transport.lastRequest?.text, '');
    expect(transport.lastRequest?.message?.id, 'a0');
  });

  test('edit puts the message in the composer', () {
    final conversation = conversationOver(
      ConversationTransport(messages: [ChatMessage.user('u1', 'Plan Lisbon'), ChatMessage.reply('a1')]),
    )..edit(ChatMessage.user('u1', 'Plan Lisbon'));

    expect(conversation.editingMessage?.id, 'u1');
    expect(conversation.composer.text, 'Plan Lisbon');
    expect(conversation.composer.isEditing, isTrue, reason: 'the composer shows the person is editing');
  });

  test('edit cancelled in the composer, sends a new message', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1'),
        ChatMessage.user('u2', 'Plan Porto'),
        ChatMessage.reply('a2'),
      ],
    );
    final conversation = conversationOver(transport)..edit(ChatMessage.user('u2', 'Plan Porto'));

    conversation.composer.cancelEditing();
    conversation.send("What's the weather in Tokyo?");
    await settle();

    expect(conversation.editingMessage, isNull);
    expect(conversation.composer.text, '');
    expect(transport.lastRequest?.kind, AIConversationRequestKind.message);
    expect(conversation.messages.ids, ['u1', 'a1', 'u2', 'a2']);
  });

  test('edit brings the messages back when the transport fails', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..sendError = const TransportError();
    final conversation = conversationOver(transport)
      ..edit(ChatMessage.user('u1'))
      ..send('Plan Porto');
    await settle();

    expect(conversation.messages.ids, ['u1', 'a1']);
    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.error);

    transport.sendError = null;
    conversation.retry();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.edit);
    expect(transport.lastRequest?.text, 'Plan Porto');
  });

  test('edit ignores replies', () {
    final conversation = conversationOver(
      ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]),
    )..edit(ChatMessage.reply('a1'));

    expect(conversation.editingMessage, isNull);
    expect(conversation.composer.text, '');
  });

  test('edit sending while editing replaces the message and what follows', () async {
    final original = ChatMessage(
      'u2',
      AIMessageRole.user,
      'Plan Porto',
      attachments: [AIMessageAttachment.image(Uri.parse('https://example.com/porto.jpg'))],
    );
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1'), ChatMessage.reply('a1'), original, ChatMessage.reply('a2')],
    );
    final conversation = conversationOver(transport)
      ..edit(original)
      ..send('Plan Porto for two', attachments: [_photo]);
    await settle();

    expect(conversation.editingMessage, isNull);
    expect(conversation.composer.isEditing, isFalse);
    expect(transport.lastRequest?.kind, AIConversationRequestKind.edit);
    expect(transport.lastRequest?.message?.id, 'u2');
    expect(transport.lastRequest?.text, 'Plan Porto for two');
    expect(conversation.messages.ids, ['u1', 'a1']);
    final pending = conversation.pendingMessage!;
    expect(pending.text, 'Plan Porto for two');
    expect(pending.attachments[0].url, Uri.parse('https://example.com/porto.jpg'), reason: 'the edit keeps them');
    expect(pending.attachments[1].image, ResizeImage(FileImage(File(_photo.path)), width: 540));
    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Plan Porto for two'),
      ChatMessage.reply('a3', text: 'For two', generating: true),
    ]);

    expect(conversation.messages.ids, ['u1', 'a1', 'u2', 'a3']);
    expect(conversation.pendingMessage, isNull);
    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('cancelEditing empties the composer', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)
      ..edit(ChatMessage.user('u1'))
      ..cancelEditing()
      ..send('Something else');
    await settle();

    expect(conversation.editingMessage, isNull);
    expect(conversation.composer.text, '');
    expect(transport.lastRequest?.kind, AIConversationRequestKind.message);
  });

  test('cancelEditing keeps the composer while not editing', () {
    final conversation = conversationOver(ConversationTransport());
    conversation.composer.textEditingController.text = 'Half a thought';

    conversation.cancelEditing();

    expect(conversation.composer.text, 'Half a thought');
  });
}
