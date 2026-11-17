// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';

void main() {
  test('a required prop is shown as name and type', () {
    expect(PropSchema('title', PropType.string).signature, 'title: string');
  });

  test('an optional prop is shown with a question mark', () {
    expect(PropSchema('title', PropType.string, required: false).signature, 'title?: string');
  });

  test('a required bindable prop is shown as a binding of its type', () {
    expect(PropSchema('value', PropType.string, bindable: true).signature, r'value: $binding<string>');
  });

  test('an optional bindable prop is shown as an optional binding of its type', () {
    expect(
      PropSchema('value', PropType.string, required: false, bindable: true).signature,
      r'value?: $binding<string>',
    );
  });

  test('a prop with a default value is optional in its signature', () {
    expect(PropSchema('size', PropType.number, defaultValue: 1).signature, 'size?: number');
  });

  test('a prop with a default value written as not required is optional in its signature', () {
    expect(PropSchema('size', PropType.number, required: false, defaultValue: 1).signature, 'size?: number');
  });

  test('toString is the signature', () {
    expect(PropSchema('title', PropType.string, required: false).toString(), 'title?: string');
  });

  test('a prop has no default value unless one is given', () {
    expect(PropSchema('a', PropType.string).hasDefault, isFalse);
  });

  test('a prop without a default value has a null default value', () {
    expect(PropSchema('a', PropType.string).defaultValue, isNull);
  });

  test('a prop with a default value has one', () {
    expect(PropSchema('a', PropType.string, required: false, defaultValue: 'x').hasDefault, isTrue);
  });

  test('a prop with a default value reports it', () {
    expect(PropSchema('a', PropType.string, required: false, defaultValue: 'x').defaultValue, 'x');
  });

  test('a null default value counts as a default value', () {
    expect(PropSchema('a', PropType.string, required: false, defaultValue: null).hasDefault, isTrue);
  });

  test('a required prop is required in the schema', () {
    expect(PropSchema('a', PropType.string).isSchemaRequired, isTrue);
  });

  test('an optional prop without a default is not required in the schema', () {
    expect(PropSchema('a', PropType.string, required: false).isSchemaRequired, isFalse);
  });

  test('an optional prop with a default is required in the schema', () {
    expect(PropSchema('a', PropType.string, required: false, defaultValue: 'x').isSchemaRequired, isTrue);
  });

  test('an optional prop with a null default is required in the schema', () {
    expect(PropSchema('a', PropType.string, required: false, defaultValue: null).isSchemaRequired, isTrue);
  });

  test('a prop without a default has the schema of its type', () {
    expect(PropSchema('a', PropType.string).jsonSchema, {'type': 'string'});
  });

  test('a prop with a default has the default and the schema of its type', () {
    final schema = PropSchema('a', PropType.string, required: false, defaultValue: 'x').jsonSchema;

    expect(schema, {'default': 'x', 'type': 'string'});
  });

  test('a prop with a default writes default before the schema of its type', () {
    final schema = PropSchema('a', PropType.string, required: false, defaultValue: 'x').jsonSchema;

    expect(schema.keys, ['default', 'type']);
  });

  test('a null default is written into the schema', () {
    final schema = PropSchema('a', PropType.string, required: false, defaultValue: null).jsonSchema;

    expect(schema, {'default': null, 'type': 'string'});
  });

  test('a default that is a list is written into the schema', () {
    final schema = PropSchema('a', PropType.array(PropType.string), required: false, defaultValue: ['x']).jsonSchema;

    expect(schema['default'], ['x']);
  });

  test('withType changes the type', () {
    final prop = PropSchema('a', PropType.string).withType(PropType.number);

    expect(prop.type, PropType.number);
  });

  test('withType keeps the name', () {
    expect(PropSchema('a', PropType.string).withType(PropType.number).name, 'a');
  });

  test('withType keeps a required prop required', () {
    expect(PropSchema('a', PropType.string).withType(PropType.number).required, isTrue);
  });

  test('withType keeps an optional prop optional', () {
    expect(PropSchema('a', PropType.string, required: false).withType(PropType.number).required, isFalse);
  });

  test('withType keeps bindable', () {
    expect(PropSchema('a', PropType.string, bindable: true).withType(PropType.number).bindable, isTrue);
  });

  test('withType keeps a default value', () {
    final prop = PropSchema('a', PropType.string, required: false, defaultValue: 'x').withType(PropType.number);

    expect(prop.defaultValue, 'x');
  });

  test('withType keeps a null default value', () {
    final prop = PropSchema('a', PropType.string, required: false, defaultValue: null).withType(PropType.number);

    expect(prop.hasDefault, isTrue);
  });

  test('withType keeps having no default value', () {
    expect(PropSchema('a', PropType.string).withType(PropType.number).hasDefault, isFalse);
  });

  test('an object schema lists the properties in order with the schemas of their types', () {
    final schema = PropSchema.objectSchema([
      PropSchema('b', PropType.number),
      PropSchema('a', PropType.string),
    ]);

    expect(schema['properties'], {
      'b': {'type': 'number'},
      'a': {'type': 'string'},
    });
  });

  test('an object schema lists the properties in the order of the props', () {
    final schema = PropSchema.objectSchema([
      PropSchema('b', PropType.number),
      PropSchema('a', PropType.string),
    ]);

    expect((schema['properties']! as Map).keys, ['b', 'a']);
  });

  test('an object schema is of type object', () {
    final schema = PropSchema.objectSchema([PropSchema('a', PropType.string)]);

    expect(schema['type'], 'object');
  });

  test('an object schema has no additional properties', () {
    expect(PropSchema.objectSchema([PropSchema('a', PropType.string)])['additionalProperties'], isFalse);
  });

  test('an object schema requires the required props and those with a default, in order', () {
    final schema = PropSchema.objectSchema([
      PropSchema('a', PropType.string),
      PropSchema('b', PropType.string, required: false),
      PropSchema('c', PropType.string, required: false, defaultValue: null),
      PropSchema('d', PropType.string, required: false, defaultValue: 1),
    ]);

    expect(schema['required'], ['a', 'c', 'd']);
  });

  test('an object schema has no required list when nothing is required', () {
    final schema = PropSchema.objectSchema([PropSchema('b', PropType.string, required: false)]);

    expect(schema, isNot(contains('required')));
  });

  test('an object schema of no props has empty properties', () {
    final schema = PropSchema.objectSchema(const []);

    expect(schema, {'type': 'object', 'properties': <String, Object?>{}, 'additionalProperties': false});
  });

  test('an object schema has a description when it is given', () {
    final schema = PropSchema.objectSchema([PropSchema('a', PropType.string)], description: 'A thing');

    expect(schema['description'], 'A thing');
  });

  test('an object schema has no description when it is empty', () {
    final schema = PropSchema.objectSchema([PropSchema('a', PropType.string)], description: '');

    expect(schema, isNot(contains('description')));
  });

  test('an object schema has no description when it is null', () {
    expect(PropSchema.objectSchema([PropSchema('a', PropType.string)]), isNot(contains('description')));
  });

  test('an object schema writes the description after the additionalProperties', () {
    final schema = PropSchema.objectSchema([PropSchema('a', PropType.string)], description: 'A thing');

    expect(schema.keys, ['type', 'properties', 'required', 'additionalProperties', 'description']);
  });

  test('an object schema writes a default into the property that has one', () {
    final schema = PropSchema.objectSchema([PropSchema('a', PropType.string, required: false, defaultValue: 'x')]);

    expect(schema['properties'], {
      'a': {'default': 'x', 'type': 'string'},
    });
  });

  _testEquivalent('equal props', _prop);

  test('props of other names are unequal', () {
    expect(_prop(), isNot(_prop(name: 'b')));
  });

  test('props of other types are unequal', () {
    expect(_prop(), isNot(_prop(type: PropType.number)));
  });

  test('props that differ in being required are unequal', () {
    expect(_prop(), isNot(_prop(required: false)));
  });

  test('props that differ in being bindable are unequal', () {
    expect(_prop(), isNot(_prop(bindable: true)));
  });

  test('a prop with a default is not equal to one without', () {
    expect(_prop(required: false), isNot(_prop(required: false, defaultValue: 'x')));
  });

  test('a prop with a null default is not equal to one without a default', () {
    expect(_prop(required: false), isNot(_prop(required: false, defaultValue: null)));
  });

  test('props of other default values are unequal', () {
    expect(_prop(defaultValue: 'x'), isNot(_prop(defaultValue: 'y')));
  });

  _testEquivalent('props with equal list defaults', () => _prop(defaultValue: ['x', 1]));

  _testEquivalent(
    'props with equal map defaults',
    () => _prop(
      defaultValue: {
        'k': [1],
      },
    ),
  );

  _testEquivalent('props with equal null defaults', () => _prop(defaultValue: null));
}

PropSchema _prop({
  String name = 'a',
  PropType type = PropType.string,
  bool required = true,
  bool bindable = false,
  Object? defaultValue = _none,
}) {
  if (identical(defaultValue, _none)) return PropSchema(name, type, required: required, bindable: bindable);
  return PropSchema(name, type, required: required, bindable: bindable, defaultValue: defaultValue);
}

const _none = Object();

void _testEquivalent(String subject, Object Function() create) {
  test('$subject compare equal', () {
    expect(create(), create());
  });

  test('$subject share a hashCode', () {
    expect(create().hashCode, create().hashCode);
  });
}
