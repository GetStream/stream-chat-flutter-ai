import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_stream.dart';

// The Ohrid weekend example an agent is shown when it learns to write A2UI:
// seven messages, one per line, creating the surface `ohrid-weekend` in the
// app's catalog and placing the app's own TripMap, CalendarCheck and PlaceCard
// components, which this package's catalog doesn't have yet.
void main() {
  test('the example has seven messages', () {
    expect(A2UIStream.messages(_example()), hasLength(7));
  });

  test('the first line creates the ohrid-weekend surface', () {
    final processor = _processor()..apply(A2UIStream.messages(_prefix(lines: 1)));

    expect(processor.surfaceIds, ['ohrid-weekend']);
  });

  test("the example reports only the app's components the catalog doesn't have", () async {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply(A2UIStream.messages(_example()));
    // Problems in components are reported in microtasks after apply, as the
    // tree is resolved; this lets them run.
    await pumpEventQueue();

    expect({for (final error in errors) error.code}, {A2UIErrorCode.unknownComponentType});
  });

  test('the second line cut in half applies only the first line', () {
    final text = _example();
    final secondLineStart = text.indexOf('\n') + 1;
    final secondLineEnd = text.indexOf('\n', secondLineStart);
    final half = secondLineStart + (secondLineEnd - secondLineStart) ~/ 2;
    final processor = _processor()..apply(A2UIStream.messages(text.substring(0, half)));

    expect(processor.surface('ohrid-weekend')!.root, isNull);
  });

  test('every prefix of the example gives the first of its messages', () {
    final text = _example();
    final all = A2UIStream.messages(text);
    final notAPrefix = [
      for (var end = 0; end <= text.length; end += 1)
        if (A2UIStream.added(all, applied: A2UIStream.messages(text.substring(0, end))) == null) end,
    ];

    expect(notAPrefix, isEmpty);
  });

  test('the data model holds the pace the first line gives', () {
    final processor = _processor()..apply(A2UIStream.messages(_prefix(lines: 1)));

    expect(processor.surface('ohrid-weekend')!.read('/pace'), ['relaxed']);
  });
}

String _example() => File('test/fixtures/ohrid_prompt_example.jsonl').readAsStringSync();

String _prefix({required int lines}) => _example().split('\n').take(lines).join('\n');

A2UIProcessor _processor({List<A2UIError>? errors}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors?.add);
  addTearDown(processor.dispose);
  return processor;
}
