import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_app_components.dart';

void main() {
  test("an app component's name becomes its A2UI type in PascalCase", () {
    final cases = jsonDecode(File('test/fixtures/ios_app_component_types.json').readAsStringSync()) as List<Object?>;
    expect(cases, hasLength(15));

    for (final entry in cases.cast<Map<String, Object?>>()) {
      final name = entry['name']! as String;
      expect(a2uiTypeNameOf(name), _differences[name] ?? entry['type'], reason: name);
    }
  });

  test('a component whose type is an A2UI identifier is placed, with nothing reported', () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([_component('place_card')], onLeftOut: leftOut.add);

    expect(placeable.map((entry) => entry.type), ['PlaceCard']);
    expect(leftOut, isEmpty);
  });

  test("a component whose type isn't an A2UI identifier is left out and reported", () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([_component('9 lives')], onLeftOut: leftOut.add);

    expect(placeable, isEmpty);
    expect(leftOut.single, contains("'9Lives' isn't an A2UI identifier"));
  });

  test('a component that would be the surface is left out and reported', () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([_component('surface')], onLeftOut: leftOut.add);

    expect(placeable, isEmpty);
    expect(leftOut.single, contains("'Surface' is the surface's own"));
  });

  test("a component named like one of the basic catalog's is left out and reported", () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([_component('card')], onLeftOut: leftOut.add);

    expect(placeable, isEmpty);
    expect(leftOut.single, contains("'Card' is one of the basic catalog's"));
  });

  test("a component with a parameter whose name isn't an A2UI identifier is left out and reported", () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([
      _component('place_card', parameters: [const AIUIParameter.required('start-date', AIUIParameterType.date)]),
    ], onLeftOut: leftOut.add);

    expect(placeable, isEmpty);
    expect(leftOut.single, contains("'start-date' isn't an A2UI identifier"));
  });

  test('a component with a parameter named component is left out and reported', () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([
      _component('badge', parameters: [const AIUIParameter.required('component', AIUIParameterType.string)]),
    ], onLeftOut: leftOut.add);

    expect(placeable, isEmpty);
    expect(leftOut.single, contains("'component' is the key that holds a component's type"));
  });

  test('a component with a parameter named id is left out and reported', () {
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([
      _component('badge', parameters: [const AIUIParameter.required('id', AIUIParameterType.string)]),
    ], onLeftOut: leftOut.add);

    expect(placeable, isEmpty);
    expect(leftOut.single, contains("'id' is the key that holds a component's id"));
  });

  for (final name in ['weight', 'accessibility']) {
    test('a component with a parameter named $name is left out and reported', () {
      final leftOut = <String>[];

      final placeable = a2uiPlaceableComponents([
        _component('badge', parameters: [AIUIParameter.required(name, AIUIParameterType.string)]),
      ], onLeftOut: leftOut.add);

      expect(placeable, isEmpty);
      expect(leftOut.single, contains("'$name' is a property every component may hold"));
    });
  }

  test('of two components placed by one type, the first is kept and the second reported', () {
    final first = _component('place_card');
    final second = _component('place-card');
    final leftOut = <String>[];

    final placeable = a2uiPlaceableComponents([first, second], onLeftOut: leftOut.add);

    expect(placeable.single.component, same(first));
    expect(leftOut.single, contains("'place-card'"));
  });

  test("the report names the component and says it can't be placed", () {
    final leftOut = <String>[];

    a2uiPlaceableComponents([_component('card')], onLeftOut: leftOut.add);

    expect(leftOut.single, startsWith("The app's component 'card' can't be placed in A2UI replies: "));
  });
}

// Where the type differs from the fixture's: a word starting with `ß` keeps
// it, as Dart has no capital for it, where the fixture writes `SS`.
const _differences = {'ßeta_card': 'ßetaCard'};

AIUIComponent<Object?> _component(String name, {List<AIUIParameter> parameters = const []}) {
  return _TestComponent(AIUIComponentDefinition(name: name, description: 'A test component', parameters: parameters));
}

final class _TestComponent extends AIUIComponent<Object?> {
  const _TestComponent(this.definition);

  @override
  final AIUIComponentDefinition definition;

  @override
  Object? readArguments(AIUIArguments arguments) => null;

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) => const SizedBox.shrink();
}
