import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test('the same problem twice is reported once', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_updateDataModel('missing'), _updateDataModel('missing')]);

    expect(errors, hasLength(1));
  });

  test('two different problems are both reported', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_updateDataModel('missing'), _updateDataModel('other')]);

    expect(errors, hasLength(2));
  });

  test('a problem reported before reset is reported again after it', () {
    final errors = <A2UIError>[];
    _processor(errors: errors)
      ..apply([_updateDataModel('missing')])
      ..reset()
      ..apply([_updateDataModel('missing')]);

    expect(errors, hasLength(2));
  });

  test("a component's problem isn't reported while apply runs", () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_createSurface('plan'), _components('plan', type: 'TripMap')]);

    expect(errors, isEmpty);
  });

  test("a component's problem is reported soon after apply", () async {
    final reported = Completer<A2UIError>();
    _processor(onError: reported.complete).apply([_createSurface('plan'), _components('plan', type: 'TripMap')]);

    expect((await reported.future).code, A2UIErrorCode.unknownComponentType);
  });

  test("a component's problem names its surface", () async {
    final reported = Completer<A2UIError>();
    _processor(onError: reported.complete).apply([_createSurface('plan'), _components('plan', type: 'TripMap')]);

    expect((await reported.future).surfaceId, 'plan');
  });

  test("a component's problem found after the processor is disposed isn't reported", () async {
    final errors = <A2UIError>[];
    A2UIProcessor(catalogs: A2UICatalogs(), onError: errors.add)
      ..apply([_createSurface('plan'), _components('plan', type: 'TripMap')])
      ..dispose();
    // There is no event to wait for: the problem would be reported in a
    // microtask, which this lets run.
    await pumpEventQueue();

    expect(errors, isEmpty);
  });

  test("a component's problem found after the processor is reset isn't reported", () async {
    final errors = <A2UIError>[];
    _processor(errors: errors)
      ..apply([_createSurface('plan'), _components('plan', type: 'TripMap')])
      ..reset();
    // There is no event to wait for: the problem would be reported in a
    // microtask, which this lets run.
    await pumpEventQueue();

    expect(errors, isEmpty);
  });

  // The core tells these apart from other integrity errors of its topology
  // checks only by their words, so a core that rewords them fails here.
  test('a component that holds itself is a recursion problem', () {
    final errors = <A2UIError>[];
    _checkedProcessor(errors).apply([
      _createSurface('plan'),
      _componentList('plan', [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['root'],
        },
      ]),
    ]);

    expect(errors.single.code, A2UIErrorCode.recursionLimitExceeded);
  });

  test('components that hold each other are a recursion problem', () {
    final errors = <A2UIError>[];
    _checkedProcessor(errors).apply([
      _createSurface('plan'),
      _componentList('plan', [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['card'],
        },
        {'id': 'card', 'component': 'Card', 'child': 'root'},
      ]),
    ]);

    expect(errors.single.code, A2UIErrorCode.recursionLimitExceeded);
  });
}

String _componentList(String surfaceId, List<Map<String, Object?>> components) => jsonEncode({
  'version': '1.0',
  'updateComponents': {'surfaceId': surfaceId, 'components': components},
});

String _createSurface(String surfaceId) => jsonEncode({
  'version': '1.0',
  'createSurface': {'surfaceId': surfaceId, 'catalogId': A2UICatalogs.defaultCatalogId},
});

String _components(String surfaceId, {required String type}) => jsonEncode({
  'version': '1.0',
  'updateComponents': {
    'surfaceId': surfaceId,
    'components': [
      {'id': 'root', 'component': type},
    ],
  },
});

String _updateDataModel(String surfaceId) => jsonEncode({
  'version': '1.0',
  'updateDataModel': {'surfaceId': surfaceId, 'path': '/title', 'value': 'Ohrid'},
});

A2UIProcessor _processor({List<A2UIError>? errors, A2UIErrorCallback? onError}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: onError ?? errors?.add);
  addTearDown(processor.dispose);
  return processor;
}

// A processor that checks the topology of each message, as a conformance case
// asks.
A2UIProcessor _checkedProcessor(List<A2UIError> errors) {
  final processor = A2UIProcessor.debug(catalogs: A2UICatalogs(), checks: const A2UIDebugChecks(), onError: errors.add);
  addTearDown(processor.dispose);
  return processor;
}
