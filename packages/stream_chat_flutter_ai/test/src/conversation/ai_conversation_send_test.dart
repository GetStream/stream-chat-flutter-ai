import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

final _photo = XFile('/tmp/alfama.jpg');
final _plan = XFile('/tmp/itinerary.pdf');

void main() {
  test('shows a message sent at once and asks the transport', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport);
    const option = ChatOption(id: 'think_harder', text: 'Think harder');

    conversation.send('And the restaurants?', attachments: [_photo, _plan], chatOption: option);
    await settle();

    expect(conversation.status, AIConversationStatus.submitted);
    expect(conversation.composer.isGenerating, isTrue);
    final pending = conversation.pendingMessage!;
    expect(pending.text, 'And the restaurants?');
    expect(
      [for (final a in pending.attachments) a.kind],
      [AIMessageAttachmentKind.image, AIMessageAttachmentKind.file],
    );
    expect(pending.attachments[0].image, ResizeImage(FileImage(File(_photo.path)), width: 540));
    expect(pending.attachments[1].url, Uri.file(_plan.path));
    final request = transport.lastRequest!;
    expect(transport.requests, hasLength(1));
    expect(request.kind, AIConversationRequestKind.message);
    expect(request.text, 'And the restaurants?');
    expect(request.attachments, [_photo, _plan]);
    expect(request.chatOption, option);
    expect(request.message, isNull);
    expect(request.messageId, pending.id, reason: 'the transport can give the message the id its copy is found by');
    expect(conversation.messages.ids, ['u1', 'a1']);
  });

  test('keeps the same message on its way as the conversation updates', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..send('And the restaurants?', attachments: [_photo]);
    final pending = conversation.pendingMessage;

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Here is a better plan')]);

    expect(conversation.pendingMessage, same(pending));
  });

  test('keeps the attachments it was given when the caller changes the list', () async {
    final transport = ConversationTransport();
    final files = [_photo];
    final conversation = conversationOver(transport)..send('Look', attachments: files);

    files.add(_plan);
    await settle();

    expect(transport.lastRequest?.attachments, [_photo]);
    expect(conversation.pendingMessage?.attachments, hasLength(1));
  });

  test('ignores a message with nothing in it', () async {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport)..send('  \n ');
    await settle();

    expect(transport.requests, isEmpty);
    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.pendingMessage, isNull);
  });

  test('sends a message of only attachments', () async {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport)..send('', attachments: [_photo]);
    await settle();

    expect(transport.lastRequest?.attachments, [_photo]);
    expect(conversation.status, AIConversationStatus.submitted);
  });

  test('shows the error when the transport fails, and retry sends the message again', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..sendError = const TransportError();
    final conversation = conversationOver(transport)..send('And the restaurants?', attachments: [_photo]);
    await settle();

    expect(conversation.status, AIConversationStatus.error);
    expect(conversation.error, isA<TransportError>());
    expect(conversation.pendingMessage?.text, 'And the restaurants?', reason: 'the message stays, to try again');
    expect(conversation.composer.isGenerating, isFalse);
    final failed = transport.lastRequest!;

    transport.sendError = null;
    conversation.retry();
    await settle();

    expect(transport.requests, hasLength(2));
    expect(transport.lastRequest?.kind, AIConversationRequestKind.message);
    expect(transport.lastRequest?.text, 'And the restaurants?');
    expect(transport.lastRequest?.attachments, [_photo]);
    expect(transport.lastRequest?.messageId, failed.messageId, reason: 'the transport can tell the message');
    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.submitted);
    expect(conversation.pendingMessage?.text, 'And the restaurants?');
  });

  test('shows no error for a request the transport cancelled', () async {
    final transport = ConversationTransport()..sendError = const AIConversationCancelledException();
    final conversation = conversationOver(transport)..send('Hi');
    await settle();

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.pendingMessage, isNull);
  });

  test('ignores the failure of a request that was overtaken', () async {
    final transport = ConversationTransport()..holdsSends = true;
    final conversation = conversationOver(transport)
      ..send('First')
      ..send('Second');
    await settle();
    transport.finishSend(0, error: const TransportError());
    await settle();

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.submitted);
    expect(conversation.pendingMessage?.text, 'Second');

    transport.finishSend(1);
    await settle();

    expect(conversation.status, AIConversationStatus.submitted, reason: 'a request that reaches the agent waits');
  });

  test('ignores a failure of the transport after the reply arrived', () async {
    final transport = ConversationTransport()..holdsSends = true;
    final conversation = conversationOver(transport)..send('Hi');
    await settle();
    transport
      ..update([ChatMessage.user('u1', 'Hi'), ChatMessage.reply('a1', text: 'Hello')])
      ..finishSend(0, error: const TransportError());
    await settle();

    expect(conversation.error, isNull, reason: 'the agent had it');
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('shows a failure of the transport while a reply is written once the reply is finished', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..sendError = const TransportError();
    final conversation = conversationOver(transport)..send('Make it three days');
    await settle();

    expect(conversation.error, isA<TransportError>());
    expect(conversation.status, AIConversationStatus.streaming, reason: 'the agent is still answering');

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one, day two')]);

    expect(conversation.status, AIConversationStatus.error);
  });

  test('forgets the error of a failed request that is answered after all', () async {
    final transport = ConversationTransport()..sendError = const TransportError();
    final conversation = conversationOver(transport)..send('Hi');
    await settle();

    transport.update([ChatMessage.user('u1', 'Hi'), ChatMessage.reply('a1', text: 'Hello', generating: true)]);

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('forgets the previous error', () async {
    final transport = ConversationTransport()..sendError = const TransportError();
    final conversation = conversationOver(transport)..send('Hi');
    await settle();
    expect(conversation.error, isNotNull);

    transport.sendError = null;
    conversation.send('Hi again');

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.submitted);
  });
}
