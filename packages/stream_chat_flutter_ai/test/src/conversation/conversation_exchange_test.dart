import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_exchange.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

final _conversation = [
  ChatMessage.user('u1'),
  ChatMessage.reply('a1'),
  ChatMessage.user('u2'),
  ChatMessage.reply('a2'),
];

void main() {
  test('ConversationExchange of a message, is on its way and replaces nothing', () {
    final photo = XFile('/tmp/alfama.jpg');
    final exchange = ConversationExchange(
      id: 1,
      request: AIConversationRequest<ChatMessage>(
        kind: AIConversationRequestKind.message,
        text: 'Hi',
        attachments: [photo],
        messageId: 'm1',
      ),
      conversation: _conversation,
    );

    expect(exchange.pending?.id, 'm1');
    expect(exchange.pending?.text, 'Hi');
    expect(
      [for (final a in exchange.pending!.attachments) a.image],
      [
        ResizeImage(FileImage(File(photo.path)), width: 540),
      ],
    );
    expect(exchange.replaced, isEmpty);
    expect(exchange.known, _conversation.ids.toSet());
  });

  test('ConversationExchange of a kind of its own, is on its way like a message', () {
    final exchange = ConversationExchange(
      id: 1,
      request: AIConversationRequest(
        kind: const AIConversationRequestKind('ui_action'),
        text: 'Picked Alfama',
        message: ChatMessage.reply('a2'),
      ),
      conversation: _conversation,
    );

    expect(exchange.pending?.text, 'Picked Alfama');
    expect(exchange.replaced, isEmpty);
  });

  test('ConversationExchange regenerating, replaces the reply and those after it', () {
    final exchange = _regenerate(ChatMessage.reply('a1'));

    expect(exchange.pending, isNull);
    expect(exchange.replaced.keys.toSet(), {'a1', 'u2', 'a2'});
  });

  test('ConversationExchange regenerating a reply not in the conversation, replaces nothing', () {
    expect(_regenerate(ChatMessage.reply('gone')).replaced, isEmpty);
  });

  test('ConversationExchange editing, replaces the message and those after it', () {
    final exchange = _edit();

    expect(exchange.replaced.keys.toSet(), {'u2', 'a2'});
    expect(exchange.pending?.text, 'Porto for two');
  });

  test('ConversationExchange its reply starts when a new reply shows something', () {
    final exchange = _message();

    expect(exchange.hasReplyStarted(_conversation), isFalse, reason: 'the latest reply was there before');
    expect(exchange.hasReplyStarted([..._conversation, ChatMessage.user('u3')]), isFalse);
    expect(
      exchange.hasReplyStarted([
        ..._conversation,
        ChatMessage.user('u3'),
        ChatMessage.reply('a3', text: '', generating: true),
      ]),
      isFalse,
    );
    expect(
      exchange.hasReplyStarted([
        ..._conversation,
        ChatMessage.user('u3'),
        ChatMessage.reply('a3', text: 'Sure', generating: true),
      ]),
      isTrue,
    );
    expect(
      exchange.hasReplyStarted([..._conversation, ChatMessage.user('u3'), ChatMessage.reply('a3', text: 'Sure')]),
      isTrue,
    );
    expect(
      exchange.hasReplyStarted([..._conversation, ChatMessage.user('u3'), ChatMessage.reply('a3', text: '')]),
      isTrue,
      reason: 'finished, with nothing to show',
    );
    expect(exchange.hasReplyStarted([]), isFalse);
  });

  test('ConversationExchange its reply starts when the one written again is rewritten', () {
    final exchange = _regenerate(ChatMessage.reply('a2'));
    final rewriting = _conversation.sublist(0, 3);

    expect(exchange.hasReplyStarted(_conversation), isFalse, reason: 'not rewritten yet');
    expect(
      exchange.reply([...rewriting, ChatMessage.reply('a2', generating: true)]),
      isNotNull,
      reason: 'started anew, though it says the same so far',
    );
    expect(exchange.hasReplyStarted([...rewriting, ChatMessage.reply('a2', text: '', generating: true)]), isFalse);
    expect(
      exchange.reply([...rewriting, ChatMessage.reply('a2', text: '', generating: true)]),
      isNotNull,
      reason: 'it is the reply, which shows nothing yet',
    );
    expect(
      exchange.hasReplyStarted([...rewriting, ChatMessage.reply('a2', text: 'Another', generating: true)]),
      isTrue,
    );
  });

  test('ConversationExchange its reply starts when the one written again arrives finished', () {
    final exchange = _regenerate(ChatMessage.reply('a2'));
    final rewriting = _conversation.sublist(0, 3);

    expect(
      exchange.hasReplyStarted([...rewriting, ChatMessage.reply('a2', text: 'Another plan')]),
      isTrue,
      reason: "an agent that doesn't stream",
    );
    expect(
      exchange.hasReplyStarted([...rewriting, ChatMessage.reply('a2')]),
      isFalse,
      reason: 'the reply as it was',
    );
  });

  test("ConversationExchange its reply starts when an edit's reply is rewritten", () {
    final exchange = _edit();
    final edited = [ChatMessage.user('u1'), ChatMessage.reply('a1'), ChatMessage.user('u2', 'Porto for two')];

    expect(exchange.hasReplyStarted(_conversation), isFalse, reason: 'nothing changed yet');
    expect(exchange.hasReplyStarted(edited), isFalse, reason: "the person's message isn't the reply");
    expect(exchange.hasReplyStarted([...edited, ChatMessage.reply('a2')]), isFalse, reason: 'the reply as it was');
    expect(
      exchange.hasReplyStarted([...edited, ChatMessage.reply('a2', text: 'For two', generating: true)]),
      isTrue,
    );
    expect(exchange.hasReplyStarted([...edited, ChatMessage.reply('a2', text: 'For two')]), isTrue);
  });

  test('ConversationExchange an answer that failed midway is not rewritten until it changes', () {
    final writing = [ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one', generating: true)];
    final exchange = ConversationExchange(
      id: 1,
      request: AIConversationRequest(kind: AIConversationRequestKind.regenerate, text: '', message: writing[1]),
      conversation: writing,
    );

    expect(exchange.reply(writing), isNull);
    expect(exchange.reply([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one')]), isNull);
    expect(
      exchange.reply([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one, day two', generating: true)]),
      isNotNull,
    );
  });

  test('ConversationExchange has not had its message arrive while nothing new is in the conversation', () {
    final exchange = _message(messageId: 'm1');

    expect(exchange.hasMessageArrived(_conversation), isFalse);
  });

  test('ConversationExchange has its message arrive as a message with its id', () {
    final exchange = _message(messageId: 'm1');

    expect(exchange.hasMessageArrived([..._conversation, ChatMessage.user('m1')]), isTrue);
  });

  test("ConversationExchange has its message arrive as the person's first new message", () {
    final exchange = _message(messageId: 'm1');

    expect(exchange.hasMessageArrived([..._conversation, ChatMessage.user('u3')]), isTrue);
  });

  test('ConversationExchange has not had its message arrive when older messages load above', () {
    final exchange = _message(messageId: 'm1');

    expect(exchange.hasMessageArrived([ChatMessage.user('u0'), ChatMessage.reply('a0'), ..._conversation]), isFalse);
  });

  test('ConversationExchange has not had its message arrive when only a reply is new', () {
    final exchange = _message(messageId: 'm1');

    expect(exchange.hasMessageArrived([..._conversation, ChatMessage.reply('a3')]), isFalse);
  });

  test("ConversationExchange a retry sends the request again, unless the agent couldn't answer a message it has", () {
    final exchange = _message(messageId: 'm1')..state = ExchangeState.failed;

    expect(
      exchange.retryRequest([..._conversation, ChatMessage.user('m1')]).messageId,
      'm1',
      reason: 'the same message, which the transport can tell',
    );
    expect(
      exchange.retryRequest([..._conversation, ChatMessage.user('m1')]).kind,
      AIConversationRequestKind.message,
    );

    exchange.state = ExchangeState.unanswered;

    expect(
      exchange.retryRequest(_conversation).kind,
      AIConversationRequestKind.message,
      reason: 'its message never arrived',
    );
    final reply = exchange.retryRequest([..._conversation, ChatMessage.user('m1')]);
    expect(reply.kind, AIConversationRequestKind.regenerate);
    expect(reply.text, 'Hi');
    expect(reply.message, isNull, reason: 'a reply to the latest message');
  });

  test("ConversationExchange a retry sends an edit again even when the agent couldn't answer it", () {
    final exchange = _edit()..state = ExchangeState.unanswered;

    expect(exchange.retryRequest([..._conversation, ChatMessage.user('u3')]).kind, AIConversationRequestKind.edit);
  });

  test("ConversationExchange the person's message shows until its reply, and afterwards only for a new message", () {
    final send = _message();
    final edit = _edit();
    expect(send.shownPending, isNotNull);
    expect(edit.shownPending, isNotNull);

    for (final state in [ExchangeState.stopped, ExchangeState.failed, ExchangeState.unanswered]) {
      send.state = state;
      edit.state = state;
      expect(send.shownPending, isNotNull);
      expect(edit.shownPending, isNull, reason: 'the edited message comes back');
      expect(send.hasFailed, state != ExchangeState.stopped);
    }
  });

  test('ConversationExchange an old reply still being written is not the new one', () {
    final writing = [ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one', generating: true)];
    final exchange = ConversationExchange(
      id: 1,
      request: AIConversationRequest<ChatMessage>(
        kind: AIConversationRequestKind.message,
        text: 'Make it three days',
      ),
      conversation: writing,
    );

    expect(
      exchange.hasReplyStarted([
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one, day two', generating: true),
      ]),
      isFalse,
    );
  });

  test('hasEmptyContent is true for a reply that has no text, steps or attachments', () {
    expect(hasEmptyContent(ChatMessage.reply('a1', text: '')), isTrue);
  });

  test('hasEmptyContent is false for a reply that has text', () {
    expect(hasEmptyContent(ChatMessage.reply('a1', text: 'Day one')), isFalse);
  });

  test('hasEmptyContent is false for a reply that has steps', () {
    final reply = ChatMessage.reply(
      'a1',
      text: '',
      parts: [AIMessagePart.fromReasoning(const AIReasoningPart(id: 'r1', summary: 'Weighing'))],
    );

    expect(hasEmptyContent(reply), isFalse);
  });

  test('hasEmptyContent is false for a reply that has attachments', () {
    final reply = ChatMessage(
      'a1',
      AIMessageRole.assistant,
      '',
      attachments: [AIMessageAttachment.file(Uri.parse('https://x.io/plan.pdf'))],
    );

    expect(hasEmptyContent(reply), isFalse);
  });

  test("hasEmptyContent is false for the person's message", () {
    expect(hasEmptyContent(ChatMessage.user('u1', '')), isFalse);
  });

  test('AIConversationRequest has the kinds of request', () {
    expect(AIConversationRequestKind.message, 'message');
    expect(AIConversationRequestKind.regenerate, 'regenerate');
    expect(AIConversationRequestKind.edit, 'edit');
    expect(const AIConversationRequestKind('edit'), AIConversationRequestKind.edit);
    expect(const AIConversationRequestKind('ui_action').isKnown, isFalse);
  });

  test('AIConversationRequest has a message id of its own by default', () {
    final first = AIConversationRequest<ChatMessage>(kind: AIConversationRequestKind.message, text: 'Hi');
    final second = AIConversationRequest<ChatMessage>(kind: AIConversationRequestKind.message, text: 'Hi');

    expect(first.messageId, isNotEmpty);
    expect(first.messageId, isNot(second.messageId));
    expect(first.attachments, isEmpty);
    expect(first.chatOption, isNull);
    expect(first.message, isNull);
  });
}

ConversationExchange<ChatMessage> _message({String? messageId}) => ConversationExchange(
  id: 1,
  request: AIConversationRequest(kind: AIConversationRequestKind.message, text: 'Hi', messageId: messageId),
  conversation: _conversation,
);

ConversationExchange<ChatMessage> _regenerate(ChatMessage reply) => ConversationExchange(
  id: 1,
  request: AIConversationRequest(kind: AIConversationRequestKind.regenerate, text: '', message: reply),
  conversation: _conversation,
);

ConversationExchange<ChatMessage> _edit() => ConversationExchange(
  id: 1,
  request: AIConversationRequest(
    kind: AIConversationRequestKind.edit,
    text: 'Porto for two',
    message: ChatMessage.user('u2'),
  ),
  conversation: _conversation,
);
