import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component_definition.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';

import 'genui_fixtures.dart';

void main() {
  test('AIUIComponentDefinition.fromJson reads parameters in the order the schema keeps', () {
    final json = genuiFixture('definition_place_card.json');

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition, _placeCard());
  });

  test("AIUIComponentDefinition.fromJson reads an object's fields and an event's parameters in order", () {
    final json = genuiFixture('definition_trip_map.json');

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition, _tripMap());
  });

  test('AIUIComponentDefinition.fromJson reads parameters without an order by name', () {
    final json = genuiFixture('definition_trip_map_unordered.json');

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition, _unorderedTripMap());
  });

  test('AIUIComponentDefinition.fromJson reads a missing description as empty', () {
    const json = <String, Object?>{'name': 'divider'};

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition.description, isEmpty);
  });

  test("AIUIComponentDefinition.fromJson reads the spec's place card", () {
    final json = genuiFixture('definition_place_card_spec.json');

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition, _specPlaceCard());
  });

  test('AIUIComponentDefinition.fromJson reads the fields the order leaves out after it, by name', () {
    final json = _definition(parameters: _objectSchema({'c': _string, 'b': _string, 'a': _string}, order: ['c']));

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition.parameters.map((parameter) => parameter.name), ['c', 'a', 'b']);
  });

  test('AIUIComponentDefinition.fromJson skips a name in the order that has no field', () {
    final json = _definition(parameters: _objectSchema({'a': _string}, order: ['ghost', 'a']));

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition.parameters.map((parameter) => parameter.name), ['a']);
  });

  test('AIUIComponentDefinition.fromJson skips a field whose schema is not an object', () {
    final json = _definition(parameters: _objectSchema({'a': 'string', 'b': _string}));

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition.parameters.map((parameter) => parameter.name), ['b']);
  });

  test("AIUIComponentDefinition.fromJson drops a field's description that is not a string", () {
    final json = _definition(
      parameters: _objectSchema({
        'a': {'type': 'string', 'description': 42},
      }),
    );

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(definition.parameters, [const AIUIParameter.optional('a', AIUIParameterType.string)]);
  });

  test('AIUIComponentDefinition.fromJson reads parameters and events given as maps of any type', () {
    final json = <String, Object?>{
      'name': 'trip_map',
      'description': 'A map.',
      'parameters': <Object?, Object?>{
        'type': 'object',
        'properties': <Object?, Object?>{
          'zoom': <Object?, Object?>{'type': 'number'},
        },
      },
      'events': [
        <Object?, Object?>{'name': 'select_place', 'description': 'A pin.'},
      ],
    };

    final definition = AIUIComponentDefinition.fromJson(json);

    expect(
      definition,
      const AIUIComponentDefinition(
        name: 'trip_map',
        description: 'A map.',
        parameters: [AIUIParameter.optional('zoom', AIUIParameterType.number)],
        events: [AIUIComponentEvent(name: 'select_place', description: 'A pin.')],
      ),
    );
  });

  test("AIUIComponentDefinition.fromJson keeps a parameter's type when the JSON changes afterwards", () {
    final items = <String, Object?>{'type': 'string'};
    final json = _definition(
      parameters: _objectSchema({
        'tags': {'type': 'array', 'items': items},
      }),
    );
    final definition = AIUIComponentDefinition.fromJson(json);

    items['type'] = 'number';

    expect(definition.parameters.single.type, AIUIParameterType.array(AIUIParameterType.string));
  });

  test("AIUIComponentDefinition.fromJson gives parameter types whose schema can't be changed", () {
    final definition = AIUIComponentDefinition.fromJson(genuiFixture('definition_place_card.json'));

    expect(() => definition.parameters.first.type.schema['type'] = 'number', throwsA(isA<UnsupportedError>()));
  });

  test("AIUIComponentDefinition.fromJson gives parameters that can't be changed", () {
    final definition = AIUIComponentDefinition.fromJson(genuiFixture('definition_place_card.json'));

    expect(definition.parameters.removeLast, throwsA(isA<UnsupportedError>()));
  });

  test("AIUIComponentDefinition.fromJson gives events that can't be changed", () {
    final definition = AIUIComponentDefinition.fromJson(genuiFixture('definition_place_card.json'));

    expect(definition.events.removeLast, throwsA(isA<UnsupportedError>()));
  });

  group('when a field is null', () {
    final cases = <(String, Map<String, Object?>, AIUIComponentDefinition)>[
      (
        'the description reads as empty',
        {'name': 'trip_map', 'description': null},
        const AIUIComponentDefinition(name: 'trip_map', description: ''),
      ),
      (
        'the parameters read as none',
        {'name': 'trip_map', 'description': 'A map.', 'parameters': null},
        const AIUIComponentDefinition(name: 'trip_map', description: 'A map.'),
      ),
      (
        'the events read as none',
        {'name': 'trip_map', 'description': 'A map.', 'events': null},
        const AIUIComponentDefinition(name: 'trip_map', description: 'A map.'),
      ),
      (
        "an event's description reads as empty and its parameters as none",
        {
          'name': 'trip_map',
          'description': 'A map.',
          'events': [
            {'name': 'select_place', 'description': null, 'parameters': null},
          ],
        },
        const AIUIComponentDefinition(
          name: 'trip_map',
          description: 'A map.',
          events: [AIUIComponentEvent(name: 'select_place', description: '')],
        ),
      ),
    ];

    for (final (behavior, json, expected) in cases) {
      test('AIUIComponentDefinition.fromJson reads it as missing: $behavior', () {
        final definition = AIUIComponentDefinition.fromJson(json);

        expect(definition, expected);
      });
    }
  });

  group('when the JSON is malformed', () {
    final cases = <(String, Map<String, Object?>)>[
      ('the definition has no name', {'description': 'Nameless'}),
      ('the name is not a string', {'name': 42}),
      ('the description is not a string', {'name': 'trip_map', 'description': 42}),
      ('the parameters are not an object', {'name': 'trip_map', 'parameters': 'places'}),
      ('the events are not an array', {'name': 'trip_map', 'events': 'select_place'}),
      (
        'an event is not an object',
        {
          'name': 'trip_map',
          'events': ['select_place'],
        },
      ),
      (
        'an event has no name',
        {
          'name': 'trip_map',
          'events': [
            {'description': 'Nameless'},
          ],
        },
      ),
      (
        "an event's description is not a string",
        {
          'name': 'trip_map',
          'events': [
            {'name': 'select_place', 'description': 42},
          ],
        },
      ),
      (
        "an event's parameters are not an object",
        {
          'name': 'trip_map',
          'events': [
            {'name': 'select_place', 'parameters': 'name'},
          ],
        },
      ),
    ];

    for (final (reason, json) in cases) {
      test('AIUIComponentDefinition.fromJson throws a FormatException because $reason', () {
        expect(() => AIUIComponentDefinition.fromJson(json), throwsA(isA<FormatException>()));
      });
    }
  });
}

