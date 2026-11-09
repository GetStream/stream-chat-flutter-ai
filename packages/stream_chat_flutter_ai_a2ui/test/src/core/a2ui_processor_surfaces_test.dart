import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test('surfaceIds lists the surfaces in the order they were created', () {
    final processor = _processor()..apply([_createSurface('b'), _createSurface('a')]);

    expect(processor.surfaceIds, ['b', 'a']);
  });

  test('a deleteSurface message removes the surface', () {
    final processor = _processor()
      ..apply([_createSurface('plan')])
      ..apply([_deleteSurface('plan')]);

    expect(processor.surface('plan'), isNull);
  });

  test("surface returns null for an id the processor doesn't have", () {
    final processor = _processor()..apply([_createSurface('plan')]);

    expect(processor.surface('other'), isNull);
  });

  test('surface returns the surface with the id', () {
    final processor = _processor()..apply([_createSurface('plan')]);

    expect(processor.surface('plan')!.id, 'plan');
  });

  test('apply notifies once when it creates surfaces', () {
    final processor = _processor();
    var notified = 0;
    processor
      ..addListener(() => notified += 1)
      ..apply([_createSurface('a'), _createSurface('b')]);

    expect(notified, 1);
  });

  test("apply doesn't notify when the surfaces stay the same", () {
    final processor = _processor()..apply([_createSurface('plan')]);
    var notified = 0;
    processor
      ..addListener(() => notified += 1)
      ..apply([_updateDataModel('plan')]);

    expect(notified, 0);
  });

  test('apply notifies when it deletes a surface', () {
    final processor = _processor()..apply([_createSurface('plan')]);
    var notified = 0;
    processor
      ..addListener(() => notified += 1)
      ..apply([_deleteSurface('plan')]);

    expect(notified, 1);
  });

  test('apply notifies when a surface is deleted and created again under its id', () {
    final processor = _processor()..apply([_createSurface('plan')]);
    var notified = 0;
    processor
      ..addListener(() => notified += 1)
      ..apply([_deleteSurface('plan'), _createSurface('plan')]);

    expect(notified, 1);
  });

  test('a surface deleted and created again under its id is a new surface', () {
    final processor = _processor()..apply([_createSurface('plan')]);
    final before = processor.surface('plan');

    processor.apply([_deleteSurface('plan'), _createSurface('plan')]);

    expect(processor.surface('plan'), isNot(same(before)));
  });
}

String _createSurface(String surfaceId) => jsonEncode({
  'version': '1.0',
  'createSurface': {'surfaceId': surfaceId, 'catalogId': A2UICatalogs.defaultCatalogId},
});

String _deleteSurface(String surfaceId) => jsonEncode({
  'version': '1.0',
  'deleteSurface': {'surfaceId': surfaceId},
});

String _updateDataModel(String surfaceId) => jsonEncode({
  'version': '1.0',
  'updateDataModel': {'surfaceId': surfaceId, 'path': '/title', 'value': 'Ohrid'},
});

A2UIProcessor _processor() {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  return processor;
}
