import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets("the agent places the app's component, with the values it wrote", (tester) async {
    await _pumpReply(tester, [_placeCard(title: 'St. Naum', note: 'Take the 10:00 boat')]);

    expect(find.text('Place: St. Naum'), findsOneWidget);
    expect(find.text('Note: Take the 10:00 boat'), findsOneWidget);
  });

  testWidgets("the app's component shows in a surface that names the basic catalog", (tester) async {
    await _pumpReply(tester, [_placeCard()], catalogId: A2UIRenderer.basicCatalogId);

    expect(find.text('Place: St. Naum'), findsOneWidget);
  });

  testWidgets("the app's component shows in a surface that names no catalog", (tester) async {
    await _pumpReply(tester, [_placeCard()], catalogId: null);

    expect(find.text('Place: St. Naum'), findsOneWidget);
  });

  testWidgets("the app's component shows in the catalog of a renderer given another id", (tester) async {
    await _pumpReply(
      tester,
      [_placeCard()],
      catalogId: 'example.com:travel',
      renderer: (onError) => A2UIRenderer(catalogId: 'example.com:travel', onError: onError),
    );

    expect(find.text('Place: St. Naum'), findsOneWidget);
  });

  testWidgets("a value bound to the surface's data reads the data", (tester) async {
    await _pumpReply(
      tester,
      [
        _placeCard(title: {'@path': '/place'}),
      ],
      data: {'place': 'Bay of Bones'},
    );

    expect(find.text('Place: Bay of Bones'), findsOneWidget);
  });

  testWidgets("a value bound to the surface's data follows the data", (tester) async {
    final first = _surface(
      [
        _placeCard(title: {'@path': '/place'}),
      ],
      data: {'place': 'Bay of Bones'},
    );
    final update = jsonEncode({
      'version': '1.0',
      'updateDataModel': {'surfaceId': 's', 'path': '/place', 'value': 'Plaošnik'},
    });
    final harness = await _pumpMessages(tester, [first]);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([first, update])),
    ]);

    expect(find.text('Place: Plaošnik'), findsOneWidget);
  });

  testWidgets("a value written as a function call reads the function's result", (tester) async {
    await _pumpReply(
      tester,
      [
        _placeCard(
          title: {
            '@call': 'formatString',
            'args': {'value': r'St. ${/saint}'},
          },
        ),
      ],
      data: {'saint': 'Naum'},
    );

    expect(find.text('Place: St. Naum'), findsOneWidget);
  });

  testWidgets('the component reads only the values of its own parameters', (tester) async {
    final seen = <Map<String, Object?>>[];

    await _pumpReply(
      tester,
      [
        {..._placeCard(), 'rating': 5},
      ],
      components: [_RecordingComponent(seen)],
    );

    expect(seen.last.keys, ['title']);
  });

  testWidgets('a parameter the agent bound to missing data is left out of the values', (tester) async {
    final seen = <Map<String, Object?>>[];

    await _pumpReply(
      tester,
      [
        _placeCard(note: {'@path': '/missing'}),
      ],
      components: [_RecordingComponent(seen)],
    );

    expect(seen.last.keys, ['title']);
  });

  testWidgets("while the reply streams, a component whose values don't fit shows nothing and isn't reported", (
    tester,
  ) async {
    final reports = _captureReports();

    final harness = await _pumpReply(tester, [
      _placeCard(title: 42),
    ], isStreaming: true);

    expect(reports.stop(), isEmpty);
    expect(harness.errors, isEmpty);
    expect(find.textContaining('Place:'), findsNothing);
  });

  testWidgets("once the reply is finished, a component whose values don't fit is reported to onError", (
    tester,
  ) async {
    final harness = await _pumpReply(tester, [_placeCard(title: 42)]);

    final (error, messageId) = harness.errors.single;
    expect((error.code, error.surfaceId, messageId), (A2UIErrorCode.validationFailed, 's', 'm1'));
    expect(error.message, contains('place_card'));
    expect(find.textContaining('Place:'), findsNothing);
  });

  testWidgets('an error the component throws reading its values is reported to onError', (tester) async {
    final reports = _captureReports();

    final harness = await _pumpReply(tester, [_placeCard()], components: const [_Throwing(inRead: true)]);
    await tester.pump();

    expect(reports.stop(), isNotEmpty);
    final (error, messageId) = harness.errors.single;
    expect((error.code, error.surfaceId, messageId), (A2UIErrorCode.executionError, 's', 'm1'));
    expect(error.message, contains('read failed'));
  });

  testWidgets('an error the component throws building its widget is reported to onError', (tester) async {
    final reports = _captureReports();

    final harness = await _pumpReply(tester, [_placeCard()], components: const [_Throwing(inRead: false)]);
    await tester.pump();

    expect(reports.stop(), isNotEmpty);
    final (error, _) = harness.errors.single;
    expect((error.code, error.surfaceId), (A2UIErrorCode.executionError, 's'));
    expect(error.message, contains('build failed'));
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('a component without a value its definition requires is reported to onError', (tester) async {
    final harness = await _pumpReply(tester, [
      {'id': 'root', 'component': 'PlaceCard', 'note': 'Take the 10:00 boat'},
    ]);

    final (error, messageId) = harness.errors.single;
    expect((error.code, messageId), (A2UIErrorCode.validationFailed, 'm1'));
    expect(error.message, contains('"title"'));
  });

  testWidgets('a required value the agent wrote as null is reported to onError', (tester) async {
    final harness = await _pumpReply(tester, [_placeCard(title: null)]);

    final (error, _) = harness.errors.single;
    expect(error.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('a reply removed before its finish reaches the component throws nothing', (tester) async {
    final message = _surface([
      {'id': 'root', 'component': 'ReplyStatus'},
    ]);
    final harness = await _pumpMessages(tester, [message], isStreaming: true, components: const [_ReplyStatus()]);

    // In one build, the finished reply is shown, which waits for the frame to
    // end to tell the component, and then leaves the conversation.
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final finished = TestReply('m1', a2uiDocument([message]));
          harness.host.receive([finished]);
          AIUIView(host: harness.host, document: finished.uiDocument!, messageId: 'm1');
          harness.host.receive(const []);
          return const SizedBox();
        },
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the component learns the reply finished, with no new message', (tester) async {
    final message = _surface([
      {'id': 'root', 'component': 'ReplyStatus'},
    ]);
    final harness = await _pumpMessages(tester, [message], isStreaming: true, components: const [_ReplyStatus()]);
    expect(find.text('Writing'), findsOneWidget);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([message])),
    ]);

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a component in an open sheet learns the reply finished', (tester) async {
    final message = _surface([
      {'id': 'root', 'component': 'Modal', 'trigger': 'open', 'content': 'status'},
      {
        'id': 'open',
        'component': 'Button',
        'child': 'label',
        'action': {
          'event': {'name': 'open_status'},
        },
      },
      {'id': 'label', 'component': 'Text', 'text': 'Open'},
      {'id': 'status', 'component': 'ReplyStatus'},
    ]);
    final harness = await _pumpMessages(tester, [message], isStreaming: true, components: const [_ReplyStatus()]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([message])),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the component sees a streaming reply as streaming from its first build', (tester) async {
    final seen = <bool>[];

    await _pumpMessages(
      tester,
      [
        _surface([
          {'id': 'root', 'component': 'ReplyStatus'},
        ]),
      ],
      isStreaming: true,
      components: [_ReplyStatus(seen: seen)],
    );

    expect(seen, everyElement(isTrue));
    expect(seen, isNotEmpty);
  });

  testWidgets('an event the component reports after its reply left sends nothing', (tester) async {
    final contexts = <AIUIComponentContext>[];
    final harness = await _pumpReply(tester, [_placeCard()], components: [_ContextKeeper(contexts)]);

    await showReplies(tester, harness, const []);
    contexts.last.emit('ask_about', label: 'Too late');
    await tester.pump();

    expect(harness.actions, isEmpty);
  });

  testWidgets('an event the component reports after the host is disposed sends nothing', (tester) async {
    final contexts = <AIUIComponentContext>[];
    final harness = await _pumpReply(tester, [_placeCard()], components: [_ContextKeeper(contexts)]);

    harness.host.dispose();
    contexts.last.emit('ask_about', label: 'Too late');
    await tester.pump();

    expect(harness.actions, isEmpty);
  });

  testWidgets('an optional value the agent wrote as null is left out, and the component shows', (tester) async {
    final harness = await _pumpReply(tester, [
      {..._placeCard(), 'note': null},
    ]);

    expect(find.text('Place: St. Naum'), findsOneWidget);
    expect(harness.errors, isEmpty);
  });

  testWidgets("a parameter's schema that refers to definitions it doesn't hold breaks nothing", (tester) async {
    await _pumpReply(
      tester,
      [_placeCard()],
      components: const [
        _PlaceCard(
          noteType: AIUIParameterType({r'$ref': r'#/$defs/Note'}),
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Place: St. Naum'), findsOneWidget);
  });

  testWidgets("a value naming another component's id is passed as the id, not as the component", (tester) async {
    final seen = <Map<String, Object?>>[];

    await _pumpReply(
      tester,
      [
        {..._placeCard(), 'note': 'other'},
        {'id': 'other', 'component': 'Text', 'text': 'Elsewhere'},
      ],
      components: [_RecordingComponent(seen)],
    );

    expect(seen.last['note'], 'other');
  });

  testWidgets("the component's event is sent as an action named after the event, in the reply", (tester) async {
    final harness = await _pumpReply(tester, [_placeCard()]);

    await tester.tap(find.text('Ask'));

    final action = harness.actions.single;
    expect((action.messageId, action.format, action.name), ('m1', AIUIFormat.a2ui, 'ask_about'));
  });

  testWidgets("the action's label is the one the component gave", (tester) async {
    final harness = await _pumpReply(tester, [_placeCard()]);

    await tester.tap(find.text('Ask'));

    expect(harness.actions.single.label, 'Tell me about St. Naum');
  });

  testWidgets("the action's payload is the component's, with the component's name, surface and id", (
    tester,
  ) async {
    final harness = await _pumpReply(tester, [_placeCard()]);

    await tester.tap(find.text('Ask'));

    expect(harness.actions.single.payload, {
      'title': 'St. Naum',
      'component': 'place_card',
      'surfaceId': 's',
      'sourceComponentId': 'root',
    });
  });

  testWidgets("a payload entry named component is replaced by the component's name", (tester) async {
    final harness = await _pumpReply(
      tester,
      [_placeCard()],
      components: const [
        _PlaceCard(payload: {'component': 'Button'}),
      ],
    );

    await tester.tap(find.text('Ask'));

    expect(harness.actions.single.payload['component'], 'place_card');
  });

  testWidgets('an action the agent writes on the component sends nothing of its own', (tester) async {
    final harness = await _pumpReply(tester, [
      {
        ..._placeCard(),
        'action': {
          'event': {'name': 'book'},
        },
      },
    ]);

    await tester.tap(find.text('Place: St. Naum'));

    expect(harness.actions, isEmpty);
  });

  testWidgets('a type the host has no component for is reported as unknown, and the rest shows', (tester) async {
    final harness = await _pumpReply(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['card', 'map'],
        },
        {..._placeCard(), 'id': 'card'},
        {'id': 'map', 'component': 'TripMap'},
      ],
    );

    expect(find.text('Place: St. Naum'), findsOneWidget);
    expect(harness.errors.single.$1.message, contains("'TripMap'"));
  });

  testWidgets('an app component named like a basic one never replaces it', (tester) async {
    final reports = _captureReports();
    final harness = await _pumpReply(
      tester,
      [
        {'id': 'root', 'component': 'Card', 'child': 'text'},
        {'id': 'text', 'component': 'Text', 'text': 'Inside the card'},
      ],
      components: const [_PlaceCard(componentName: 'card')],
    );

    reports.stop();
    expect(find.text('Inside the card'), findsOneWidget);
    expect(find.text('Ask'), findsNothing);
    expect(harness.errors, isEmpty);
  });

  testWidgets('a component left out of the catalog is reported in debug builds, not to onError', (tester) async {
    final reports = _captureReports();

    final harness = await _pumpReply(
      tester,
      [_placeCard()],
      components: const [
        _PlaceCard(),
        _PlaceCard(componentName: 'card'),
      ],
    );

    expect(reports.stop().single, contains("The app's component 'card' can't be placed"));
    expect(harness.errors, isEmpty);
  });

  testWidgets("the agent's accessibility label is read for the component", (tester) async {
    final semantics = tester.ensureSemantics();

    await _pumpReply(tester, [
      {
        ..._placeCard(),
        'accessibility': {'label': 'A monastery by the lake'},
      },
    ]);

    expect(find.bySemanticsLabel(RegExp('A monastery by the lake')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a weight gives the component its share of a row', (tester) async {
    await _pumpReply(tester, [
      {
        'id': 'root',
        'component': 'Row',
        'children': ['card', 'other'],
      },
      {..._placeCard(), 'id': 'card', 'weight': 3},
      {'id': 'other', 'component': 'Text', 'text': 'x', 'weight': 1},
    ]);

    final row = tester.getRect(find.byType(AIUIView));
    final other = tester.getTopLeft(find.text('x'));
    // Within the space between the row's children.
    expect(other.dx - row.left, moreOrLessEquals(row.width * 3 / 4, epsilon: 8));
  });
}

// Shows a reply whose surface `s` has [components], from [catalogId], with
// [data], through a host with the app's [components].
Future<ReplyHarness> _pumpReply(
  WidgetTester tester,
  List<Map<String, Object?>> surfaceComponents, {
  Object? catalogId = A2UIRenderer.defaultCatalogId,
  Map<String, Object?> data = const {},
  bool isStreaming = false,
  List<AIUIComponent<Object?>> components = const [_PlaceCard()],
  A2UIRenderer Function(A2UIErrorHandler onError)? renderer,
}) {
  return _pumpMessages(
    tester,
    [_surface(surfaceComponents, catalogId: catalogId, data: data)],
    isStreaming: isStreaming,
    components: components,
    renderer: renderer,
  );
}

Future<ReplyHarness> _pumpMessages(
  WidgetTester tester,
  List<String> messages, {
  bool isStreaming = false,
  List<AIUIComponent<Object?>> components = const [_PlaceCard()],
  A2UIRenderer Function(A2UIErrorHandler onError)? renderer,
}) {
  return pumpReplies(
    tester,
    [TestReply('m1', a2uiDocument(messages, isStreaming: isStreaming))],
    components: components,
    renderer: renderer,
  );
}

// The message that creates surface `s` with [components] and [data], naming
// [catalogId], or no catalog when it is `null`.
String _surface(
  List<Map<String, Object?>> components, {
  Object? catalogId = A2UIRenderer.defaultCatalogId,
  Map<String, Object?> data = const {},
}) {
  return jsonEncode({
    'version': '1.0',
    'createSurface': {
      'surfaceId': 's',
      'catalogId': ?catalogId,
      'dataModel': data,
      'components': components,
    },
  });
}

// The agent's `PlaceCard`, the root of its surface.
Map<String, Object?> _placeCard({Object? title = 'St. Naum', Object? note}) {
  return {'id': 'root', 'component': 'PlaceCard', 'title': title, 'note': ?note};
}

// What is reported to [FlutterError.onError] and printed in debug builds,
// until the test calls [_Reports.stop], which it does before it checks them.
_Reports _captureReports() {
  final reports = _Reports(FlutterError.onError, debugPrint);
  FlutterError.onError = (details) => reports.messages.add(details.exceptionAsString());
  debugPrint = (message, {wrapWidth}) {
    if (message != null) reports.messages.add(message);
  };
  addTearDown(reports.stop);
  return reports;
}

final class _Reports {
  _Reports(this._onError, this._debugPrint);

  final FlutterExceptionHandler? _onError;
  final DebugPrintCallback _debugPrint;
  final messages = <String>[];

  // Stops capturing, giving the test framework its handlers back.
  List<String> stop() {
    FlutterError.onError = _onError;
    debugPrint = _debugPrint;
    return messages;
  }
}

// A place: its title, an optional note, and a button that asks about it.
final class _PlaceCard extends AIUIComponent<({String title, String? note})> {
  const _PlaceCard({this.componentName = 'place_card', this.payload, this.noteType = AIUIParameterType.string});

  final String componentName;
  final AIUIParameterType noteType;
  final Map<String, Object?>? payload;

  @override
  AIUIComponentDefinition get definition => AIUIComponentDefinition(
    name: componentName,
    description: 'A place on the trip.',
    parameters: [
      const AIUIParameter.required('title', AIUIParameterType.string),
      AIUIParameter.optional('note', noteType),
    ],
    events: const [AIUIComponentEvent(name: 'ask_about', description: 'The person asks about the place.')],
  );

  @override
  ({String title, String? note}) readArguments(AIUIArguments arguments) =>
      (title: arguments.string('title'), note: arguments.optional('note', arguments.string));

  @override
  Widget build(BuildContext context, ({String title, String? note}) arguments, AIUIComponentContext ui) {
    return Column(
      key: const ValueKey('place-card'),
      children: [
        Text('Place: ${arguments.title}'),
        if (arguments.note case final note?) Text('Note: $note'),
        TextButton(
          onPressed: () => ui.emit(
            'ask_about',
            label: 'Tell me about ${arguments.title}',
            payload: payload ?? {'title': arguments.title},
          ),
          child: const Text('Ask'),
        ),
      ],
    );
  }
}

// A `place_card` that records the values it is given each time it builds.
final class _RecordingComponent extends AIUIComponent<Object?> {
  const _RecordingComponent(this.seen);

  final List<Map<String, Object?>> seen;

  @override
  AIUIComponentDefinition get definition => const _PlaceCard().definition;

  @override
  Object? readArguments(AIUIArguments arguments) {
    seen.add(arguments.json);
    return null;
  }

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) => const SizedBox.shrink();
}

// Says whether the agent is still writing the reply, and records what it was
// told each time it builds.
final class _ReplyStatus extends AIUIComponent<Object?> {
  const _ReplyStatus({this.seen});

  final List<bool>? seen;

  @override
  AIUIComponentDefinition get definition =>
      const AIUIComponentDefinition(name: 'reply_status', description: 'Whether the reply is still coming.');

  @override
  Object? readArguments(AIUIArguments arguments) => null;

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) {
    seen?.add(ui.isStreaming);
    return Text(ui.isStreaming ? 'Writing' : 'Done');
  }
}

// A `place_card` that keeps the context of each build, to report events later.
final class _ContextKeeper extends AIUIComponent<Object?> {
  const _ContextKeeper(this.contexts);

  final List<AIUIComponentContext> contexts;

  @override
  AIUIComponentDefinition get definition => const _PlaceCard().definition;

  @override
  Object? readArguments(AIUIArguments arguments) => null;

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) {
    contexts.add(ui);
    return const SizedBox.shrink();
  }
}

// A `place_card` that throws reading its values, or building its widget.
final class _Throwing extends AIUIComponent<Object?> {
  const _Throwing({required this.inRead});

  final bool inRead;

  @override
  AIUIComponentDefinition get definition => const _PlaceCard().definition;

  @override
  Object? readArguments(AIUIArguments arguments) => inRead ? throw StateError('read failed') : null;

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) => throw StateError('build failed');
}
