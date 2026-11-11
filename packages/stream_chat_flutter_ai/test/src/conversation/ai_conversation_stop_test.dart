import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test('stop ends the reply and tells the transport', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    );
    final conversation = conversationOver(transport);
    expect(conversation.status, AIConversationStatus.streaming);

    conversation.stop();
    await settle();

    expect(transport.stops, 1);
    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.composer.isGenerating, isFalse);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one', generating: true)]);

    expect(conversation.status, AIConversationStatus.ready, reason: 'a stopped reply is finished');
    expect(conversation.messages.ids, ['u1', 'a1'], reason: 'what it wrote so far stays');
  });

  test("stop while waiting, keeps the person's message", () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)
      ..send('Hi')
      ..stop();
    await settle();

    expect(conversation.pendingMessage?.text, 'Hi', reason: 'it is on its way until its copy arrives');
    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.composer.isGenerating, isFalse);
    expect(transport.stops, 1);
  });

  test('stop while waiting, finishes a reply that arrives later', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)
      ..send('Hi')
      ..stop();
    await settle();

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Hi'),
      ChatMessage.reply('a2', text: '', generating: true),
    ]);

    expect(conversation.status, AIConversationStatus.ready);
    expect(conversation.messages.ids, ['u1', 'a1', 'u2'], reason: 'it has nothing to show');

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Hi'),
      ChatMessage.reply('a2', text: 'Hello', generating: true),
    ]);

    expect(conversation.status, AIConversationStatus.ready, reason: 'the person stopped it');
    expect(conversation.composer.isGenerating, isFalse);
    expect(conversation.messages.ids, ['u1', 'a1', 'u2', 'a2']);
    expect(conversation.pendingMessage, isNull);
  });

  test("stop while waiting, lets the next request's reply stream", () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)
      ..send('Hi')
      ..stop();
    await settle();

    conversation.send('Porto?');
    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Hi'),
      ChatMessage.user('u3', 'Porto?'),
      ChatMessage.reply('a3', text: 'Sure', generating: true),
    ]);

    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('stop while waiting for a regenerated reply, brings the reply back', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..regenerate(ChatMessage.reply('a1'));
    expect(conversation.messages.ids, ['u1']);

    conversation.stop();

    expect(conversation.messages.ids, ['u1', 'a1']);
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('stop holds the next request until the stop reaches the transport', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..holdsStops = true;
    final conversation = conversationOver(transport)
      ..stop()
      ..send('Something else');
    await settle();

    expect(transport.stops, 1);
    expect(transport.requests, isEmpty, reason: 'the stop would stop it too');
    expect(conversation.status, AIConversationStatus.submitted);

    transport.finishStop(0);
    await settle();

    expect(transport.lastRequest?.text, 'Something else');
  });

  test('stop leaves out a reply that shows nothing', () {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: '', generating: true),
      ],
    );
    final conversation = conversationOver(transport);
    expect(conversation.status, AIConversationStatus.submitted);

    conversation.stop();

    expect(conversation.messages.ids, ['u1'], reason: 'the conversation would think it is still on its way');
    expect(conversation.status, AIConversationStatus.ready);
  });

  test('stop does nothing while the agent is not answering', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    conversationOver(transport).stop();
    await settle();

    expect(transport.stops, 0);
  });

  test('stop ignores what the agent says until it stops saying', () {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1')]);
    final conversation = conversationOver(transport);
    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.thinking));
    expect(conversation.status, AIConversationStatus.submitted);

    conversation.stop();
    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.generating));

    expect(conversation.activity, isNull);
    expect(conversation.status, AIConversationStatus.ready);

    transport
      ..updateActivity(null)
      ..updateActivity(const AIAgentActivity(state: AIAgentActivityState.thinking));

    expect(conversation.activity, const AIAgentActivity(state: AIAgentActivityState.thinking));
    expect(conversation.status, AIConversationStatus.submitted);
  });

  test('stop shows the reply still being written when the transport fails', () async {
    final errors = captureErrors();
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..stopError = const TransportError();
    final conversation = conversationOver(transport)..stop();
    await settle();

    expect(conversation.error, isNull, reason: 'nothing to try again');
    expect(conversation.status, AIConversationStatus.streaming);
    expect(conversation.composer.isGenerating, isTrue, reason: 'the composer offers to stop it again');
    expect([for (final e in errors) e.exception], [const TransportError()]);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one, day two')]);

    expect(conversation.status, AIConversationStatus.ready);
  });

  test('stop handles a transport that fails to stop at once only after the stop returned', () async {
    final errors = captureErrors();
    final conversation = conversationOver(_FailsAtOnceTransport());
    var notifications = 0;
    conversation
      ..addListener(() => notifications += 1)
      ..stop();

    expect(conversation.status, AIConversationStatus.ready, reason: 'stopped until the transport has failed');
    expect(notifications, 1);
    expect(errors, isEmpty);

    await settle();

    expect(conversation.status, AIConversationStatus.streaming);
    expect(conversation.composer.isGenerating, isTrue);
    expect(notifications, 2);
    expect([for (final e in errors) e.exception], [const TransportError()]);
  });

  test('stop heeds what the agent says again when the transport fails', () async {
    captureErrors();
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..stopError = const TransportError();
    final conversation = conversationOver(transport)..stop();
    await settle();

    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.checkingExternalSources));

    expect(conversation.activity?.state, AIAgentActivityState.checkingExternalSources);
  });

  test('stop lets a reply it stopped stream again once it is written anew', () async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    );
    final conversation = conversationOver(transport)..stop();
    await settle();
    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Day one')]);

    conversation.regenerate(ChatMessage.reply('a1'));
    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1', text: 'Another', generating: true)]);

    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('stop while waiting, waits for the reply again when the transport fails', () async {
    captureErrors();
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..stopError = const TransportError();
    final conversation = conversationOver(transport)
      ..send('Hi')
      ..stop();
    await settle();

    expect(conversation.status, AIConversationStatus.submitted);

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Hi'),
      ChatMessage.reply('a2', text: 'Hello', generating: true),
    ]);

    expect(conversation.status, AIConversationStatus.streaming);
  });

  test('stop ignores a failure of the transport after a new request', () async {
    final errors = captureErrors();
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..stopError = const TransportError();
    final conversation = conversationOver(transport)
      ..stop()
      ..send('Something else');
    await settle();

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.submitted);
    expect(errors, isEmpty);
  });

  test('stop reports nothing for a stop the transport cancelled', () async {
    final errors = captureErrors();
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    )..stopError = const AIConversationCancelledException();
    final conversation = conversationOver(transport)..stop();
    await settle();

    expect(errors, isEmpty);
    expect(conversation.status, AIConversationStatus.ready);
  });
}

/// A transport whose `stop` throws before it returns a future.
class _FailsAtOnceTransport with AIConversationTransport<ChatMessage> {
  @override
  void connect(AIConversationFeed<ChatMessage> feed) {
    feed.updateMessages([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1', text: 'Day one', generating: true),
    ]);
  }

  @override
  Future<void> send(AIConversationRequest<ChatMessage> request) async {}

  @override
  Future<void> stop() => throw const TransportError();
}
