// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/portable_component.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

void main() {
  test('snake case words are joined in upper camel case', () {
    expect(portableTypeName('place_card'), 'PlaceCard');
  });

  test('kebab case words are joined in upper camel case', () {
    expect(portableTypeName('place-card'), 'PlaceCard');
  });

  test('words split at spaces are joined in upper camel case', () {
    expect(portableTypeName('place card'), 'PlaceCard');
  });

  test('mixed separators are all separators', () {
    expect(portableTypeName('place_card-with details'), 'PlaceCardWithDetails');
  });

  test('repeated and leading and trailing separators leave no empty words', () {
    expect(portableTypeName('__place--card  '), 'PlaceCard');
  });

  test('a name that is already upper camel case is unchanged', () {
    expect(portableTypeName('PlaceCard'), 'PlaceCard');
  });

  test('only the first letter of a word changes case', () {
    expect(portableTypeName('place_cARD'), 'PlaceCARD');
  });

  test('a letter that is upper case inside a word is kept', () {
    expect(portableTypeName('placeCard'), 'PlaceCard');
  });

  test('a one letter name is upper case', () {
    expect(portableTypeName('a'), 'A');
  });

  test('digits are kept', () {
    expect(portableTypeName('place_card_2'), 'PlaceCard2');
  });

  test('a name of separators only is empty', () {
    expect(portableTypeName('_-_'), isEmpty);
  });

  test('a first letter outside ASCII is upper cased', () {
    expect(portableTypeName('élan_vital'), 'ÉlanVital');
  });

  test('a first character outside the basic plane is kept whole', () {
    expect(portableTypeName('😀_card'), '😀Card');
  });

  test('an enum of strings is an enumeration', () {
    expect(
      portablePropType({
        'enum': ['a', 'b'],
      }),
      PropType.enumeration(['a', 'b']),
    );
  });

  test('an enum that is not only strings is read by its type', () {
    expect(
      portablePropType({
        'enum': ['a', 1],
        'type': 'string',
      }),
      PropType.string,
    );
  });

  test('an enum that is not only strings with no type takes any value', () {
    expect(
      portablePropType({
        'enum': ['a', null],
      }),
      PropType.any,
    );
  });

  test('an empty enum is read by its type', () {
    expect(portablePropType({'enum': <Object?>[], 'type': 'number'}), PropType.number);
  });

  test('an enum that is not a list is read by its type', () {
    expect(portablePropType({'enum': 'ab', 'type': 'number'}), PropType.number);
  });

  test('an enum comes before anyOf', () {
    final schema = {
      'enum': ['a'],
      'anyOf': [
        {'type': 'number'},
      ],
    };

    expect(portablePropType(schema), PropType.enumeration(['a']));
  });

  test('a string const is a literal', () {
    expect(portablePropType({'const': 'a'}), PropType.literal('a'));
  });

  test('a const that is not a string is read by its type', () {
    expect(portablePropType({'const': 1, 'type': 'number'}), PropType.number);
  });

  test('a const comes before the type', () {
    expect(portablePropType({'const': 'a', 'type': 'number'}), PropType.literal('a'));
  });

  test('a string is a string', () {
    expect(portablePropType({'type': 'string'}), PropType.string);
  });

  test('a number is a number', () {
    expect(portablePropType({'type': 'number'}), PropType.number);
  });

  test('an integer is a number', () {
    expect(portablePropType({'type': 'integer'}), PropType.number);
  });

  test('a boolean is a boolean', () {
    expect(portablePropType({'type': 'boolean'}), PropType.boolean);
  });

  test('an array is an array of its items', () {
    expect(
      portablePropType({
        'type': 'array',
        'items': {'type': 'number'},
      }),
      PropType.array(PropType.number),
    );
  });

  test('an array without items is an array of any', () {
    expect(portablePropType({'type': 'array'}), PropType.array(PropType.any));
  });

  test('an array whose items are not a schema is an array of any', () {
    expect(portablePropType({'type': 'array', 'items': 'x'}), PropType.array(PropType.any));
  });

  test('an object with properties is an object of fields', () {
    final schema = {
      'type': 'object',
      'properties': {
        'a': {'type': 'string'},
        'b': {'type': 'number'},
      },
      'required': ['a'],
    };

    expect(
      portablePropType(schema),
      PropType.object([PropSchema('a', PropType.string), PropSchema('b', PropType.number, required: false)]),
    );
  });

  test('an object with properties and additionalProperties is an object of its fields', () {
    final schema = {
      'type': 'object',
      'properties': {
        'a': {'type': 'string'},
      },
      'additionalProperties': {'type': 'number'},
    };

    expect(portablePropType(schema), PropType.object([PropSchema('a', PropType.string, required: false)]));
  });

  test('an object with no properties and a schema for additionalProperties is a record', () {
    final schema = {
      'type': 'object',
      'additionalProperties': {'type': 'number'},
    };

    expect(portablePropType(schema), PropType.record(PropType.number));
  });

  test('an object with empty properties and a schema for additionalProperties is a record', () {
    final schema = {
      'type': 'object',
      'properties': <String, Object?>{},
      'additionalProperties': {'type': 'number'},
    };

    expect(portablePropType(schema), PropType.record(PropType.number));
  });

  test('an object with additionalProperties that is not a schema takes any value', () {
    expect(portablePropType({'type': 'object', 'additionalProperties': true}), PropType.any);
  });

  test('an object with nothing takes any value', () {
    expect(portablePropType({'type': 'object'}), PropType.any);
  });

  test('an unknown type takes any value', () {
    expect(portablePropType({'type': 'tuple'}), PropType.any);
  });

  test('a schema without a type takes any value', () {
    expect(portablePropType(<String, Object?>{}), PropType.any);
  });

  test('a list of a type and null is that type', () {
    expect(
      portablePropType({
        'type': ['string', 'null'],
      }),
      PropType.string,
    );
  });

  test('a list of null and a type is that type', () {
    expect(
      portablePropType({
        'type': ['null', 'number'],
      }),
      PropType.number,
    );
  });

  test('a list of one type is that type', () {
    expect(
      portablePropType({
        'type': ['boolean'],
      }),
      PropType.boolean,
    );
  });

  test('a list of two types besides null takes any value', () {
    expect(
      portablePropType({
        'type': ['string', 'number'],
      }),
      PropType.any,
    );
  });

  test('a list of null only takes any value', () {
    expect(
      portablePropType({
        'type': ['null'],
      }),
      PropType.any,
    );
  });

  test('an anyOf of one type besides null is that type', () {
    final schema = {
      'anyOf': [
        {'type': 'string'},
        {'type': 'null'},
      ],
    };

    expect(portablePropType(schema), PropType.string);
  });

  test('an anyOf of one option is that option', () {
    final schema = {
      'anyOf': [
        {'type': 'string'},
      ],
    };

    expect(portablePropType(schema), PropType.string);
  });

  test('an anyOf of several options is a union of them without null', () {
    final schema = {
      'anyOf': [
        {'type': 'string'},
        {'type': 'null'},
        {'type': 'number'},
      ],
    };

    expect(portablePropType(schema), PropType.union([PropType.string, PropType.number]));
  });

  test('a oneOf is read like an anyOf', () {
    final schema = {
      'oneOf': [
        {'type': 'string'},
        {'type': 'number'},
      ],
    };

    expect(portablePropType(schema), PropType.union([PropType.string, PropType.number]));
  });

  test('an anyOf with an option that takes any value takes any value', () {
    final schema = {
      'anyOf': [
        {'type': 'string'},
        <String, Object?>{},
      ],
    };

    expect(portablePropType(schema), PropType.any);
  });

  test('an anyOf of null only takes any value', () {
    final schema = {
      'anyOf': [
        {'type': 'null'},
      ],
    };

    expect(portablePropType(schema), PropType.any);
  });

  test('an anyOf option that is not a schema takes any value', () {
    final schema = {
      'anyOf': [
        {'type': 'string'},
        5,
      ],
    };

    expect(portablePropType(schema), PropType.any);
  });

  test('an empty anyOf is read by its type', () {
    expect(portablePropType({'anyOf': <Object?>[], 'type': 'number'}), PropType.number);
  });

  test('an anyOf comes before the type', () {
    final schema = {
      'type': 'number',
      'anyOf': [
        {'type': 'string'},
      ],
    };

    expect(portablePropType(schema), PropType.string);
  });

  test('a union of arrays keeps the options as arrays', () {
    final schema = {
      'anyOf': [
        {
          'type': 'array',
          'items': {'type': 'string'},
        },
        {'type': 'boolean'},
      ],
    };

    expect(
      portablePropType(schema),
      PropType.union([PropType.array(PropType.string), PropType.boolean]),
    );
  });

  test('a value that is not a schema takes any value', () {
    for (final schema in [
      null,
      5,
      'string',
      true,
      <Object?>[],
      <Object?>['string'],
    ]) {
      expect(portablePropType(schema), PropType.any, reason: '$schema');
    }
  });

  test('the name is turned into one a program calls', () {
    expect(portableComponentSchema({'name': 'place_card'}).name, 'PlaceCard');
  });

  test('a definition of a name only has no props', () {
    expect(portableComponentSchema({'name': 'place_card'}).props, isEmpty);
  });

  test('a definition of a name only has no description', () {
    expect(portableComponentSchema({'name': 'place_card'}).description, isEmpty);
  });

  test('a definition without a name is a format error', () {
    expect(() => portableComponentSchema({'description': 'x'}), throwsA(isA<FormatException>()));
  });

  test('a definition with an empty name is a format error', () {
    expect(() => portableComponentSchema({'name': ''}), throwsA(isA<FormatException>()));
  });

  test('a definition whose name is not a string is a format error', () {
    for (final name in [
      null,
      1,
      1.5,
      true,
      <Object?>['a'],
      <String, Object?>{'a': 1},
    ]) {
      expect(() => portableComponentSchema({'name': name}), throwsA(isA<FormatException>()), reason: '$name');
    }
  });

  test('a name of separators only is read as an empty component name', () {
    expect(portableComponentSchema({'name': '_'}).name, isEmpty);
  });

  test('a name of whitespace only is read as an empty component name', () {
    expect(portableComponentSchema({'name': ' '}).name, isEmpty);
  });

  test('the props are the properties in the order of x-order and then as written', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {'a': _string, 'b': _string, 'c': _string, 'd': _string},
        order: ['c', 'a'],
      ),
    );

    expect([for (final prop in schema.props) prop.name], ['c', 'a', 'b', 'd']);
  });

  test('without x-order the props are in the order written', () {
    final schema = portableComponentSchema(_definition(properties: {'b': _string, 'a': _string}));

    expect([for (final prop in schema.props) prop.name], ['b', 'a']);
  });

  test('an x-order name that is not a property is ignored', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {'a': _string, 'b': _string},
        order: ['z', 'b'],
      ),
    );

    expect([for (final prop in schema.props) prop.name], ['b', 'a']);
  });

  test('an x-order name given twice makes one prop', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {'a': _string, 'b': _string},
        order: ['b', 'b', 'a'],
      ),
    );

    expect([for (final prop in schema.props) prop.name], ['b', 'a']);
  });

  test('an x-order entry that is not a string is ignored', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {'a': _string, 'b': _string},
        order: [1, null, 'b'],
      ),
    );

    expect([for (final prop in schema.props) prop.name], ['b', 'a']);
  });

  test('a property is required when required names it', () {
    final schema = portableComponentSchema(
      _definition(properties: {'a': _string, 'b': _string}, required: ['a']),
    );

    expect([for (final prop in schema.props) prop.required], [true, false]);
  });

  test('a required entry that is not a string is ignored', () {
    final schema = portableComponentSchema(
      _definition(properties: {'a': _string}, required: [1, null]),
    );

    expect(schema.props.single.required, isFalse);
  });

  test('a property with a default is optional even when required names it', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {'type': 'string', 'default': 'x'},
        },
        required: ['a'],
      ),
    );

    expect(schema.props.single, PropSchema('a', PropType.string, required: false, defaultValue: 'x'));
  });

  test('a property with a null default has a default', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {'type': 'string', 'default': null},
        },
      ),
    );

    expect(schema.props.single, PropSchema('a', PropType.string, required: false, defaultValue: null));
  });

  test('a property with a list default keeps it', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {
            'type': 'array',
            'default': ['x'],
          },
        },
      ),
    );

    expect(schema.props.single.defaultValue, ['x']);
  });

  test('a property is read as the closest prop type', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {'type': 'integer'},
          'b': {
            'enum': ['x', 'y'],
          },
        },
      ),
    );

    expect(
      [for (final prop in schema.props) prop.type],
      [
        PropType.number,
        PropType.enumeration(['x', 'y']),
      ],
    );
  });

  test('a property that can not be described takes any value', () {
    final schema = portableComponentSchema(_definition(properties: {'a': 5, 'b': null, 'c': <String, Object?>{}}));

    expect([for (final prop in schema.props) prop.type], [PropType.any, PropType.any, PropType.any]);
  });

  test('a nested object takes its required fields from its own required', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {
            'type': 'object',
            'properties': {'x': _string, 'y': _string},
            'required': ['y'],
          },
        },
        required: ['x'],
      ),
    );

    expect(
      schema.props.single.type,
      PropType.object([PropSchema('x', PropType.string, required: false), PropSchema('y', PropType.string)]),
    );
  });

  test('the description is the component description as a sentence', () {
    expect(portableComponentSchema({'name': 'a', 'description': 'A photo'}).description, 'A photo.');
  });

  test('the description adds each property description as name and description', () {
    final schema = portableComponentSchema(
      _definition(
        description: 'A card',
        properties: {
          'title': {'type': 'string', 'description': 'The title'},
          'plain': _string,
        },
      ),
    );

    expect(schema.description, 'A card. title: The title.');
  });

  test('the property descriptions follow the order of the props', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {'description': 'First'},
          'b': {'description': 'Second'},
        },
        order: ['b'],
      ),
    );

    expect(schema.description, 'b: Second. a: First.');
  });

  test('the description adds each event description last', () {
    final schema = portableComponentSchema({
      'name': 'a',
      'description': 'A card',
      'parameters': _parameters({
        'title': {'description': 'The title'},
      }),
      'events': [
        {'name': 'tap', 'description': 'The person taps'},
        {'name': 'close', 'description': 'The person closes'},
      ],
    });

    expect(schema.description, 'A card. title: The title. The person taps. The person closes.');
  });

  test('an event without a description adds nothing', () {
    final schema = portableComponentSchema({
      'name': 'a',
      'description': 'A card',
      'events': [
        {'name': 'tap'},
      ],
    });

    expect(schema.description, 'A card.');
  });

  test('whitespace in a description is collapsed to one line', () {
    final schema = portableComponentSchema({'name': 'a', 'description': '  A\n\tcard   with\r\nlines  '});

    expect(schema.description, 'A card with lines.');
  });

  test('a no-break space in a description is collapsed like a space', () {
    final schema = portableComponentSchema({'name': 'a', 'description': 'A\u00A0\u00A0card\u00A0'});

    expect(schema.description, 'A card.');
  });

  test('an ideographic space in a description is collapsed like a space', () {
    final schema = portableComponentSchema({'name': 'a', 'description': '\u3000A\u3000\u3000card'});

    expect(schema.description, 'A card.');
  });

  test('whitespace in a property description is collapsed to one line', () {
    final schema = portableComponentSchema(
      _definition(
        properties: {
          'a': {'description': 'The\n  title'},
        },
      ),
    );

    expect(schema.description, 'a: The title.');
  });

  test('a description that ends in a period gets no other', () {
    expect(portableComponentSchema({'name': 'a', 'description': 'A card.'}).description, 'A card.');
  });

  test('a description that ends in an exclamation mark gets no period', () {
    expect(portableComponentSchema({'name': 'a', 'description': 'A card!'}).description, 'A card!');
  });

  test('a description that ends in a question mark gets no period', () {
    expect(portableComponentSchema({'name': 'a', 'description': 'A card?'}).description, 'A card?');
  });

  test('a description that ends in whitespace after a period gets no other', () {
    expect(portableComponentSchema({'name': 'a', 'description': 'A card.  \n'}).description, 'A card.');
  });

  test('a description that ends in a colon gets a period', () {
    expect(portableComponentSchema({'name': 'a', 'description': 'A card:'}).description, 'A card:.');
  });

  test('a blank description adds nothing', () {
    final schema = portableComponentSchema({
      'name': 'a',
      'description': '   ',
      'events': [
        {'description': ' \n '},
      ],
    });

    expect(schema.description, isEmpty);
  });

  test('a blank description does not leave a gap before the next one', () {
    final schema = portableComponentSchema({
      'name': 'a',
      'description': '  ',
      'events': [
        {'description': 'Tap'},
      ],
    });

    expect(schema.description, 'Tap.');
  });

  test('a definition read from JSON text gives the same schema as one built in code', () {
    final decoded = jsonDecode(
      '{"name": "place_card", "description": "A photo", "parameters": {"type": "object", '
      '"properties": {"title": {"type": "string"}}, "required": ["title"], "x-order": ["title"]}, '
      '"events": [{"name": "ask_about", "description": "The person asks"}]}',
    );

    final schema = portableComponentSchema(decoded as Map<String, Object?>);

    expect(
      schema,
      ComponentSchema(
        'PlaceCard',
        description: 'A photo. The person asks.',
        props: [PropSchema('title', PropType.string)],
      ),
    );
  });

  test('parameters that are not an object give no props', () {
    for (final parameters in _junk()) {
      final schema = portableComponentSchema({'name': 'a', 'parameters': parameters});

      expect(schema.props, isEmpty, reason: '$parameters');
    }
  });

  test('properties that are not an object give no props', () {
    for (final properties in _junk().where((value) => value is! Map)) {
      final schema = portableComponentSchema({
        'name': 'a',
        'parameters': {'properties': properties},
      });

      expect(schema.props, isEmpty, reason: '$properties');
    }
  });

  test('an x-order that is not a list is ignored', () {
    for (final order in _junk().where((value) => value is! List)) {
      final schema = portableComponentSchema(
        _definition(properties: {'b': _string, 'a': _string}, order: order),
      );

      expect([for (final prop in schema.props) prop.name], ['b', 'a'], reason: '$order');
    }
  });

  test('a required that is not a list leaves every prop optional', () {
    for (final required in _junk().where((value) => value is! List)) {
      final schema = portableComponentSchema(_definition(properties: {'a': _string}, required: required));

      expect(schema.props.single.required, isFalse, reason: '$required');
    }
  });

  test('events that are not a list add no description', () {
    for (final events in _junk().where((value) => value is! List)) {
      final schema = portableComponentSchema({'name': 'a', 'description': 'A', 'events': events});

      expect(schema.description, 'A.', reason: '$events');
    }
  });

  test('an event that is not an object adds no description', () {
    final schema = portableComponentSchema({
      'name': 'a',
      'description': 'A',
      'events': [null, 1, 'tap', <Object?>[], true],
    });

    expect(schema.description, 'A.');
  });

  test('an event description that is not a string adds no description', () {
    for (final description in _junk().where((value) => value is! String)) {
      final schema = portableComponentSchema({
        'name': 'a',
        'description': 'A',
        'events': [
          {'description': description},
        ],
      });

      expect(schema.description, 'A.', reason: '$description');
    }
  });

  test('a description that is not a string adds no description', () {
    for (final description in _junk().where((value) => value is! String)) {
      final schema = portableComponentSchema({'name': 'a', 'description': description});

      expect(schema.description, isEmpty, reason: '$description');
    }
  });

  test('a property description that is not a string adds no description', () {
    for (final description in _junk().where((value) => value is! String)) {
      final schema = portableComponentSchema(
        _definition(
          properties: {
            'a': {'description': description},
          },
        ),
      );

      expect(schema.description, isEmpty, reason: '$description');
    }
  });

  test('a property that is not an object is a prop that takes any value', () {
    for (final property in _junk().where((value) => value is! Map)) {
      final schema = portableComponentSchema(_definition(properties: {'a': property}, required: ['a']));

      expect(schema.props.single, PropSchema('a', PropType.any), reason: '$property');
    }
  });

  test('a type that is not a string or a list of strings takes any value', () {
    for (final value in _junk().where((value) => value is! String && value is! List)) {
      expect(portablePropType({'type': value}), PropType.any, reason: '$value');
    }
  });

  test('a type that is a string the schema does not know takes any value', () {
    for (final value in _junk().whereType<String>()) {
      expect(portablePropType({'type': value}), PropType.any, reason: value);
    }
  });

  test('a type that is a list takes any value unless it names one type besides null', () {
    for (final value in _junk().whereType<List>()) {
      expect(portablePropType({'type': value}), PropType.any, reason: '$value');
    }
  });

  test('an enum that is not a non-empty list of strings takes any value', () {
    for (final value in _junk().where((value) => !_isEnumValues(value))) {
      expect(portablePropType({'enum': value}), PropType.any, reason: '$value');
    }
  });

  test('an enum that is a non-empty list of strings is an enumeration', () {
    expect(portablePropType({'enum': _junk().firstWhere(_isEnumValues)}), PropType.enumeration(['a', 'b']));
  });

  test('a const that is not a string takes any value', () {
    for (final value in _junk().where((value) => value is! String)) {
      expect(portablePropType({'const': value}), PropType.any, reason: '$value');
    }
  });

  test('a const that is a string is a literal', () {
    for (final value in _junk().whereType<String>()) {
      expect(portablePropType({'const': value}), PropType.literal(value), reason: value);
    }
  });

  test('an anyOf of junk takes any value', () {
    for (final value in _junk()) {
      expect(portablePropType({'anyOf': value}), PropType.any, reason: '$value');
    }
  });

  test('items of junk are items of any value', () {
    for (final value in _junk()) {
      expect(portablePropType({'type': 'array', 'items': value}), PropType.array(PropType.any), reason: '$value');
    }
  });

  test('properties that are not an object take any value', () {
    for (final value in _junk().where((value) => value is! Map)) {
      expect(portablePropType({'type': 'object', 'properties': value}), PropType.any, reason: '$value');
    }
  });

  test('properties that are an object of junk are fields that take any value', () {
    final type = portablePropType({
      'type': 'object',
      'properties': {'a': 1, 'b': <String, Object?>{}},
    });

    expect(
      type,
      PropType.object([PropSchema('a', PropType.any, required: false), PropSchema('b', PropType.any, required: false)]),
    );
  });

  test('additionalProperties that are not an object take any value', () {
    for (final value in _junk().where((value) => value is! Map)) {
      expect(portablePropType({'type': 'object', 'additionalProperties': value}), PropType.any, reason: '$value');
    }
  });

  test('additionalProperties that are an empty object are a record of any value', () {
    expect(
      portablePropType({'type': 'object', 'additionalProperties': <String, Object?>{}}),
      PropType.record(PropType.any),
    );
  });

  test('every wrong typed part of a definition reads as props of the types the schema allows', () {
    for (final key in ['description', 'parameters', 'events']) {
      for (final value in _junk()) {
        final schema = portableComponentSchema({'name': 'a', key: value});

        expect(schema.props.every((prop) => _isReadType(prop.type)), isTrue, reason: '$key: $value');
      }
    }
  });

  test('every wrong typed part of a definition reads as a description on one line', () {
    for (final key in ['description', 'parameters', 'events']) {
      for (final value in _junk()) {
        final schema = portableComponentSchema({'name': 'a', key: value});

        expect(schema.description, isNot(contains('\n')), reason: '$key: $value');
      }
    }
  });

  test('every wrong typed part of a definition reads without throwing when shown', () {
    for (final key in ['description', 'parameters', 'events']) {
      for (final value in _junk()) {
        expect(
          () => _show(portableComponentSchema({'name': 'a', key: value})),
          returnsNormally,
          reason: '$key: $value',
        );
      }
    }
  });

  test('random definitions read as props of the types the schema allows', () {
    final random = Random(20261106);

    for (var i = 0; i < 1000; i++) {
      final definition = <String, Object?>{
        'name': 'component_$i',
        for (final key in ['description', 'parameters', 'events'])
          if (random.nextBool()) key: _randomJson(random, 4),
      };

      final schema = portableComponentSchema(definition);

      expect(schema.props.every((prop) => _isReadType(prop.type)), isTrue, reason: '$definition');
    }
  });

  test('random definitions read as a description on one line', () {
    final random = Random(20261107);

    for (var i = 0; i < 1000; i++) {
      final definition = <String, Object?>{
        'name': 'component_$i',
        for (final key in ['description', 'parameters', 'events'])
          if (random.nextBool()) key: _randomJson(random, 4),
      };

      expect(portableComponentSchema(definition).description, isNot(matches(RegExp(r'[\n\r]'))), reason: '$definition');
    }
  });

  test('random definitions read without throwing when shown', () {
    final random = Random(20261108);

    for (var i = 0; i < 1000; i++) {
      final definition = <String, Object?>{
        'name': 'component_$i',
        for (final key in ['description', 'parameters', 'events'])
          if (random.nextBool()) key: _randomJson(random, 4),
      };

      expect(() => _show(portableComponentSchema(definition)), returnsNormally, reason: '$definition');
    }
  });

  test('random schemas read as a prop type the schema allows', () {
    final random = Random(7);

    for (var i = 0; i < 1000; i++) {
      final schema = _randomJson(random, 5);

      expect(_isReadType(portablePropType(schema)), isTrue, reason: '$schema');
    }
  });

  test('random parameters read as one prop for each of the properties', () {
    final random = Random(42);

    for (var i = 0; i < 1000; i++) {
      final properties = _randomJson(random, 3, keys: _schemaKeys);
      final definition = <String, Object?>{
        'name': 'a',
        'parameters': {
          'properties': properties,
          'x-order': _randomJson(random, 2),
          'required': _randomJson(random, 2),
        },
      };

      final schema = portableComponentSchema(definition);

      expect(schema.props, hasLength(properties is Map ? properties.length : 0), reason: '$definition');
    }
  });

  test('a definition with a value that is not JSON data is a format error', () {
    expect(
      () => portableComponentSchema({'name': 'a', 'description': DateTime(2026)}),
      throwsA(isA<FormatException>()),
    );
  });

  test('a definition nested deeper than the JSON depth limit is a format error', () {
    final definition = {'name': 'a', 'parameters': _nested(OpenUIValue.maxJsonDepth)};

    expect(() => portableComponentSchema(definition), throwsA(isA<FormatException>()));
  });

  test('a property of arrays nested 600 levels deep is a format error', () {
    expect(() => portableComponentSchema(_arrayDefinition(600)), throwsA(isA<FormatException>()));
  });

  test('a property of arrays nested well under the depth limit is read as arrays', () {
    final type = portableComponentSchema(_arrayDefinition(20)).props.single.type;

    expect(type.signature, 'string${'[]' * 20}');
  });

  test('a definition nested as deep as the JSON depth limit allows is read', () {
    final definition = {'name': 'a', 'parameters': _nested(OpenUIValue.maxJsonDepth - 1)};

    expect(portableComponentSchema(definition).name, 'A');
  });
}

