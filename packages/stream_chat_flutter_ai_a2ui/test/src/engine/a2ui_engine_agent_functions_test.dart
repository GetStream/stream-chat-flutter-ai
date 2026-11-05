import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets("a function no catalog has runs as the host's read-only tool, with its arguments", (tester) async {
    final city = TestTool('city', output: 'Ohrid');

    await _pumpSurface(
      tester,
      [
        _textCalling('city', {'id': 7}),
      ],
      tools: [city],
    );

    expect(city.runs, [
      {'id': 7},
    ]);
  });

  testWidgets("a tool's output shows where the surface uses it", (tester) async {
    final city = TestTool('city', output: 'Ohrid');

    await _pumpSurface(tester, [_textCalling('city', const {})], tools: [city]);
    await _answer(tester);

    expect(find.text('Ohrid'), findsOneWidget);
  });

  testWidgets("a tool that isn't read-only doesn't run as a surface shows", (tester) async {
    final email = TestTool('send_email', isReadOnly: false);

    await _pumpSurface(tester, [_textCalling('send_email', const {})], tools: [email]);
    await _answer(tester);

    expect(email.runs, isEmpty);
  });

  testWidgets("a tool that isn't read-only, refused as a surface shows, is reported", (tester) async {
    final email = TestTool('send_email', isReadOnly: false);

    final harness = await _pumpSurface(tester, [_textCalling('send_email', const {})], tools: [email]);
    await _answer(tester);

    expect(harness.errors.map((error) => error.$1.message), contains(contains("isn't read-only")));
  });

  testWidgets("a tool that isn't read-only runs from the person's tap", (tester) async {
    final email = TestTool('send_email', isReadOnly: false);
    await _pumpSurface(tester, _buttonCalling('send_email'), tools: [email]);

    await tester.tap(find.text('Send'));
    await _answer(tester);

    expect(email.runs, hasLength(1));
  });

  testWidgets('each tap runs the tool again', (tester) async {
    final email = TestTool('send_email', isReadOnly: false);
    await _pumpSurface(tester, _buttonCalling('send_email'), tools: [email]);

    await tester.tap(find.text('Send'));
    await _answer(tester);
    await tester.tap(find.text('Send'));
    await _answer(tester);

    expect(email.runs, hasLength(2));
  });

  testWidgets('a function no tool answers is reported as an expression error', (
    tester,
  ) async {
    final harness = await _pumpSurface(tester, [_textCalling('nowhere', const {})]);
    await _answer(tester);

    expect(harness.errors.single.$1.code, A2UIErrorCode.expressionError);
  });

  testWidgets('a tool the UI calls as it shows gets its arguments as the surface holds them', (tester) async {
    final strength = TestTool('strength', output: 'Strong');
    await _pumpSurface(
      tester,
      [
        _password,
        _textCalling('strength', {
          'value': {'@path': '/password'},
        }, id: 'check'),
      ],
      tools: [strength],
    );

    await tester.enterText(find.byType(EditableText), 'hunter2');
    await _answer(tester);

    expect(strength.runs.last, {'value': 'hunter2'});
  });

  testWidgets("a tool that isn't read-only doesn't run from work a tap started later", (tester) async {
    final email = TestTool('send_email', isReadOnly: false);
    final book = surfaceMessage(buttonSaying('Book it'));
    final grown = [
      book,
      surfaceMessage(_column([_textCalling('send_email', const {})]), surfaceId: 'mail'),
    ];
    late final AIUIHost host;
    // The app's send goes on after the tap, and a new part of the reply
    // arrives from there, outside any build.
    host = AIUIHost(
      renderers: [A2UIRenderer(onError: (_, _) {})],
      tools: [email],
      send: (_) async {
        await Future<void>.value();
        host.receive([TestReply('m1', a2uiDocument(grown, isStreaming: true))]);
      },
    );
    addTearDown(host.dispose);
    await tester.pumpWidget(_hostApp(host, a2uiDocument([book], isStreaming: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book it'));
    await _answer(tester);

    expect(email.runs, isEmpty);
  });

  testWidgets("a tool that isn't read-only doesn't run from new messages while a tapped tool still runs", (
    tester,
  ) async {
    final email = TestTool('send_email', isReadOnly: false);
    final book = TestTool('book', isReadOnly: false, holds: true);
    final tap = surfaceMessage(_buttonCalling('book'));
    final grown = [
      tap,
      surfaceMessage(_column([_textCalling('send_email', const {})]), surfaceId: 'mail'),
    ];
    final harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([tap], isStreaming: true)),
      ],
      tools: [email, book],
    );
    await tester.tap(find.text('Send'));
    await _answer(tester);

    harness.host.receive([TestReply('m1', a2uiDocument(grown, isStreaming: true))]);
    await _answer(tester);
    book.pending!.complete(AIClientToolCompleted(null));
    await _answer(tester);

    expect(email.runs, isEmpty);
  });

  testWidgets("a tool that isn't read-only doesn't run from what the person types while a tapped tool still runs", (
    tester,
  ) async {
    final email = TestTool('send_email', isReadOnly: false);
    final book = TestTool('book', isReadOnly: false, holds: true);
    await _pumpSurface(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['name', 'mail', 'go'],
        },
        {
          'id': 'name',
          'component': 'TextField',
          'label': 'Name',
          'value': {'@path': '/name'},
        },
        _textCalling('send_email', {
          'to': {'@path': '/name'},
        }, id: 'mail'),
        ..._buttonCalling('book').map((component) => {...component, 'id': component['id'] == 'root' ? 'go' : 'label'}),
      ],
      tools: [email, book],
    );
    await tester.tap(find.text('Send'));
    await _answer(tester);

    await tester.enterText(find.byType(EditableText), 'Ana');
    await _answer(tester);
    book.pending!.complete(AIClientToolCompleted(null));
    await _answer(tester);

    expect(email.runs, isEmpty);
  });

  testWidgets("a tool that isn't read-only doesn't run from new messages the tapped tool's own code applies", (
    tester,
  ) async {
    final email = TestTool('send_email', isReadOnly: false);
    final tap = surfaceMessage(_buttonCalling('book'));
    final grown = [
      tap,
      surfaceMessage(_column([_textCalling('send_email', const {})]), surfaceId: 'mail'),
    ];
    late final AIUIHost host;
    host = AIUIHost(
      renderers: [A2UIRenderer(onError: (_, _) {})],
      tools: [
        _ReceivingTool('book', () => host.receive([TestReply('m1', a2uiDocument(grown, isStreaming: true))])),
        email,
      ],
      send: (_) async {},
    );
    addTearDown(host.dispose);
    host.receive([
      TestReply('m1', a2uiDocument([tap], isStreaming: true)),
    ]);
    await tester.pumpWidget(_hostApp(host, a2uiDocument([tap], isStreaming: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send'));
    await _answer(tester);

    expect(email.runs, isEmpty);
  });

  testWidgets("a tool's failure is reported in the tool's own words", (tester) async {
    final harness = await _pumpSurface(tester, [_textCalling('nowhere', const {})]);
    await _answer(tester);

    expect(harness.errors.single.$1.message, contains("Function 'nowhere' failed: No tool named nowhere"));
  });

  testWidgets('a tool started while the screen builds runs after the frame', (tester) async {
    final phases = <SchedulerPhase>[];

    await _pumpSurface(tester, [_textCalling('city', const {})], tools: [_PhaseTool(phases)]);

    expect(phases, [isNot(anyOf(SchedulerPhase.persistentCallbacks, SchedulerPhase.midFrameMicrotasks))]);
  });
}

final _password = {
  'id': 'password',
  'component': 'TextField',
  'label': 'Password',
  'variant': 'obscured',
  'value': {'@path': '/password'},
};

Map<String, Object?> _textCalling(String name, Map<String, Object?> args, {String id = 'text'}) => {
  'id': id,
  'component': 'Text',
  'text': {'@call': name, 'args': args},
};

List<Map<String, Object?>> _buttonCalling(String name) => [
  {
    'id': 'root',
    'component': 'Button',
    'child': 'label',
    'action': {
      'functionCall': {'@call': name, 'args': <String, Object?>{}},
    },
  },
  {'id': 'label', 'component': 'Text', 'text': 'Send'},
];

List<Map<String, Object?>> _column(List<Map<String, Object?>> children) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': [for (final child in children) child['id']],
  },
  ...children,
];

