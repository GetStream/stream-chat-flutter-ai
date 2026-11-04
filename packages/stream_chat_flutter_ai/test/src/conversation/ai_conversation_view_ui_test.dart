import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import '../genui/genui_test_doubles.dart';

void main() {
  testWidgets("AIConversationView shows a reply's UI when a renderer reads it", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', text: 'Here is your plan', uiDocument: openUI('Ohrid plan card')),
    ], ui: testHost());

    expect(_text('Ohrid plan card'), findsOneWidget);
  });

  testWidgets('AIConversationView leaves out the text of a reply whose UI shows', (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', text: 'Here is your plan', uiDocument: openUI('Ohrid plan card')),
    ], ui: testHost());

    expect(_text('Here is your plan'), findsNothing);
  });

  testWidgets("AIConversationView shows a reply's text when no host is given", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', text: 'Here is your plan', uiDocument: openUI('Ohrid plan card')),
    ]);

    expect(_text('Here is your plan'), findsOneWidget);
  });

  testWidgets("AIConversationView shows a reply's text when no renderer reads its UI", (tester) async {
    await _pump(tester, [
      _question(),
      Reply(
        'a1',
        text: 'Here is your plan',
        uiDocument: const AIUIDocument(format: AIUIFormat.a2ui, content: '{}'),
      ),
    ], ui: testHost());

    expect(_text('Here is your plan'), findsOneWidget);
  });

  testWidgets("AIConversationView gives the assistant message builder no text when the reply's UI shows", (
    tester,
  ) async {
    final texts = <String>[];
    Widget assistant(BuildContext context, AIAssistantMessageProps props) {
      texts.add(props.text);
      return const SizedBox.shrink();
    }

    await _pump(
      tester,
      [
        _question(),
        Reply('a1', text: 'Here is your plan', uiDocument: openUI('Ohrid plan card')),
      ],
      ui: testHost(),
      builders: StreamComponentBuilders(extensions: streamAIComponentBuilders(assistantMessage: assistant)),
    );

    expect(texts.toSet(), {''});
  });

  testWidgets("AIConversationView shows a reply's UI after its steps", (tester) async {
    await _pump(tester, [
      _question(),
      Reply(
        'a1',
        parts: [AIMessagePart.fromToolCall(const AIToolCallPart(id: 't1', name: 'search', displayTitle: 'Searching'))],
        uiDocument: openUI('Ohrid plan card'),
      ),
    ], ui: testHost());

    expect(
      tester.getTopLeft(find.text('Ohrid plan card')).dy,
      greaterThan(tester.getBottomLeft(find.textContaining('Searching')).dy),
    );
  });

  testWidgets('AIConversationView shows actions under a finished reply that has only UI', (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', uiDocument: openUI('Ohrid plan card')),
    ], ui: testHost());

    expect(find.text('actions for a1'), findsOneWidget);
  });

  testWidgets("AIConversationView holds a reply's actions while its UI is being written", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', uiDocument: openUI('Ohrid plan card', isStreaming: true)),
    ], ui: testHost());

    expect(find.text('actions for a1'), findsNothing);
  });

  testWidgets("AIConversationView shows a reply's UI while the agent writes it", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: openUI('Ohrid plan card', isStreaming: true)),
    ], ui: testHost());

    expect(_text('Ohrid plan card'), findsOneWidget);
  });

  testWidgets("AIConversationView doesn't show the thinking for a reply whose UI a renderer reads", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: openUI('Ohrid plan card', isStreaming: true)),
    ], ui: testHost());

    expect(find.byType(AIThinkingView), findsNothing);
  });

  testWidgets("AIConversationView leaves 8 between an app's own view of a reply and its UI", (tester) async {
    Widget assistant(BuildContext context, AIAssistantMessageProps props) =>
        const SizedBox(key: Key('header'), height: 20);

    await _pump(
      tester,
      [
        _question(),
        Reply('a1', uiDocument: openUI('Ohrid plan card')),
      ],
      ui: testHost(),
      builders: StreamComponentBuilders(extensions: streamAIComponentBuilders(assistantMessage: assistant)),
    );

    expect(
      tester.getTopLeft(find.text('Ohrid plan card')).dy - tester.getBottomLeft(find.byKey(const Key('header'))).dy,
      8,
    );
  });

  testWidgets("AIConversationView leaves 8 above a reply's UI when nothing else of the reply shows", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', uiDocument: openUI('Ohrid plan card')),
    ], ui: testHost());

    expect(
      tester.getTopLeft(find.text('Ohrid plan card')).dy - tester.getBottomLeft(find.byType(AIAssistantMessageView)).dy,
      8,
    );
  });

  testWidgets("AIConversationView shows a reply's UI from a host given in place of another", (tester) async {
    final renderer = TestRenderer();
    final messages = [
      _question(),
      Reply('a1', uiDocument: openUI('Ohrid plan card')),
    ];
    await _pump(tester, messages, ui: testHost());

    await _pump(tester, messages, ui: testHost(renderers: [renderer]));

    expect(renderer.engines.single.shown.map((shown) => shown.$1), ['a1']);
  });

  testWidgets("AIConversationView keeps the thinking while no renderer reads the reply's UI", (tester) async {
    await _pump(tester, [
      _question(),
      Reply(
        'a1',
        isGenerating: true,
        uiDocument: const AIUIDocument(format: AIUIFormat('cards'), content: 'x'),
      ),
    ], ui: testHost());

    expect(find.byType(AIThinkingView), findsOneWidget);
  });

  testWidgets("AIConversationView gives the engines every reply's UI before its rows build", (tester) async {
    const moreTurnsThanFitOnScreen = 80;
    final renderer = TestRenderer();
    final replies = [
      for (var i = 0; i < moreTurnsThanFitOnScreen; i++) Reply('a$i', uiDocument: openUI('Card $i')),
    ];
    final conversation = [
      for (final (i, reply) in replies.indexed) ...[Reply('q$i', role: AIMessageRole.user, text: 'Question $i'), reply],
    ];

    await _pump(tester, conversation, ui: testHost(renderers: [renderer]));

    expect(renderer.engines.single.asked.take(replies.length), [for (final reply in replies) 'receive ${reply.id}']);
  });

  testWidgets("AIConversationView asks for a reply's UI again when its document changes", (tester) async {
    final renderer = TestRenderer();
    final ui = testHost(renderers: [renderer]);

    await _pump(tester, [_question(), Reply('a1', uiDocument: openUI('Ohrid plan card'))], ui: ui);
    await _pump(tester, [_question(), Reply('a1', uiDocument: openUI('Ohrid and Struga plan card'))], ui: ui);

    expect(renderer.engines.single.shown.where((shown) => shown.$1 == 'a1'), hasLength(2));
  });

  testWidgets("AIConversationView doesn't ask for a reply's UI again while its document is unchanged", (
    tester,
  ) async {
    final renderer = TestRenderer();
    final ui = testHost(renderers: [renderer]);
    final reply = Reply('a1', uiDocument: openUI('Ohrid plan card'));

    await _pump(tester, [_question(), reply], ui: ui);
    await _pump(tester, [_question(), reply, Reply('q2', role: AIMessageRole.user, text: 'And Struga?')], ui: ui);

    expect(renderer.engines.single.shown.where((shown) => shown.$1 == 'a1'), hasLength(1));
  });
}

const _kScreen = Size(400, 600);

Reply _question() => Reply('q1', role: AIMessageRole.user, text: 'Plan a weekend in Ohrid');

Finder _text(String text) => find.textContaining(text, findRichText: true);

Widget _actions(BuildContext context, AIReplyActionsProps props) => Text('actions for ${props.message.id}');

Future<void> _pump(
  WidgetTester tester,
  List<AIMessage> messages, {
  AIUIHost? ui,
  StreamComponentBuilders? builders,
}) async {
  tester.view.physicalSize = _kScreen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    StreamComponentFactory(
      builders: builders ?? StreamComponentBuilders(extensions: streamAIComponentBuilders(replyActions: _actions)),
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: _kScreen, disableAnimations: true),
          child: Scaffold(
            body: AIConversationView(messages: messages, ui: ui),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
