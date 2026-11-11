import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

const _thinking = AIAgentActivity(state: AIAgentActivityState.thinking);
const _failed = AIAgentActivity(state: AIAgentActivityState.error);

void main() {
  test("activity shows the agent working while the person's message waits", () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1')]);
    final conversation = conversationOver(transport);
    expect(conversation.status, AIConversationStatus.ready);

    transport.updateActivity(
      const AIAgentActivity(state: AIAgentActivityState.checkingExternalSources, text: 'Searching the web'),
    );

    expect(conversation.activity?.text, 'Searching the web');
    expect(conversation.status, AIConversationStatus.submitted);
    expect(conversation.composer.isGenerating, isTrue);

    transport.updateActivity(null);

    expect(conversation.activity, isNull);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('activity shows the agent working in an empty conversation', () {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport);

    transport.updateActivity(_thinking);

    expect(conversation.status, AIConversationStatus.submitted);
  });

  test("activity after a finished reply, doesn't mean the agent is answering", () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport);

    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.generating));

    expect(conversation.activity?.state, AIAgentActivityState.generating);
    expect(conversation.status, AIConversationStatus.ready, reason: "an indicator that wasn't cleared yet");
  });

  test("activity in the error state, ends the request with the agent's error", () async {
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1', 'Lisbon?'), ChatMessage.reply('a1')],
    );
    final conversation = conversationOver(transport)..send('Porto?');
    transport
      ..update([ChatMessage.user('u1', 'Lisbon?'), ChatMessage.reply('a1'), ChatMessage.user('u2', 'Porto?')])
      ..updateActivity(const AIAgentActivity(state: AIAgentActivityState.error, text: 'Rate limited'));

    expect(conversation.pendingMessage?.text, 'Porto?', reason: 'its copy takes its place');
    expect(conversation.status, AIConversationStatus.error);
    expect(conversation.error, const AIAgentError(message: 'Rate limited'));
    expect((conversation.error! as AIAgentError).localizedMessage(const DefaultAITranslations()), 'Rate limited');

    transport.updateActivity(null);

    expect(conversation.status, AIConversationStatus.error, reason: 'it stays until the next request');

    conversation.retry();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.regenerate);
    expect(transport.lastRequest?.text, 'Porto?');
    expect(transport.lastRequest?.message, isNull, reason: 'the message has no reply to replace');
    expect(conversation.status, AIConversationStatus.submitted);
    expect(conversation.error, isNull);
  });

  test('activity in the error state while a reply is written, finishes it', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    );
    final conversation = conversationOver(transport);

    transport.updateActivity(_failed);

    expect(conversation.status, AIConversationStatus.error);
    expect(conversation.messages.ids, ['u1', 'a1']);

    conversation.retry();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.regenerate);
    expect(transport.lastRequest?.message?.id, 'a1');
  });

  test('activity in the error state, ignores the failure of the request it ended', () async {
    final transport = ConversationTransport()..holdsSends = true;
    final conversation = conversationOver(transport)..send('Hi');
    await settle();

    transport
      ..updateActivity(const AIAgentActivity(state: AIAgentActivityState.error, text: 'Rate limited'))
      ..finishSend(0, error: const TransportError());
    await settle();

    expect(conversation.error, const AIAgentError(message: 'Rate limited'));
  });

  test("activity in the error state before the person's message arrives, retry sends it again", () async {
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1', 'Lisbon?'), ChatMessage.reply('a1')],
    );
    final conversation = conversationOver(transport)..send('Porto?');
    await settle();
    final sent = transport.lastRequest!;

    transport
      ..updateActivity(const AIAgentActivity(state: AIAgentActivityState.error, text: "Couldn't read it"))
      ..updateActivity(null);

    expect(conversation.pendingMessage?.text, 'Porto?');
    expect(conversation.messages.ids, ['u1', 'a1']);

    conversation.retry();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.message, reason: 'not a1 written again');
    expect(transport.lastRequest?.messageId, sent.messageId);
    expect(transport.lastRequest?.text, 'Porto?');
  });

  test("activity in the error state when the person's message arrives after it, retry asks for its reply", () async {
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1', 'Lisbon?'), ChatMessage.reply('a1')],
    );
    final conversation = conversationOver(transport)..send('Porto?');
    await settle();

    transport
      ..updateActivity(_failed)
      ..update([ChatMessage.user('u1', 'Lisbon?'), ChatMessage.reply('a1'), ChatMessage.user('u2', 'Porto?')]);
    conversation.retry();
    await settle();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.regenerate);
    expect(transport.lastRequest?.text, 'Porto?');
    expect(transport.lastRequest?.message, isNull);
  });

  test('activity in the error state, is forgotten once a new reply starts', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..send('Porto?');
    transport
      ..update([ChatMessage.user('u1'), ChatMessage.reply('a1'), ChatMessage.user('u2', 'Porto?')])
      ..updateActivity(_failed)
      ..updateActivity(null);
    expect(conversation.status, AIConversationStatus.error);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Porto?'),
      ChatMessage.reply('a2', text: 'Porto it is', generating: true),
    ]);

    expect(conversation.error, isNull, reason: 'the agent answered after all');
    expect(conversation.status, AIConversationStatus.streaming);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Porto?'),
      ChatMessage.reply('a2', text: 'Porto it is'),
    ]);

    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.pendingMessage, isNull);
  });

  test('activity in the error state while a reply is written, is forgotten once the agent writes on', () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    );
    final conversation = conversationOver(transport);
    transport
      ..updateActivity(_failed)
      ..updateActivity(null)
      ..update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one')]);

    expect(conversation.status, AIConversationStatus.error, reason: 'the same reply, finished');

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2', text: 'Day two', generating: true),
    ]);

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('activity is forgotten when the person sends a message', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport);
    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.checkingExternalSources));

    conversation.send('Hi');

    expect(conversation.activity, isNull);
  });

  test('retry does nothing without an error', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    conversationOver(transport).retry();
    await settle();

    expect(transport.requests, isEmpty);
  });

  test('retry has nothing to try after a stop failed', () async {
    captureErrors();
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..stopError = const TransportError();
    final conversation = conversationOver(transport)..stop();
    await settle();

    conversation.retry();
    await settle();

    expect(transport.requests, isEmpty);
  });

  test('retry does nothing after the agent failed in an empty conversation', () async {
    final transport = ConversationTransport();
    final conversation = conversationOver(transport);
    transport.updateActivity(_failed);

    conversation.retry();
    await settle();

    expect(transport.requests, isEmpty);
  });

  test('clearError forgets the error and the request that failed', () async {
    final transport = ConversationTransport()..sendError = const TransportError();
    final conversation = conversationOver(transport)..send('Hi');
    await settle();

    conversation
      ..clearError()
      ..retry();
    await settle();

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.ready);
    expect(transport.requests, hasLength(1));
  });
}
