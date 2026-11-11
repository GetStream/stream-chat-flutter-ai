import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import '../genui/genui_test_doubles.dart';
import 'ai_conversation_test_doubles.dart';

void main() {
  testWidgets('conversation view shows the conversation as it is', (tester) async {
    final conversation = _conversation([ChatMessage.user('u1', 'Lisbon?'), ChatMessage.reply('a1')]);
    await _pump(tester, conversation);

    expect(find.text('Lisbon?'), findsOneWidget);
    expect(_text("Here's a plan"), findsOneWidget);
    expect(find.byType(AIThinkingView), findsNothing);

    conversation.send('Porto?');
    await tester.pump();

    expect(find.text('Porto?'), findsOneWidget, reason: 'the message on its way shows straight away');
    expect(find.byType(AIThinkingView), findsOneWidget);
  });

  testWidgets('conversation view shows the agent thinking while a reply is written again', (tester) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    await _pump(tester, conversation);

    conversation.regenerate(ChatMessage.reply('a1'));
    await tester.pump();

    expect(_text("Here's a plan"), findsNothing);
    expect(find.byType(AIThinkingView), findsOneWidget, reason: 'no message is on its way, but a reply is');
  });

  testWidgets("conversation view doesn't show the agent thinking once it is stopped", (tester) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    await _pump(tester, conversation);
    conversation.send('Porto?');
    await tester.pump();
    expect(find.byType(AIThinkingView), findsOneWidget);

    conversation.stop();
    await tester.pump();

    expect(find.byType(AIThinkingView), findsNothing);
    expect(find.text('Porto?'), findsOneWidget, reason: "the person's message stays");
  });

  testWidgets("conversation view doesn't show the agent thinking once a message failed", (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..sendError = const TransportError();
    final conversation = _over(transport);
    await _pump(tester, conversation);

    conversation.send('Porto?');
    await tester.pumpAndSettle();

    expect(conversation.status, AIConversationStatus.error);
    expect(find.text('Porto?'), findsOneWidget, reason: 'the message stays, to try again');
    expect(find.byType(AIThinkingView), findsNothing);
  });

  testWidgets('conversation view shows its footer under the empty content of an empty conversation', (tester) async {
    await _pump(
      tester,
      _conversation(const []),
      footer: const Text('footer'),
      emptyContent: const Text('empty'),
    );

    expect(find.text('empty'), findsOneWidget);
    expect(find.text('footer'), findsOneWidget, reason: 'such as the error of a first message that failed');
    expect(tester.getTopLeft(find.text('footer')).dy, greaterThan(tester.getTopLeft(find.text('empty')).dy));
  });

  testWidgets('conversation view loads older messages while there are any', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _over(transport);
    await _pump(tester, conversation);

    expect(_olderMessagesLoader, findsNothing);

    transport.feed!.updateHasOlderMessages(true);
    await tester.pump();
    await tester.drag(find.byType(Scrollable), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_olderMessagesLoader, findsOneWidget);
    expect(transport.loads, 1);
  });

  testWidgets('conversation view shows a footer and empty content that follow the conversation', (tester) async {
    final transport = ConversationTransport()..sendError = const TransportError();
    final conversation = _over(transport);
    await _pump(
      tester,
      conversation,
      footer: ListenableBuilder(
        listenable: conversation,
        builder: (context, _) => Text(conversation.error == null ? 'No error' : "Couldn't send"),
      ),
      emptyContent: ListenableBuilder(
        listenable: conversation.composer,
        builder: (context, _) => Text('Draft: ${conversation.composer.text}'),
      ),
    );
    expect(find.text('No error'), findsOneWidget);

    conversation.composer.textEditingController.text = 'Hello';
    await tester.pump();

    expect(find.text('Draft: Hello'), findsOneWidget);

    conversation.send('Hi');
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send"), findsOneWidget);
  });

  testWidgets("conversation view hands the conversation's approver to its rows", (tester) async {
    final approver = _approver();
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')], approver: approver);
    await _pump(tester, conversation);

    expect(tester.widget<AIAssistantMessageView>(find.byType(AIAssistantMessageView)).approver, same(approver));
  });

  testWidgets("conversation view hands the conversation's actions to the builders", (tester) async {
    final conversation = _conversation([
      ChatMessage.user('u1'),
      ChatMessage.reply('a1'),
      ChatMessage.user('u2'),
      ChatMessage.reply('a2'),
    ]);
    final recorded = _Recorded();
    await _pump(tester, conversation, builders: recorded.builders);

    expect(recorded.edits, {'u1': false, 'u2': true}, reason: 'the person edits their latest message');
    expect(recorded.actions['a1']?.onRegenerate, isNull, reason: 'only the latest reply is written again');
    expect(recorded.actions['a2']?.onRegenerate, isNotNull);

    recorded.actions['a1']!.onRate!(AIMessageRating.positive);

    expect(conversation.ratings['a1'], AIMessageRating.positive);
  });

  testWidgets("conversation view hands the conversation's approver to the assistant message builder", (tester) async {
    final approver = _approver();
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')], approver: approver);
    final approvers = <AIToolApprover?>[];
    await _pump(
      tester,
      conversation,
      builders: StreamComponentBuilders(
        extensions: streamAIComponentBuilders(
          assistantMessage: (context, props) {
            approvers.add(props.approver);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(approvers, isNotEmpty);
    expect(approvers, everyElement(same(approver)));
  });

  testWidgets('conversation view follows the conversation as it changes', (tester) async {
    final transport = ConversationTransport();
    final conversation = _over(transport);
    await _pump(tester, conversation, emptyContent: const Text('How can I help?'));

    transport.update([ChatMessage.user('u1', 'Lisbon?')]);
    await tester.pump();

    expect(find.text('Lisbon?'), findsOneWidget);
    expect(find.text('How can I help?'), findsNothing);
  });

  testWidgets(
    'conversation view with generated UI shows a reply that shows only its UI rather than the agent thinking',
    (tester) async {
      final reply = ChatMessage.reply('a1', text: '', generating: true, uiDocument: openUI('Ohrid plan card'));
      final conversation = _conversation([ChatMessage.user('u1'), reply]);

      await _pump(tester, conversation);

      expect(conversation.status, AIConversationStatus.submitted, reason: "it can't tell the reply shows anything");
      expect(_text('Ohrid plan card'), findsNothing);
      expect(find.byType(AIThinkingView), findsOneWidget);

      await _pump(tester, conversation, ui: testHost());

      expect(_text('Ohrid plan card'), findsOneWidget);
      expect(find.byType(AIThinkingView), findsNothing, reason: "the reply's UI shows");
    },
  );

  testWidgets("conversation view with generated UI shows the agent thinking while nothing reads the reply's UI", (
    tester,
  ) async {
    final reply = ChatMessage.reply(
      'a1',
      text: '',
      generating: true,
      uiDocument: const AIUIDocument(format: AIUIFormat('cards'), content: '{}'),
    );
    await _pump(tester, _conversation([ChatMessage.user('u1'), reply]), ui: testHost());

    expect(find.byType(AIThinkingView), findsOneWidget);
  });

  testWidgets('conversation view with generated UI shows the agent thinking while a message is on its way', (
    tester,
  ) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    await _pump(tester, conversation, ui: testHost());

    conversation.send('Porto?');
    await tester.pump();

    expect(find.text('Porto?'), findsOneWidget);
    expect(find.byType(AIThinkingView), findsOneWidget, reason: "the latest reply is the previous message's");
  });

  testWidgets("conversation view with generated UI gives every reply's UI to the engines before its rows show", (
    tester,
  ) async {
    final renderer = TestRenderer();
    final conversation = _conversation([
      ChatMessage.user('u1'),
      for (var i = 0; i < 3; i++) ChatMessage.reply('a$i', uiDocument: openUI('Card $i')),
    ]);

    await _pump(tester, conversation, ui: testHost(renderers: [renderer]));

    expect([for (final (id, _) in renderer.engines.first.received) id], ['a0', 'a1', 'a2']);
  });

  testWidgets("conversation view with generated UI hands the conversation's actions to the builders", (tester) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final recorded = _Recorded();
    await _pump(tester, conversation, ui: testHost(), builders: recorded.builders);

    expect(recorded.edits, {'u1': true});
    expect(recorded.actions['a1']?.onRegenerate, isNotNull);

    recorded.actions['a1']!.onRate!(AIMessageRating.positive);
    await tester.pump();

    expect(conversation.ratings['a1'], AIMessageRating.positive);
    expect(recorded.actions['a1']?.rating, AIMessageRating.positive, reason: 'the row shows the new rating');
  });

  testWidgets('conversation view rows are built again when a reply is rated, and only then', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _over(transport);
    final recorded = _Recorded();
    await _pump(tester, conversation, builders: recorded.builders);
    final builds = recorded.replyBuilds;

    conversation.rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    await tester.pump();

    expect(recorded.replyBuilds, builds + 1);
    expect(recorded.actions['a1']?.rating, AIMessageRating.positive);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    await tester.pump();

    expect(recorded.replyBuilds, builds + 1, reason: 'nothing it shows changed');
  });

  testWidgets('conversation view rows are built again when regenerating stops being offered', (tester) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final recorded = _Recorded();
    await _pump(tester, conversation, builders: recorded.builders);
    expect(recorded.actions['a1']?.onRegenerate, isNotNull);

    conversation.send('Hi');
    await tester.pump();

    expect(recorded.actions['a1']?.onRegenerate, isNull, reason: 'the agent is answering');
  });

  testWidgets('conversation view rows are built again when editing stops being offered', (tester) async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = _over(transport);
    final recorded = _Recorded();
    await _pump(tester, conversation, builders: recorded.builders);
    expect(recorded.edits['u1'], isTrue);

    transport.update([ChatMessage.user('u1'), ChatMessage.reply('a1'), ChatMessage.user('u2')]);
    await tester.pump();

    expect(recorded.edits['u1'], isFalse, reason: "it isn't their latest message anymore");
  });

  testWidgets('conversation view rows act on the conversation the view shows now', (tester) async {
    final first = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final second = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final recorded = _Recorded();
    await _pump(tester, first, builders: recorded.builders);

    await _pump(tester, second, builders: recorded.builders);
    recorded.actions['a1']!.onRate!(AIMessageRating.negative);

    expect(second.ratings['a1'], AIMessageRating.negative);
    expect(first.ratings, isEmpty, reason: 'its actions would act on the conversation it was made with');

    second.rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    await tester.pump();

    expect(recorded.actions['a1']?.rating, AIMessageRating.positive, reason: 'it follows the conversation it shows');
  });

  testWidgets("conversation view default rows show the conversation's actions under a finished reply", (tester) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    await _pump(tester, conversation);

    final actions = tester.widget<AIReplyActionsView>(find.byType(AIReplyActionsView));
    expect(actions.text, "Here's a plan");
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Regenerate'), findsOneWidget);

    await tester.tap(find.byTooltip('Good response'));
    await tester.pump();

    expect(conversation.ratings['a1'], AIMessageRating.positive);
    expect(
      tester.widget<AIReplyActionsView>(find.byType(AIReplyActionsView)).actions.rating,
      AIMessageRating.positive,
    );
  });

  testWidgets('conversation view default rows show actions under a finished reply that has only attachments', (
    tester,
  ) async {
    final reply = ChatMessage(
      'a1',
      AIMessageRole.assistant,
      '',
      attachments: [AIMessageAttachment.file(Uri.parse('https://example.com/plan.pdf'), name: 'plan.pdf')],
    );
    await _pump(tester, _conversation([ChatMessage.user('u1'), reply]));

    expect(find.byType(AIReplyActionsView), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing, reason: 'there is no text to copy');
    expect(find.byTooltip('Good response'), findsOneWidget);
  });

  testWidgets('conversation view shows the actions of a reply from history in its first frame', (tester) async {
    final conversation = _conversation([ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AIConversationView.conversation(conversation: conversation)),
      ),
    );

    expect(find.byType(AIReplyActionsView), findsOneWidget);
  });

  testWidgets("conversation view opens at its end, under its latest reply's actions", (tester) async {
    // Turns taller than the list, of different heights, so the list finds its end over a few frames,
    // and the actions show only once their reply is on screen.
    final history = [
      for (var i = 0; i < 15; i++) ...[
        ChatMessage.user('u$i', 'Question $i'),
        ChatMessage.reply('a$i', text: List.filled(12 + i % 5, 'A paragraph of answer $i.').join('\n\n')),
      ],
    ];
    final transport = ConversationTransport();
    final conversation = _over(transport);
    await _pump(tester, conversation);

    transport.update(history);
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, position.maxScrollExtent);
    final list = tester.getRect(find.byType(AIConversationView));
    expect(tester.getRect(find.byType(AIReplyActionsView)).bottom, lessThanOrEqualTo(list.bottom - 16));
  });

  testWidgets("conversation view default rows offer to edit the person's latest message", (tester) async {
    final conversation = _conversation([ChatMessage.user('u1', 'Plan Lisbon'), ChatMessage.reply('a1')]);
    await _pump(tester, conversation);

    await tester.longPress(find.text('Plan Lisbon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(conversation.editingMessage?.id, 'u1');
    expect(conversation.composer.text, 'Plan Lisbon');
  });
}

/// A conversation of [messages], disposed once the test ends, which waits for
/// replies as long as they take so no timer outlives the test.
AIConversation<ChatMessage> _conversation(List<ChatMessage> messages, {AIToolApprover? approver}) =>
    _over(ConversationTransport(messages: messages), approver: approver);

AIConversation<ChatMessage> _over(ConversationTransport transport, {AIToolApprover? approver}) =>
    conversationOver(transport, approver: approver, replyTimeout: null);

AIToolApprover _approver() {
  final approver = AIToolApprover(
    identity: const AIClientIdentity(userId: 'u_1', clientId: 'ios-1'),
    decide: (_, _) async {},
  );
  addTearDown(approver.dispose);
  return approver;
}

/// Records what the builders were given, by message id.
class _Recorded {
  final edits = <String, bool>{};
  final actions = <String, AIReplyActions?>{};
  int replyBuilds = 0;

  late final builders = StreamComponentBuilders(
    extensions: streamAIComponentBuilders(
      userMessage: (context, props) {
        edits[props.message?.id ?? 'pending'] = props.onEdit != null;
        return Text(props.text);
      },
      replyActions: (context, props) {
        replyBuilds += 1;
        actions[props.message.id] = props.actions;
        return const SizedBox.shrink();
      },
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  AIConversation conversation, {
  AIUIHost? ui,
  StreamComponentBuilders? builders,
  Widget? footer,
  Widget? emptyContent,
}) => _pumpView(
  tester,
  AIConversationView.conversation(conversation: conversation, ui: ui, footer: footer, emptyContent: emptyContent),
  builders: builders,
);

Future<void> _pumpView(
  WidgetTester tester,
  Widget view, {
  StreamComponentBuilders? builders,
}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    StreamComponentFactory(
      builders: builders ?? StreamComponentBuilders(),
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600), disableAnimations: true),
          child: Scaffold(body: view),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _olderMessagesLoader = find.byWidgetPredicate(
  (widget) => '${widget.runtimeType}' == '_OlderMessagesLoader',
  skipOffstage: false,
);

Finder _text(String text) => find.textContaining(text, findRichText: true);
