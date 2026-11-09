import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets("each problem with a reply's A2UI reaches onError with the reply's id", (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_unknown)])),
    ]);

    expect(harness.errors.single.$1.code, A2UIErrorCode.unknownComponentType);
    expect(harness.errors.single.$2, 'm1');
  });

  testWidgets('a component removed from the catalog is reported as one the catalog does not have', (tester) async {
    final harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_video)])),
      ],
      renderer: (onError) => A2UIRenderer(catalog: A2UICatalog.basic.removing(['Video']), onError: onError),
    );

    expect(harness.errors.single.$1.code, A2UIErrorCode.unknownComponentType);
    expect(harness.errors.single.$1.message, contains('Video'));
  });

  testWidgets('a component of the catalog is not reported', (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_video)])),
    ]);

    expect(harness.errors, isEmpty);
  });

  testWidgets('a problem found again reaches onError once', (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([_versioned('0.8'), _versioned('0.8')])),
    ]);

    expect(harness.errors, hasLength(1));
  });

  testWidgets('a problem is reported again once its reply starts over', (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([_versioned('0.8'), surfaceMessage(_text)], isStreaming: true)),
    ]);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([_versioned('0.8'), surfaceMessage(_shown('Changed'))])),
    ]);

    expect(harness.errors, hasLength(2));
  });

  testWidgets('onError is never called while the screen builds', (tester) async {
    final phases = <SchedulerPhase>[];
    await pumpReplies(
      tester,
      // A message of another version is reported as it is applied, while the
      // reply's view builds.
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_text).replaceFirst('"1.0"', '"0.9"')])),
      ],
      renderer: (_) => A2UIRenderer(onError: (_, _) => phases.add(SchedulerBinding.instance.schedulerPhase)),
    );

    expect(phases, [isNot(anyOf(SchedulerPhase.persistentCallbacks, SchedulerPhase.midFrameMicrotasks))]);
  });

  testWidgets('an onError that throws once still gets the problems after it', (tester) async {
    final seen = <A2UIError>[];
    final reports = _captureReports();
    await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([_versioned('0.8'), _versioned('0.7')])),
      ],
      renderer: (_) => A2UIRenderer(
        onError: (error, _) {
          seen.add(error);
          if (seen.length == 1) throw StateError('The app failed.');
        },
      ),
    );

    reports.stop();
    expect(seen, hasLength(2));
    expect(reports.list.single.exception, isA<StateError>());
  });

  testWidgets('an onError that throws while a reply applies outside a build stops none of its messages', (
    tester,
  ) async {
    final reports = _captureReports();
    final first = surfaceMessage(_text);
    final harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([first], isStreaming: true)),
      ],
      renderer: (_) => A2UIRenderer(onError: (_, _) => throw StateError('The app failed.')),
    );

    harness.host.receive([
      TestReply('m1', a2uiDocument([first, _versioned('0.8'), surfaceMessage(_shown('Later'), surfaceId: 'later')])),
    ]);
    await tester.pump();

    reports.stop();
    expect(find.text('Later'), findsOneWidget);
    expect(reports.list.single.exception, isA<StateError>());
  });

  testWidgets('an onError that removes its reply gets no more of its problems', (tester) async {
    final seen = <A2UIError>[];
    final document = a2uiDocument([_versioned('0.8'), _versioned('0.7')]);
    late final AIUIHost host;
    host = AIUIHost(
      renderers: [
        A2UIRenderer(
          onError: (error, _) {
            seen.add(error);
            host.receive(const []);
          },
        ),
      ],
      send: (_) async {},
    );
    addTearDown(host.dispose);
    host.receive([TestReply('m1', document)]);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => AIUIView(host: host, document: document, messageId: 'm1'),
        ),
      ),
    );

    expect(seen, hasLength(1));
  });

  testWidgets("an onError that removes its reply stops the reply's tools from running", (tester) async {
    final city = TestTool('city', output: 'Ohrid');
    final cityText = surfaceMessage([
      {
        'id': 'root',
        'component': 'Text',
        'text': {'@call': 'city', 'args': <String, Object?>{}},
      },
    ], surfaceId: 'city');
    final document = a2uiDocument([_versioned('0.8'), cityText]);
    late final AIUIHost host;
    host = AIUIHost(
      renderers: [A2UIRenderer(onError: (_, _) => host.receive(const []))],
      tools: [city],
      send: (_) async {},
    );
    addTearDown(host.dispose);
    host.receive([TestReply('m1', document)]);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => AIUIView(host: host, document: document, messageId: 'm1'),
        ),
      ),
    );

    expect(city.runs, isEmpty);
  });

  testWidgets('an onError that removes its reply while it finishes applying throws nothing', (tester) async {
    late final ReplyHarness harness;
    harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_text)], isStreaming: true)),
      ],
      renderer: (_) => A2UIRenderer(onError: (_, _) => harness.host.receive(const [])),
    );

    // Outside a build, so the problem reaches onError while the reply applies.
    harness.host.receive([
      TestReply('m1', a2uiDocument([surfaceMessage(_text), _versioned('0.8')])),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a reply the host receives again from onError applies its messages in order', (tester) async {
    late final ReplyHarness harness;
    final first = surfaceMessage(_text);
    final create = surfaceMessage(_text, surfaceId: 'late');
    final grown = [first, _versioned('0.8'), create, componentsMessage(_shown('Arrived'), surfaceId: 'late')];
    var receivedAgain = false;
    harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([first], isStreaming: true)),
      ],
      renderer: (_) => A2UIRenderer(
        onError: (_, _) {
          if (receivedAgain) return;
          receivedAgain = true;
          harness.host.receive([TestReply('m1', a2uiDocument(grown, isStreaming: true))]);
        },
      ),
    );

    // Outside a build, so the version problem reaches onError while the
    // messages before the last one apply.
    harness.host.receive([
      TestReply('m1', a2uiDocument([first, _versioned('0.8'), create], isStreaming: true)),
    ]);
    await tester.pump();

    expect(find.text('Arrived'), findsOneWidget);
  });

  testWidgets('without onError, a problem is reported to FlutterError.onError', (tester) async {
    final (reported, _) = await _reportsOf(tester, a2uiDocument([surfaceMessage(_unknown)]), onError: false);

    expect(reported.single.exception, isA<A2UIError>());
  });

  testWidgets("a message that isn't JSON is reported in debug builds", (tester) async {
    final document = a2uiDocument(['{not json}', surfaceMessage(_text)]);
    final (reported, _) = await _reportsOf(tester, document, onError: true);

    expect(reported.single.exception, contains("isn't a JSON object"));
  });

  testWidgets("a message that isn't JSON never reaches onError", (tester) async {
    final document = a2uiDocument(['{not json}', surfaceMessage(_text)]);
    final (_, handled) = await _reportsOf(tester, document, onError: true);

    expect(handled, isEmpty);
  });
}

