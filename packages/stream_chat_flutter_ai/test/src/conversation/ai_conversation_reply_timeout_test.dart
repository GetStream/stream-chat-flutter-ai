import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  testWidgets("shows the agent's error when the reply doesn't start in time", (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _conversation(transport, const Duration(milliseconds: 50))..send('Hi');
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 50));

    expect(conversation.status, AIConversationStatus.error);
    expect(conversation.error, const AIAgentError());
    expect(conversation.pendingMessage?.text, 'Hi');
  });

  testWidgets('shows a reply that starts after the timeout as an answer after all', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _conversation(transport, const Duration(milliseconds: 50))..send('Hi');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    transport.update([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2', 'Hi'),
      ChatMessage.reply('a2', text: 'Hello', generating: true),
    ]);

    expect(conversation.error, isNull);
    expect(conversation.status, AIConversationStatus.streaming);
  });

  testWidgets('waits for the reply while the agent says it is working', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _conversation(transport, const Duration(milliseconds: 100))..send('Hi');
    await tester.pump();

    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.thinking));
    await tester.pump(const Duration(milliseconds: 400));

    expect(conversation.status, AIConversationStatus.submitted, reason: 'however long it thinks');
    expect(conversation.error, isNull);
  });

  testWidgets('shows the error when the agent stops saying it is working without answering', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _conversation(transport, const Duration(milliseconds: 100))..send('Hi');
    await tester.pump();
    transport.updateActivity(const AIAgentActivity(state: AIAgentActivityState.thinking));
    await tester.pump(const Duration(milliseconds: 400));

    transport.updateActivity(null);
    await tester.pump(const Duration(milliseconds: 100));

    expect(conversation.status, AIConversationStatus.error);
    expect(conversation.error, const AIAgentError());
  });

  testWidgets('waits for the reply when the agent says it is working before the transport returns', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..holdsSends = true;
    final conversation = _conversation(transport, const Duration(milliseconds: 100))..send('Hi');
    await tester.pump();

    transport
      ..updateActivity(const AIAgentActivity(state: AIAgentActivityState.thinking))
      ..finishSend(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(conversation.status, AIConversationStatus.submitted);
  });

  testWidgets('waits as long as it takes without a timeout', (tester) async {
    final conversation = _conversation(ConversationTransport(), null)..send('Hi');
    await tester.pump();

    await tester.pump(const Duration(days: 1));

    expect(conversation.status, AIConversationStatus.submitted);
  });

  testWidgets('waits as long as it takes with a very long timeout', (tester) async {
    final conversation = AIConversation(
      transport: ConversationTransport(),
      replyTimeout: const Duration(days: 365000),
    )..send('Hi');
    await tester.pump();

    await tester.pump(const Duration(days: 1));

    expect(conversation.status, AIConversationStatus.submitted);
    // Its timer is still pending, which a tear-down would cancel too late.
    conversation.dispose();
  });
}

AIConversation<ChatMessage> _conversation(ConversationTransport transport, Duration? replyTimeout) {
  final conversation = AIConversation(transport: transport, replyTimeout: replyTimeout);
  addTearDown(conversation.dispose);
  return conversation;
}
