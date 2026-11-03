import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child, {AIComponentBuilders? builders}) {
  final body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 360, child: child),
  );
  return MaterialApp(
    home: Scaffold(
      body: builders == null ? body : AIComponentFactory(builders: builders, child: body),
    ),
  );
}

const _codeFence = '```dart\nvoid main() {}\n```';

const _chartFence = '''
```chartjs
{"type": "bar", "data": {"labels": ["Jan", "Feb"], "datasets": [{"label": "Sales", "data": [10, 25]}]}}
```
''';

final _parts = AIMessagePart.parseAll([
  (type: 'ai_reasoning', payload: const {'id': 'r1', 'status': 'completed'}),
  (type: 'ai_tool_call', payload: const {'id': 'call_1', 'name': 'get_weather', 'status': 'completed'}),
  (type: 'ai_citation', payload: const {'id': 'c1'}),
]);

const _awaiting = AIToolCallPart(
  id: 'call_1',
  name: 'send_email',
  status: AIToolCallStatus.awaitingApproval,
  executor: AIToolExecutor.server,
  targetUserId: 'alice',
  approval: AIToolApproval(title: 'Send it?'),
  hasPayloadId: true,
);

AIToolApprover _approver({List<AIToolApprovalDecision>? answers}) => AIToolApprover(
  identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
  decide: (call, decision) async => answers?.add(decision),
);

/// Builders for every slot, each a labelled [Text].
AIComponentBuilders _custom([String tag = 'custom']) => AIComponentBuilders(
  codeBlock: (context, props) => Text('$tag code ${props.language}: ${props.code}'),
  chart: (context, props) => Text('$tag chart ${props.spec.kind.name}'),
  math: (context, props) => Text('$tag math ${props.inline ? 'inline' : 'block'}: ${props.tex}'),
  reasoning: (context, props) => Text('$tag reasoning'),
  toolCall: (context, props) => Text('$tag tool ${props.call.name}'),
  toolApproval: (context, props) => TextButton(
    onPressed: () => props.onAnswer(AIToolApprovalDecision.allowed),
    child: Text('$tag approval ${props.toolName}'),
  ),
  unsupportedPart: (context, props) => Text('$tag unsupported ${props.part.id}'),
  composer: _CustomComposer(tag),
);

class _CustomComposer extends ChatComposerFactory {
  const _CustomComposer(this.tag);

  final String tag;

  @override
  Widget? buildTrailing(BuildContext context, ChatComposerTrailingProps props) => Text('$tag trailing');

  @override
  Widget buildAttachmentSheet(BuildContext context, ChatComposerAttachmentSheetProps props) => Builder(
    builder: (context) => Text(
      AIComponentFactory.of(context).composer is _CustomComposer ? 'sheet sees custom' : 'sheet sees default',
    ),
  );
}

Widget _hidden(BuildContext context, Object props) => AIMessagePartsView.hidden;

const _hiding = AIComponentBuilders(reasoning: _hidden, toolCall: _hidden, unsupportedPart: _hidden);

/// Records the props each slot gets, and renders the approval state.
class _Recording {
  final codeBlocks = <AICodeBlockProps>[];
  final charts = <AIChartProps>[];
  final approvals = <AIToolApprovalProps>[];

  late final builders = AIComponentBuilders(
    codeBlock: (context, props) {
      codeBlocks.add(props);
      return const Text('code');
    },
    chart: (context, props) {
      charts.add(props);
      return const Text('chart');
    },
    toolApproval: (context, props) {
      approvals.add(props);
      return TextButton(
        onPressed: () => props.onAnswer(AIToolApprovalDecision.allowed),
        child: Text('state ${props.state.runtimeType}'),
      );
    },
  );
}

