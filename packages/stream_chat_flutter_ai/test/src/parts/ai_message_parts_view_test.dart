import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

final _parts = AIMessagePart.parseAll([
  (type: 'ai_reasoning', payload: const {'id': 'r1', 'status': 'completed'}),
  (type: 'ai_tool_call', payload: const {'id': 'call_1', 'name': 'get_weather'}),
  (type: 'ai_citation', payload: const {'id': 'c1', 'url': 'https://example.com'}),
]);

void main() {
  group('AIMessagePartsView', () {
    testWidgets('shows reasoning and tool calls in their views, and the placeholder only for parts it cannot read', (
      tester,
    ) async {
      final parts = [
        ..._parts,
        ...AIMessagePart.parseAll([
          (type: 'ai_reasoning', payload: const {'id': 'r2', 'v': 2}),
        ]),
      ];
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: parts)));

      // The readable reasoning and tool call get their views. The citation
      // (unknown kind) and the v2 reasoning (newer format) get the placeholder.
      expect(find.byType(StreamingReasoningView), findsOneWidget);
      expect(find.text('Thought process'), findsOneWidget);
      expect(find.byType(AIToolCallView), findsOneWidget);
      expect(find.text('get weather'), findsOneWidget);
      expect(find.byType(AIUnsupportedPartView), findsNWidgets(2));
      expect(find.text("A step this app version can't show"), findsNWidgets(2));
      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('r1'),
        ValueKey<Object>('call_1'),
        ValueKey<Object>('c1'),
        ValueKey<Object>('r2'),
      ]);
    });

    testWidgets('a tool call shows its title, status and summary', (tester) async {
      final parts = AIMessagePart.parseAll([
        (
          type: 'ai_tool_call',
          payload: const {
            'id': 'call_1',
            'name': 'get_weather',
            'display_title': 'Checking the weather',
            'status': 'completed',
            'summary': 'Sunny, 21°C',
            'duration_ms': 800,
          },
        ),
      ]);
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: parts)));

      final view = tester.widget<AIToolCallView>(find.byType(AIToolCallView));
      expect(view.call, parts.single.toolCall);
      expect(find.text('Checking the weather'), findsOneWidget);
      expect(find.text('Sunny, 21°C'), findsOneWidget);
      expect(find.text('0.8s'), findsOneWidget);
    });

    testWidgets('a toolCallBuilder shows some tools its own way and leaves the rest to the default', (tester) async {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_tool_call', payload: const {'id': 'call_1', 'name': 'get_weather', 'status': 'completed'}),
        (type: 'ai_tool_call', payload: const {'id': 'call_2', 'name': 'search_web', 'status': 'completed'}),
        (type: 'ai_reasoning', payload: const {'id': 'r1', 'status': 'completed'}),
      ]);
      final asked = <String>[];
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: parts,
            toolCallBuilder: (context, call) {
              asked.add(call.id);
              return call.name == 'get_weather' ? const Text('weather card') : null;
            },
          ),
        ),
      );

      expect(asked, ['call_1', 'call_2'], reason: 'only asked for tool calls');
      expect(find.text('weather card'), findsOneWidget);
      expect(find.byType(AIToolCallView), findsOneWidget);
      expect(find.text('search web'), findsOneWidget);
      expect(find.byType(StreamingReasoningView), findsOneWidget);
      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('call_1'),
        ValueKey<Object>('call_2'),
        ValueKey<Object>('r1'),
      ]);
    });

    testWidgets('a partBuilder returning null hands tool calls to the toolCallBuilder', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts,
            partBuilder: (context, part) => part.kind.value == 'ai_citation' ? const Text('citation') : null,
            toolCallBuilder: (context, call) {
              asked.add(call.id);
              return const Text('call');
            },
          ),
        ),
      );

      expect(asked, ['call_1']);
      expect(find.text('call'), findsOneWidget);
      expect(find.text('citation'), findsOneWidget);
    });

    testWidgets('hidden leaves a part out, with no spacing for it', (tester) async {
      Widget build({required bool hide}) => _wrap(
        AIMessagePartsView(
          parts: _parts,
          spacing: 20,
          partBuilder: (context, part) => part.kind.value == 'ai_citation' ? const SizedBox(height: 10) : null,
          toolCallBuilder: (context, call) => hide ? AIMessagePartsView.hidden : const SizedBox(height: 10),
        ),
      );

      await tester.pumpWidget(build(hide: false));
      final shown = tester.getSize(find.byType(AIMessagePartsView)).height;
      await tester.pumpWidget(build(hide: true));
      final hidden = tester.getSize(find.byType(AIMessagePartsView)).height;
      expect(shown - hidden, 30, reason: 'the 10pt part and one 20pt gap are gone');

      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.children.map((child) => child.key), const [ValueKey<Object>('r1'), ValueKey<Object>('c1')]);
    });

    testWidgets('hiding the first of two parts with one id keeps the second its state', (tester) async {
      final twins = AIMessagePart.parseAll([
        (type: 'ai_tool_call', payload: const {'id': 'same', 'name': 'first'}),
        (type: 'ai_tool_call', payload: const {'id': 'same', 'name': 'second'}),
      ]);
      Widget build({required bool hideFirst}) => _wrap(
        AIMessagePartsView(
          parts: twins,
          toolCallBuilder: (context, call) =>
              hideFirst && call.name == 'first' ? AIMessagePartsView.hidden : _Counter(key: ValueKey(call.name)),
        ),
      );

      await tester.pumpWidget(build(hideFirst: false));
      final second = tester.state(find.byKey(const ValueKey('second')));
      await tester.pumpWidget(build(hideFirst: true));
      expect(tester.state(find.byKey(const ValueKey('second'))), same(second));
    });

    testWidgets('hidden from a partBuilder hides any part', (tester) async {
      await tester.pumpWidget(
        _wrap(AIMessagePartsView(parts: _parts, partBuilder: (context, part) => AIMessagePartsView.hidden)),
      );
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('a partBuilder is asked before the toolCallBuilder', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts,
            partBuilder: (context, part) => part.kind == AIMessagePartKind.toolCall ? const Text('part') : null,
            toolCallBuilder: (context, call) {
              asked.add(call.id);
              return const Text('call');
            },
          ),
        ),
      );

      expect(find.text('part'), findsOneWidget);
      expect(find.text('call'), findsNothing);
      expect(asked, isEmpty);
    });

    testWidgets('a tool call in a newer format stays a placeholder, unseen by the toolCallBuilder', (tester) async {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_tool_call', payload: const {'id': 'call_1', 'v': 99}),
      ]);
      await tester.pumpWidget(
        _wrap(AIMessagePartsView(parts: parts, toolCallBuilder: (context, call) => const Text('call'))),
      );

      expect(find.byType(AIToolCallView), findsNothing);
      expect(find.text('call'), findsNothing);
      expect(find.byType(AIUnsupportedPartView), findsOneWidget);
    });

    testWidgets('a reasoning part shows its status, duration, summary and preview', (tester) async {
      final parts = AIMessagePart.parseAll([
        (
          type: 'ai_reasoning',
          payload: const {
            'id': 'r1',
            'status': 'completed',
            'summary': 'Compared both plans',
            'preview': 'The user wants a plan.',
            'duration_ms': 12400,
          },
        ),
      ]);
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: parts)));

      // Title and summary share one line of text.
      expect(find.textContaining('Thought for 12s'), findsOneWidget);
      expect(find.textContaining('Compared both plans'), findsOneWidget);

      await tester.tap(find.textContaining('Thought for 12s'));
      await tester.pumpAndSettle();
      expect(find.text('The user wants a plan.'), findsOneWidget);
    });

    testWidgets('a reasoning part in a newer format stays a placeholder', (tester) async {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'id': 'r1', 'v': 99}),
      ]);
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: parts)));

      expect(find.byType(StreamingReasoningView), findsNothing);
      expect(find.byType(AIUnsupportedPartView), findsOneWidget);
    });

    testWidgets('renders parts in order, keyed by id', (tester) async {
      await tester.pumpWidget(
        _wrap(AIMessagePartsView(parts: _parts, partBuilder: (context, part) => Text(part.id))),
      );

      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('r1'),
        ValueKey<Object>('call_1'),
        ValueKey<Object>('c1'),
      ]);
      final dy = ['r1', 'call_1', 'c1'].map((id) => tester.getTopLeft(find.text(id)).dy).toList();
      expect(dy, orderedEquals([...dy]..sort()));
    });

    testWidgets('a builder returning null falls back to the default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts,
            partBuilder: (context, part) => part.kind.value == 'ai_citation' ? const Text('citation') : null,
          ),
        ),
      );

      expect(find.text('citation'), findsOneWidget);
      expect(find.byType(StreamingReasoningView), findsOneWidget);
      expect(find.byType(AIUnsupportedPartView), findsNothing);

      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts,
            partBuilder: (context, part) => part.kind == AIMessagePartKind.reasoning ? const Text('reasoning') : null,
          ),
        ),
      );
      expect(find.text('reasoning'), findsOneWidget);
      expect(find.byType(StreamingReasoningView), findsNothing);
      expect(find.byType(AIUnsupportedPartView), findsOneWidget);
    });

    testWidgets('tells apart parts that share an id', (tester) async {
      debugPartIssueReporter = (_) {};
      addTearDown(() => debugPartIssueReporter = null);
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'id': 'same'}),
        (type: 'ai_tool_call', payload: const {'id': 'same'}),
        (type: 'ai_tool_call', payload: const {'id': 'same'}),
      ]);

      await tester.pumpWidget(
        _wrap(AIMessagePartsView(parts: parts, partBuilder: (context, part) => Text(part.kind.value))),
      );

      expect(tester.takeException(), isNull);
      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('same'),
        ValueKey<Object>(('same', 1)),
        ValueKey<Object>(('same', 2)),
      ]);
    });

    testWidgets('keeps a part state when one is added before it', (tester) async {
      final first = AIMessagePart(id: 'a', kind: AIMessagePartKind.reasoning);
      final second = AIMessagePart(id: 'b', kind: AIMessagePartKind.toolCall);
      Widget build(List<AIMessagePart> parts) => _wrap(
        AIMessagePartsView(
          parts: parts,
          partBuilder: (context, part) => _Stateful(label: part.id),
        ),
      );

      await tester.pumpWidget(build([second]));
      final state = tester.state(find.byType(_Stateful));

      await tester.pumpWidget(build([first, second]));
      expect(tester.state(find.byWidgetPredicate((w) => w is _Stateful && w.label == 'b')), same(state));
    });

    testWidgets('applies the spacing between parts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts.take(2).toList(),
            spacing: 20,
            partBuilder: (context, part) => SizedBox(height: 10, child: Text(part.id)),
          ),
        ),
      );

      final gap = tester.getTopLeft(find.text('call_1')).dy - tester.getBottomLeft(find.text('r1')).dy;
      expect(gap, 20);
    });

    testWidgets('renders nothing for no parts', (tester) async {
      await tester.pumpWidget(_wrap(const AIMessagePartsView(parts: [])));

      expect(find.byType(Column), findsNothing);
    });
  });

  group('AIMessagePartsView with an approver', () {
    final answers = <(String, bool)>[];
    final approver = AIToolApprover(
      userId: 'alice',
      clientId: 'phone',
      decide: (call, allowed) async => answers.add((call.id, allowed)),
    );
    setUp(answers.clear);

    List<AIMessagePart> parts({String status = 'awaiting_approval', String? decision}) => AIMessagePart.parseAll([
      (
        type: 'ai_tool_call',
        payload: {
          'id': 'call_1',
          'name': 'send_email',
          'status': status,
          'target_user_id': 'alice',
          'approval': {'title': 'Send the summary by email?', 'decision': ?decision},
        },
      ),
      (type: 'ai_tool_call', payload: const {'id': 'call_2', 'name': 'search_web', 'status': 'completed'}),
    ]);

    testWidgets('asks under a call awaiting approval, and only there', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(parts: parts(), approver: approver),
          ),
        ),
      );

      expect(find.byType(AIToolCallView), findsNWidgets(2));
      expect(find.byType(AIToolApprovalCard), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(AIToolApprovalCard)).dy,
        greaterThan(tester.getBottomLeft(find.text('send email')).dy),
        reason: 'the question sits under its row',
      );

      await tester.tap(find.text('Allow'));
      await tester.pump();
      expect(answers, [('call_1', true)]);
    });

    testWidgets('asks nothing without an approver', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(width: 360, child: AIMessagePartsView(parts: parts()))));
      expect(find.byType(AIToolApprovalView), findsNothing);
    });

    testWidgets('the question goes away once answered, and the row keeps its state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(parts: parts(), approver: approver),
          ),
        ),
      );
      final row = tester.state(find.byType(AIToolCallView).first);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(
              parts: parts(status: 'running', decision: 'allowed'),
              approver: approver,
            ),
          ),
        ),
      );
      expect(find.byType(AIToolApprovalView), findsNothing);
      expect(tester.state(find.byType(AIToolCallView).first), same(row));
    });

    testWidgets('a builder showing the call its own way gets no question', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(
              parts: parts(),
              approver: approver,
              toolCallBuilder: (context, call) => call.name == 'send_email' ? const Text('email card') : null,
            ),
          ),
        ),
      );
      expect(find.text('email card'), findsOneWidget);
      expect(find.byType(AIToolApprovalView), findsNothing);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(
              parts: parts(),
              approver: approver,
              partBuilder: (context, part) => part.id == 'call_1' ? const Text('part') : null,
            ),
          ),
        ),
      );
      expect(find.text('part'), findsOneWidget);
      expect(find.byType(AIToolApprovalView), findsNothing);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(
              parts: parts(),
              approver: approver,
              toolCallBuilder: (context, call) => call.id == 'call_1' ? AIMessagePartsView.hidden : null,
            ),
          ),
        ),
      );
      expect(find.byType(AIToolCallView), findsOneWidget, reason: 'the hidden call is left out');
      expect(find.byType(AIToolApprovalView), findsNothing);
    });
  });

  group('AIUnsupportedPartView', () {
    testWidgets('translates its text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AITranslationsScope(
            translations: _DutchTranslations(),
            child: AIUnsupportedPartView(),
          ),
        ),
      );

      expect(find.text('Onbekende stap'), findsOneWidget);
    });

    testWidgets('uses the given style and icon color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AIUnsupportedPartView(
            textStyle: TextStyle(fontSize: 20, color: Color(0xFFFF0000)),
            iconColor: Color(0xFF00FF00),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.fontSize, 20);
      expect(text.style!.color, const Color(0xFFFF0000));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFF00FF00));
      // Scales with the text rather than staying a fixed size.
      expect(icon.size, greaterThan(20));
    });

    testWidgets('the icon takes the text color by default', (tester) async {
      await tester.pumpWidget(_wrap(const AIUnsupportedPartView(textStyle: TextStyle(color: Color(0xFF0000FF)))));

      expect(tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFF0000FF));
    });

    goldenTest(
      'unsupported part',
      fileName: 'ai_unsupported_part_view',
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 80),
      builder: () => _wrap(const Padding(padding: EdgeInsets.all(12), child: AIUnsupportedPartView())),
    );
  });
}

class _Stateful extends StatefulWidget {
  const _Stateful({required this.label});

  final String label;

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => Text(widget.label);
}

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String get unsupportedMessagePart => 'Onbekende stap';
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}
