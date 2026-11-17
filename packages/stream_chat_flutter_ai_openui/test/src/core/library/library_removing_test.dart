// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';

void main() {
  test('removing drops the components it names', () {
    final library = _library().removing(['Button', 'Image']);

    expect(library.componentNames, ['Card', 'TextContent']);
  });

  test('removing keeps the order of the components left', () {
    final library = _library().removing(['TextContent']);

    expect(library.componentNames, ['Card', 'Button', 'Image']);
  });

  test('removing a name the library has no component for changes nothing', () {
    expect(_library().removing(['Missing']).components, _library().components);
  });

  test('removing nothing changes nothing', () {
    expect(_library().removing(const []).components, _library().components);
  });

  test('removing does not change the library it is called on', () {
    final library = _library()..removing(['Button']);

    expect(library.componentNames, ['Card', 'TextContent', 'Button', 'Image']);
  });

  test('removing takes the components out of the union of the items of an array prop', () {
    final library = _library().removing(['Button']);

    expect(library.component('Card')!.props.single.type, PropType.array(PropType.components(['TextContent', 'Image'])));
  });

  test('removing takes the components out of the union of a prop that takes other types too', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [
          PropSchema('x', PropType.union([PropType.string, PropType.component('A'), PropType.component('B')])),
        ]),
        _component('A'),
        _component('B'),
      ],
    ).removing(['A']);

    expect(library.component('Host')!.props.single.type, PropType.union([PropType.string, PropType.component('B')]));
  });

  test('removing keeps what a prop is besides its type', () {
    final library = LibraryDefinition(
      components: [
        _component('Card', [
          PropSchema('x', PropType.components(['A', 'B']), required: false, defaultValue: 1, bindable: true),
        ]),
        _component('A'),
        _component('B'),
      ],
    ).removing(['A']);

    expect(
      library.component('Card')!.props.single,
      PropSchema('x', PropType.components(['B']), required: false, defaultValue: 1, bindable: true),
    );
  });

  test('removing takes the components out of the unions of object fields', () {
    final library = LibraryDefinition(
      components: [
        _component('Card', [
          PropSchema(
            'o',
            PropType.object([
              PropSchema('x', PropType.components(['A', 'B'])),
            ]),
          ),
        ]),
        _component('A'),
        _component('B'),
      ],
    ).removing(['A']);

    expect(
      library.component('Card')!.props.single.type,
      PropType.object([
        PropSchema('x', PropType.components(['B'])),
      ]),
    );
  });

  test('removing takes the components out of the unions of records', () {
    final library = LibraryDefinition(
      components: [
        _component('Card', [
          PropSchema('r', PropType.record(PropType.components(['A', 'B']))),
        ]),
        _component('A'),
        _component('B'),
      ],
    ).removing(['A']);

    expect(library.component('Card')!.props.single.type, PropType.record(PropType.components(['B'])));
  });

  test('removing keeps the root when it is named', () {
    final library = _library().removing(['Card', 'Button']);

    expect(library.componentNames, contains('Card'));
  });

  test('removing keeps a component that is the only type a slot takes', () {
    final library = LibraryDefinition(
      components: [
        _component('List', [PropSchema('items', PropType.array(PropType.component('Item')))]),
        _component('Item'),
        _component('Other'),
      ],
    ).removing(['Item', 'Other']);

    expect(library.componentNames, ['List', 'Item']);
  });

  test('removing keeps a component that is the type of a field of an object slot', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [
          PropSchema('o', PropType.object([PropSchema('x', PropType.component('Item'))])),
        ]),
        _component('Item'),
      ],
    ).removing(['Item']);

    expect(library.componentNames, ['Host', 'Item']);
  });

  test('removing keeps a component that is the type of a record slot', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [PropSchema('r', PropType.record(PropType.component('Item')))]),
        _component('Item'),
      ],
    ).removing(['Item']);

    expect(library.componentNames, ['Host', 'Item']);
  });

  test('removing keeps the components a kept component needs in turn', () {
    final library = LibraryDefinition(
      components: [
        _component('List', [PropSchema('items', PropType.array(PropType.component('Item')))]),
        _component('Item', [PropSchema('icon', PropType.component('Icon'))]),
        _component('Icon'),
        _component('Other'),
      ],
    ).removing(['Item', 'Icon', 'Other']);

    expect(library.componentNames, ['List', 'Item', 'Icon']);
  });

  test('removing drops a component that was only needed by a component it removes', () {
    final library = LibraryDefinition(
      components: [
        _component('Host'),
        _component('Item', [PropSchema('icon', PropType.component('Icon'))]),
        _component('Icon'),
      ],
    ).removing(['Item', 'Icon']);

    expect(library.componentNames, ['Host']);
  });

  test('removing keeps every option of a union whose options would all go', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [
          PropSchema('x', PropType.components(['A', 'B'])),
        ]),
        _component('A'),
        _component('B'),
        _component('C'),
      ],
    ).removing(['A', 'B', 'C']);

    expect(library.componentNames, ['Host', 'A', 'B']);
  });

  test('removing keeps the type of a union whose options would all go', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [
          PropSchema('x', PropType.components(['A', 'B'])),
        ]),
        _component('A'),
        _component('B'),
        _component('C'),
      ],
    ).removing(['A', 'B', 'C']);

    expect(library.component('Host')!.props.single.type, PropType.components(['A', 'B']));
  });

  test('removing drops a component of a union when another option stays', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [
          PropSchema('x', PropType.components(['A', 'B'])),
        ]),
        _component('A'),
        _component('B'),
      ],
    ).removing(['A']);

    expect(library.componentNames, ['Host', 'B']);
  });

  test('removing drops a component of a union with an option that is not a component', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [
          PropSchema('x', PropType.union([PropType.string, PropType.component('A')])),
        ]),
        _component('A'),
      ],
    ).removing(['A']);

    expect(library.componentNames, ['Host']);
  });

  test('removing drops a group that is left with no component', () {
    final library = _library().removing(['Button', 'Image']);

    expect([for (final group in library.componentGroups) group.name], ['Layout']);
  });

  test('removing keeps the components of a group that are left, in order', () {
    final library = _library().removing(['Button']);

    expect(library.componentGroups.last.components, ['Image']);
  });

  test('removing keeps the notes of a group that has components left', () {
    final library = _library().removing(['Button']);

    expect(library.componentGroups.last.notes, ['Pick one.']);
  });

  test('removing keeps the notes of a group when it keeps a component only because it is needed', () {
    final library = LibraryDefinition(
      components: [
        _component('Host', [PropSchema('x', PropType.component('Item'))]),
        _component('Item'),
      ],
      componentGroups: [
        ComponentGroup('Items', components: ['Item'], notes: ['A note']),
      ],
    ).removing(['Item']);

    expect(library.componentGroups, [
      ComponentGroup('Items', components: ['Item'], notes: ['A note']),
    ]);
  });

  test('removing keeps the groups when none of their components go', () {
    expect(_library().removing(['Missing']).componentGroups, _library().componentGroups);
  });

  test('removing keeps the default prompt options with their examples and rules', () {
    final library = _library().removing(['Button']);

    expect(library.defaultPromptOptions, _library().defaultPromptOptions);
  });

  test('removing keeps the functions', () {
    final library = LibraryDefinition(
      components: [_component('A'), _component('B')],
      functions: [FunctionSchema('Upper', description: '', params: const [])],
      actions: [ActionSchema('Copy', description: '', params: const [])],
    ).removing(['B']);

    expect([for (final function in library.functions) function.name], ['Upper']);
  });

  test('removing keeps the actions', () {
    final library = LibraryDefinition(
      components: [_component('A'), _component('B')],
      functions: [FunctionSchema('Upper', description: '', params: const [])],
      actions: [ActionSchema('Copy', description: '', params: const [])],
    ).removing(['B']);

    expect([for (final action in library.actions) action.name], ['Copy']);
  });

  test('removing keeps the root of the library it makes', () {
    expect(_library().removing(['Button']).root, 'Card');
  });
}

LibraryDefinition _library() {
  return LibraryDefinition(
    root: 'Card',
    components: [
      _component('Card', [
        PropSchema('children', PropType.array(PropType.components(['TextContent', 'Button', 'Image']))),
      ]),
      _component('TextContent'),
      _component('Button'),
      _component('Image'),
    ],
    componentGroups: [
      ComponentGroup('Layout', components: ['Card', 'TextContent']),
      ComponentGroup('Content', components: ['Button', 'Image'], notes: ['Pick one.']),
    ],
    defaultPromptOptions: PromptOptions(examples: ['An example'], additionalRules: ['A rule']),
  );
}

ComponentSchema _component(String name, [List<PropSchema> props = const []]) {
  return ComponentSchema(name, description: '', props: props);
}