void main() {
  setUp(debugClearFenceCaches);

  group('AIComponentBuilders', () {
    test('leaves every component to its default when empty', () {
      const builders = AIComponentBuilders();
      expect(builders.codeBlock, isNull);
      expect(builders.chart, isNull);
      expect(builders.math, isNull);
      expect(builders.reasoning, isNull);
      expect(builders.toolCall, isNull);
      expect(builders.toolApproval, isNull);
      expect(builders.toolAuthorization, isNull);
      expect(builders.unsupportedPart, isNull);
      expect(builders.composer, isNull);
    });

    test('copyWith and merge replace only what they set', () {
      final custom = _custom();
      final merged = const AIComponentBuilders(reasoning: _hidden).merge(AIComponentBuilders(chart: custom.chart));
      expect(merged.reasoning, _hidden);
      expect(merged.chart, same(custom.chart));
      expect(merged.codeBlock, isNull);
      expect(merged.copyWith(codeBlock: custom.codeBlock).codeBlock, same(custom.codeBlock));
      final withMath = merged.merge(AIComponentBuilders(math: custom.math));
      expect(withMath.math, same(custom.math));
      expect(withMath.chart, same(custom.chart));
      expect(withMath, isNot(merged));
      final signIn = merged.merge(const AIComponentBuilders(toolAuthorization: _hidden));
      expect(signIn.toolAuthorization, _hidden);
      expect(signIn.reasoning, _hidden);
      expect(signIn, isNot(merged));
      expect(const AIComponentBuilders().merge(null), const AIComponentBuilders());
    });

    test('compares its builders by identity', () {
      const same = AIComponentBuilders(reasoning: _hidden, toolCall: _hidden, unsupportedPart: _hidden);
      expect(_hiding, same);
      expect(_hiding.hashCode, same.hashCode);
      expect(_custom(), isNot(_custom()), reason: 'new closures are new builders');
    });

    testWidgets('AIComponentFactory.of falls back to empty builders', (tester) async {
      late AIComponentBuilders found;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              found = AIComponentFactory.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, const AIComponentBuilders());
    });

    testWidgets('without builders every component is the package widget', (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: Column(
              children: [
                const AIMarkdownBody(data: '$_codeFence\n\n$_chartFence'),
                AIMessagePartsView(
                  parts: [
                    ..._parts,
                    AIMessagePart.fromToolCall(_awaiting.copyWith(id: 'call_2')),
                  ],
                  approver: approver,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CodeBlockView), findsOneWidget);
      expect(find.byType(ChartView), findsOneWidget);
      expect(find.byType(StreamingReasoningView), findsOneWidget);
      expect(find.byType(AIToolCallView), findsNWidgets(2));
      expect(find.byType(AIUnsupportedPartView), findsOneWidget);
      expect(find.byType(AIToolApprovalCard), findsOneWidget);
    });
  });

  group('overridden slots', () {
    testWidgets('AIMarkdownBody builds its code blocks and charts through the factory', (tester) async {
      await tester.pumpWidget(
        _wrap(const AIMarkdownBody(data: '$_codeFence\n\n$_chartFence'), builders: _custom()),
      );

      expect(find.text('custom code dart: void main() {}'), findsOneWidget);
      expect(find.text('custom chart bar'), findsOneWidget);
      expect(find.byType(CodeBlockView), findsNothing);
      expect(find.byType(ChartView), findsNothing);
    });

    testWidgets('swapping the builders updates an already rendered AIMarkdownBody', (tester) async {
      const body = AIMarkdownBody(data: '$_codeFence\n\n$_chartFence');
      await tester.pumpWidget(_wrap(body));
      expect(find.byType(CodeBlockView), findsOneWidget);
      expect(find.byType(ChartView), findsOneWidget);

      await tester.pumpWidget(_wrap(body, builders: _custom('first')));
      expect(find.text('first code dart: void main() {}'), findsOneWidget);
      expect(find.text('first chart bar'), findsOneWidget);

      await tester.pumpWidget(_wrap(body, builders: _custom('second')));
      expect(find.text('second code dart: void main() {}'), findsOneWidget);
      expect(find.text('second chart bar'), findsOneWidget);
    });

    testWidgets('AIMarkdownBody renders LaTeX through the factory when it has no mathBuilder', (tester) async {
      const body = AIMarkdownBody(data: 'Inline \\(x^2\\) here.\n\n\\[\\sum_i i\\]');
      await tester.pumpWidget(_wrap(body));
      expect(find.text('x^2'), findsOneWidget);

      await tester.pumpWidget(_wrap(body, builders: _custom('first')));
      expect(find.text('first math inline: x^2'), findsOneWidget);
      expect(find.text(r'first math block: \sum_i i'), findsOneWidget);

      // Swapping the builders reaches LaTeX already on screen, without new text.
      await tester.pumpWidget(_wrap(body, builders: _custom('second')));
      expect(find.text('second math inline: x^2'), findsOneWidget);
    });

    testWidgets("an AIMarkdownBody's own mathBuilder wins over the factory", (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMarkdownBody(
            data: r'Inline \(x^2\) here.',
            mathBuilder: (context, tex, style, {required inline}) => Text('own $tex'),
          ),
          builders: _custom(),
        ),
      );

      expect(find.text('own x^2'), findsOneWidget);
      expect(find.textContaining('custom math'), findsNothing);
    });

    testWidgets('AIMessagePartsView builds reasoning, tool calls and unsupported parts through the factory', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: _parts), builders: _custom()));

      expect(find.text('custom reasoning'), findsOneWidget);
      expect(find.text('custom tool get_weather'), findsOneWidget);
      expect(find.text('custom unsupported c1'), findsOneWidget);
      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('r1'),
        ValueKey<Object>('call_1'),
        ValueKey<Object>('c1'),
      ]);
    });

    testWidgets('AIMessagePartsView leaves out a part the factory returns hidden for', (tester) async {
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: _parts), builders: _hiding));
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('partBuilder and toolCallBuilder are asked before the factory', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts,
            partBuilder: (context, part) => part.reasoning != null ? const Text('own reasoning') : null,
            toolCallBuilder: (context, call) => const Text('own tool'),
          ),
          builders: _custom(),
        ),
      );

      expect(find.text('own reasoning'), findsOneWidget);
      expect(find.text('own tool'), findsOneWidget);
      expect(find.text('custom unsupported c1'), findsOneWidget);
    });

    testWidgets('the tool approval question comes from the factory under the factory row', (tester) async {
      final answers = <AIToolApprovalDecision>[];
      final approver = _approver(answers: answers);
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(parts: [AIMessagePart.fromToolCall(_awaiting)], approver: approver),
          builders: _custom(),
        ),
      );

      expect(find.text('custom tool send_email'), findsOneWidget);
      expect(find.byType(AIToolApprovalCard), findsNothing);
      await tester.tap(find.text('custom approval send email'));
      await tester.pump();
      expect(answers, [AIToolApprovalDecision.allowed]);
    });

    testWidgets("AIToolApprovalView's builder wins over the factory", (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          AIToolApprovalView(
            call: _awaiting,
            approver: approver,
            builder: (context, approval, state, answer) => const Text('own approval'),
          ),
          builders: _custom(),
        ),
      );

      expect(find.text('own approval'), findsOneWidget);
      expect(find.textContaining('custom approval'), findsNothing);
    });

    testWidgets('ChatComposer takes its slots from AIComponentFactory without a factory of its own', (tester) async {
      await tester.pumpWidget(_wrap(ChatComposer(onSendPressed: (_, __, ___) {}), builders: _custom()));
      expect(find.text('custom trailing'), findsOneWidget);
    });

    testWidgets("ChatComposer's own factory beats the inherited one", (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatComposer(onSendPressed: (_, __, ___) {}, factory: const ChatComposerFactory()),
          builders: _custom(),
        ),
      );
      expect(find.text('custom trailing'), findsNothing);
    });

    testWidgets('the inherited factory reaches the attachment sheet route', (tester) async {
      await tester.pumpWidget(_wrap(ChatComposer(onSendPressed: (_, __, ___) {}), builders: _custom()));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('sheet sees custom'), findsOneWidget);
    });

    testWidgets('AIMarkdownBody passes its theme, highlighter and language to the code block', (tester) async {
      const theme = CodeBlockThemeData(backgroundColor: Colors.black);
      TextSpan? highlighter(CodeHighlightRequest request) => null;
      final recording = _Recording();
      await tester.pumpWidget(
        _wrap(
          AIMarkdownBody(
            data: '$_codeFence\n\n```\nplain\n```\n\n```chartjs\nnot json\n```',
            codeBlockTheme: theme,
            codeHighlighter: highlighter,
          ),
          builders: recording.builders,
        ),
      );

      expect(recording.charts, isEmpty);
      expect(recording.codeBlocks.map((p) => (p.language, p.code)), [
        ('dart', 'void main() {}'),
        (null, 'plain'),
        ('chartjs', 'not json'),
      ]);
      for (final props in recording.codeBlocks) {
        expect(props.theme, same(theme));
        expect(props.highlighter, same(highlighter));
      }
    });

    testWidgets('one fence under two factories at once uses the builders of each', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              AIComponentFactory(
                builders: _custom('a'),
                child: const AIMarkdownBody(data: _codeFence),
              ),
              AIComponentFactory(
                builders: _custom('b'),
                child: const AIMarkdownBody(data: _codeFence),
              ),
            ],
          ),
        ),
      );

      expect(find.text('a code dart: void main() {}'), findsOneWidget);
      expect(find.text('b code dart: void main() {}'), findsOneWidget);
    });

    testWidgets('swapping the builders updates an already built AIMessagePartsView', (tester) async {
      final view = AIMessagePartsView(parts: _parts);
      await tester.pumpWidget(_wrap(view, builders: _custom('first')));
      expect(find.text('first tool get_weather'), findsOneWidget);

      await tester.pumpWidget(_wrap(view, builders: _custom('second')));
      expect(find.text('second tool get_weather'), findsOneWidget);
      expect(find.textContaining('first'), findsNothing);
    });

    testWidgets('a hidden row whose call stops waiting lets the approver forget the answer', (tester) async {
      final approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
        decide: (call, decision) async {},
        sentTimeout: const Duration(seconds: 5),
      );
      addTearDown(approver.dispose);
      var notified = 0;
      Widget build(AIToolCallPart call) => _wrap(
        AIMessagePartsView(parts: [AIMessagePart.fromToolCall(call)], approver: approver),
        builders: _hiding,
      );

      await tester.pumpWidget(build(_awaiting));
      approver.answer(_awaiting, AIToolApprovalDecision.allowed);
      await tester.pump();
      expect(approver.stateOf(_awaiting), isA<AIToolApprovalSent>());
      approver.addListener(() => notified++);

      // The backend moves the step on; the row is hidden and nothing asks.
      await tester.pumpWidget(build(_awaiting.copyWith(status: AIToolCallStatus.running)));
      await tester.pump(const Duration(seconds: 6));
      expect(notified, 0, reason: 'the sent timeout was cancelled, so nothing turns failed');
      expect(approver.stateOf(_awaiting), const AIToolApprovalIdle(), reason: 'the answer was forgotten');
    });

    testWidgets('a hidden factory row still asks its question', (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(parts: [AIMessagePart.fromToolCall(_awaiting)], approver: approver),
          builders: _hiding,
        ),
      );

      expect(find.byType(AIToolCallView), findsNothing);
      expect(find.byType(AIToolApprovalCard), findsOneWidget);
    });

    testWidgets('a hidden factory row with nothing to ask is left out', (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(parts: _parts, approver: approver),
          builders: _hiding,
        ),
      );
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('a call toolCallBuilder hides still asks its question, like a hidden factory row', (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      Widget build(AIToolCallPart call) => _wrap(
        AIMessagePartsView(
          parts: [AIMessagePart.fromToolCall(call)],
          approver: approver,
          toolCallBuilder: (context, call) => AIMessagePartsView.hidden,
        ),
      );

      await tester.pumpWidget(build(_awaiting));
      expect(find.byType(AIToolCallView), findsNothing);
      expect(find.byType(AIToolApprovalCard), findsOneWidget);

      // With nothing to ask, it is left out.
      await tester.pumpWidget(build(_awaiting.copyWith(status: AIToolCallStatus.completed)));
      expect(find.byType(AIToolApprovalCard), findsNothing);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('the toolApproval builder gets the call, theme and current state', (tester) async {
      final pending = Completer<void>();
      final approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
        decide: (call, decision) => pending.future,
      );
      addTearDown(approver.dispose);
      const theme = ToolApprovalThemeData(backgroundColor: Colors.amber);
      final recording = _Recording();
      await tester.pumpWidget(
        _wrap(
          AIToolApprovalView(call: _awaiting, approver: approver, theme: theme),
          builders: recording.builders,
        ),
      );

      expect(find.text('state AIToolApprovalIdle'), findsOneWidget);
      expect(recording.approvals.last.call, same(_awaiting));
      expect(recording.approvals.last.approval, same(_awaiting.approval));
      expect(recording.approvals.last.theme, same(theme));

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.text('state AIToolApprovalSending'), findsOneWidget);
    });

    testWidgets('swapping the builders updates a ChatComposer without its own', (tester) async {
      final composer = ChatComposer(onSendPressed: (_, __, ___) {});
      await tester.pumpWidget(_wrap(composer, builders: _custom('first')));
      expect(find.text('first trailing'), findsOneWidget);

      await tester.pumpWidget(_wrap(composer, builders: _custom('second')));
      expect(find.text('second trailing'), findsOneWidget);
      expect(find.text('first trailing'), findsNothing);
    });
  });
}
