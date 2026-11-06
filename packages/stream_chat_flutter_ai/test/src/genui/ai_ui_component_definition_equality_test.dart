import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component_definition.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';

void main() {
  test('AIUIComponentDefinitions with the same fields are equal', () {
    final definition = _definition();

    expect(definition, _definition());
  });

  test('AIUIComponentDefinitions with the same fields have the same hash code', () {
    final definition = _definition();

    expect(definition.hashCode, _definition().hashCode);
  });

  final differences = <(String, AIUIComponentDefinition)>[
    ('name', _definition(name: 'trip_map')),
    ('description', _definition(description: 'A map.')),
    ('parameters', _definition(parameters: [_parameter(name: 'note')])),
    ('events', _definition(events: [_event(name: 'dismiss')])),
  ];
  for (final (field, other) in differences) {
    test('AIUIComponentDefinitions that differ only in their $field are not equal', () {
      final definition = _definition();

      expect(definition, isNot(other));
    });
  }

  test('AIUIComponentEvents with the same fields have the same hash code', () {
    final event = _event();

    expect(event.hashCode, _event().hashCode);
  });

  final eventDifferences = <(String, AIUIComponentEvent)>[
    ('name', _event(name: 'dismiss')),
    ('description', _event(description: 'The person taps a pin.')),
    ('parameters', _event(parameters: [_parameter(name: 'note')])),
  ];
  for (final (field, other) in eventDifferences) {
    test('AIUIComponentEvents that differ only in their $field are not equal', () {
      final event = _event();

      expect(event, isNot(other));
    });
  }

  test('AIUIParameters with the same fields have the same hash code', () {
    final parameter = _parameter();

    expect(parameter.hashCode, _parameter().hashCode);
  });

  final parameterDifferences = <(String, AIUIParameter)>[
    ('name', _parameter(name: 'note')),
    ('type', _parameter(type: AIUIParameterType.number)),
    ('description', _parameter(description: 'The title')),
    ('isRequired', _parameter(isRequired: false)),
  ];
  for (final (field, other) in parameterDifferences) {
    test('AIUIParameters that differ only in their $field are not equal', () {
      final parameter = _parameter();

      expect(parameter, isNot(other));
    });
  }
}

// A definition with new lists each time, so equality can't rest on identity.
AIUIComponentDefinition _definition({
  String name = 'place_card',
  String description = 'A place.',
  List<AIUIParameter>? parameters,
  List<AIUIComponentEvent>? events,
}) => AIUIComponentDefinition(
  name: name,
  description: description,
  parameters: parameters ?? [_parameter()],
  events: events ?? [_event()],
);

AIUIComponentEvent _event({
  String name = 'ask_about',
  String description = 'The person asks about the place.',
  List<AIUIParameter>? parameters,
}) => AIUIComponentEvent(name: name, description: description, parameters: parameters ?? [_parameter()]);

AIUIParameter _parameter({
  String name = 'title',
  AIUIParameterType? type,
  String? description,
  bool isRequired = true,
}) => AIUIParameter(
  name: name,
  type: type ?? AIUIParameterType.enumeration(['sight', 'food']),
  description: description,
  isRequired: isRequired,
);