const _string = {'type': 'string'};

Map<String, Object?> _definition({required Map<String, Object?> parameters}) => {
  'name': 'card',
  'description': 'A card.',
  'parameters': parameters,
};

Map<String, Object?> _objectSchema(Map<String, Object?> properties, {List<String>? order}) => {
  'type': 'object',
  'properties': properties,
  'x-order': ?order,
};

// A place card: a required, an optional and a nested parameter, and an event.
AIUIComponentDefinition _placeCard() => AIUIComponentDefinition(
  name: 'place_card',
  description: 'A photo and a short summary of a place.',
  parameters: [
    const AIUIParameter.required('title', AIUIParameterType.string, description: "The place's Wikipedia title."),
    const AIUIParameter.optional('visit_on', AIUIParameterType.date),
    AIUIParameter.optional('tags', AIUIParameterType.array(AIUIParameterType.enumeration(['sight', 'food', 'nature']))),
  ],
  events: const [AIUIComponentEvent(name: 'ask_about', description: 'The person asks about the place.')],
);

// A trip map: a list of objects, and an event with parameters.
AIUIComponentDefinition _tripMap() => AIUIComponentDefinition(
  name: 'trip_map',
  description: 'A map of a plan.',
  parameters: [
    AIUIParameter.required(
      'places',
      AIUIParameterType.array(
        AIUIParameterType.object(const [
          AIUIParameter.required('name', AIUIParameterType.string),
          AIUIParameter.required('latitude', AIUIParameterType.number),
          AIUIParameter.required('longitude', AIUIParameterType.number),
        ]),
      ),
    ),
  ],
  events: const [
    AIUIComponentEvent(
      name: 'select_place',
      description: 'The person taps a pin.',
      parameters: [
        AIUIParameter.required('name', AIUIParameterType.string),
        AIUIParameter.optional('day', AIUIParameterType.date),
      ],
    ),
  ],
);

// The trip map as a backend might write it: no description, and no order.
AIUIComponentDefinition _unorderedTripMap() => AIUIComponentDefinition(
  name: 'trip_map',
  description: '',
  parameters: [
    AIUIParameter.required('places', AIUIParameterType.array(AIUIParameterType.string)),
    const AIUIParameter.optional('zoom', AIUIParameterType.number),
  ],
  events: const [
    AIUIComponentEvent(
      name: 'select_place',
      description: '',
      parameters: [AIUIParameter.optional('name', AIUIParameterType.string)],
    ),
  ],
);

// The place card of the spec's example.
AIUIComponentDefinition _specPlaceCard() => const AIUIComponentDefinition(
  name: 'place_card',
  description:
      'One place of a plan, with its photo and a short summary, which the phone loads from Wikipedia, so it needs '
      'no image URL.',
  parameters: [
    AIUIParameter.required(
      'title',
      AIUIParameterType.string,
      description: "The place's exact English Wikipedia article title",
    ),
    AIUIParameter.optional(
      'note',
      AIUIParameterType.string,
      description: 'One short line about it for this plan, such as "Best at sunset"',
    ),
  ],
  events: [AIUIComponentEvent(name: 'ask_about', description: 'Tapping the card asks you about the place.')],
);
