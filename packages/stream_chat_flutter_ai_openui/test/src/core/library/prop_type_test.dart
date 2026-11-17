// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';

void main() {
  test('a string is shown as string', () {
    expect(PropType.string.signature, 'string');
  });

  test('a string schema is of type string', () {
    expect(PropType.string.jsonSchema, {'type': 'string'});
  });

  test('a number is shown as number', () {
    expect(PropType.number.signature, 'number');
  });

  test('a number schema is of type number', () {
    expect(PropType.number.jsonSchema, {'type': 'number'});
  });

  test('a boolean is shown as boolean', () {
    expect(PropType.boolean.signature, 'boolean');
  });

  test('a boolean schema is of type boolean', () {
    expect(PropType.boolean.jsonSchema, {'type': 'boolean'});
  });

  test('any is shown as any', () {
    expect(PropType.any.signature, 'any');
  });

  test('any has an empty schema', () {
    expect(PropType.any.jsonSchema, isEmpty);
  });

  test('an action is shown as ActionExpression', () {
    expect(PropType.action.signature, 'ActionExpression');
  });

  test('an action schema refers to the ActionExpression definition', () {
    expect(PropType.action.jsonSchema, {r'$ref': r'#/$defs/ActionExpression'});
  });

  test('an action refers to the ActionExpression shape as an action definition', () {
    expect(PropType.action.definitionReferences, [DefinitionReference('ActionExpression', isAction: true)]);
  });

  test('a scalar refers to no definition', () {
    expect(PropType.string.definitionReferences, isEmpty);
  });

  test('toString is the signature', () {
    expect(PropType.array(PropType.string).toString(), 'string[]');
  });

  test('an enumeration is shown as quoted strings joined by bars', () {
    expect(PropType.enumeration(['row', 'column']).signature, '"row" | "column"');
  });

  test('an enumeration is a string schema with its values', () {
    expect(PropType.enumeration(['row', 'column']).jsonSchema, {
      'type': 'string',
      'enum': ['row', 'column'],
    });
  });

  test('an enumeration refers to no definition', () {
    expect(PropType.enumeration(['a']).definitionReferences, isEmpty);
  });

  test('a literal is shown as a quoted string', () {
    expect(PropType.literal('open_url').signature, '"open_url"');
  });

  test('a literal is a string schema with a const', () {
    expect(PropType.literal('open_url').jsonSchema, {'type': 'string', 'const': 'open_url'});
  });

  test('a literal refers to no definition', () {
    expect(PropType.literal('a').definitionReferences, isEmpty);
  });

  test('an array is shown with brackets after its items', () {
    expect(PropType.array(PropType.string).signature, 'string[]');
  });

  test('an array of a union parenthesizes the union', () {
    final type = PropType.array(PropType.union([PropType.string, PropType.number]));

    expect(type.signature, '(string | number)[]');
  });

  test('an array of components is parenthesized like a union', () {
    expect(PropType.array(PropType.components(['A', 'B'])).signature, '(A | B)[]');
  });

  test('an array schema has type array and the schema of its items', () {
    expect(PropType.array(PropType.string).jsonSchema, {
      'type': 'array',
      'items': {'type': 'string'},
    });
  });

  test('an array schema has no minItems when it is not given', () {
    expect(PropType.array(PropType.string).jsonSchema, isNot(contains('minItems')));
  });

  test('an array schema writes minItems before type', () {
    expect(PropType.array(PropType.string, minItems: 1).jsonSchema.keys, ['minItems', 'type', 'items']);
  });

  test('an array schema has the minItems it is given', () {
    expect(PropType.array(PropType.string, minItems: 1).jsonSchema['minItems'], 1);
  });

  test('an array refers to the definitions of its items', () {
    final type = PropType.array(PropType.component('A'));

    expect(type.definitionReferences, [DefinitionReference('A')]);
  });

  test('an object is shown with its fields in braces', () {
    final type = PropType.object([PropSchema('a', PropType.string), PropSchema('b', PropType.number, required: false)]);

    expect(type.signature, '{a: string, b?: number}');
  });

  test('an object schema lists its fields and requires the required ones', () {
    final type = PropType.object([PropSchema('a', PropType.string), PropSchema('b', PropType.number, required: false)]);

    expect(type.jsonSchema, {
      'type': 'object',
      'properties': {
        'a': {'type': 'string'},
        'b': {'type': 'number'},
      },
      'required': ['a'],
      'additionalProperties': false,
    });
  });

  test('an object refers to the definitions of its fields in order', () {
    final type = PropType.object([
      PropSchema('a', PropType.component('A')),
      PropSchema('b', PropType.array(PropType.component('B'))),
    ]);

    expect(type.definitionReferences, [DefinitionReference('A'), DefinitionReference('B')]);
  });

  test('a record is shown as Record of string and its value', () {
    expect(PropType.record(PropType.number).signature, 'Record<string, number>');
  });

  test('a record schema has string property names and its value as additionalProperties', () {
    expect(PropType.record(PropType.number).jsonSchema, {
      'type': 'object',
      'propertyNames': {'type': 'string'},
      'additionalProperties': {'type': 'number'},
    });
  });

  test('a record refers to the definitions of its value', () {
    expect(PropType.record(PropType.component('A')).definitionReferences, [DefinitionReference('A')]);
  });

  test('a component is shown by its name', () {
    expect(PropType.component('Card').signature, 'Card');
  });

  test('a component schema refers to its definition', () {
    expect(PropType.component('Card').jsonSchema, {r'$ref': r'#/$defs/Card'});
  });

  test('a component refers to its own definition, not as an action', () {
    expect(PropType.component('Card').definitionReferences, [DefinitionReference('Card')]);
  });

  test('a union is shown with its options joined by bars', () {
    expect(PropType.union([PropType.string, PropType.number]).signature, 'string | number');
  });

  test('a union schema is the anyOf of its options', () {
    expect(PropType.union([PropType.string, PropType.number]).jsonSchema, {
      'anyOf': [
        {'type': 'string'},
        {'type': 'number'},
      ],
    });
  });

  test('a union refers to the definitions of its options in order', () {
    final type = PropType.union([PropType.component('B'), PropType.string, PropType.component('A')]);

    expect(type.definitionReferences, [DefinitionReference('B'), DefinitionReference('A')]);
  });

  test('components are a union of component types', () {
    expect(PropType.components(['A', 'B']), PropType.union([PropType.component('A'), PropType.component('B')]));
  });

  test('actions are shown with an at sign before each step', () {
    expect(PropType.actions(['CopyToClipboard', 'OpenUrl']).signature, '@CopyToClipboard | @OpenUrl');
  });

  test('actions schema is the anyOf of the step definitions', () {
    expect(PropType.actions(['CopyToClipboard', 'OpenUrl']).jsonSchema, {
      'anyOf': [
        {r'$ref': r'#/$defs/CopyToClipboard'},
        {r'$ref': r'#/$defs/OpenUrl'},
      ],
    });
  });

  test('actions refer to their steps as action definitions', () {
    expect(PropType.actions(['A', 'B']).definitionReferences, [
      DefinitionReference('A', isAction: true),
      DefinitionReference('B', isAction: true),
    ]);
  });

  test('a union loses the options that are the removed components', () {
    final type = PropType.components(['A', 'B', 'C']);

    expect(type.removingComponents({'B'}), PropType.components(['A', 'C']));
  });

  test('a union keeps its options that are not components', () {
    final type = PropType.union([PropType.string, PropType.component('A')]);

    expect(type.removingComponents({'A'}), PropType.union([PropType.string]));
  });

  test('a union that would be left with no option keeps them all', () {
    final type = PropType.components(['A', 'B']);

    expect(type.removingComponents({'A', 'B'}), PropType.components(['A', 'B']));
  });

  test('a union ignores names it has no component for', () {
    final type = PropType.components(['A', 'B']);

    expect(type.removingComponents({'Z'}), PropType.components(['A', 'B']));
  });

  test('removing components keeps a component on its own', () {
    expect(PropType.component('A').removingComponents({'A'}), PropType.component('A'));
  });

  test('an array removes from the union of its items and keeps minItems', () {
    final type = PropType.array(PropType.components(['A', 'B']), minItems: 2);

    expect(type.removingComponents({'A'}), PropType.array(PropType.components(['B']), minItems: 2));
  });

  test('an object removes from the unions of its fields and keeps their other parts', () {
    final type = PropType.object([
      PropSchema('x', PropType.components(['A', 'B']), required: false, defaultValue: 1, bindable: true),
    ]);

    expect(
      type.removingComponents({'A'}),
      PropType.object([
        PropSchema('x', PropType.components(['B']), required: false, defaultValue: 1, bindable: true),
      ]),
    );
  });

  test('a record removes from the union of its value', () {
    final type = PropType.record(PropType.components(['A', 'B']));

    expect(type.removingComponents({'B'}), PropType.record(PropType.components(['A'])));
  });

  test('a union removes from the unions nested in its options', () {
    final type = PropType.union([
      PropType.array(PropType.components(['A', 'B'])),
      PropType.string,
    ]);

    expect(
      type.removingComponents({'A'}),
      PropType.union([
        PropType.array(PropType.components(['B'])),
        PropType.string,
      ]),
    );
  });

  test('removing components leaves a scalar unchanged', () {
    expect(PropType.string.removingComponents({'A'}), PropType.string);
  });

  test('removing components leaves actions unchanged', () {
    expect(PropType.actions(['A']).removingComponents({'A'}), PropType.actions(['A']));
  });

  test('a component is needed whatever is removed', () {
    expect(PropType.component('A').neededComponents(const {}), ['A']);
  });

  test('a union of only removed components needs all of them', () {
    expect(PropType.components(['A', 'B']).neededComponents({'A', 'B'}), ['A', 'B']);
  });

  test('a union with a component that is kept needs none', () {
    expect(PropType.components(['A', 'B']).neededComponents({'A'}), isEmpty);
  });

  test('a union with an option that is not a component needs none of its components', () {
    final type = PropType.union([PropType.string, PropType.component('A')]);

    expect(type.neededComponents({'A'}), isEmpty);
  });

  test('a union of components with an array of a component needs the array component', () {
    final type = PropType.union([PropType.component('A'), PropType.array(PropType.component('B'))]);

    expect(type.neededComponents({'A'}), ['B']);
  });

  test('an array needs the components of its items', () {
    expect(PropType.array(PropType.component('A')).neededComponents(const {}), ['A']);
  });

  test('an object needs the components of its fields in order', () {
    final type = PropType.object([
      PropSchema('a', PropType.component('A')),
      PropSchema('b', PropType.string),
      PropSchema('c', PropType.component('C')),
    ]);

    expect(type.neededComponents(const {}), ['A', 'C']);
  });

  test('a record needs the component of its value', () {
    expect(PropType.record(PropType.component('A')).neededComponents(const {}), ['A']);
  });

  test('a scalar needs none', () {
    expect(PropType.string.neededComponents({'A'}), isEmpty);
  });

  test('a union that takes TextContent gains the components after its options', () {
    final type = PropType.components(['TextContent', 'Button']);

    expect(type.addingContentComponents(['X', 'Y']), PropType.components(['TextContent', 'Button', 'X', 'Y']));
  });

  test('a union does not gain a component it already has', () {
    final type = PropType.components(['TextContent', 'X']);

    expect(type.addingContentComponents(['X', 'Y']), PropType.components(['TextContent', 'X', 'Y']));
  });

  test('a union that does not take TextContent is unchanged', () {
    final type = PropType.components(['Button', 'Image']);

    expect(type.addingContentComponents(['X']), PropType.components(['Button', 'Image']));
  });

  test('a union gains components next to options that are not components', () {
    final type = PropType.union([PropType.component('TextContent'), PropType.string]);

    expect(
      type.addingContentComponents(['X']),
      PropType.union([PropType.component('TextContent'), PropType.string, PropType.component('X')]),
    );
  });

  test('an array widens the union of its items and keeps minItems', () {
    final type = PropType.array(PropType.components(['TextContent']), minItems: 1);

    expect(
      type.addingContentComponents(['X']),
      PropType.array(PropType.components(['TextContent', 'X']), minItems: 1),
    );
  });

  test('an array of an array widens the inner union', () {
    final type = PropType.array(PropType.array(PropType.components(['TextContent'])));

    expect(
      type.addingContentComponents(['X']),
      PropType.array(PropType.array(PropType.components(['TextContent', 'X']))),
    );
  });

  test('TextContent on its own is not widened', () {
    expect(PropType.component('TextContent').addingContentComponents(['X']), PropType.component('TextContent'));
  });

  test('adding content components leaves a scalar unchanged', () {
    expect(PropType.string.addingContentComponents(['X']), PropType.string);
  });

  test('an object leaves the unions of its fields as they are', () {
    final type = PropType.object([
      PropSchema('a', PropType.components(['TextContent'])),
    ]);

    expect(type.addingContentComponents(['X']), type);
  });

  test('a record leaves the union of its value as it is', () {
    final type = PropType.record(PropType.components(['TextContent']));

    expect(type.addingContentComponents(['X']), type);
  });

  test('scalars of different kinds are unequal', () {
    expect(PropType.string, isNot(PropType.number));
  });

  test('an action is not equal to any', () {
    expect(PropType.action, isNot(PropType.any));
  });

  _testEquivalent('equal enumerations', () => PropType.enumeration(['a', 'b']));

  test('enumerations with other values are unequal', () {
    expect(PropType.enumeration(['a', 'b']), isNot(PropType.enumeration(['a', 'c'])));
  });

  test('enumerations with the values in another order are unequal', () {
    expect(PropType.enumeration(['a', 'b']), isNot(PropType.enumeration(['b', 'a'])));
  });

  _testEquivalent('equal literals', () => PropType.literal('a'));

  test('literals of other values are unequal', () {
    expect(PropType.literal('a'), isNot(PropType.literal('b')));
  });

  test('a literal is not equal to an enumeration of its value', () {
    expect(PropType.literal('a'), isNot(PropType.enumeration(['a'])));
  });

  _testEquivalent('equal arrays', () => PropType.array(PropType.string, minItems: 1));

  test('arrays of other items are unequal', () {
    expect(PropType.array(PropType.string), isNot(PropType.array(PropType.number)));
  });

  test('arrays of other minItems are unequal', () {
    expect(PropType.array(PropType.string, minItems: 1), isNot(PropType.array(PropType.string)));
  });

  _testEquivalent('equal objects', () => PropType.object([PropSchema('a', PropType.string)]));

  test('objects of other fields are unequal', () {
    expect(
      PropType.object([PropSchema('a', PropType.string)]),
      isNot(PropType.object([PropSchema('b', PropType.string)])),
    );
  });

  _testEquivalent('equal records', () => PropType.record(PropType.string));

  test('records of other values are unequal', () {
    expect(PropType.record(PropType.string), isNot(PropType.record(PropType.number)));
  });

  _testEquivalent('equal components', () => PropType.component('A'));

  test('components of other names are unequal', () {
    expect(PropType.component('A'), isNot(PropType.component('B')));
  });

  _testEquivalent('equal unions', () => PropType.components(['A', 'B']));

  test('unions of other options are unequal', () {
    expect(PropType.components(['A', 'B']), isNot(PropType.components(['A', 'C'])));
  });

  test('unions with the options in another order are unequal', () {
    expect(PropType.components(['A', 'B']), isNot(PropType.components(['B', 'A'])));
  });

  _testEquivalent('equal actions', () => PropType.actions(['A', 'B']));

  test('actions of other steps are unequal', () {
    expect(PropType.actions(['A']), isNot(PropType.actions(['B'])));
  });

  _testEquivalent('equal definition references', () => DefinitionReference('A', isAction: true));

  test('definition references of other names are unequal', () {
    expect(DefinitionReference('A'), isNot(DefinitionReference('B')));
  });

  test('definition references of another kind are unequal', () {
    expect(DefinitionReference('A'), isNot(DefinitionReference('A', isAction: true)));
  });
}

void _testEquivalent(String subject, Object Function() create) {
  test('$subject compare equal', () {
    expect(create(), create());
  });

  test('$subject share a hashCode', () {
    expect(create().hashCode, create().hashCode);
  });
}
