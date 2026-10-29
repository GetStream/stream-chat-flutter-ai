import 'dart:async';

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

    testWidgets('a streamed tool call announces its finish, and one loaded already finished does not', (tester) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      List<AIMessagePart> parts(String status) => AIMessagePart.parseAll([
        (type: 'ai_tool_call', payload: const {'id': 'old', 'name': 'look_up', 'status': 'completed'}),
        (type: 'ai_tool_call', payload: {'id': 'new', 'name': 'get_weather', 'status': status}),
      ]);

      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: parts('running'))));
      expect(tester.getSemantics(find.bySemanticsLabel('look up, Completed')), isSemantics(isLiveRegion: false));
      expect(tester.getSemantics(find.bySemanticsLabel('get weather, Running')), isSemantics(isLiveRegion: true));

      // A reasoning step arriving before the call doesn't cost it its state.
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: [
              ...AIMessagePart.parseAll([
                (type: 'ai_reasoning', payload: const {'id': 'r1', 'status': 'completed'}),
              ]),
              ...parts('completed'),
            ],
          ),
        ),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('get weather, Completed')), isSemantics(isLiveRegion: true));
      expect(tester.getSemantics(find.bySemanticsLabel('look up, Completed')), isSemantics(isLiveRegion: false));
      handle.dispose();
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
            partBuilder: (context, part) => part.kind == 'ai_citation' ? const Text('citation') : null,
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
          partBuilder: (context, part) => part.kind == 'ai_citation' ? const SizedBox(height: 10) : null,
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
            partBuilder: (context, part) => part.kind == 'ai_citation' ? const Text('citation') : null,
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
        _wrap(AIMessagePartsView(parts: parts, partBuilder: (context, part) => Text(part.kind))),
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

    testWidgets('spaces parts 10 apart by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts.take(2).toList(),
            partBuilder: (context, part) => SizedBox(height: 10, child: Text(part.id)),
          ),
        ),
      );

      final gap = tester.getTopLeft(find.text('call_1')).dy - tester.getBottomLeft(find.text('r1')).dy;
      expect(gap, 10);
    });

    testWidgets('fills a bounded width and shrink-wraps an unbounded one', (tester) async {
      Widget parts() => AIMessagePartsView(
        parts: _parts.take(1).toList(),
        partBuilder: (context, part) => const SizedBox(width: 40, height: 10),
      );
      await tester.pumpWidget(_wrap(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: parts())));
      expect(tester.getSize(find.byType(AIMessagePartsView)), const Size(300, 10));

      await tester.pumpWidget(_wrap(Row(mainAxisSize: MainAxisSize.min, children: [parts()])));
      expect(tester.getSize(find.byType(AIMessagePartsView)), const Size(40, 10));
    });

    testWidgets('renders nothing for no parts', (tester) async {
      await tester.pumpWidget(_wrap(const AIMessagePartsView(parts: [])));

      expect(find.byType(Column), findsNothing);
    });
  });

  group('AIMessagePartsView with an approver', () {
    final answers = <(String, AIToolApprovalDecision)>[];
    late AIToolApprover approver;
    setUp(() {
      answers.clear();
      approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
        decide: (call, decision) async => answers.add((call.id, decision)),
      );
    });
    tearDown(() => approver.dispose());

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
      expect(answers, [('call_1', AIToolApprovalDecision.allowed)]);
    });

    testWidgets('leaves 8 between a call and its question, whatever the spacing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: AIMessagePartsView(parts: parts(), approver: approver, spacing: 20),
          ),
        ),
      );

      final row = find.ancestor(of: find.text('send email'), matching: find.byType(AIToolCallView));
      expect(tester.getTopLeft(find.byType(AIToolApprovalCard)).dy - tester.getBottomLeft(row).dy, 8);
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
      expect(find.byType(AIToolApprovalCard), findsNothing);
      expect(tester.getSize(find.byType(AIToolApprovalView).first).height, 0, reason: 'empty, and spaced like nothing');
      expect(tester.state(find.byType(AIToolCallView).first), same(row));
    });

    testWidgets('the row keeps its state when the approver comes and goes', (tester) async {
      Widget view({AIToolApprover? approver}) => _wrap(
        SizedBox(
          width: 360,
          child: AIMessagePartsView(parts: parts(), approver: approver),
        ),
      );

      await tester.pumpWidget(view());
      final row = tester.state(find.byType(AIToolCallView).first);

      await tester.pumpWidget(view(approver: approver));
      expect(find.byType(AIToolApprovalCard), findsOneWidget);
      expect(tester.state(find.byType(AIToolCallView).first), same(row));

      await tester.pumpWidget(view());
      expect(find.byType(AIToolApprovalCard), findsNothing);
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
      expect(find.byType(AIToolApprovalCard), findsNothing);

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
      expect(find.byType(AIToolApprovalCard), findsNothing);
    });

    testWidgets('a call partBuilder hides still asks its question, without its row', (tester) async {
      Widget view({String status = 'awaiting_approval'}) => _wrap(
        SizedBox(
          width: 360,
          child: AIMessagePartsView(
            parts: parts(status: status),
            approver: approver,
            partBuilder: (context, part) => part.id == 'call_1' ? AIMessagePartsView.hidden : null,
          ),
        ),
      );

      await tester.pumpWidget(view());
      expect(find.byType(AIToolCallView), findsOneWidget, reason: 'only the other call has a row');
      expect(find.byType(AIToolApprovalCard), findsOneWidget);
      await tester.tap(find.text('Allow'));
      await tester.pump();
      expect(answers, [('call_1', AIToolApprovalDecision.allowed)]);

      // With nothing to ask, it is left out.
      await tester.pumpWidget(view(status: 'completed'));
      expect(find.byType(AIToolApprovalCard), findsNothing);
      expect(find.byType(AIToolCallView), findsOneWidget);
    });

    testWidgets('a call a builder draws its own way lets the approver forget the answer once it stops waiting', (
      tester,
    ) async {
      final timing = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
        decide: (call, decision) async {},
        sentTimeout: const Duration(seconds: 5),
      );
      addTearDown(timing.dispose);
      // The host's own widget asks while the call waits, then shows a summary.
      Widget view(List<AIMessagePart> parts) => _wrap(
        SizedBox(
          width: 360,
          child: AIMessagePartsView(
            parts: parts,
            approver: timing,
            toolCallBuilder: (context, call) => call.name != 'send_email'
                ? null
                : timing.identity.canApprove(call)
                ? AIToolApprovalView(call: call, approver: timing)
                : const Text('email sent'),
          ),
        ),
      );

      final waiting = parts();
      await tester.pumpWidget(view(waiting));
      timing.answer(waiting.first.toolCall!, AIToolApprovalDecision.allowed);
      await tester.pump();
      expect(timing.stateOf(waiting.first.toolCall!), isA<AIToolApprovalSent>());

      var notified = 0;
      timing.addListener(() => notified++);
      await tester.pumpWidget(view(parts(status: 'running', decision: 'allowed')));
      await tester.pump(const Duration(seconds: 6));
      expect(notified, 0, reason: 'the sent timeout was cancelled, so nothing turns failed');
      expect(timing.stateOf(waiting.first.toolCall!), const AIToolApprovalIdle(), reason: 'the answer was forgotten');
    });
  });

  group('AIMessagePartsView with an authorizer', () {
    final opened = <String>[];
    late AIToolApprover approver;
    setUp(() {
      opened.clear();
      approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice', clientId: 'phone'),
        decide: (_, _) async {},
        authorizer: AIToolAuthorizer(
          connect: (call, url) async {
            opened.add(call.id);
            return true;
          },
          decline: (_) async {},
        ),
      );
    });
    tearDown(() => approver.dispose());

    List<AIMessagePart> parts({String status = 'awaiting_authorization'}) => AIMessagePart.parseAll([
      (
        type: 'ai_tool_call',
        payload: {
          'id': 'call_1',
          'name': 'linear__list_issues',
          'display_title': 'Using Linear',
          'status': status,
          'target_user_id': 'alice',
          'authorization': {'title': 'Connect Linear', 'url': 'https://agent.example/launch'},
        },
      ),
      (type: 'ai_tool_call', payload: const {'id': 'call_2', 'name': 'search_web', 'status': 'completed'}),
    ]);

    Widget view(
      List<AIMessagePart> parts, {
      AIToolApprover? approver,
      AIComponentBuilders? builders,
      AIMessagePartWidgetBuilder? partBuilder,
      AIToolCallWidgetBuilder? toolCallBuilder,
    }) => _wrap(
      AIComponentFactory(
        builders: builders ?? const AIComponentBuilders(),
        child: SizedBox(
          width: 360,
          child: AIMessagePartsView(
            parts: parts,
            approver: approver,
            partBuilder: partBuilder,
            toolCallBuilder: toolCallBuilder,
          ),
        ),
      ),
    );

    testWidgets('asks for the sign-in under its row, 8 below it whatever the spacing', (tester) async {
      await tester.pumpWidget(view(parts(), approver: approver));

      expect(find.byType(AIToolAuthorizationCard), findsOneWidget);
      final row = find.ancestor(of: find.text('Using Linear'), matching: find.byType(AIToolCallView));
      expect(
        tester.getTopLeft(find.byType(AIToolAuthorizationCard)).dy - tester.getBottomLeft(row).dy,
        8,
        reason: 'the sign-in sits 8 under its row, closer than the steps',
      );

      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(opened, ['call_1']);
      // Let the connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('a call that no longer waits takes no extra room', (tester) async {
      await tester.pumpWidget(view(parts(status: 'running')));
      final without = tester.getSize(find.byType(AIMessagePartsView)).height;

      await tester.pumpWidget(view(parts(status: 'running'), approver: approver));

      expect(find.byType(AIToolAuthorizationCard), findsNothing);
      expect(tester.getSize(find.byType(AIMessagePartsView)).height, without);
    });

    testWidgets('asks nothing without an authorizer, and the row says only that the call waits', (tester) async {
      final plain = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice'),
        decide: (_, _) async {},
      );
      addTearDown(plain.dispose);

      await tester.pumpWidget(view(parts(), approver: plain));

      expect(find.byType(AIToolAuthorizationCard), findsNothing);
      expect(find.text('Waiting for sign-in'), findsOneWidget, reason: 'nothing here lets them sign in');
    });

    testWidgets('a sign-in of a kind it does not show leaves the row saying only that the call waits', (
      tester,
    ) async {
      final deviceCode = AIMessagePart.parseAll([
        (
          type: 'ai_tool_call',
          payload: {
            'id': 'call_1',
            'name': 'linear__list_issues',
            'display_title': 'Using Linear',
            'status': 'awaiting_authorization',
            'target_user_id': 'alice',
            'authorization': {'type': 'device_code', 'title': 'Connect Linear', 'url': 'https://agent.example/launch'},
          },
        ),
      ]);

      await tester.pumpWidget(view(deviceCode, approver: approver));

      expect(find.byType(AIToolAuthorizationCard), findsNothing);
      expect(find.text('Waiting for sign-in'), findsOneWidget);
    });

    testWidgets("the row tells the approver's person the call waits for them, and others it waits", (tester) async {
      await tester.pumpWidget(view(parts(), approver: approver));
      expect(find.text('Waiting for you to sign in'), findsOneWidget);

      final bob = AIToolApprover(
        identity: const AIClientIdentity(userId: 'bob'),
        decide: (_, _) async {},
      );
      addTearDown(bob.dispose);
      await tester.pumpWidget(view(parts(), approver: bob));
      expect(find.text('Waiting for sign-in'), findsOneWidget);

      await tester.pumpWidget(view(parts()));
      expect(find.text('Waiting for sign-in'), findsOneWidget);
    });

    testWidgets('a hidden row of a call that no longer waits forgets its sign-in', (tester) async {
      final pending = Completer<bool>();
      final forgetful = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice'),
        decide: (_, _) async {},
        authorizer: AIToolAuthorizer(connect: (_, _) => pending.future, decline: (_) async {}),
      );
      addTearDown(forgetful.dispose);
      final waiting = parts().first.toolCall!;
      forgetful.connect(waiting);
      expect(forgetful.authorizationStateOf(waiting).isConnecting, isTrue);

      await tester.pumpWidget(
        view(
          parts(status: 'running'),
          approver: forgetful,
          builders: AIComponentBuilders(toolCall: (context, props) => AIMessagePartsView.hidden),
        ),
      );
      pending.complete(false);
      await tester.pump();

      // Forgotten while it moved on: waiting again, it starts afresh.
      expect(forgetful.authorizationStateOf(waiting), const AIToolAuthorizationState());
    });

    testWidgets('a row the factory hides still asks for the sign-in', (tester) async {
      await tester.pumpWidget(
        view(
          parts(),
          approver: approver,
          builders: AIComponentBuilders(
            toolCall: (context, props) => props.call.id == 'call_1' ? AIMessagePartsView.hidden : const Text('row'),
          ),
        ),
      );

      expect(find.text('Using Linear'), findsNothing);
      expect(find.byType(AIToolAuthorizationCard), findsOneWidget);
    });

    testWidgets('a row partBuilder or toolCallBuilder hides still asks for the sign-in', (tester) async {
      await tester.pumpWidget(
        view(
          parts(),
          approver: approver,
          partBuilder: (context, part) => part.id == 'call_1' ? AIMessagePartsView.hidden : null,
        ),
      );
      expect(find.text('Using Linear'), findsNothing);
      expect(find.byType(AIToolAuthorizationCard), findsOneWidget);

      await tester.pumpWidget(
        view(
          parts(),
          approver: approver,
          toolCallBuilder: (context, call) => call.id == 'call_1' ? AIMessagePartsView.hidden : null,
        ),
      );
      expect(find.text('Using Linear'), findsNothing);
      expect(find.byType(AIToolAuthorizationCard), findsOneWidget);
    });

    testWidgets('a call a builder draws its own way forgets its sign-in once it stops waiting', (tester) async {
      final pending = Completer<bool>();
      final forgetful = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice'),
        decide: (_, _) async {},
        authorizer: AIToolAuthorizer(connect: (_, _) => pending.future, decline: (_) async {}),
      );
      addTearDown(forgetful.dispose);
      final waiting = parts().first.toolCall!;
      forgetful.connect(waiting);
      expect(forgetful.authorizationStateOf(waiting).isConnecting, isTrue);

      Widget own(BuildContext context, AIToolCallPart call) => Text('own ${call.id}');
      await tester.pumpWidget(view(parts(), approver: forgetful, toolCallBuilder: own));
      expect(find.byType(AIToolAuthorizationCard), findsNothing, reason: 'its own widget asks for the sign-in');
      expect(forgetful.authorizationStateOf(waiting).isConnecting, isTrue, reason: 'still waiting, so kept');

      await tester.pumpWidget(
        view(
          parts(status: 'running'),
          approver: forgetful,
          toolCallBuilder: own,
        ),
      );
      // Connected: kept, it would read connecting until its settle ran out.
      pending.complete(true);
      await tester.pump();

      // Forgotten while it moved on: waiting again, it starts afresh.
      expect(forgetful.authorizationStateOf(waiting), const AIToolAuthorizationState());
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
      // A tool call's icon size, whatever the text's.
      expect(icon.size, 16);
    });

    testWidgets("reads like a tool call's row by default", (tester) async {
      await tester.pumpWidget(_wrap(const AIUnsupportedPartView()));
      final theme = Theme.of(tester.element(find.byType(AIUnsupportedPartView)));

      final style = tester.widget<Text>(find.byType(Text)).style!;
      expect(style.fontSize, theme.textTheme.bodyMedium!.fontSize, reason: "the tool call title's size");
      expect(style.color, theme.colorScheme.onSurfaceVariant, reason: "the tool call detail's color");
      expect(tester.widget<Icon>(find.byType(Icon)).size, 16);
      expect(tester.getTopLeft(find.byType(Text)).dx - tester.getTopRight(find.byType(Icon)).dx, 8);
    });

    testWidgets('follows the tool call theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallTheme(
            data: ToolCallThemeData(
              titleStyle: TextStyle(fontSize: 17),
              detailStyle: TextStyle(color: Color(0xFF0000E1)),
              iconSize: 20,
            ),
            child: AIUnsupportedPartView(),
          ),
        ),
      );

      final style = tester.widget<Text>(find.byType(Text)).style!;
      expect(style.fontSize, 17);
      expect(style.color, const Color(0xFF0000E1));
      expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
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
