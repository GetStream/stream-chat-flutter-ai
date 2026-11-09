import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component_definition.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';

import 'genui_fixtures.dart';

void main() {
  test('AIUIComponentDefinition.toJson writes its parameters as a JSON Schema object that keeps their order', () {
    final placeCard = _placeCard();

    final json = overTheWire(placeCard.toJson());

    expect(json, genuiFixture('definition_place_card.json'));
  });

  test("AIUIComponentDefinition.toJson keeps the order of an object's fields and of an event's parameters", () {
    final tripMap = _tripMap();

    final json = overTheWire(tripMap.toJson());

    expect(json, genuiFixture('definition_trip_map.json'));
  });

  test('AIUIComponentDefinition.parametersSchema is the JSON Schema object of its parameters', () {
    final placeCard = _placeCard();

    final schema = overTheWire(placeCard.parametersSchema);

    expect(schema, genuiFixture('definition_place_card.json')['parameters']);
  });

  test('AIUIComponentDefinition.toJson writes an empty object schema for a component without parameters', () {
    const definition = AIUIComponentDefinition(name: 'divider', description: 'A line between parts.');

    final json = overTheWire(definition.toJson());

    expect((json! as Map<String, Object?>)['parameters'], {
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <Object?>[],
      'x-order': <Object?>[],
    });
  });

  test('AIUIComponentDefinition.toJson writes no events for a component that reports none', () {
    const definition = AIUIComponentDefinition(name: 'divider', description: 'A line between parts.');

    final json = overTheWire(definition.toJson());

    expect((json! as Map<String, Object?>)['events'], isEmpty);
  });

  test('AIUIComponentDefinition.toJson leaves the parameters out of an event that carries none', () {
    final placeCard = _placeCard();

    final events = (overTheWire(placeCard.toJson())! as Map<String, Object?>)['events']! as List<Object?>;

    expect(events.single, isNot(contains('parameters')));
  });

  test("AIUIComponentDefinition.toJson writes JSON that doesn't change the definition when it is changed", () {
    final placeCard = _placeCard();
    final json = placeCard.toJson();

    _tagsItems(json)['enum'] = ['shopping'];

    expect(placeCard, _placeCard());
  });

  test('AIUIComponentDefinition.toJson writes JSON that can be changed for a definition read from JSON', () {
    final placeCard = AIUIComponentDefinition.fromJson(genuiFixture('definition_place_card.json'));
    final json = placeCard.toJson();

    _tagsItems(json)['minItems'] = 1;

    expect(_tagsItems(json)['minItems'], 1);
  });
}

// The schema of the place card's tags' items in its JSON.
Map<String, Object?> _tagsItems(Map<String, Object?> json) {
  final properties = (json['parameters']! as Map<String, Object?>)['properties']! as Map<String, Object?>;
  return (properties['tags']! as Map<String, Object?>)['items']! as Map<String, Object?>;
}

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
