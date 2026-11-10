import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test('children lists the children of a Column in order', () {
    final root = planSurface().root!;

    expect(root.children('children').map((node) => node.id), ['title', 'pace', 'email', 'update']);
  });

  test('children is empty for a property that holds no components', () {
    final root = planSurface().root!;

    expect(root.children('justify'), isEmpty);
  });

  test('property reads a literal value', () {
    final title = rootChild(planSurface(), 'title');

    expect(title.property('text'), 'A weekend in Ohrid');
  });

  test('property reads a bound value from the data model', () {
    final email = rootChild(planSurface(), 'email');

    expect(email.property('value'), 'person@example.com');
  });

  test("property is null for a property the component doesn't set", () {
    final title = rootChild(planSurface(), 'title');

    expect(title.property('variant'), isNull);
  });

  test('property is null for an action', () {
    final update = rootChild(planSurface(), 'update');

    expect(update.property('action'), isNull);
  });

  test('property gives the components inside a value as nodes', () {
    final tabs = _tabs().root!.property('tabs')! as List<Object?>;

    expect(((tabs.single! as Map<String, Object?>)['child']! as A2UINode).id, 'saturday');
  });

  test("a value property gives can't be changed", () {
    final tabs = _tabs().root!.property('tabs')! as List<Object?>;

    expect(() => tabs.add(null), throwsUnsupportedError);
  });

  test("an object inside a value property gives can't be changed", () {
    final tabs = _tabs().root!.property('tabs')! as List<Object?>;

    expect(() => (tabs.single! as Map<String, Object?>)['title'] = 'Sunday', throwsUnsupportedError);
  });

  test('a bound property follows a change to the data model', () {
    final surface = planSurface();
    final email = rootChild(surface, 'email');

    surface.write('/email', 'other@example.com');

    expect(email.property('value'), 'other@example.com');
  });

  test('a node notifies when a value it is bound to changes', () {
    final surface = planSurface();
    final email = rootChild(surface, 'email');
    var notified = 0;
    email.addListener(() => notified += 1);

    surface.write('/email', 'other@example.com');

    expect(notified, 1);
  });

  test('a node notifies when a child that was on its way arrives', () {
    final processor = testProcessor()
      ..apply([
        createPlanSurface(),
        updatePlanComponents(
          components: [
            {'id': 'root', 'component': 'Card', 'child': 'later'},
          ],
        ),
      ]);
    final card = processor.surface('plan')!.root!;
    var notified = 0;
    card.addListener(() => notified += 1);

    processor.apply([
      updatePlanComponents(
        components: [
          {'id': 'later', 'component': 'Text', 'text': 'Arrived'},
        ],
      ),
    ]);

    expect(notified, 1);
  });

  test('template children give one node per item, each with its own key', () {
    final items = _placesList().root!.children('children');

    expect({for (final item in items) item.key}, hasLength(2));
  });

  test('a template child reads its own item', () {
    final items = _placesList().root!.children('children');

    expect(items.map((item) => item.property('text')), ['Kaneo', 'Plaošnik']);
  });

  test('isResolved is true for a component of the catalog', () {
    final title = rootChild(planSurface(), 'title');

    expect(title.isResolved, isTrue);
  });

  test("isResolved is false for a type the catalog doesn't have", () {
    final surface = planSurface(
      components: [
        {'id': 'root', 'component': 'TripMap'},
      ],
    );

    expect(surface.root!.isResolved, isFalse);
  });

  test('isResolved is false for a component that would hold itself', () {
    final surface = planSurface(
      components: [
        {'id': 'root', 'component': 'Card', 'child': 'inner'},
        {'id': 'inner', 'component': 'Card', 'child': 'inner'},
      ],
    );

    final inner = surface.root!.children('child').single;

    expect(inner.children('child').single.isResolved, isFalse);
  });

  test("isResolved is false for a child that hasn't arrived yet", () {
    final surface = planSurface(
      components: [
        {'id': 'root', 'component': 'Card', 'child': 'later'},
      ],
    );

    expect(surface.root!.children('child').single.isResolved, isFalse);
  });
}

A2UISurface _tabs() {
  return planSurface(
    components: [
      {
        'id': 'root',
        'component': 'Tabs',
        'tabs': [
          {'title': 'Saturday', 'child': 'saturday'},
        ],
      },
      {'id': 'saturday', 'component': 'Text', 'text': 'Kaneo'},
    ],
  );
}

A2UISurface _placesList() {
  return planSurface(
    components: [
      {
        'id': 'root',
        'component': 'List',
        'children': {'componentId': 'item', 'path': '/places'},
      },
      {
        'id': 'item',
        'component': 'Text',
        'text': {'@path': 'name'},
      },
    ],
    data: {
      'places': [
        {'name': 'Kaneo'},
        {'name': 'Plaošnik'},
      ],
    },
  );
}
