import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import '../a2ui_test_app.dart';

// What a builder reads of its component's properties, through a `Text` drawn
// by a probe.
void main() {
  testWidgets('id is the id the agent gave the component', (tester) async {
    expect(await _read(tester, {}, (scope) => scope.id), 'root');
  });

  testWidgets('type is the type of the component', (tester) async {
    expect(await _read(tester, {}, (scope) => scope.type), 'Text');
  });

  testWidgets('value reads a property the agent wrote', (tester) async {
    expect(await _read(tester, {'text': 'Ohrid'}, (scope) => scope.value('text')), 'Ohrid');
  });

  testWidgets('value reads a bound property from the data model', (tester) async {
    final value = await _read(
      tester,
      {
        'text': {'@path': '/city'},
      },
      (scope) => scope.value('text'),
      data: {'city': 'Ohrid'},
    );

    expect(value, 'Ohrid');
  });

  testWidgets('value reads a style property bound to the data model from the data model', (tester) async {
    final value = await _read(
      tester,
      {
        'variant': {'@path': '/style'},
      },
      (scope) => scope.value('variant'),
      data: {'style': 'caption'},
    );

    expect(value, 'caption');
  });

  testWidgets('value is null for a property the component does not set', (tester) async {
    expect(await _read(tester, {}, (scope) => scope.value('description')), isNull);
  });

  testWidgets('a builder builds again with the new value when the data model changes', (tester) async {
    final reads = <Object?>[];
    final processor = await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Text',
          'text': {'@path': '/city'},
        },
      ],
      data: {'city': 'Ohrid'},
      catalog: _probe((scope) => reads.add(scope.value('text'))),
    );

    processor.apply([updateData('/city', 'Struga')]);
    await tester.pump();

    expect(reads.last, 'Struga');
  });

  testWidgets('string reads a string as it is', (tester) async {
    expect(await _read(tester, {'text': 'Ohrid'}, (scope) => scope.string('text')), 'Ohrid');
  });

  testWidgets('string writes a whole number without a decimal point', (tester) async {
    expect(await _readBound(tester, 3.0, (scope) => scope.string('text')), '3');
  });

  testWidgets('string writes a fraction as it is', (tester) async {
    expect(await _readBound(tester, 2.5, (scope) => scope.string('text')), '2.5');
  });

  testWidgets('string writes a boolean as true or false', (tester) async {
    expect(await _readBound(tester, true, (scope) => scope.string('text')), 'true');
  });

  testWidgets('string writes a list as JSON', (tester) async {
    expect(
      await _readBound(tester, [1.0, 'a'], (scope) => scope.string('text')),
      '[1,"a"]',
    );
  });

  testWidgets('string writes the whole numbers nested in a map without a decimal point', (tester) async {
    final text = await _readBound(
      tester,
      {
        'count': 2.0,
        'sizes': [1.0, 2.5],
        'place': {'floor': 3.0, 'name': 'Ohrid'},
      },
      (scope) => scope.string('text'),
    );

    expect(text, '{"count":2,"sizes":[1,2.5],"place":{"floor":3,"name":"Ohrid"}}');
  });

  testWidgets('string writes a component nested in a property as its id', (tester) async {
    final text = await _readComponent(tester, 'Tabs', [
      {
        'id': 'root',
        'component': 'Tabs',
        'tabs': [
          {'title': 'One', 'child': 'one'},
        ],
      },
      {'id': 'one', 'component': 'Text', 'text': 'x'},
    ], (scope) => scope.string('tabs'));

    expect(text, '[{"title":"One","child":"one"}]');
  });

  testWidgets('string writes the numbers nested in a map that are not finite as null', (tester) async {
    final reads = <String?>[];
    final processor = await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Text',
          'text': {'@path': '/value'},
        },
      ],
      data: {'value': 'x'},
      catalog: _probe((scope) => reads.add(scope.string('text'))),
    );

    // The data model takes values JSON can't hold only from the app, such as
    // from a component writing what the user picked.
    processor.surface('s')!.root!.write('text', {
      'values': [double.nan, double.infinity, 1.0],
    });
    await tester.pump();

    expect(reads.last, '{"values":[null,null,1]}');
  });

  testWidgets('string is null for a missing property', (tester) async {
    expect(await _read(tester, {}, (scope) => scope.string('description')), isNull);
  });

  testWidgets('number reads a number', (tester) async {
    expect(await _read(tester, {'weight': 2}, (scope) => scope.number('weight')), 2.0);
  });

  testWidgets('number reads a string that holds a number', (tester) async {
    expect(await _read(tester, {'text': ' 2.5 '}, (scope) => scope.number('text')), 2.5);
  });

  testWidgets('number is null for a string that holds no number', (tester) async {
    expect(await _read(tester, {'text': 'two'}, (scope) => scope.number('text')), isNull);
  });

  testWidgets('number is null for the string NaN', (tester) async {
    expect(await _read(tester, {'text': 'NaN'}, (scope) => scope.number('text')), isNull);
  });

  testWidgets('number is null for the string Infinity', (tester) async {
    expect(await _read(tester, {'text': 'Infinity'}, (scope) => scope.number('text')), isNull);
  });

  testWidgets('boolean reads a boolean', (tester) async {
    expect(await _readBound(tester, false, (scope) => scope.boolean('text')), isFalse);
  });

  testWidgets('boolean counts a number other than 0 as true', (tester) async {
    expect(await _readBound(tester, 2, (scope) => scope.boolean('text')), isTrue);
  });

  testWidgets('boolean counts 0 as false', (tester) async {
    expect(await _readBound(tester, 0, (scope) => scope.boolean('text')), isFalse);
  });

  testWidgets('boolean reads the string true in any capitalization', (tester) async {
    expect(await _read(tester, {'text': 'TRUE'}, (scope) => scope.boolean('text')), isTrue);
  });

  testWidgets('boolean is null for another string', (tester) async {
    expect(await _read(tester, {'text': 'yes'}, (scope) => scope.boolean('text')), isNull);
  });

  testWidgets("boolean reads a check's result as whether it passed", (tester) async {
    final passed = await _read(
      tester,
      {
        'text': {
          '@call': 'required',
          'args': {'value': 'x'},
        },
      },
      (scope) => scope.boolean('text'),
    );

    expect(passed, isTrue);
  });

  testWidgets('stringList reads each item as text', (tester) async {
    expect(
      await _readBound(tester, ['a', 2.0, true], (scope) => scope.stringList('text')),
      ['a', '2', 'true'],
    );
  });

  testWidgets('stringList leaves out null items', (tester) async {
    expect(
      await _readBound(tester, ['a', null], (scope) => scope.stringList('text')),
      ['a'],
    );
  });

  testWidgets('stringList is null for a value that is not a list', (tester) async {
    expect(await _read(tester, {'text': 'a'}, (scope) => scope.stringList('text')), isNull);
  });

  testWidgets('hint reads a style hint the agent wrote', (tester) async {
    expect(await _read(tester, {'variant': 'caption'}, (scope) => scope.hint('variant')), 'caption');
  });

  testWidgets('hint returns a value the type does not know as it is', (tester) async {
    expect(await _read(tester, {'variant': 'h1'}, (scope) => scope.hint('variant')), 'h1');
  });

  testWidgets('hint is null for a style hint bound to the data model', (tester) async {
    final hint = await _read(
      tester,
      {
        'variant': {'@path': '/style'},
      },
      (scope) => scope.hint('variant'),
      data: {'style': 'caption'},
    );

    expect(hint, isNull);
  });

  for (final (type, property) in [
    ('Text', 'variant'),
    ('Image', 'fit'),
    ('Image', 'variant'),
    ('Row', 'justify'),
    ('Row', 'align'),
    ('List', 'direction'),
    ('Divider', 'axis'),
  ]) {
    testWidgets("hint is null for a $type's $property bound to the data model", (tester) async {
      final hint = await _readComponent(
        tester,
        type,
        [
          {
            'id': 'root',
            'component': type,
            if (type == 'Text') 'text': 'x',
            if (type == 'Image') 'url': 'https://example.com/a.png',
            if (type == 'Row' || type == 'List') 'children': <String>[],
            property: {'@path': '/style'},
          },
        ],
        (scope) => scope.hint(property),
        data: {'style': 'center'},
      );

      expect(hint, isNull);
    });
  }

  testWidgets('hint is null for a style hint computed with a function', (tester) async {
    final hint = await _read(
      tester,
      {
        'variant': {
          '@call': 'formatString',
          'args': {'value': 'caption'},
        },
      },
      (scope) => scope.hint('variant'),
    );

    expect(hint, isNull);
  });

  testWidgets('hint is null for a property that is not a style hint bound to the data model', (tester) async {
    final hint = await _read(
      tester,
      {
        'text': {'@path': '/city'},
      },
      (scope) => scope.hint('text'),
      data: {'city': 'Ohrid'},
    );

    expect(hint, isNull);
  });

  testWidgets('hint is null for a missing style hint', (tester) async {
    expect(await _read(tester, {}, (scope) => scope.hint('variant')), isNull);
  });

  testWidgets('isBound is true for a property bound to the data model', (tester) async {
    final isBound = await _read(
      tester,
      {
        'text': {'@path': '/city'},
      },
      (scope) => scope.isBound('text'),
      data: {'city': 'Ohrid'},
    );

    expect(isBound, isTrue);
  });

  testWidgets('isBound is true for a style property bound to the data model', (tester) async {
    final isBound = await _read(
      tester,
      {
        'variant': {'@path': '/style'},
      },
      (scope) => scope.isBound('variant'),
      data: {'style': 'caption'},
    );

    expect(isBound, isTrue);
  });

  testWidgets('isBound is false for a property the agent wrote', (tester) async {
    expect(await _read(tester, {}, (scope) => scope.isBound('text')), isFalse);
  });
}

