import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test('apply creates the surface a createSurface message names', () {
    final processor = _processor()..apply([_createSurface('plan')]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('apply applies messages in order', () {
    final processor = _processor()..apply([_createSurface('plan'), _deleteSurface('plan'), _createSurface('next')]);

    expect(processor.surfaceIds, ['next']);
  });

  test("apply skips a message that isn't JSON and applies the next", () {
    final processor = _processor()..apply(['{curly}', _createSurface('plan')]);

    expect(processor.surfaceIds, ['plan']);
  });

  test("apply doesn't report a message that isn't JSON", () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply(['{curly}']);

    expect(errors, isEmpty);
  });

  test("apply tells onUnreadable about a message that isn't JSON", () {
    var unreadable = 0;
    _processor(onUnreadable: () => unreadable += 1).apply(['{curly}', _createSurface('plan')]);

    expect(unreadable, 1);
  });

  test("apply tells onUnreadable about JSON that isn't an object", () {
    var unreadable = 0;
    _processor(onUnreadable: () => unreadable += 1).apply(['[1, 2]']);

    expect(unreadable, 1);
  });

  test('apply applies each message of a batch', () {
    final processor = _processor()
      ..apply([
        jsonEncode({
          'messages': [jsonDecode(_createSurface('plan')), jsonDecode(_createSurface('next'))],
        }),
      ]);

    expect(processor.surfaceIds, ['plan', 'next']);
  });

  test("apply reports a batch item that isn't an object", () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([
      jsonEncode({
        'messages': ['text', jsonDecode(_createSurface('plan'))],
      }),
    ]);

    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  test("apply applies the rest of a batch after an item that isn't an object", () {
    final processor = _processor()
      ..apply([
        jsonEncode({
          'messages': ['text', jsonDecode(_createSurface('plan'))],
        }),
      ]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('apply reads a message whose version is spelled v1.0', () {
    final processor = _processor()..apply([_createSurface('plan', version: 'v1.0')]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('apply reads the spelled versions of the messages in a batch', () {
    final processor = _processor()
      ..apply([
        jsonEncode({
          'messages': [jsonDecode(_createSurface('plan', version: 'v1'))],
        }),
      ]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('apply reports a message of version v0.9', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_createSurface('plan', version: 'v0.9')]);

    expect(errors.single.path, '/version');
  });

  test('apply applies nothing of a message of version v0.9', () {
    final processor = _processor()..apply([_createSurface('plan', version: 'v0.9')]);

    expect(processor.surfaceIds, isEmpty);
  });

  test("apply reports an update for a surface that doesn't exist", () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_updateDataModel('plan')]);

    expect(errors.single.code, A2UIErrorCode.integrityError);
  });

  test("apply gives an update for a surface that doesn't exist that surface's id", () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_updateDataModel('plan')]);

    expect(errors.single.surfaceId, 'plan');
  });

  test('apply reports a second createSurface for the same surface', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_createSurface('plan'), _createSurface('plan')]);

    expect(errors.single.code, A2UIErrorCode.integrityError);
  });

  test("apply reports a surface naming a catalog it doesn't have", () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_createSurface('plan', catalogId: 'unknown')]);

    expect(errors.single.code, A2UIErrorCode.catalogNotFound);
  });

  test('apply creates a surface naming the basic catalog', () {
    final processor = _processor()..apply([_createSurface('plan', catalogId: A2UICatalogs.basicCatalogId)]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('apply keeps applying after a message it reports', () {
    final processor = _processor()..apply([_updateDataModel('missing'), _createSurface('plan')]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('a surface that names no catalog is drawn from the app catalog', () {
    final processor = _processor()
      ..apply([
        jsonEncode({
          'version': '1.0',
          'createSurface': {
            'surfaceId': 'plan',
            'components': [
              {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
            ],
          },
        }),
      ]);

    expect(processor.surface('plan')!.root!.isResolved, isTrue);
  });

  test('a surface whose catalog is null is drawn from the app catalog', () {
    final processor = _processor()
      ..apply([
        jsonEncode({
          'version': '1.0',
          'createSurface': {
            'surfaceId': 'plan',
            'catalogId': null,
            'components': [
              {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
            ],
          },
        }),
      ]);

    expect(processor.surface('plan')!.root!.isResolved, isTrue);
  });

  test('apply reports a batch item that is not an object for the whole message', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([
      jsonEncode({
        'messages': ['text'],
      }),
    ]);

    expect(errors.single.path, '');
  });

  test('apply reports a message that holds a messages list beside its message key', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([
      jsonEncode({
        'version': '1.0',
        'createSurface': {'surfaceId': 'plan', 'catalogId': A2UICatalogs.defaultCatalogId},
        'messages': <Object?>[],
      }),
    ]);

    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  test('apply reports a malformed function call from the agent as INVALID_FUNCTION_CALL', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_callRendererFunctionWithoutCall()]);

    expect(errors.single.code, A2UIErrorCode.invalidFunctionCall);
  });

  test('a malformed function call from the agent names no surface', () {
    final errors = <A2UIError>[];
    _processor(errors: errors).apply([_callRendererFunctionWithoutCall()]);

    expect(errors.single.surfaceId, isNull);
  });
}

String _callRendererFunctionWithoutCall() => jsonEncode({
  'version': '1.0',
  'callRendererFunction': {'functionCallId': 'call-1'},
});

String _createSurface(String surfaceId, {String version = '1.0', String catalogId = A2UICatalogs.defaultCatalogId}) =>
    jsonEncode({
      'version': version,
      'createSurface': {'surfaceId': surfaceId, 'catalogId': catalogId},
    });

String _deleteSurface(String surfaceId) => jsonEncode({
  'version': '1.0',
  'deleteSurface': {'surfaceId': surfaceId},
});

String _updateDataModel(String surfaceId) => jsonEncode({
  'version': '1.0',
  'updateDataModel': {'surfaceId': surfaceId, 'path': '/title', 'value': 'Ohrid'},
});

A2UIProcessor _processor({List<A2UIError>? errors, void Function()? onUnreadable}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors?.add, onUnreadable: onUnreadable);
  addTearDown(processor.dispose);
  return processor;
}
