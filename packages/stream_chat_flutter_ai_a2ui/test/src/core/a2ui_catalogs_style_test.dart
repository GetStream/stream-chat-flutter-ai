import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

// A style property takes any value, so a component with one its catalog
// doesn't list still shows.
void main() {
  test('a Text with a variant the catalog does not list is kept', () {
    final root = _rootOf({'id': 'root', 'component': 'Text', 'text': 'Ohrid', 'variant': 'h1'});

    expect(root?.type, 'Text');
  });

  test('a variant the catalog does not list reads as the agent wrote it', () {
    final root = _rootOf({'id': 'root', 'component': 'Text', 'text': 'Ohrid', 'variant': 'h1'});

    expect(root?.property('variant'), 'h1');
  });

  test('a Text with a variant bound to the data model is kept', () {
    final root = _rootOf({
      'id': 'root',
      'component': 'Text',
      'text': 'Ohrid',
      'variant': {'@path': '/style'},
    });

    expect(root?.type, 'Text');
  });

  test('a variant bound to the data model reads the value at its path', () {
    final root = _rootOf({
      'id': 'root',
      'component': 'Text',
      'text': 'Ohrid',
      'variant': {'@path': '/style'},
    });

    expect(root?.property('variant'), 'caption');
  });

  test('a variant bound to the data model is bound', () {
    final root = _rootOf({
      'id': 'root',
      'component': 'Text',
      'text': 'Ohrid',
      'variant': {'@path': '/style'},
    });

    expect(root?.canWrite('variant'), isTrue);
  });

  test('a variant that is not a string is kept as the agent wrote it', () {
    final root = _rootOf({'id': 'root', 'component': 'Text', 'text': 'Ohrid', 'variant': 3});

    expect(root?.property('variant'), 3);
  });

  test('a component with an unlisted style value reports nothing', () {
    final errors = <A2UIError>[];

    _rootOf({'id': 'root', 'component': 'Row', 'children': <String>[], 'justify': 'middle'}, errors: errors);

    expect(errors, isEmpty);
  });

  for (final (type, property) in [
    ('Image', 'fit'),
    ('Image', 'variant'),
    ('Row', 'justify'),
    ('Row', 'align'),
    ('Column', 'justify'),
    ('Column', 'align'),
    ('List', 'direction'),
    ('List', 'align'),
    ('Divider', 'axis'),
  ]) {
    test('a $type with an unlisted $property is kept', () {
      final root = _rootOf({
        'id': 'root',
        'component': type,
        if (type == 'Image') 'url': 'https://example.com/a.png',
        if (type == 'Row' || type == 'Column' || type == 'List') 'children': <String>[],
        property: 'unlisted',
      });

      expect(root?.type, type);
    });
  }

  for (final (type, property, extra) in [
    (
      'Button',
      'variant',
      <String, Object?>{
        'child': 'label',
        'action': {
          'event': {'name': 'go'},
        },
      },
    ),
    ('TextField', 'variant', <String, Object?>{'label': 'Email', 'value': 'a'}),
    ('ChoicePicker', 'displayStyle', <String, Object?>{'options': <Object?>[], 'value': <Object?>[]}),
  ]) {
    test('a $type with a $property that is not a string is kept', () {
      final root = _rootOf({'id': 'root', 'component': type, ...extra, property: 3});

      expect(root?.type, type);
    });
  }

  test('an Icon with a name the catalog does not list is kept', () {
    final root = _rootOf({'id': 'root', 'component': 'Icon', 'name': 'restaurant'});

    expect(root?.property('name'), 'restaurant');
  });

  test('an Icon with a name that is not a string is still checked', () {
    final root = _rootOf({'id': 'root', 'component': 'Icon', 'name': 3});

    expect(root, isNull);
  });

  test('a property other than a style property is still checked', () {
    final errors = <A2UIError>[];

    _rootOf({'id': 'root', 'component': 'Text', 'text': 'Ohrid', 'weight': 'heavy'}, errors: errors);

    expect(errors.map((error) => error.code), [A2UIErrorCode.validationFailed]);
  });

  test('a DateTimeInput with a minimum and a maximum is kept', () {
    final root = _rootOf({
      'id': 'root',
      'component': 'DateTimeInput',
      'value': '',
      'min': '2026-10-05',
      'max': '2026-10-20',
    });

    expect(root?.type, 'DateTimeInput');
  });

  test('a DateTimeInput with a minimum time is kept', () {
    final root = _rootOf({
      'id': 'root',
      'component': 'DateTimeInput',
      'value': '',
      'enableTime': true,
      'min': '09:00:00',
    });

    expect(root?.type, 'DateTimeInput');
  });
}

// The root of a surface whose root is [component], from a processor disposed
// when the test ends.
A2UINode? _rootOf(Map<String, Object?> component, {List<A2UIError>? errors}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors?.add);
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {
        'surfaceId': 's',
        'catalogId': A2UICatalogs.defaultCatalogId,
        'dataModel': {'style': 'caption'},
        'components': [component],
      },
    }),
  ]);
  return processor.surface('s')?.root;
}
