import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

// A surface that would expand to more than 5,000 components, counting a
// component once for each place it shows, or whose components nest more than
// 50 levels below the root, isn't built.
void main() {
  test('a surface that fans out past the limit has no root', () {
    final surface = _surfaceWith(_fanOut(width: 10, depth: 5));

    expect(surface.root, isNull);
  });

  // A component of a type the catalog doesn't have is reported only when the
  // tree is built, so a report of one shows the tree was built.
  test('a surface created past the limit is not built while it is applied', () async {
    final errors = <A2UIError>[];

    _surfaceWith(_fanOut(width: 10, depth: 4, leaf: 'Nope'), errors: errors);
    await pumpEventQueue();

    expect(errors.map((error) => error.code), [A2UIErrorCode.recursionLimitExceeded]);
  });

  test('a surface updated past the limit is not built while it is applied', () async {
    final errors = <A2UIError>[];
    final processor = _processor(errors: errors)..apply([_create(_column(childCount: 1))]);

    // ignore: cascade_invocations
    processor.apply([_update(_fanOut(width: 10, depth: 4, leaf: 'Nope'))]);
    await pumpEventQueue();

    expect(errors.map((error) => error.code), [A2UIErrorCode.recursionLimitExceeded]);
  });

  test('an update past the limit with the components already there is not built while it is applied', () async {
    final errors = <A2UIError>[];
    final processor = _processor(errors: errors)
      ..apply([
        _create([
          {
            'id': 'root',
            'component': 'Column',
            'children': ['n1'],
          },
          {'id': 'n1', 'component': 'Text', 'text': 'x'},
        ]),
      ]);

    // The root, already there, isn't sent again.
    // ignore: cascade_invocations
    processor.apply([
      _update([
        {'id': 'n1', 'component': 'Column', 'children': List.filled(20, 'n2')},
        {'id': 'n2', 'component': 'Column', 'children': List.filled(20, 'n3')},
        {'id': 'n3', 'component': 'Column', 'children': List.filled(20, 'n4')},
        {'id': 'n4', 'component': 'Nope'},
      ]),
    ]);
    await pumpEventQueue();

    expect(errors.map((error) => error.code), [A2UIErrorCode.recursionLimitExceeded]);
  });

  test('a fan-out under the limit with an unknown type is built and reports the type', () async {
    final errors = <A2UIError>[];

    _surfaceWith(_fanOut(width: 10, depth: 2, leaf: 'Nope'), errors: errors);
    await pumpEventQueue();

    expect(errors.map((error) => error.code), [A2UIErrorCode.unknownComponentType]);
  });

  test('a component whose catalog id is not a string is counted without failing', () {
    final processor = _processor()..apply([_create(_column(childCount: 1))]);

    expect(
      () => processor.apply([
        _update([
          {
            'id': 'root',
            'component': 'Column',
            'catalogId': 7,
            'children': ['t0'],
          },
        ]),
      ]),
      returnsNormally,
    );
  });

  test('a surface that fans out past the limit is reported', () {
    final errors = <A2UIError>[];

    _surfaceWith(_fanOut(width: 10, depth: 5), errors: errors);

    expect(errors.map((error) => error.code), [A2UIErrorCode.recursionLimitExceeded]);
  });

  test('the report says what multiplies the components', () {
    final errors = <A2UIError>[];

    _surfaceWith(_fanOut(width: 10, depth: 5), errors: errors);

    expect(
      errors.single.message,
      "Surface 's' expands to more than 5000 components. "
      'A component listed as a child more than once, or a template inside a template, multiplies the components '
      'under it.',
    );
  });

  test('the report names the surface', () {
    final errors = <A2UIError>[];

    _surfaceWith(_fanOut(width: 10, depth: 5), errors: errors);

    expect(errors.single.surfaceId, 's');
  });

  test('a surface that expands to exactly 5000 components is built', () {
    // The root and one text listed 4,999 times.
    final surface = _surfaceWith(_listing(4999));

    expect(surface.root!.children('children'), hasLength(4999));
  });

  test('a surface that expands to 5001 components is not built', () {
    // The root and one text listed 5,000 times.
    final surface = _surfaceWith(_listing(5000));

    expect(surface.root, isNull);
  });

  test('distinct components count once each', () {
    final surface = _surfaceWith(_column(childCount: 3));

    expect(surface.root!.children('children'), hasLength(3));
  });

  test('a template child counts once for each item of its list', () {
    // The root and 4,999 items.
    final surface = _surfaceWith(_template(), data: {'items': _items(4999)});

    expect(surface.root!.children('children'), hasLength(4999));
  });

  test('a template whose list takes the surface past the limit is not built', () {
    // The root and 5,000 items.
    final surface = _surfaceWith(_template(), data: {'items': _items(5000)});

    expect(surface.root, isNull);
  });

  test('a surface created with data past the limit is not built while it is applied', () async {
    final errors = <A2UIError>[];

    _surfaceWith(
      _template(leaf: 'Nope'),
      data: {'items': _items(6000)},
      errors: errors,
    );
    await pumpEventQueue();

    expect(errors.map((error) => error.code), [A2UIErrorCode.recursionLimitExceeded]);
  });

  test('a template inside a template multiplies the components', () {
    // 150 rows of 150 cells, both read from the same list.
    final surface = _surfaceWith(
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': {'componentId': 'row', 'path': '/items'},
        },
        {
          'id': 'row',
          'component': 'Column',
          'children': {'componentId': 'cell', 'path': '/items'},
        },
        {'id': 'cell', 'component': 'Text', 'text': 'x'},
      ],
      data: {'items': _items(150)},
    );

    expect(surface.root, isNull);
  });

  test("a template inside a template reads its list from the outer template's item", () {
    // The root, 100 groups and 50 cells in each: 5,101 components.
    final surface = _surfaceWith(
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': {'componentId': 'group', 'path': '/groups'},
        },
        {
          'id': 'group',
          'component': 'Column',
          'children': {'componentId': 'cell', 'path': 'cells'},
        },
        {'id': 'cell', 'component': 'Text', 'text': 'x'},
      ],
      data: {
        'groups': List.generate(100, (_) => {'cells': _items(50)}),
      },
    );

    expect(surface.root, isNull);
  });

  test('a data change that takes a template past the limit releases the tree', () {
    final processor = _processor()
      ..apply([
        _create(_template(), data: {'items': _items(3)}),
      ]);
    final surface = processor.surface('s')!;

    processor.apply([_setData('/items', _items(6000))]);

    expect(surface.root, isNull);
  });

  test('a data change that takes a template past the limit is not built while it is applied', () async {
    final errors = <A2UIError>[];
    final processor = _processor(errors: errors)..apply([_create(_template(leaf: 'Nope'))]);

    // ignore: cascade_invocations
    processor.apply([_setData('/items', _items(6000))]);
    await pumpEventQueue();

    expect(errors.map((error) => error.code), [A2UIErrorCode.recursionLimitExceeded]);
  });

  test('a data change that brings a template under the limit builds the tree again', () {
    final processor = _processor()
      ..apply([
        _create(_template(), data: {'items': _items(6000)}),
      ]);
    final surface = processor.surface('s')!;

    processor.apply([_setData('/items', _items(3))]);

    expect(surface.root!.children('children'), hasLength(3));
  });

  test('a data change the data model rejects leaves the tree built', () {
    final processor = _processor()
      ..apply([
        _create(_template(), data: {'items': _items(3)}),
      ]);
    final surface = processor.surface('s')!;

    processor.apply([_setData('/items/name/x', 1)]);

    expect(surface.root!.children('children'), hasLength(3));
  });

  test('a component reached first deep in the tree counts its children everywhere', () {
    // `fan` shows 9 times, 47 levels down the first time, and expands to
    // 1,111 components each time.
    final surface = _surfaceWith([
      {
        'id': 'root',
        'component': 'Column',
        'children': ['c1', ...List.filled(8, 'fan')],
      },
      for (var level = 1; level <= 46; level += 1)
        {
          'id': 'c$level',
          'component': 'Column',
          'children': [if (level == 46) 'fan' else 'c${level + 1}'],
        },
      {'id': 'fan', 'component': 'Column', 'children': List.filled(10, 'f1')},
      {'id': 'f1', 'component': 'Column', 'children': List.filled(10, 'f2')},
      {'id': 'f2', 'component': 'Column', 'children': List.filled(10, 'f3')},
      {'id': 'f3', 'component': 'Text', 'text': 'x'},
    ]);

    expect(surface.root, isNull);
  });

  test('a reference to a component that has not arrived counts once', () {
    // The root and 5,000 references to components that haven't arrived.
    final surface = _surfaceWith([
      {
        'id': 'root',
        'component': 'Column',
        'children': [for (var index = 0; index < 5000; index += 1) 'later$index'],
      },
    ]);

    expect(surface.root, isNull);
  });

  test('a component that holds one of its ancestors counts its other children each time it shows', () {
    // `a` and `b` hold each other; `a` shows 21 times, each time with the
    // 3,000 texts of `g`.
    final surface = _surfaceWith([
      {
        'id': 'root',
        'component': 'Column',
        'children': ['a', ...List.filled(20, 'b')],
      },
      {
        'id': 'a',
        'component': 'Column',
        'children': ['b', 'g'],
      },
      {
        'id': 'b',
        'component': 'Column',
        'children': ['a'],
      },
      {'id': 'g', 'component': 'Column', 'children': List.filled(3000, 'z')},
      {'id': 'z', 'component': 'Text', 'text': 'x'},
    ]);

    expect(surface.root, isNull);
  });

  test('a template whose path is the item itself counts the items of each list', () {
    // The root, 100 groups and 50 cells in each: 5,101 components.
    final surface = _surfaceWith(
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': {'componentId': 'group', 'path': '/groups'},
        },
        {
          'id': 'group',
          'component': 'Column',
          'children': {'componentId': 'cell', 'path': '.'},
        },
        {'id': 'cell', 'component': 'Text', 'text': 'x'},
      ],
      data: {
        'groups': List.generate(100, (_) => List.filled(50, 'x')),
      },
    );

    expect(surface.root, isNull);
  });

  test('a template whose path is not a data path is applied without failing', () {
    final processor = _processor();

    expect(
      () => processor.apply([
        _create(
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': {'componentId': 'item', 'path': '/a~2'},
            },
            {'id': 'item', 'component': 'Text', 'text': 'x'},
          ],
          data: {
            'a': [1],
          },
        ),
      ]),
      returnsNormally,
    );
  });

  test('a later template whose path is not a data path is applied without failing', () {
    final processor = _processor()
      ..apply([
        _create(
          _column(childCount: 1),
          data: {
            'a': [1],
          },
        ),
      ]);

    expect(
      () => processor.apply([
        _update([
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 't0', 'path': '/a~2'},
          },
        ]),
      ]),
      returnsNormally,
    );
  });

  test('a template that places its own component for each item counts each placement', () {
    // Each of the 8 items places `node` for each of the 8 items again, at
    // another data path each time, down to where the paths repeat.
    final surface = _surfaceWith(
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': {'componentId': 'node', 'path': '/items'},
        },
        {
          'id': 'node',
          'component': 'Column',
          'children': {'componentId': 'node', 'path': '/items'},
        },
      ],
      data: {'items': List.filled(8, 'x')},
    );

    expect(surface.root, isNull);
  });

  test('a template that places its own component for each reply in a thread is built', () {
    final surface = _surfaceWith(_thread(), data: {'replies': _replies(depth: 3)});

    expect(surface.root, isNotNull);
  });

  test('a template that places its own component more than 50 levels deep is reported', () {
    final errors = <A2UIError>[];

    _surfaceWith(_thread(), data: {'replies': _replies(depth: 60)}, errors: errors);

    expect(errors.single.message, "Component nesting exceeded 50 levels at 'reply'.");
  });

  test('components nested 50 levels below the root are built', () {
    final surface = _surfaceWith(_chain(50));

    expect(surface.root, isNotNull);
  });

  test('components nested more than 50 levels below the root are not built', () {
    final surface = _surfaceWith(_chain(51));

    expect(surface.root, isNull);
  });

  test('components nested more than 50 levels below the root are reported', () {
    final errors = <A2UIError>[];

    _surfaceWith(_chain(51), errors: errors);

    expect(errors.single.code, A2UIErrorCode.recursionLimitExceeded);
    expect(errors.single.message, "Component nesting exceeded 50 levels at 'c51'.");
  });

  test('a chain of 1200 components is not built', () {
    final surface = _surfaceWith(_chain(1200));

    expect(surface.root, isNull);
  });

  test("the children of each tab's child count", () {
    final surface = _surfaceWith([
      {
        'id': 'root',
        'component': 'Tabs',
        'tabs': [
          {'title': 'One', 'child': 'many'},
        ],
      },
      {'id': 'many', 'component': 'Column', 'children': List.filled(5000, 'text')},
      {'id': 'text', 'component': 'Text', 'text': 'x'},
    ]);

    expect(surface.root, isNull);
  });

  test('a component inside itself counts once without its children', () {
    final surface = _surfaceWith([
      {
        'id': 'root',
        'component': 'Column',
        'children': ['loop'],
      },
      {
        'id': 'loop',
        'component': 'Column',
        'children': List.filled(10, 'loop'),
      },
    ]);

    expect(surface.root, isNotNull);
  });

  test('a later message that fans the surface out past the limit releases its tree', () {
    final processor = _processor()..apply([_create(_column(childCount: 1))]);
    final surface = processor.surface('s')!;
    final roots = <A2UINode?>[];
    surface.addListener(() => roots.add(surface.root));

    processor.apply([_update(_fanOut(width: 10, depth: 5))]);

    expect(roots, [null]);
  });

  test('a later message that brings the surface under the limit builds its tree again', () {
    final processor = _processor()..apply([_create(_fanOut(width: 10, depth: 5))]);
    final surface = processor.surface('s')!;

    processor.apply([
      _update([
        {
          'id': 'root',
          'component': 'Column',
          'children': ['n1'],
        },
        {'id': 'n1', 'component': 'Text', 'text': 'x'},
      ]),
    ]);

    expect(surface.root?.type, 'Column');
  });

  test('a surface built again notifies its listeners', () {
    final processor = _processor()..apply([_create(_fanOut(width: 10, depth: 5))]);
    final surface = processor.surface('s')!;
    var notified = 0;
    surface.addListener(() => notified += 1);

    processor.apply([
      _update([
        {
          'id': 'root',
          'component': 'Column',
          'children': ['n1'],
        },
        {'id': 'n1', 'component': 'Text', 'text': 'x'},
      ]),
    ]);

    expect(notified, 1);
  });

  test('a surface that stays past the limit is reported once', () {
    final errors = <A2UIError>[];
    final processor = _processor(errors: errors)..apply([_create(_fanOut(width: 10, depth: 5))]);

    // ignore: cascade_invocations
    processor.apply([
      _update([
        {'id': 'n5', 'component': 'Text', 'text': 'y'},
      ]),
    ]);

    expect(errors, hasLength(1));
  });

  test('a data change to a surface past the limit leaves it without a root', () {
    final processor = _processor()..apply([_create(_fanOut(width: 10, depth: 5))]);

    // ignore: cascade_invocations
    processor.apply([
      jsonEncode({
        'version': '1.0',
        'updateDataModel': {'surfaceId': 's', 'path': '/x', 'value': 1},
      }),
    ]);

    expect(processor.surface('s')!.root, isNull);
  });
}