final _unknown = [
  {'id': 'root', 'component': 'Gauge'},
];

final _video = [
  {'id': 'root', 'component': 'Video', 'url': 'https://example.com/clip.mp4'},
];

final _text = [
  {'id': 'root', 'component': 'Text', 'text': 'Hello'},
];

// What reaches [FlutterError.onError] while [document] shows, and what
// reaches the renderer's onError when it has one.
Future<(List<FlutterErrorDetails>, List<A2UIError>)> _reportsOf(
  WidgetTester tester,
  AIUIDocument document, {
  required bool onError,
}) async {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = previous);
  final handled = <A2UIError>[];
  await pumpReplies(
    tester,
    [TestReply('m1', document)],
    renderer: (_) => A2UIRenderer(onError: onError ? (error, _) => handled.add(error) : null),
  );
  FlutterError.onError = previous;
  return (reported, handled);
}

// A message of A2UI [version], which isn't read.
String _versioned(String version) => surfaceMessage(_text).replaceFirst('"1.0"', '"$version"');

// What reaches [FlutterError.onError] from now on. The test calls
// [_Reports.stop] before it asserts, so a failing expectation is reported as
// a failure rather than to the capture.
_Reports _captureReports() {
  final reports = _Reports(FlutterError.onError);
  FlutterError.onError = reports.list.add;
  addTearDown(reports.stop);
  return reports;
}

final class _Reports {
  _Reports(this._previous);

  final FlutterExceptionHandler? _previous;
  final list = <FlutterErrorDetails>[];

  void stop() => FlutterError.onError = _previous;
}

List<Map<String, Object?>> _shown(String text) => [
  {'id': 'root', 'component': 'Text', 'text': text},
];
