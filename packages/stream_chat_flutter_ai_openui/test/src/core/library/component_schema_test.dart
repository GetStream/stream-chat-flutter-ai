// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';

void main() {
  test('the signature of a component is the name with the signatures of its props', () {
    expect(_header().signature, 'CardHeader(title: string, subtitle?: string)');
  });

  test('the signature of a component without props has empty parentheses', () {
    expect(ComponentSchema('Divider', description: '', props: const []).signature, 'Divider()');
  });

  test('toString of a component is its signature', () {
    expect(_header().toString(), 'CardHeader(title: string, subtitle?: string)');
  });

  test('the schema of a component is the object schema of the props with the description', () {
    expect(_header().jsonSchema, {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'subtitle': {'type': 'string'},
      },
      'required': ['title'],
      'additionalProperties': false,
      'description': 'A header',
    });
  });

  test('the schema of a component has no description when it is empty', () {
    final schema = ComponentSchema('Divider', description: '', props: const []).jsonSchema;

    expect(schema, isNot(contains('description')));
  });

  test('mapping prop types changes the type of each prop', () {
    final mapped = _header().mappingPropTypes(PropType.array);

    expect(mapped.signature, 'CardHeader(title: string[], subtitle?: string[])');
  });

  test('mapping prop types keeps the name', () {
    expect(_header().mappingPropTypes((type) => type).name, 'CardHeader');
  });

  test('mapping prop types keeps the description', () {
    expect(_header().mappingPropTypes((type) => type).description, 'A header');
  });

  test('mapping prop types keeps what a prop is besides its type', () {
    final component = ComponentSchema(
      'Input',
      description: '',
      props: [PropSchema('value', PropType.string, required: false, defaultValue: 'x', bindable: true)],
    );

    final mapped = component.mappingPropTypes((type) => PropType.number);

    expect(
      mapped.props.single,
      PropSchema('value', PropType.number, required: false, defaultValue: 'x', bindable: true),
    );
  });

  test('mapping prop types does not change the original', () {
    final component = _header()..mappingPropTypes((type) => PropType.number);

    expect(component, _header());
  });

  _testEquivalent('equal components', _header);

  test('components of other names are unequal', () {
    expect(_header(), isNot(_header(name: 'Other')));
  });

  test('components of other descriptions are unequal', () {
    expect(_header(), isNot(_header(description: 'Other')));
  });

  test('components of other props are unequal', () {
    expect(_header(), isNot(_header(subtitle: PropType.number)));
  });

  test('components with the props in another order are unequal', () {
    final reversed = ComponentSchema('CardHeader', description: 'A header', props: _header().props.reversed.toList());

    expect(_header(), isNot(reversed));
  });

  _testEquivalent('equal groups', _group);

  test('groups of other names are unequal', () {
    expect(_group(), isNot(_group(name: 'Other')));
  });

  test('groups of other components are unequal', () {
    expect(_group(), isNot(_group(components: ['A'])));
  });

  test('groups with the components in another order are unequal', () {
    expect(_group(), isNot(_group(components: ['B', 'A'])));
  });

  test('groups of other notes are unequal', () {
    expect(_group(), isNot(_group(notes: ['Other'])));
  });

  test('a group has no notes unless they are given', () {
    expect(ComponentGroup('Forms', components: ['A']).notes, isEmpty);
  });

  test('the signature of a function has the parameters and the type it returns', () {
    expect(_upper().signature, 'Upper(text: string, locale?: string) → string');
  });

  test('the signature of a function has no arrow when no type is given', () {
    final function = FunctionSchema('Log', description: '', params: [PropSchema('text', PropType.string)]);

    expect(function.signature, 'Log(text: string)');
  });

  test('the signature of a function without parameters has empty parentheses', () {
    expect(
      FunctionSchema('Now', description: '', params: const [], returns: PropType.number).signature,
      'Now() → number',
    );
  });

  test('the return type of an array is shown with its brackets', () {
    final function = FunctionSchema(
      'Names',
      description: '',
      params: const [],
      returns: PropType.array(PropType.string),
    );

    expect(function.signature, 'Names() → string[]');
  });

  test('the parameters schema of a function is the object schema of the parameters', () {
    expect(_upper().paramsSchema, {
      'type': 'object',
      'properties': {
        'text': {'type': 'string'},
        'locale': {'type': 'string'},
      },
      'required': ['text'],
      'additionalProperties': false,
    });
  });

  _testEquivalent('equal functions', _upper);

  test('functions of other names are unequal', () {
    expect(_upper(), isNot(_upper(name: 'Lower')));
  });

  test('functions of other descriptions are unequal', () {
    expect(_upper(), isNot(_upper(description: 'Other')));
  });

  test('functions of other parameters are unequal', () {
    expect(_upper(), isNot(_upper(params: [PropSchema('text', PropType.number)])));
  });

  test('functions of other return types are unequal', () {
    expect(_upper(), isNot(_upper(returns: PropType.number)));
  });

  test('a function that returns a type is not equal to one that returns none', () {
    expect(_upper(), isNot(FunctionSchema('Upper', description: 'The text in upper case', params: _upper().params)));
  });

  test('the signature of an action is the name with the signatures of its parameters', () {
    expect(_copy().signature, 'CopyToClipboard(text: string, label?: string)');
  });

  test('the signature of an action without parameters has empty parentheses', () {
    expect(ActionSchema('Close', description: '', params: const []).signature, 'Close()');
  });

  test('the parameters schema of an action is the object schema of the parameters', () {
    expect(_copy().paramsSchema, {
      'type': 'object',
      'properties': {
        'text': {'type': 'string'},
        'label': {'type': 'string'},
      },
      'required': ['text'],
      'additionalProperties': false,
    });
  });

  test('the step schema is an object of its name as type and its parameters', () {
    expect(_copy().stepSchema, {
      'type': 'object',
      'properties': {
        'type': {'type': 'string', 'const': 'CopyToClipboard'},
        'params': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
            'label': {'type': 'string'},
          },
          'required': ['text'],
          'additionalProperties': false,
        },
      },
      'required': ['type', 'params'],
      'additionalProperties': false,
    });
  });

  test('the step schema requires params even when the action has none', () {
    final schema = ActionSchema('Close', description: '', params: const []).stepSchema;

    expect(schema['required'], ['type', 'params']);
  });

  _testEquivalent('equal actions', _copy);

  test('actions of other names are unequal', () {
    expect(_copy(), isNot(_copy(name: 'Other')));
  });

  test('actions of other descriptions are unequal', () {
    expect(_copy(), isNot(_copy(description: 'Other')));
  });

  test('actions of other parameters are unequal', () {
    expect(_copy(), isNot(_copy(params: [PropSchema('text', PropType.number)])));
  });
}