// A column whose children each list the same child [width] times, [depth]
// levels down: width^depth placements of the last level.
List<Map<String, Object?>> _fanOut({required int width, required int depth, String leaf = 'Text'}) => [
  for (var level = 0; level < depth; level += 1)
    {'id': level == 0 ? 'root' : 'n$level', 'component': 'Column', 'children': List.filled(width, 'n${level + 1}')},
  {'id': 'n$depth', 'component': leaf, 'text': 'x'},
];

// A root column whose children are the template `item`, one for each item of
// `/items`, of type [leaf].
List<Map<String, Object?>> _template({String leaf = 'Text'}) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': {'componentId': 'item', 'path': '/items'},
  },
  {
    'id': 'item',
    'component': leaf,
    'text': {'@path': 'name'},
  },
];

List<Map<String, Object?>> _items(int count) => [
  for (var index = 0; index < count; index += 1) {'name': '$index'},
];

// A root column with a column inside it, and so on: the last component, a
// text, is [depth] levels below the root.
List<Map<String, Object?>> _chain(int depth) => [
  for (var level = 0; level < depth; level += 1)
    {
      'id': level == 0 ? 'root' : 'c$level',
      'component': 'Column',
      'children': ['c${level + 1}'],
    },
  {'id': 'c$depth', 'component': 'Text', 'text': 'x'},
];

