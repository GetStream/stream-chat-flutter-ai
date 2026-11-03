import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';

void main() {
  final schemas = <(String, AIUIParameterType, Map<String, Object?>)>[
    ('string', AIUIParameterType.string, {'type': 'string'}),
    ('number', AIUIParameterType.number, {'type': 'number'}),
    ('integer', AIUIParameterType.integer, {'type': 'integer'}),
    ('boolean', AIUIParameterType.boolean, {'type': 'boolean'}),
    ('date', AIUIParameterType.date, {'type': 'string', 'format': 'date'}),
    ('dateTime', AIUIParameterType.dateTime, {'type': 'string', 'format': 'date-time'}),
    ('url', AIUIParameterType.url, {'type': 'string', 'format': 'uri'}),
    (
      'enumeration',
      AIUIParameterType.enumeration(['sight', 'food']),
      {
        'type': 'string',
        'enum': ['sight', 'food'],
      },
    ),
    (
      'array',
      AIUIParameterType.array(AIUIParameterType.number),
      {
        'type': 'array',
        'items': {'type': 'number'},
      },
    ),
    (
      'object',
      AIUIParameterType.object(const [
        AIUIParameter.required('name', AIUIParameterType.string, description: 'The name'),
        AIUIParameter.optional('day', AIUIParameterType.date),
      ]),
      {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'The name'},
          'day': {'type': 'string', 'format': 'date'},
        },
        'required': ['name'],
        'x-order': ['name', 'day'],
      },
    ),
  ];

  for (final (name, type, schema) in schemas) {
    test('AIUIParameterType.$name is the JSON Schema the other platforms write', () {
      expect(type.schema, schema);
    });
  }

  test('AIUIParameterType.enumeration keeps its values when the list it was given changes', () {
    final values = ['sight'];
    final type = AIUIParameterType.enumeration(values);

    values.add('food');

    expect(type.schema['enum'], ['sight']);
  });

  for (final (name, type) in [
    ('enumeration', AIUIParameterType.enumeration(['sight'])),
    ('array', AIUIParameterType.array(AIUIParameterType.string)),
    ('object', AIUIParameterType.object(const [AIUIParameter.required('name', AIUIParameterType.string)])),
  ]) {
    test("AIUIParameterType.$name gives a schema that can't be changed", () {
      expect(() => type.schema['type'] = 'number', throwsA(isA<UnsupportedError>()));
    });
  }

  test('AIUIParameterTypes with the same schema are equal, compared deeply', () {
    final type = AIUIParameterType.enumeration(['sight', 'food']);

    expect(type, AIUIParameterType.enumeration(['sight', 'food']));
  });

  test('AIUIParameter.required makes a parameter the agent must fill in', () {
    const parameter = AIUIParameter.required('title', AIUIParameterType.string);

    expect(parameter.isRequired, isTrue);
  });

  test('AIUIParameter.optional makes a parameter the agent may leave out', () {
    const parameter = AIUIParameter.optional('note', AIUIParameterType.string);

    expect(parameter.isRequired, isFalse);
  });

  test('AIUIParameter is required by default', () {
    const parameter = AIUIParameter(name: 'title', type: AIUIParameterType.string);

    expect(parameter.isRequired, isTrue);
  });
}
