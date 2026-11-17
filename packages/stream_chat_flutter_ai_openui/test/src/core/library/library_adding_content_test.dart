// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';

void main() {
  test('adding content appends the components after the library own', () {
    final library = _library().addingContent([_component('PlaceCard'), _component('TripMap')]);

    expect(library.componentNames, ['Card', 'TextContent', 'Button', 'Plain', 'Grid', 'PlaceCard', 'TripMap']);
  });

  test('adding content adds the components to a union that takes TextContent', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect(
      library.component('Card')!.props.first.type,
      PropType.array(PropType.components(['TextContent', 'Button', 'PlaceCard'])),
    );
  });

  test('adding content adds the components to a union of an array of arrays', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect(
      library.component('Grid')!.props.single.type,
      PropType.array(PropType.array(PropType.components(['TextContent', 'PlaceCard']))),
    );
  });

  test('adding content leaves a union that does not take TextContent as it is', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect(library.component('Card')!.props.last.type, PropType.array(PropType.components(['Button', 'Plain'])));
  });

  test('adding content leaves a prop of one component other than TextContent as it is', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect(library.component('Plain')!.props.single.type, PropType.component('Button'));
  });

  test('adding content keeps what a widened prop is besides its type', () {
    final library = LibraryDefinition(
      components: [
        _component('TextContent'),
        _component('Card', [
          PropSchema('c', PropType.components(['TextContent']), required: false, defaultValue: null, bindable: true),
        ]),
      ],
    ).addingContent([_component('PlaceCard')]);

    expect(
      library.component('Card')!.props.single,
      PropSchema(
        'c',
        PropType.components(['TextContent', 'PlaceCard']),
        required: false,
        defaultValue: null,
        bindable: true,
      ),
    );
  });

  test('adding content leaves the props of the added components as they are', () {
    final added = _component('PlaceCard', [
      PropSchema('body', PropType.array(PropType.components(['TextContent']))),
    ]);

    final library = _library().addingContent([added]);

    expect(library.component('PlaceCard'), added);
  });

  test('adding content lists the components in a group named App components after the others', () {
    final library = _library().addingContent([_component('PlaceCard'), _component('TripMap')]);

    expect(library.componentGroups, [
      ComponentGroup('Layout', components: ['Card']),
      ComponentGroup('App components', components: ['PlaceCard', 'TripMap']),
    ]);
  });

  test('adding content lists the components in the group given, with its notes', () {
    final library = _library().addingContent(
      [_component('PlaceCard')],
      group: 'Trip',
      notes: ['Use for places.', 'Never alone.'],
    );

    expect(
      library.componentGroups.last,
      ComponentGroup('Trip', components: ['PlaceCard'], notes: ['Use for places.', 'Never alone.']),
    );
  });

  test('adding content leaves out a component whose name can not be called', () {
    final library = _library().addingContent([_component('place_card'), _component('PlaceCard')]);

    expect(library.componentNames, [..._library().componentNames, 'PlaceCard']);
  });

  for (final name in ['Count', 'Action', 'Query', 'Mutation', 'ActionExpression', 'OpenUrl', 'ToAssistant']) {
    test('adding content leaves out a component named $name', () {
      final library = _library().addingContent([_component(name)]);

      expect(library.componentNames, _library().componentNames);
    });
  }

  test('adding content leaves the ActionExpression shape as it is when a component is named like it', () {
    final library =
        LibraryDefinition(
          components: [
            _component('Host', [PropSchema('x', PropType.action)]),
          ],
        ).addingContent([
          _component('ActionExpression', [PropSchema('y', PropType.string)]),
        ]);

    final shape = (library.toJsonSchema()[r'$defs']! as Map)['ActionExpression']! as Map;

    expect(shape.keys, ['anyOf']);
  });

  test('adding content leaves the OpenUrl shape as it is when a component is named like it', () {
    final library =
        LibraryDefinition(
          components: [
            _component('Host', [
              PropSchema('x', PropType.actions(['OpenUrl'])),
            ]),
          ],
        ).addingContent([
          _component('OpenUrl', [PropSchema('y', PropType.string)]),
        ]);

    final shape = (library.toJsonSchema()[r'$defs']! as Map)['OpenUrl']! as Map;

    expect((shape['properties']! as Map).keys, ['type', 'url']);
  });

  for (final name in ['OpenUrls', 'ActionExpressions', 'PlaceCard']) {
    test('adding content keeps a component named $name', () {
      final library = _library().addingContent([_component(name)]);

      expect(library.componentNames, contains(name));
    });
  }

  test('adding content leaves out a component named like one of the library', () {
    final library = _library().addingContent([
      _component('Button', [PropSchema('x', PropType.string)]),
    ]);

    expect(library.component('Button')!.props, isEmpty);
  });

  test('adding content leaves out a component named like a function', () {
    final library = _library().addingContent([_component('Upper')]);

    expect(library.componentNames, isNot(contains('Upper')));
  });

  test('adding content leaves out a component named like an action', () {
    final library = _library().addingContent([_component('Copy')]);

    expect(library.componentNames, isNot(contains('Copy')));
  });

  test('adding content leaves out a component named like an earlier one given', () {
    final library = _library().addingContent([
      _component('PlaceCard', [PropSchema('first', PropType.string)]),
      _component('PlaceCard'),
    ]);

    expect(library.component('PlaceCard')!.props.single.name, 'first');
  });

  test('adding content adds a component given twice once', () {
    final library = _library().addingContent([_component('PlaceCard'), _component('PlaceCard')]);

    expect(library.componentNames.where((name) => name == 'PlaceCard'), hasLength(1));
  });

  test('adding content only widens unions with the components it keeps', () {
    final library = _library().addingContent([_component('place_card'), _component('TripMap')]);

    expect(
      library.component('Card')!.props.first.type,
      PropType.array(PropType.components(['TextContent', 'Button', 'TripMap'])),
    );
  });

  test('adding content only lists the components it keeps in the group', () {
    final library = _library().addingContent([_component('place_card'), _component('TripMap')]);

    expect(library.componentGroups.last.components, ['TripMap']);
  });

  test('adding content with none left returns the same library', () {
    final library = _library();

    expect(identical(library.addingContent([_component('place_card'), _component('Button')]), library), isTrue);
  });

  test('adding no content returns the same library', () {
    final library = _library();

    expect(identical(library.addingContent(const []), library), isTrue);
  });

  test('adding content keeps the root', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect(library.root, 'Card');
  });

  test('adding content keeps the functions', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect([for (final function in library.functions) function.name], ['Upper']);
  });

  test('adding content keeps the actions', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect([for (final action in library.actions) action.name], ['Copy']);
  });

  test('adding content keeps the default options', () {
    final library = _library().addingContent([_component('PlaceCard')]);

    expect(library.defaultPromptOptions, _library().defaultPromptOptions);
  });

  test('adding content does not change the library it is called on', () {
    final library = _library()..addingContent([_component('PlaceCard')]);

    expect(library.componentNames, ['Card', 'TextContent', 'Button', 'Plain', 'Grid']);
  });

  test('adding content does not change the groups of the library it is called on', () {
    final library = _library()..addingContent([_component('PlaceCard')]);

    expect(library.componentGroups, hasLength(1));
  });

  test('a program can call an added component where content goes', () {
    final library = _library().addingContent([
      _component('PlaceCard', [PropSchema('title', PropType.string)]),
    ]);

    final result = OpenUILangParser(library.schema).parse('root = Card([TextContent("Hi"), PlaceCard("Ohrid")])');

    expect(result.meta.errors, isEmpty);
  });

  test('a program reads the root of a program with an added component', () {
    final library = _library().addingContent([
      _component('PlaceCard', [PropSchema('title', PropType.string)]),
    ]);

    final result = OpenUILangParser(library.schema).parse('root = Card([TextContent("Hi"), PlaceCard("Ohrid")])');

    expect(result.root!.typeName, 'Card');
  });

  test('the prompt lists the added components under their group', () {
    final library = _library().addingContent([
      _component('PlaceCard', [PropSchema('title', PropType.string)]),
    ]);

    expect(library.systemPrompt(), contains('### App components\nPlaceCard(title: string)'));
  });
}

LibraryDefinition _library() {
  return LibraryDefinition(
    root: 'Card',
    components: [
      _component('Card', [
        PropSchema('children', PropType.array(PropType.components(['TextContent', 'Button']))),
        PropSchema('footer', PropType.array(PropType.components(['Button', 'Plain'])), required: false),
      ]),
      _component('TextContent', [PropSchema('text', PropType.string)]),
      _component('Button'),
      _component('Plain', [PropSchema('child', PropType.component('Button'))]),
      _component('Grid', [
        PropSchema('rows', PropType.array(PropType.array(PropType.components(['TextContent'])))),
      ]),
    ],
    componentGroups: [
      ComponentGroup('Layout', components: ['Card']),
    ],
    functions: [FunctionSchema('Upper', description: '', params: const [])],
    actions: [ActionSchema('Copy', description: '', params: const [])],
    defaultPromptOptions: PromptOptions(examples: ['An example']),
  );
}

ComponentSchema _component(String name, [List<PropSchema> props = const []]) {
  return ComponentSchema(name, description: '', props: props);
}
