import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import '../a2ui_test_app.dart';

// The children a builder reads of its component, and what it reads of each,
// through a probe that replaces the builder of the root's type.
void main() {
  testWidgets("child is the component a Card's child names", (tester) async {
    final id = await _readComponent(tester, 'Card', _card(), (scope) => scope.child()?.id);

    expect(id, 'inner');
  });

  testWidgets('child is null when the child has not arrived', (tester) async {
    final child = await _readComponent(tester, 'Card', [
      {'id': 'root', 'component': 'Card', 'child': 'missing'},
    ], (scope) => scope.child());

    expect(child, isNull);
  });

  testWidgets('child is null for a property that holds a list of children', (tester) async {
    final child = await _readComponent(tester, 'Column', [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['a'],
      },
      {'id': 'a', 'component': 'Text', 'text': 'a'},
    ], (scope) => scope.child('children'));

    expect(child, isNull);
  });

  testWidgets('children are the components the list of ids names, in order', (tester) async {
    final ids = await _readComponent(tester, 'Column', [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['b', 'a'],
      },
      {'id': 'a', 'component': 'Text', 'text': 'a'},
      {'id': 'b', 'component': 'Text', 'text': 'b'},
    ], (scope) => [for (final child in scope.children()) child.id]);

    expect(ids, ['b', 'a']);
  });

  testWidgets('a template gives one child for each item of its list', (tester) async {
    final count = await _readComponent(
      tester,
      'List',
      _template(),
      (scope) => scope.children().length,
      data: _items(),
    );

    expect(count, 3);
  });

  testWidgets('the children of a template have distinct keys', (tester) async {
    final keys = await _readComponent(
      tester,
      'List',
      _template(),
      (scope) => {for (final child in scope.children()) child.key},
      data: _items(),
    );

    expect(keys, hasLength(3));
  });

  testWidgets('a property that holds no children gives no children', (tester) async {
    final children = await _readComponent(tester, 'Text', [
      {'id': 'root', 'component': 'Text', 'text': 'x'},
    ], (scope) => scope.children());

    expect(children, isEmpty);
  });

  testWidgets("a component inside a property value is a child, such as a tab's child", (tester) async {
    final child = await _readComponent(tester, 'Tabs', [
      {
        'id': 'root',
        'component': 'Tabs',
        'tabs': [
          {'title': 'One', 'child': 'one'},
        ],
      },
      {'id': 'one', 'component': 'Text', 'text': 'x'},
    ], (scope) => ((scope.value('tabs')! as List<Object?>).single! as Map<String, Object?>)['child']);

    expect(child, isA<A2UIChild>().having((child) => child.id, 'id', 'one'));
  });

  testWidgets("a component inside a property value that has not arrived is null, such as a tab's child", (
    tester,
  ) async {
    final child = await _readComponent(tester, 'Tabs', [
      {
        'id': 'root',
        'component': 'Tabs',
        'tabs': [
          {'title': 'One', 'child': 'later'},
        ],
      },
    ], (scope) => ((scope.value('tabs')! as List<Object?>).single! as Map<String, Object?>)['child']);

    expect(child, isNull);
  });

  testWidgets('build draws a child with the surface catalog', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Card', 'child': 'inner'},
        {'id': 'inner', 'component': 'Text', 'text': 'Inside'},
      ],
    );

    expect(find.text('Inside'), findsOneWidget);
  });

  testWidgets('children leave out a child of a type the catalog has no builder for', (tester) async {
    final ids = await _readComponent(
      tester,
      'Column',
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'a'},
        {'id': 'b', 'component': 'Divider'},
      ],
      (scope) => [for (final child in scope.children()) child.id],
      catalog: A2UICatalog.basic.removing(['Divider']),
    );

    expect(ids, ['a']);
  });

  testWidgets('children leave out a child of a type the agent made up', (tester) async {
    final ids = await _readComponent(tester, 'Column', [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['a', 'b'],
      },
      {'id': 'a', 'component': 'Text', 'text': 'a'},
      {'id': 'b', 'component': 'Nope'},
    ], (scope) => [for (final child in scope.children()) child.id]);

    expect(ids, ['a']);
  });

  testWidgets('a weight above 0 is the weight of a child', (tester) async {
    final weight = await _readComponent(tester, 'Row', _weighted(2), (scope) => scope.children().single.weight);

    expect(weight, 2.0);
  });

  testWidgets('a weight too large to be a number is no weight', (tester) async {
    // JSON can hold 1e400, which reads as infinity.
    final message = createSurface(_weighted(1e300)).replaceFirst('1e+300', '1e400');
    final processor = A2UIProcessor(catalogs: A2UICatalogs())..apply([message]);
    addTearDown(processor.dispose);
    double? weight = 0;

    await tester.pumpWidget(
      surfaceApp(
        processor.surface('s')!,
        catalog: A2UICatalog.basic.replacing('Row', (context, scope) {
          weight = scope.children().single.weight;
          return const SizedBox();
        }),
      ),
    );

    expect(weight, isNull);
  });

  testWidgets('a weight of 0 is no weight', (tester) async {
    final weight = await _readComponent(tester, 'Row', _weighted(0), (scope) => scope.children().single.weight);

    expect(weight, isNull);
  });

  testWidgets('two reads of the same child are equal', (tester) async {
    final equal = await _readComponent(tester, 'Card', _card(), (scope) => scope.child() == scope.child());

    expect(equal, isTrue);
  });

  testWidgets('two different children are not equal', (tester) async {
    final children = await _readComponent(tester, 'Column', [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['a', 'b'],
      },
      {'id': 'a', 'component': 'Text', 'text': 'a'},
      {'id': 'b', 'component': 'Text', 'text': 'b'},
    ], (scope) => scope.children());

    expect(children.first, isNot(children.last));
  });

  testWidgets("a child's key stays the same when the agent replaces the child with another type", (tester) async {
    final reads = <A2UIChild?>[];
    final processor = await pumpSurface(
      tester,
      components: _card(),
      catalog: _recording('Card', (scope) => reads.add(scope.child())),
    );

    processor.apply([
      updateComponents([
        {'id': 'inner', 'component': 'Divider'},
      ]),
    ]);
    await tester.pump();

    // A replacement of another type is another child; one of the same type
    // updates the child in place.
    expect(reads.last, isNot(reads.first));
    expect(reads.last?.key, reads.first?.key);
  });

  testWidgets("a child's key stays the same when the agent replaces its parent with another type", (tester) async {
    final reads = <A2UIChild?>[];
    final processor = await pumpSurface(
      tester,
      components: _card(),
      catalog: _recording(
        'Column',
        (scope) => reads.add(scope.children().single),
        catalog: _recording('Card', (scope) => reads.add(scope.child())),
      ),
    );

    processor.apply([
      updateComponents([
        {
          'id': 'root',
          'component': 'Column',
          'children': ['inner'],
        },
      ]),
    ]);
    await tester.pump();

    // The new parent holds another child, with the key of the first.
    expect(reads.last, isNot(reads.first));
    expect(reads.last?.key, reads.first?.key);
  });
}