// Shows a surface of [components], in a column unless they hold the root.
Future<ReplyHarness> _pumpSurface(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  List<AIResultClientTool> tools = const [],
}) {
  final hasRoot = components.any((component) => component['id'] == 'root');
  final document = a2uiDocument([surfaceMessage(hasRoot ? components : _column(components))]);
  return pumpReplies(tester, [TestReply('m1', document)], tools: tools);
}

// Lets a tool's answer reach the surface: a frame for the tool to start
// after, one for its answer, and one for the surface to show it.
Future<void> _answer(WidgetTester tester) async {
  for (var turn = 0; turn < 3; turn += 1) {
    await tester.pump();
  }
}

// A read-only tool that records the phase of the frame it ran in.
final class _PhaseTool extends AIResultClientTool {
  _PhaseTool(this.phases);

  final List<SchedulerPhase> phases;

  @override
  AIToolDefinition get definition => const AIToolDefinition(name: 'city', description: 'A city', isReadOnly: true);

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) async {
    phases.add(SchedulerBinding.instance.schedulerPhase);
    return AIClientToolCompleted('Ohrid');
  }
}

// An app that shows the reply `m1` of [document] through [host].
Widget _hostApp(AIUIHost host, AIUIDocument document) {
  return MaterialApp(
    theme: ThemeData(extensions: [StreamTheme.light()]),
    home: Material(
      child: AIUIView(host: host, document: document, messageId: 'm1'),
    ),
  );
}

// A tool that isn't read-only and, as soon as it runs, calls [onRun].
final class _ReceivingTool extends AIResultClientTool {
  _ReceivingTool(this.name, this.onRun);

  final String name;
  final VoidCallback onRun;

  @override
  AIToolDefinition get definition => AIToolDefinition(name: name, description: 'A tool that books');

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) {
    onRun();
    return Future.value(AIClientToolCompleted(null));
  }
}