const _string = <String, Object?>{'type': 'string'};

// JSON values of every type, for the places that expect one.
List<Object?> _junk() => <Object?>[
  null,
  0,
  1.5,
  'text',
  '',
  true,
  false,
  <Object?>[],
  <Object?>[1, 'a', null],
  <Object?>['a', 'b'],
  <Object?>[<String, Object?>{}],
  <String, Object?>{},
  <String, Object?>{'a': 1},
  <String, Object?>{'a': <String, Object?>{}},
];

const _schemaKeys = [
  'type',
  'enum',
  'const',
  'anyOf',
  'oneOf',
  'items',
  'properties',
  'additionalProperties',
  'required',
  'default',
  'description',
  'x-order',
];

Map<String, Object?> _parameters(Map<String, Object?> properties, {Object? order, Object? required}) {
  return {
    'type': 'object',
    'properties': properties,
    'x-order': ?order,
    'required': ?required,
  };
}

Map<String, Object?> _definition({
  String description = '',
  Map<String, Object?> properties = const {},
  Object? order,
  Object? required,
}) {
  return {
    'name': 'a',
    if (description.isNotEmpty) 'description': description,
    'parameters': _parameters(properties, order: order, required: required),
  };
}

// Reads everything a schema can show, so a read that is only lazily wrong shows.
Object _show(ComponentSchema schema) => [schema.signature, schema.jsonSchema];