ComponentSchema _header({
  String name = 'CardHeader',
  String description = 'A header',
  PropType subtitle = PropType.string,
}) {
  return ComponentSchema(
    name,
    description: description,
    props: [PropSchema('title', PropType.string), PropSchema('subtitle', subtitle, required: false)],
  );
}

ComponentGroup _group({String name = 'Forms', List<String> components = const ['A', 'B'], List<String>? notes}) {
  return ComponentGroup(
    name,
    components: [...components],
    notes: [
      ...(notes ?? ['Note']),
    ],
  );
}

FunctionSchema _upper({
  String name = 'Upper',
  String description = 'The text in upper case',
  List<PropSchema>? params,
  PropType returns = PropType.string,
}) {
  return FunctionSchema(
    name,
    description: description,
    params: params ?? [PropSchema('text', PropType.string), PropSchema('locale', PropType.string, required: false)],
    returns: returns,
  );
}

ActionSchema _copy({String name = 'CopyToClipboard', String description = 'Copies', List<PropSchema>? params}) {
  return ActionSchema(
    name,
    description: description,
    params: params ?? [PropSchema('text', PropType.string), PropSchema('label', PropType.string, required: false)],
  );
}

void _testEquivalent(String subject, Object Function() create) {
  test('$subject compare equal', () {
    expect(create(), create());
  });

  test('$subject share a hashCode', () {
    expect(create().hashCode, create().hashCode);
  });
}
