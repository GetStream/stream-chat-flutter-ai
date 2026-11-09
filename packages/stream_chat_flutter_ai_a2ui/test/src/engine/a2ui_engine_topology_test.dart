import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets('a finished reply whose component names a missing child is reported', (tester) async {
    final problems = await _problemsOf(tester, [
      _column(['missing']),
    ]);

    expect(problems.single.message, contains("references non-existent component 'missing' in field 'children[0]'"));
  });

  testWidgets('a finished reply without a root component is reported', (tester) async {
    final problems = await _problemsOf(tester, [_textComponent('intro')]);

    expect(problems.single.message, contains("has no component with id 'root'"));
  });

  testWidgets('a finished reply whose component holds itself is reported', (tester) async {
    final problems = await _problemsOf(tester, [
      _column(['root']),
    ]);

    expect(problems.single.message, contains("component 'root' refers to itself"));
  });

  testWidgets('a finished reply whose components hold each other is reported', (tester) async {
    final problems = await _problemsOf(tester, [
      _column(['a']),
      {
        'id': 'a',
        'component': 'Card',
        'child': 'b',
      },
      {
        'id': 'b',
        'component': 'Card',
        'child': 'a',
      },
    ]);

    expect(problems.map((problem) => problem.message), contains('Circular reference detected: a -> b -> a.'));
  });

  testWidgets("a component the root doesn't reach isn't reported", (tester) async {
    final problems = await _problemsOf(tester, [
      _column(['intro']),
      _textComponent('intro'),
      _textComponent('left'),
    ]);

    expect(problems, isEmpty);
  });

  testWidgets("a deep tree that shows isn't reported when its reply finishes", (tester) async {
    // The root and 50 levels below it, the deepest a surface builds.
    final problems = await _problemsOf(tester, [
      for (var level = 0; level <= 50; level += 1)
        {'id': level == 0 ? 'root' : 'c$level', 'component': 'Card', if (level < 50) 'child': 'c${level + 1}'},
    ]);

    expect(problems, isEmpty);
  });

  testWidgets('a finished reply shown again is not checked again', (tester) async {
    final reports = _captureReports();
    final reply = TestReply(
      'm1',
      a2uiDocument([
        surfaceMessage([
          _column(['missing']),
        ]),
      ]),
    );
    final harness = await pumpReplies(tester, [reply]);

    await showReplies(tester, harness, [reply]);

    reports.stop();
    expect(reports.list, hasLength(1));
  });

  testWidgets('a finished reply is checked again when it grows', (tester) async {
    final reports = _captureReports();
    final first = surfaceMessage([_textComponent('root')]);
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([first])),
    ]);

    await showReplies(tester, harness, [
      TestReply(
        'm1',
        a2uiDocument([
          first,
          componentsMessage([
            _column(['missing']),
          ]),
        ]),
      ),
    ]);

    reports.stop();
    expect(reports.list, hasLength(1));
  });

  testWidgets("a streaming reply's components aren't checked", (tester) async {
    final problems = await _problemsOf(tester, [
      _column(['missing']),
    ], isStreaming: true);

    expect(problems, isEmpty);
  });

  testWidgets('a reply is checked once it finishes', (tester) async {
    final reports = _captureReports();
    final message = surfaceMessage([
      _column(['missing']),
    ]);
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([message], isStreaming: true)),
    ]);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([message])),
    ]);

    reports.stop();
    expect(reports.list, hasLength(1));
  });

  testWidgets("a finished reply's problems never reach onError", (tester) async {
    final reports = _captureReports();
    final harness = await pumpReplies(tester, [
      TestReply(
        'm1',
        a2uiDocument([
          surfaceMessage([
            _column(['missing']),
          ]),
        ]),
      ),
    ]);

    reports.stop();
    expect(harness.errors, isEmpty);
  });
}

Map<String, Object?> _column(List<String> children) => {'id': 'root', 'component': 'Column', 'children': children};

Map<String, Object?> _textComponent(String id) => {'id': id, 'component': 'Text', 'text': id};

// The problems reported in debug builds while a reply of [components] shows.
Future<List<A2UIError>> _problemsOf(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  bool isStreaming = false,
}) async {
  final reports = _captureReports();
  await pumpReplies(tester, [
    TestReply('m1', a2uiDocument([surfaceMessage(components)], isStreaming: isStreaming)),
  ]);
  reports.stop();
  return [
    for (final details in reports.list)
      if (details.exception case final A2UIError error) error,
  ];
}

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
