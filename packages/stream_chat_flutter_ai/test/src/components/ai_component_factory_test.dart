import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child, {AIComponentFactory? factory}) {
  final body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 360, child: child),
  );
  return MaterialApp(
    home: Scaffold(
      body: factory == null ? body : AIComponents(factory: factory, child: body),
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

/// Overrides every slot with a labelled [Text].
class _Custom extends AIComponentFactory {
  const _Custom([this.tag = 'custom']);

  final String tag;

  @override
  Widget buildCodeBlock(BuildContext context, AICodeBlockProps props) =>
      Text('$tag code ${props.language}: ${props.code}');

  @override
  Widget buildChart(BuildContext context, AIChartProps props) => Text('$tag chart ${props.spec.kind.name}');

  @override
  Widget buildReasoning(BuildContext context, AIReasoningProps props) => Text('$tag reasoning');

  @override
  Widget buildToolCall(BuildContext context, AIToolCallProps props) => Text('$tag tool ${props.call.name}');

  @override
  Widget buildToolApproval(BuildContext context, AIToolApprovalProps props) => TextButton(
    onPressed: () => props.onAnswer(AIToolApprovalDecision.allowed),
    child: Text('$tag approval ${props.toolName}'),
  );

  @override
  Widget buildUnsupportedPart(BuildContext context, AIUnsupportedPartProps props) =>
      Text('$tag unsupported ${props.part.id}');

  @override
  ChatComposerFactory get composer => _CustomComposer(tag);
}

class _CustomComposer extends ChatComposerFactory {
  const _CustomComposer(this.tag);

  final String tag;

  @override
  Widget? buildTrailing(BuildContext context, ChatComposerTrailingProps props) => Text('$tag trailing');

  @override
  Widget buildAttachmentSheet(BuildContext context, ChatComposerAttachmentSheetProps props) => Builder(
    builder: (context) => Text(AIComponents.of(context) is _Custom ? 'sheet sees custom' : 'sheet sees default'),
  );
}

class _Hiding extends AIComponentFactory {
  const _Hiding();

  @override
  Widget buildReasoning(BuildContext context, AIReasoningProps props) => AIMessagePartsView.hidden;

  @override
  Widget buildToolCall(BuildContext context, AIToolCallProps props) => AIMessagePartsView.hidden;

  @override
  Widget buildUnsupportedPart(BuildContext context, AIUnsupportedPartProps props) => AIMessagePartsView.hidden;
}

/// Records the props each slot gets, and renders the approval state.
class _Recording extends AIComponentFactory {
  _Recording();

  final codeBlocks = <AICodeBlockProps>[];
  final charts = <AIChartProps>[];
  final approvals = <AIToolApprovalProps>[];

  @override
  Widget buildCodeBlock(BuildContext context, AICodeBlockProps props) {
    codeBlocks.add(props);
    return const Text('code');
  }

  @override
  Widget buildChart(BuildContext context, AIChartProps props) {
    charts.add(props);
    return const Text('chart');
  }

  @override
  Widget buildToolApproval(BuildContext context, AIToolApprovalProps props) {
    approvals.add(props);
    return TextButton(
      onPressed: () => props.onAnswer(AIToolApprovalDecision.allowed),
      child: Text('state ${props.state.runtimeType}'),
    );
  }
}

void main() {
  setUp(debugClearFenceCaches);

  group('AIComponentFactory defaults', () {
    testWidgets('each slot builds the package widget', (tester) async {
      const factory = AIComponentFactory();
      late BuildContext context;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final code = factory.buildCodeBlock(context, const AICodeBlockProps(code: 'x', language: 'dart'));
      expect(
        code,
        isA<CodeBlockView>().having((v) => v.code, 'code', 'x').having((v) => v.language, 'language', 'dart'),
      );

      final spec = USpecParser.tryParse('{"type": "bar", "data": {"labels": ["a"], "datasets": [{"data": [1]}]}}')!;
      expect(
        factory.buildChart(context, AIChartProps(spec: spec)),
        isA<ChartView>().having((v) => v.spec, 'spec', spec),
      );

      final reasoning = _parts[0].reasoning!;
      expect(factory.buildReasoning(context, AIReasoningProps(reasoning: reasoning)), isA<StreamingReasoningView>());

      final call = _parts[1].toolCall!;
      expect(
        factory.buildToolCall(context, AIToolCallProps(call: call)),
        isA<AIToolCallView>().having((v) => v.call, 'call', call),
      );

      void onAnswer(AIToolApprovalDecision _) {}
      final approval = factory.buildToolApproval(
        context,
        AIToolApprovalProps(
          call: _awaiting,
          toolName: 'send email',
          state: const AIToolApprovalIdle(),
          onAnswer: onAnswer,
        ),
      );
      expect(
        approval,
        isA<AIToolApprovalCard>()
            .having((v) => v.approval, 'approval', _awaiting.approval)
            .having((v) => v.toolName, 'toolName', 'send email')
            .having((v) => v.onAnswer, 'onAnswer', onAnswer),
      );

      expect(
        factory.buildUnsupportedPart(context, AIUnsupportedPartProps(part: _parts[2])),
        isA<AIUnsupportedPartView>(),
      );
      expect(factory.composer, isA<ChatComposerFactory>());
    });

    testWidgets('AIComponents.of falls back to the default factory', (tester) async {
      late AIComponentFactory found;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              found = AIComponents.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found.runtimeType, AIComponentFactory);
    });
  });

  group('overridden slots', () {
    testWidgets('AIMarkdownBody builds its code blocks and charts through the factory', (tester) async {
      await tester.pumpWidget(
        _wrap(const AIMarkdownBody(data: '$_codeFence\n\n$_chartFence'), factory: const _Custom()),
      );

      expect(find.text('custom code dart: void main() {}'), findsOneWidget);
      expect(find.text('custom chart bar'), findsOneWidget);
      expect(find.byType(CodeBlockView), findsNothing);
      expect(find.byType(ChartView), findsNothing);
    });

    testWidgets('swapping the factory updates an already rendered AIMarkdownBody', (tester) async {
      const body = AIMarkdownBody(data: '$_codeFence\n\n$_chartFence');
      await tester.pumpWidget(_wrap(body));
      expect(find.byType(CodeBlockView), findsOneWidget);
      expect(find.byType(ChartView), findsOneWidget);

      await tester.pumpWidget(_wrap(body, factory: const _Custom('first')));
      expect(find.text('first code dart: void main() {}'), findsOneWidget);
      expect(find.text('first chart bar'), findsOneWidget);

      await tester.pumpWidget(_wrap(body, factory: const _Custom('second')));
      expect(find.text('second code dart: void main() {}'), findsOneWidget);
      expect(find.text('second chart bar'), findsOneWidget);
    });

    testWidgets('AIMessagePartsView builds reasoning, tool calls and unsupported parts through the factory', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: _parts), factory: const _Custom()));

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
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: _parts), factory: const _Hiding()));
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
          factory: const _Custom(),
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
          factory: const _Custom(),
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
          factory: const _Custom(),
        ),
      );

      expect(find.text('own approval'), findsOneWidget);
      expect(find.textContaining('custom approval'), findsNothing);
    });

    testWidgets('ChatComposer takes its slots from AIComponents without a factory of its own', (tester) async {
      await tester.pumpWidget(_wrap(ChatComposer(onSendPressed: (_, __, ___) {}), factory: const _Custom()));
      expect(find.text('custom trailing'), findsOneWidget);
    });

    testWidgets("ChatComposer's own factory beats the inherited one", (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatComposer(onSendPressed: (_, __, ___) {}, factory: const ChatComposerFactory()),
          factory: const _Custom(),
        ),
      );
      expect(find.text('custom trailing'), findsNothing);
    });

    testWidgets('the inherited factory reaches the attachment sheet route', (tester) async {
      await tester.pumpWidget(_wrap(ChatComposer(onSendPressed: (_, __, ___) {}), factory: const _Custom()));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('sheet sees custom'), findsOneWidget);
    });

    testWidgets('AIMarkdownBody passes its theme, highlighter and language to the code block', (tester) async {
      const theme = CodeBlockThemeData(backgroundColor: Colors.black);
      TextSpan? highlighter(CodeHighlightRequest request) => null;
      final factory = _Recording();
      await tester.pumpWidget(
        _wrap(
          AIMarkdownBody(
            data: '$_codeFence\n\n```\nplain\n```\n\n```chartjs\nnot json\n```',
            codeBlockTheme: theme,
            codeHighlighter: highlighter,
          ),
          factory: factory,
        ),
      );

      expect(factory.charts, isEmpty);
      expect(factory.codeBlocks.map((p) => (p.language, p.code)), [
        ('dart', 'void main() {}'),
        (null, 'plain'),
        ('chartjs', 'not json'),
      ]);
      for (final props in factory.codeBlocks) {
        expect(props.theme, same(theme));
        expect(props.highlighter, same(highlighter));
      }
    });

    testWidgets('one fence under two AIComponents at once uses each factory', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              AIComponents(
                factory: _Custom('a'),
                child: AIMarkdownBody(data: _codeFence),
              ),
              AIComponents(
                factory: _Custom('b'),
                child: AIMarkdownBody(data: _codeFence),
              ),
            ],
          ),
        ),
      );

      expect(find.text('a code dart: void main() {}'), findsOneWidget);
      expect(find.text('b code dart: void main() {}'), findsOneWidget);
    });

    testWidgets('swapping the factory updates an already built AIMessagePartsView', (tester) async {
      final view = AIMessagePartsView(parts: _parts);
      await tester.pumpWidget(_wrap(view, factory: const _Custom('first')));
      expect(find.text('first tool get_weather'), findsOneWidget);

      await tester.pumpWidget(_wrap(view, factory: const _Custom('second')));
      expect(find.text('second tool get_weather'), findsOneWidget);
      expect(find.textContaining('first'), findsNothing);
    });

    testWidgets('a hidden factory row still asks its question', (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(parts: [AIMessagePart.fromToolCall(_awaiting)], approver: approver),
          factory: const _Hiding(),
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
          factory: const _Hiding(),
        ),
      );
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('a call toolCallBuilder hides gets no question', (tester) async {
      final approver = _approver();
      addTearDown(approver.dispose);
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: [AIMessagePart.fromToolCall(_awaiting)],
            approver: approver,
            toolCallBuilder: (context, call) => AIMessagePartsView.hidden,
          ),
        ),
      );
      expect(find.byType(AIToolApprovalCard), findsNothing);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('buildToolApproval gets the call, theme and current state', (tester) async {
      final pending = Completer<void>();
      final approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
        decide: (call, decision) => pending.future,
      );
      addTearDown(approver.dispose);
      const theme = ToolApprovalThemeData(backgroundColor: Colors.amber);
      final factory = _Recording();
      await tester.pumpWidget(
        _wrap(
          AIToolApprovalView(call: _awaiting, approver: approver, theme: theme),
          factory: factory,
        ),
      );

      expect(find.text('state AIToolApprovalIdle'), findsOneWidget);
      expect(factory.approvals.last.call, same(_awaiting));
      expect(factory.approvals.last.approval, same(_awaiting.approval));
      expect(factory.approvals.last.theme, same(theme));

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.text('state AIToolApprovalSending'), findsOneWidget);
    });

    testWidgets('swapping the factory updates a ChatComposer without its own', (tester) async {
      final composer = ChatComposer(onSendPressed: (_, __, ___) {});
      await tester.pumpWidget(_wrap(composer, factory: const _Custom('first')));
      expect(find.text('first trailing'), findsOneWidget);

      await tester.pumpWidget(_wrap(composer, factory: const _Custom('second')));
      expect(find.text('second trailing'), findsOneWidget);
      expect(find.text('first trailing'), findsNothing);
    });
  });
}