// A catalog whose `Text` builder calls [read] with its scope and draws
// nothing.
A2UICatalog _probe(void Function(A2UIComponentScope scope) read) {
  return A2UICatalog.basic.replacing('Text', (context, scope) {
    read(scope);
    return const SizedBox();
  });
}

// What [read] reads of a root `Text` with [properties], on a surface with
// [data]. Its text is `x` unless [properties] say otherwise.
Future<T> _read<T>(
  WidgetTester tester,
  Map<String, Object?> properties,
  T Function(A2UIComponentScope scope) read, {
  Map<String, Object?> data = const {},
}) async {
  late T result;
  await pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Text', 'text': 'x', ...properties},
    ],
    data: data,
    catalog: _probe((scope) => result = read(scope)),
  );
  return result;
}

// What [read] reads of a root `Text` whose text is bound to [value] in the
// data model.
Future<T> _readBound<T>(WidgetTester tester, Object? value, T Function(A2UIComponentScope scope) read) {
  return _read(
    tester,
    {
      'text': {'@path': '/value'},
    },
    read,
    data: {'value': value},
  );
}

// What [read] reads of the root component of [type] among [components].
Future<T> _readComponent<T>(
  WidgetTester tester,
  String type,
  List<Map<String, Object?>> components,
  T Function(A2UIComponentScope scope) read, {
  Map<String, Object?> data = const {},
}) async {
  late T result;
  await pumpSurface(
    tester,
    components: components,
    data: data,
    catalog: A2UICatalog.basic.replacing(type, (context, scope) {
      result = read(scope);
      return const SizedBox();
    }),
  );
  return result;
}