// A root column of `reply` for each of `/replies`, each with its own
// `replies` below it.
List<Map<String, Object?>> _thread() => [
  {
    'id': 'root',
    'component': 'Column',
    'children': {'componentId': 'reply', 'path': '/replies'},
  },
  {
    'id': 'reply',
    'component': 'Column',
    'children': {'componentId': 'reply', 'path': 'replies'},
  },
];

// One reply with one reply below it, [depth] replies deep.
List<Object?> _replies({required int depth}) => [
  {'replies': depth > 1 ? _replies(depth: depth - 1) : <Object?>[]},
];

String _setData(String path, Object? value) => jsonEncode({
  'version': '1.0',
  'updateDataModel': {'surfaceId': 's', 'path': path, 'value': value},
});

// A root column that lists one text [count] times.
List<Map<String, Object?>> _listing(int count) => [
  {'id': 'root', 'component': 'Column', 'children': List.filled(count, 'text')},
  {'id': 'text', 'component': 'Text', 'text': 'x'},
];

// A root column with [childCount] distinct texts.
List<Map<String, Object?>> _column({required int childCount}) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': [for (var index = 0; index < childCount; index += 1) 't$index'],
  },
  for (var index = 0; index < childCount; index += 1) {'id': 't$index', 'component': 'Text', 'text': '$index'},
];

String _create(List<Map<String, Object?>> components, {Map<String, Object?> data = const {}}) => jsonEncode({
  'version': '1.0',
  'createSurface': {
    'surfaceId': 's',
    'catalogId': A2UICatalogs.defaultCatalogId,
    'dataModel': data,
    'components': components,
  },
});

String _update(List<Map<String, Object?>> components) => jsonEncode({
  'version': '1.0',
  'updateComponents': {'surfaceId': 's', 'components': components},
});

A2UIProcessor _processor({List<A2UIError>? errors}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors?.add);
  addTearDown(processor.dispose);
  return processor;
}

A2UISurface _surfaceWith(
  List<Map<String, Object?>> components, {
  Map<String, Object?> data = const {},
  List<A2UIError>? errors,
}) {
  final processor = _processor(errors: errors)..apply([_create(components, data: data)]);
  return processor.surface('s')!;
}
