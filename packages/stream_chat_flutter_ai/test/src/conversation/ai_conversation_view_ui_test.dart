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

  testWidgets("AIConversationView keeps the thinking while a reply's engine has built nothing yet", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: _builtNothing(isStreaming: true)),
    ], ui: testHost());

    expect(find.byType(AIThinkingView), findsOneWidget);
    expect(find.byType(AIAssistantMessageView), findsNothing);
  });

  testWidgets('AIConversationView leaves out a finished reply that has no text and whose engine built nothing', (
    tester,
  ) async {
    await _pump(tester, [_question(), Reply('a1', uiDocument: _builtNothing())], ui: testHost());

    expect(find.byType(AIAssistantMessageView), findsNothing);
    expect(find.text('actions for a1'), findsNothing);
  });

  testWidgets("AIConversationView shows a reply's text when its engine built nothing", (tester) async {
    await _pump(tester, [
      _question(),
      Reply('a1', text: 'Your plan is updated', uiDocument: _builtNothing()),
    ], ui: testHost());

    expect(_text('Your plan is updated'), findsOneWidget);
    expect(find.text('actions for a1'), findsOneWidget);
  });

  testWidgets('AIConversationView shows a reply once its engine builds its UI', (tester) async {
    final ui = testHost();

    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: _builtNothing(isStreaming: true)),
    ], ui: ui);
    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: openUI('Ohrid plan card', isStreaming: true)),
    ], ui: ui);

    expect(_text('Ohrid plan card'), findsOneWidget);
    expect(find.byType(AIThinkingView), findsNothing);
  });

  testWidgets("AIConversationView shows the other replies' UI when an engine throws on receiving one", (tester) async {
    final renderer = TestRenderer(fails: {'a1': 'receive'});

    await _pump(tester, [
      _question(),
      Reply('a1', uiDocument: openUI('Ohrid plan card')),
      Reply('a2', uiDocument: openUI('Struga plan card')),
    ], ui: testHost(renderers: [renderer]));

    expect(tester.takeException(), isStateError);
    expect(_text('Struga plan card'), findsOneWidget);
  });

  testWidgets("AIConversationView shows a reply's text when its engine throws on building its UI", (tester) async {
    final renderer = TestRenderer(fails: {'a1': 'view'});

    await _pump(tester, [
      _question(),
      Reply('a1', text: 'Here is your plan', uiDocument: openUI('Ohrid plan card')),
    ], ui: testHost(renderers: [renderer]));

    expect(tester.takeException(), isStateError);
    expect(_text('Here is your plan'), findsOneWidget);
  });

  testWidgets('AIConversationView still builds when an engine throws on removing a reply', (tester) async {
    final ui = testHost(
      renderers: [
        TestRenderer(fails: {'a1': 'remove'}),
      ],
    );

    await _pump(tester, [_question(), Reply('a1', uiDocument: openUI('Ohrid plan card'))], ui: ui);
    await _pump(tester, [_question()], ui: ui);

    expect(tester.takeException(), isStateError);
    expect(_text('Plan a weekend in Ohrid'), findsOneWidget);
  });

  testWidgets('AIConversationView shows the actions once a reply whose UI streamed finishes', (tester) async {
    final ui = testHost();

    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: openUI('Ohrid plan card', isStreaming: true)),
    ], ui: ui);
    await _pump(tester, [_question(), Reply('a1', uiDocument: openUI('Ohrid plan card'))], ui: ui);

    expect(find.text('actions for a1'), findsOneWidget);
  });

  testWidgets("AIConversationView keeps the state of a reply's UI while the agent writes more of it", (tester) async {
    final renderer = _StatefulRenderer();
    final ui = testHost(renderers: [renderer]);

    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: openUI('Ohrid', isStreaming: true)),
    ], ui: ui);
    await _pump(tester, [
      _question(),
      Reply('a1', isGenerating: true, uiDocument: openUI('Ohrid and Struga', isStreaming: true)),
    ], ui: ui);

    expect(_text('Ohrid and Struga'), findsOneWidget);
    expect(renderer.states, 1);
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

// A renderer whose UI keeps state, counting the states it makes.
class _StatefulRenderer extends AIUIRenderer {
  int states = 0;

  @override
  AIUIFormat get format => AIUIFormat.openUI;

  @override
  AIUIEngine createEngine(AIUIHosting host) => _StatefulEngine(this);
}

class _StatefulEngine extends AIUIEngine {
  _StatefulEngine(this.renderer);

  final _StatefulRenderer renderer;

  @override
  Widget? view(AIUIDocument document, String messageId) => _Card(document.text!, renderer);
}

class _Card extends StatefulWidget {
  const _Card(this.text, this.renderer);

  final String text;
  final _StatefulRenderer renderer;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  @override
  void initState() {
    super.initState();
    widget.renderer.states++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.text);
}

Reply _question() => Reply('q1', role: AIMessageRole.user, text: 'Plan a weekend in Ohrid');

// A document the test engine reads but builds nothing for, as an engine does
// before a reply's UI has anything to show.
AIUIDocument _builtNothing({bool isStreaming = false}) =>
    AIUIDocument(format: AIUIFormat.openUI, isStreaming: isStreaming, content: const <Object?>[]);

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
