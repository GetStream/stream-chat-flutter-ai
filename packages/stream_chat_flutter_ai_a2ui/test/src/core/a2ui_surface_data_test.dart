import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test('read of / gives the whole data model', () {
    final surface = _surface(data: {'title': 'Ohrid'});

    expect(surface.read('/'), {'title': 'Ohrid'});
  });

  test('read gives the value at a path', () {
    final surface = _surface(
      data: {
        'trip': {'title': 'Ohrid'},
      },
    );

    expect(surface.read('/trip/title'), 'Ohrid');
  });

  test('read of a missing path gives null', () {
    final surface = _surface(data: {'title': 'Ohrid'});

    expect(surface.read('/other'), isNull);
  });

  test('a value read is a copy that cannot be changed', () {
    final surface = _surface(
      data: {
        'pace': ['relaxed'],
      },
    );

    final pace = surface.read('/pace')! as List<Object?>;

    expect(() => pace.add('packed'), throwsUnsupportedError);
  });

  test('write changes what read gives', () {
    final surface = _surface(data: {'title': 'Ohrid'})..write('/title', 'Struga');

    expect(surface.read('/title'), 'Struga');
  });

  test('write of null removes the value', () {
    final surface = _surface(data: {'title': 'Ohrid'})..write('/title', null);

    expect(surface.read('/'), isEmpty);
  });

  test("write reports a path that can't be written", () {
    final errors = <A2UIError>[];
    _surface(data: {'title': 'Ohrid'}, errors: errors).write('/title/first', 'Struga');

    expect(errors.single.surfaceId, 'plan');
  });

  test("write changes nothing at a path that can't be written", () {
    final surface = _surface(data: {'title': 'Ohrid'})..write('/title/first', 'Struga');

    expect(surface.read('/'), {'title': 'Ohrid'});
  });

  test("read reports a path that can't be read", () {
    final errors = <A2UIError>[];
    _surface(data: {'title': 'Ohrid'}, errors: errors).read('/title/~2');

    expect(errors.single.code, A2UIErrorCode.dataError);
  });

  test("read gives null for a path that can't be read", () {
    final surface = _surface(data: {'title': 'Ohrid'});

    expect(surface.read('/title/~2'), isNull);
  });

  test('write of null makes an item of a list null', () {
    final surface = _surface(
      data: {
        'pace': ['relaxed', 'packed'],
      },
    )..write('/pace/0', null);

    expect(surface.read('/pace'), [null, 'packed']);
  });

  test('read gives null once the surface is deleted', () {
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      _create(data: {'title': 'Ohrid'}),
    ]);
    final surface = processor.surface('plan')!;

    processor.apply([_delete()]);

    expect(surface.read('/title'), isNull);
  });

  test('sendDataModel is true when the agent asks for the data model', () {
    final surface = _surface(sendDataModel: true);

    expect(surface.sendDataModel, isTrue);
  });

  test("sendDataModel is false when the agent doesn't ask", () {
    final surface = _surface();

    expect(surface.sendDataModel, isFalse);
  });
}

String _create({Map<String, Object?> data = const {}}) => jsonEncode({
  'version': '1.0',
  'createSurface': {'surfaceId': 'plan', 'catalogId': A2UICatalogs.defaultCatalogId, 'dataModel': data},
});

String _delete() => jsonEncode({
  'version': '1.0',
  'deleteSurface': {'surfaceId': 'plan'},
});

A2UISurface _surface({Map<String, Object?> data = const {}, bool? sendDataModel, List<A2UIError>? errors}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors?.add);
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {
        'surfaceId': 'plan',
        'catalogId': A2UICatalogs.defaultCatalogId,
        'dataModel': data,
        'sendDataModel': ?sendDataModel,
      },
    }),
  ]);
  return processor.surface('plan')!;
}