// A root `Card` whose child is a `Text`.
List<Map<String, Object?>> _card() => [
  {'id': 'root', 'component': 'Card', 'child': 'inner'},
  {'id': 'inner', 'component': 'Text', 'text': 'x'},
];

// A root `List` that draws an `item` for each entry of `/items`.
List<Map<String, Object?>> _template() => [
  {
    'id': 'root',
    'component': 'List',
    'children': {'componentId': 'item', 'path': '/items'},
  },
  {
    'id': 'item',
    'component': 'Text',
    'text': {'@path': 'name'},
  },
];

// A data model with three items for [_template].
Map<String, Object?> _items() => {
  'items': [
    {'name': 'a'},
    {'name': 'b'},
    {'name': 'c'},
  ],
};

// A root `Row` with one child of [weight].
List<Map<String, Object?>> _weighted(num weight) => [
  {
    'id': 'root',
    'component': 'Row',
    'children': ['a'],
  },
  {'id': 'a', 'component': 'Text', 'text': 'a', 'weight': weight},
];

// [catalog] with the builder of [type] replaced by one that calls [read] with
// its scope and draws nothing.
A2UICatalog _recording(
  String type,
  void Function(A2UIComponentScope scope) read, {
  A2UICatalog catalog = A2UICatalog.basic,
}) {
  return catalog.replacing(type, (context, scope) {
    read(scope);
    return const SizedBox();
  });
}

// What [read] reads of the root component of [type] among [components], on a
// surface with [data].
Future<T> _readComponent<T>(
  WidgetTester tester,
  String type,
  List<Map<String, Object?>> components,
  T Function(A2UIComponentScope scope) read, {
  Map<String, Object?> data = const {},
  A2UICatalog catalog = A2UICatalog.basic,
}) async {
  late T result;
  await pumpSurface(
    tester,
    components: components,
    data: data,
    catalog: _recording(type, (scope) => result = read(scope), catalog: catalog),
  );
  return result;
}