Object? _randomJson(Random random, int depth, {List<String> keys = _schemaKeys}) {
  final kinds = depth <= 0 ? 5 : 8;
  switch (random.nextInt(kinds)) {
    case 0:
      return null;
    case 1:
      return random.nextInt(10);
    case 2:
      return random.nextBool();
    case 3:
      return ['string', 'number', 'integer', 'boolean', 'array', 'object', 'null', 'a', 'b', ''][random.nextInt(10)];
    case 4:
      return random.nextDouble();
    case 5:
      return <Object?>[for (var i = 0; i < random.nextInt(4); i++) _randomJson(random, depth - 1, keys: keys)];
    default:
      return <String, Object?>{
        for (var i = 0; i < random.nextInt(5); i++)
          keys[random.nextInt(keys.length)]: _randomJson(random, depth - 1, keys: keys),
      };
  }
}

// Whether `values` is what a schema's `enum` reads as an enumeration of.
bool _isEnumValues(Object? values) {
  return values is List<Object?> && values.isNotEmpty && values.every((value) => value is String);
}

// Whether `type` is one a definition can be read as: no component or action.
bool _isReadType(PropType type) {
  return switch (type) {
    ScalarType() => type != PropType.action,
    EnumerationType() || LiteralType() => true,
    ArrayType(:final items) => _isReadType(items),
    RecordType(:final value) => _isReadType(value),
    ObjectType(:final fields) => fields.every((field) => _isReadType(field.type)),
    UnionType(:final options) => options.every(_isReadType),
    ComponentType() || ActionsType() => false,
  };
}

// A definition with one property, a list of lists `levels` deep, built from the
// inside out.
Map<String, Object?> _arrayDefinition(int levels) {
  var schema = <String, Object?>{'type': 'string'};
  for (var i = 0; i < levels; i++) {
    schema = {'type': 'array', 'items': schema};
  }
  return _definition(properties: {'x': schema});
}

// A map of `depth` levels, built from the inside out.
Map<String, Object?> _nested(int depth) {
  var value = <String, Object?>{};
  for (var i = 1; i < depth; i++) {
    value = {'k': value};
  }
  return value;
}
