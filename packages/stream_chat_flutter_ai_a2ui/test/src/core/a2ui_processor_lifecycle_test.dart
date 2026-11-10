import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test('reset removes every surface', () {
    final processor = _processor()
      ..apply([_createSurface('plan')])
      ..reset();

    expect(processor.surfaceIds, isEmpty);
  });

  test('reset notifies when there were surfaces', () {
    final processor = _processor()..apply([_createSurface('plan')]);
    var notified = 0;
    processor
      ..addListener(() => notified += 1)
      ..reset();

    expect(notified, 1);
  });

  test("reset doesn't notify when there were no surfaces", () {
    final processor = _processor();
    var notified = 0;
    processor
      ..addListener(() => notified += 1)
      ..reset();

    expect(notified, 0);
  });

  test('messages apply again after reset', () {
    final processor = _processor()
      ..apply([_createSurface('plan')])
      ..reset()
      ..apply([_createSurface('plan')]);

    expect(processor.surfaceIds, ['plan']);
  });

  test('reset disposes the surfaces it removes', () {
    final processor = _processor()..apply([_createSurface('plan')]);
    final surface = processor.surface('plan')!;

    processor.reset();

    expect(() => surface.addListener(() {}), throwsFlutterError);
  });

  test('dispose disposes the surfaces', () {
    final processor = A2UIProcessor(catalogs: A2UICatalogs())..apply([_createSurface('plan')]);
    final surface = processor.surface('plan')!;

    processor.dispose();

    expect(() => surface.addListener(() {}), throwsFlutterError);
  });

  test('a deleted surface is disposed', () {
    final processor = _processor()..apply([_createSurface('plan')]);
    final surface = processor.surface('plan')!;

    processor.apply([_deleteSurface('plan')]);

    expect(() => surface.addListener(() {}), throwsFlutterError);
  });

  test('apply calls nothing more once a callback disposed the processor', () {
    var unreadable = 0;
    _disposedOnError(onUnreadable: () => unreadable += 1).apply([_deleteSurface('plan', version: '0.9'), '{curly}']);

    expect(unreadable, 0);
  });

  test('apply after dispose is a mistake the processor asserts on', () {
    final processor = A2UIProcessor(catalogs: A2UICatalogs())..dispose();

    expect(() => processor.apply([_createSurface('plan')]), throwsAssertionError);
  });
}

String _createSurface(String surfaceId) => jsonEncode({
  'version': '1.0',
  'createSurface': {'surfaceId': surfaceId, 'catalogId': A2UICatalogs.defaultCatalogId},
});

String _deleteSurface(String surfaceId, {String version = '1.0'}) => jsonEncode({
  'version': version,
  'deleteSurface': {'surfaceId': surfaceId},
});

// A processor that disposes itself when it reports a problem, and is disposed
// when the test ends if it never does.
A2UIProcessor _disposedOnError({VoidCallback? onUnreadable}) {
  A2UIProcessor? processor;
  var disposed = false;
  void disposeOnce() {
    if (disposed) return;
    disposed = true;
    processor?.dispose();
  }

  final created = A2UIProcessor(catalogs: A2UICatalogs(), onError: (_) => disposeOnce(), onUnreadable: onUnreadable);
  processor = created;
  addTearDown(disposeOnce);
  return created;
}

A2UIProcessor _processor() {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  return processor;
}
