import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component_definition.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';

import 'genui_fixtures.dart';

void main() {
  for (final fixture in const [
    'definition_place_card.json',
    'definition_trip_map.json',
    'definition_place_card_spec.json',
  ]) {
    test('AIUIComponentDefinition writes back $fixture exactly as it read it', () {
      final json = genuiFixture(fixture);

      final written = overTheWire(AIUIComponentDefinition.fromJson(json).toJson());

      expect(written, json);
    });
  }

  test('AIUIComponentDefinition reads back a definition from the JSON it writes', () {
    final tripMap = _tripMap();

    final read = AIUIComponentDefinition.fromJson(overTheWire(tripMap.toJson())! as Map<String, Object?>);

    expect(read, tripMap);
  });
}

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
