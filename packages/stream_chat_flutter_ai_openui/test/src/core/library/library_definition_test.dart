// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/schemas/schema_dsl.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

import 'spec_library.dart';

void main() {
  test('a component whose name an earlier one has replaces it in place', () {
    final library = LibraryDefinition(
      components: [_component('A', 'first'), _component('B', 'b'), _component('A', 'second'), _component('C', 'c')],
    );

    expect(library.componentNames, ['A', 'B', 'C']);
    expect(library.component('A')!.description, 'second');
  });

  test('a component keeps the place of its first appearance when replaced twice', () {
    final library = LibraryDefinition(
      components: [_component('A', '1'), _component('B', 'b'), _component('A', '2'), _component('A', '3')],
    );

    expect([for (final component in library.components) component.description], ['3', 'b']);
  });

  test('the components are unmodifiable', () {
    final library = LibraryDefinition(components: [_component('A')]);

    expect(() => library.components.add(_component('B')), throwsUnsupportedError);
  });

  test('the component groups are unmodifiable', () {
    final library = LibraryDefinition(components: [_component('A')], componentGroups: [_group()]);

    expect(() => library.componentGroups.add(_group()), throwsUnsupportedError);
  });

  test('the functions are unmodifiable', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Upper')]);

    expect(() => library.functions.add(_function('Lower')), throwsUnsupportedError);
  });

  test('the actions are unmodifiable', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Copy')]);

    expect(() => library.actions.add(_step('Other')), throwsUnsupportedError);
  });

  test('a root that is not a component is an error', () {
    expect(
      () => LibraryDefinition(root: 'Missing', components: [_component('A')]),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a root that is a component is kept', () {
    expect(LibraryDefinition(root: 'A', components: [_component('A')]).root, 'A');
  });

  test('a library without a root has none', () {
    expect(LibraryDefinition(components: [_component('A')]).root, isNull);
  });

  test('a function is kept', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Upper')]);

    expect(library.functions, [_function('Upper')]);
  });

  test('an action is kept', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Copy')]);

    expect(library.actions, [_step('Copy')]);
  });

  test('a function named like a built-in function is left out', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Count')]);

    expect(library.functions, isEmpty);
  });

  test('a function named like a built-in step is left out', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('OpenUrl')]);

    expect(library.functions, isEmpty);
  });

  test('a function named ActionExpression is left out', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('ActionExpression')]);

    expect(library.functions, isEmpty);
  });

  test('an action named ActionExpression is left out', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('ActionExpression')]);

    expect(library.actions, isEmpty);
  });

  test('an action named ActionExpression leaves the built-in ActionExpression shape in the schema', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.action)]),
      ],
      actions: [_step('ActionExpression')],
    );

    expect((_definitions(library)['ActionExpression']! as Map).keys, ['anyOf']);
  });

  test('an action named CopyToClipboard is kept', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('CopyToClipboard')]);

    expect([for (final action in library.actions) action.name], ['CopyToClipboard']);
  });

  test('a function named Action is left out', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Action')]);

    expect(library.functions, isEmpty);
  });

  test('a function named Query is left out', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Query')]);

    expect(library.functions, isEmpty);
  });

  test('a function named Mutation is left out', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Mutation')]);

    expect(library.functions, isEmpty);
  });

  test('a function named like a component is left out', () {
    final library = LibraryDefinition(components: [_component('Card')], functions: [_function('Card')]);

    expect(library.functions, isEmpty);
  });

  test('a function named like an earlier function is left out', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [_function('Upper', 'first'), _function('Upper', 'second')],
    );

    expect([for (final function in library.functions) function.description], ['first']);
  });

  test('a function whose name only differs in case from a built-in is kept', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [_function('count'), _function('Counter')],
    );

    expect([for (final function in library.functions) function.name], ['count', 'Counter']);
  });

  test('an action named like a built-in step is left out', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Set')]);

    expect(library.actions, isEmpty);
  });

  test('an action named like a built-in function is left out', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Sum')]);

    expect(library.actions, isEmpty);
  });

  test('an action named Query or Mutation is left out', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Query'), _step('Mutation')]);

    expect(library.actions, isEmpty);
  });

  test('an action named like a component is left out', () {
    final library = LibraryDefinition(components: [_component('Card')], actions: [_step('Card')]);

    expect(library.actions, isEmpty);
  });

  test('an action named like an earlier action is left out', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      actions: [_step('Copy', 'first'), _step('Copy', 'second')],
    );

    expect([for (final action in library.actions) action.description], ['first']);
  });

  test('an action named like a function is left out', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [_function('Shared')],
      actions: [_step('Shared'), _step('Other')],
    );

    expect([for (final action in library.actions) action.name], ['Other']);
  });

  test('a function keeps its name when an action of the same name comes later', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [_function('Shared', 'function')],
      actions: [_step('Shared', 'action')],
    );

    expect(library.functions.single.description, 'function');
  });

  test('the component names are in library order', () {
    final library = LibraryDefinition(components: [_component('B'), _component('A'), _component('C')]);

    expect(library.componentNames, ['B', 'A', 'C']);
  });

  test('a component is found by name', () {
    final library = LibraryDefinition(components: [_component('A', 'the a'), _component('B')]);

    expect(library.component('A')!.description, 'the a');
  });

  test('a component the library has none of is null', () {
    expect(LibraryDefinition(components: [_component('A')]).component('a'), isNull);
  });

  test('a bindable prop is bindable', () {
    expect(specLibrary().isBindable('Input', 'value'), isTrue);
  });

  test('a prop that is not bindable is not bindable', () {
    expect(specLibrary().isBindable('Input', 'placeholder'), isFalse);
  });

  test('a prop the component has none of is not bindable', () {
    expect(specLibrary().isBindable('Input', 'missing'), isFalse);
  });

  test('a prop of a component the library has none of is not bindable', () {
    expect(specLibrary().isBindable('Missing', 'value'), isFalse);
  });

  test('a bindable prop of another component is not bindable', () {
    expect(specLibrary().isBindable('Card', 'value'), isFalse);
  });

  test('the document names its JSON Schema draft', () {
    expect(specLibrary().toJsonSchema()[r'$schema'], 'https://json-schema.org/draft/2020-12/schema');
  });

  test('the document is of type object', () {
    expect(specLibrary().toJsonSchema()['type'], 'object');
  });

  test('the document takes no additional properties', () {
    expect(specLibrary().toJsonSchema()['additionalProperties'], isFalse);
  });

  test('the document requires every component', () {
    expect(specLibrary().toJsonSchema()['required'], specLibrary().componentNames);
  });

  test('the properties refer to every component in library order', () {
    final schema = LibraryDefinition(components: [_component('B'), _component('A')]).toJsonSchema();

    expect(schema['properties'], {
      'B': {r'$ref': r'#/$defs/B'},
      'A': {r'$ref': r'#/$defs/A'},
    });
  });

  test('the properties are in library order', () {
    final schema = LibraryDefinition(components: [_component('B'), _component('A')]).toJsonSchema();

    expect((schema['properties']! as Map).keys, ['B', 'A']);
  });

  test('each component is a definition with its schema', () {
    final library = LibraryDefinition(
      components: [
        _component('A', 'the a', [PropSchema('x', PropType.string)]),
      ],
    );

    expect(library.toJsonSchema()[r'$defs'], {'A': library.component('A')!.jsonSchema});
  });

  test('the definitions are in the order they are reached depth first from the components', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.component('C'))]),
        _component('B'),
        _component('C', '', [PropSchema('y', PropType.component('D'))]),
        _component('D'),
      ],
    );

    expect(_definitions(library).keys, ['A', 'C', 'D', 'B']);
  });

  test('a component that refers to itself is defined once', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('children', PropType.array(PropType.component('A')))]),
      ],
    );

    expect(_definitions(library).keys, ['A']);
  });

  test('components that refer to each other are each defined once', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.component('B'))]),
        _component('B', '', [PropSchema('x', PropType.component('A'))]),
      ],
    );

    expect(_definitions(library).keys, ['A', 'B']);
  });

  test('a reference to a component the library has none of adds no definition', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.component('Ghost'))]),
      ],
    );

    expect(_definitions(library).keys, ['A']);
  });

  test('an action prop adds the ActionExpression shape after its component', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.action)]),
        _component('B'),
      ],
    );

    expect(_definitions(library).keys, ['A', 'ActionExpression', 'B']);
  });

  test('the ActionExpression shape is any of the open url, assistant and custom steps', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.action)]),
      ],
    );

    final shape = _definitions(library)['ActionExpression']! as Map<String, Object?>;

    expect(
      [for (final option in shape['anyOf']! as List) ((option as Map)['properties'] as Map)['type']],
      [
        {'type': 'string', 'const': 'open_url'},
        {'type': 'string', 'const': 'continue_conversation'},
        {'type': 'string'},
      ],
    );
  });

  test('the open url step needs a type and a url', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [
          PropSchema('x', PropType.actions(['OpenUrl'])),
        ]),
      ],
    );

    expect(_definitions(library)['OpenUrl'], {
      'type': 'object',
      'properties': {
        'type': {'type': 'string', 'const': 'open_url'},
        'url': {'type': 'string'},
      },
      'required': ['type', 'url'],
      'additionalProperties': false,
    });
  });

  test('the assistant step needs a type and may have a context', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [
          PropSchema('x', PropType.actions(['ToAssistant'])),
        ]),
      ],
    );

    expect(_definitions(library)['ToAssistant'], {
      'type': 'object',
      'properties': {
        'type': {'type': 'string', 'const': 'continue_conversation'},
        'context': {'type': 'string'},
      },
      'required': ['type'],
      'additionalProperties': false,
    });
  });

  test('a custom action step is defined by its step schema', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [
          PropSchema('x', PropType.actions(['Copy'])),
        ]),
      ],
      actions: [_step('Copy')],
    );

    expect(_definitions(library)['Copy'], _step('Copy').stepSchema);
  });

  test('a step the library does not know adds no definition', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [
          PropSchema('x', PropType.actions(['Unknown'])),
        ]),
      ],
    );

    expect(_definitions(library).keys, ['A']);
  });

  test('a step is defined once however many props take it', () {
    final library = LibraryDefinition(
      components: [
        _component('A', '', [PropSchema('x', PropType.action), PropSchema('y', PropType.action)]),
      ],
    );

    expect(_definitions(library).keys, ['A', 'ActionExpression']);
  });

  test('a library without functions has no functions section', () {
    expect(LibraryDefinition(components: [_component('A')]).toJsonSchema(), isNot(contains('functions')));
  });

  test('a library without actions has no actions section', () {
    expect(LibraryDefinition(components: [_component('A')]).toJsonSchema(), isNot(contains('actions')));
  });

  test('the functions section has the description, parameters and return type of each function', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [
        _function('Upper', 'Upper case', PropType.string),
        _function('Log', 'Logs'),
      ],
    );

    expect(library.toJsonSchema()['functions'], {
      'Upper': {
        'description': 'Upper case',
        'params': _function('Upper').paramsSchema,
        'returns': {'type': 'string'},
      },
      'Log': {'description': 'Logs', 'params': _function('Log').paramsSchema},
    });
  });

  test('a function that returns no type has no returns entry', () {
    final library = LibraryDefinition(components: [_component('A')], functions: [_function('Log')]);

    expect((library.toJsonSchema()['functions']! as Map)['Log'], isNot(contains('returns')));
  });

  test('the actions section has the description and parameters of each action', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Copy', 'Copies')]);

    expect(library.toJsonSchema()['actions'], {
      'Copy': {'description': 'Copies', 'params': _step('Copy').paramsSchema},
    });
  });

  test('the functions and actions come after the definitions', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [_function('Upper')],
      actions: [_step('Copy')],
    );

    expect(library.toJsonSchema().keys.skipWhile((key) => key != r'$defs'), [r'$defs', 'functions', 'actions']);
  });

  test('the spec has the root, components, functions, actions and schema in order', () {
    expect(specLibrary().toSpec().keys, ['root', 'components', 'functions', 'actions', 'schema']);
  });

  test('the spec has the root', () {
    expect(specLibrary().toSpec()['root'], 'Stack');
  });

  test('the spec has no root when the library has none', () {
    expect(LibraryDefinition(components: [_component('A')]).toSpec(), isNot(contains('root')));
  });

  test('the spec has the signature and description of each component by name', () {
    final library = LibraryDefinition(
      components: [
        _component('A', 'The a', [PropSchema('x', PropType.string)]),
        _component('B', 'The b'),
      ],
    );

    expect(library.toSpec()['components'], {
      'A': {'signature': 'A(x: string)', 'description': 'The a'},
      'B': {'signature': 'B()', 'description': 'The b'},
    });
  });

  test('the spec has no component groups when the library has none', () {
    expect(LibraryDefinition(components: [_component('A')]).toSpec(), isNot(contains('componentGroups')));
  });

  test('the spec has each group with its name, components and notes', () {
    final library = LibraryDefinition(
      components: [_component('A'), _component('B')],
      componentGroups: [
        ComponentGroup('First', components: ['A'], notes: ['Note']),
        ComponentGroup('Second', components: ['B']),
      ],
    );

    expect(library.toSpec()['componentGroups'], [
      {
        'name': 'First',
        'components': ['A'],
        'notes': ['Note'],
      },
      {
        'name': 'Second',
        'components': ['B'],
      },
    ]);
  });

  test('the spec has the component groups after the components', () {
    final library = LibraryDefinition(components: [_component('A')], componentGroups: [_group()]);

    expect(library.toSpec().keys, ['components', 'componentGroups', 'schema']);
  });

  test('the spec has no functions when the library has none', () {
    expect(LibraryDefinition(components: [_component('A')]).toSpec(), isNot(contains('functions')));
  });

  test('the spec has no actions when the library has none', () {
    expect(LibraryDefinition(components: [_component('A')]).toSpec(), isNot(contains('actions')));
  });

  test('the spec has the signature and description of each function by name', () {
    final spec = specLibrary().toSpec();

    expect(spec['functions'], {
      'Upper': {'signature': 'Upper(text: string) → string', 'description': 'The text in upper case'},
    });
  });

  test('the spec has the signature and description of each action by name', () {
    final spec = specLibrary().toSpec();

    expect(spec['actions'], {
      'CopyToClipboard': {
        'signature': 'CopyToClipboard(text: string)',
        'description': 'Copies text to the clipboard',
      },
    });
  });

  test('the spec has the JSON schema of the library', () {
    expect(specLibrary().toSpec()['schema'], specLibrary().toJsonSchema());
  });

  test('the compiled schema has the components of the library', () {
    expect(specLibrary().schema.componentNames, specLibrary().componentNames);
  });

  test('the compiled schema reads the root of a program of the library', () {
    expect(_readSpecProgram().root!.typeName, 'Stack');
  });

  test('the compiled schema reads a program of the library without errors', () {
    expect(_readSpecProgram().meta.errors, isEmpty);
  });

  test('the compiled schema reads a program of the library without unresolved references', () {
    expect(_readSpecProgram().meta.unresolved, isEmpty);
  });

  test('the compiled schema reads a program of the library without orphaned statements', () {
    expect(_readSpecProgram().meta.orphaned, isEmpty);
  });

  test('the compiled schema falls back to the root for a program without a root statement', () {
    final library = LibraryDefinition(
      root: 'Card',
      components: [
        _component('Card', '', [PropSchema('title', PropType.string)]),
      ],
    );

    final result = OpenUILangParser(library.schema).parse('title = "x"\nbody = Card(title)');

    expect(result.root!.typeName, 'Card');
  });

  test('the compiled schema reports an argument of the wrong type as a type mismatch of its prop', () {
    final result = OpenUILangParser(specLibrary().schema).parse('root = Stack([Metric("Users", "many")])');

    expect(
      [for (final error in result.meta.errors) (error.code, error.component, error.path)],
      [
        (OpenUIErrorCode.typeMismatch, 'Metric', '/value'),
      ],
    );
  });

  test('the compiled schema reads a component added to the library', () {
    final library = specLibrary().addingContent([
      _component('PlaceCard', '', [PropSchema('title', PropType.string)]),
    ]);

    final result = OpenUILangParser(library.schema).parse('root = Stack([PlaceCard("Ohrid")])');

    expect(result.meta.errors, isEmpty);
  });

  test('the compiled schema reports a wrong argument of a component added to the library', () {
    final library = specLibrary().addingContent([
      _component('PlaceCard', '', [PropSchema('title', PropType.string)]),
    ]);

    final result = OpenUILangParser(library.schema).parse('root = Stack([PlaceCard(5)])');

    expect(
      [for (final error in result.meta.errors) (error.code, error.component)],
      [
        (OpenUIErrorCode.typeMismatch, 'PlaceCard'),
      ],
    );
  });

  test('the compiled schema gives a prop left out the default of the library', () {
    final result = OpenUILangParser(_sizedLibrary().schema).parse('root = Sized()');

    expect(result.root!.props['size'], OpenUIString('m'));
  });

  test('the compiled schema keeps an argument that is given over the default', () {
    final result = OpenUILangParser(_sizedLibrary().schema).parse('root = Sized("s")');

    expect(result.root!.props['size'], OpenUIString('s'));
  });

  test('the compiled schema gives a prop passed an invalid argument the default of the library', () {
    final result = OpenUILangParser(_sizedLibrary().schema).parse('root = Sized("x")');

    expect(result.root!.props['size'], OpenUIString('m'));
  });

  test('the compiled schema reports an argument that is not one of the values of an enumeration', () {
    final result = OpenUILangParser(_sizedLibrary().schema).parse('root = Sized("x")');

    expect([for (final error in result.meta.errors) error.code], [OpenUIErrorCode.typeMismatch]);
  });

  test('the prompt is made with the default options when none are given', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      defaultPromptOptions: PromptOptions(preamble: 'Default preamble', additionalRules: ['Default rule']),
    );

    final prompt = library.systemPrompt();

    expect(prompt, startsWith('Default preamble\n'));
  });

  test('the prompt has the default rules when no options are given', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      defaultPromptOptions: PromptOptions(preamble: 'Default preamble', additionalRules: ['Default rule']),
    );

    expect(library.systemPrompt(), endsWith('- Default rule'));
  });

  test('the prompt is made with the options given instead of the defaults', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      defaultPromptOptions: PromptOptions(preamble: 'Default preamble', additionalRules: ['Default rule']),
    );

    final prompt = library.systemPrompt(PromptOptions(preamble: 'Given preamble'));

    expect(prompt, startsWith('Given preamble\n'));
  });

  test('the prompt has no default rules when options are given', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      defaultPromptOptions: PromptOptions(preamble: 'Default preamble', additionalRules: ['Default rule']),
    );

    expect(library.systemPrompt(PromptOptions(preamble: 'Given preamble')), isNot(contains('Default rule')));
  });

  test('the prompt lists each component with its description and the root', () {
    final library = LibraryDefinition(
      root: 'A',
      components: [
        _component('A', 'The a', [PropSchema('x', PropType.string)]),
      ],
    );

    expect(library.systemPrompt(), contains('A(x: string) — The a'));
  });

  test('the prompt names the root', () {
    final library = LibraryDefinition(root: 'A', components: [_component('A')]);

    expect(library.systemPrompt(), contains('root = A(...)'));
  });

  test('the prompt lists the functions of the library', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      functions: [_function('Upper', 'Upper case', PropType.string)],
    );

    expect(library.systemPrompt(), contains('@Upper(text: string) → string — Upper case'));
  });

  test('the prompt lists the actions of the library', () {
    final library = LibraryDefinition(components: [_component('A')], actions: [_step('Copy', 'Copies')]);

    expect(library.systemPrompt(), contains('- @Copy(text: string) — Copies'));
  });

  test('the prompt lists the groups of the library', () {
    final library = LibraryDefinition(
      components: [_component('A')],
      componentGroups: [
        ComponentGroup('Layout', components: ['A'], notes: ['Use it.']),
      ],
    );

    expect(library.systemPrompt(), contains('### Layout\nA()\nUse it.'));
  });

  for (final name in [
    'PlaceCard',
    'A',
    'Card1',
    'A1b2C3',
    'Counter',
    'Queries',
    'Runner',
    'OpenUrls',
    'ActionExpressions',
  ]) {
    test('$name, a capital letter followed by letters and digits, can be called', () {
      expect(LibraryDefinition.isCallableName(name), isTrue);
    });
  }

  for (final (reason, name) in [
    ('a name starting in lower case', 'placeCard'),
    ('a name with an underscore', 'Place_Card'),
    ('a name with a space', 'Place Card'),
    ('a name with a hyphen', 'Place-Card'),
    ('a name starting in a digit', '1Card'),
    ('a name starting in a capital letter outside ASCII', 'Ünder'),
    ('a name with a letter outside ASCII', 'Cardé'),
    ('an empty name', ''),
    ('a name ending in a line break', 'Card\n'),
    ('the name of a built-in function', 'Count'),
    ('the name of a built-in step', 'Set'),
    ('Action', 'Action'),
    ('Query', 'Query'),
    ('Mutation', 'Mutation'),
    ('ActionExpression, the shape of an action prop', 'ActionExpression'),
    ('OpenUrl, the shape of an open url step', 'OpenUrl'),
    ('ToAssistant, the shape of an assistant step', 'ToAssistant'),
  ]) {
    test('$reason can not be called', () {
      expect(LibraryDefinition.isCallableName(name), isFalse);
    });
  }
}

Map<String, Object?> _definitions(LibraryDefinition library) {
  return library.toJsonSchema()[r'$defs']! as Map<String, Object?>;
}

ComponentSchema _component(String name, [String description = '', List<PropSchema> props = const []]) {
  return ComponentSchema(name, description: description, props: props);
}

ComponentGroup _group() => ComponentGroup('Group', components: ['A']);

FunctionSchema _function(String name, [String description = '', PropType? returns]) {
  return FunctionSchema(
    name,
    description: description,
    params: [PropSchema('text', PropType.string)],
    returns: returns,
  );
}

ActionSchema _step(String name, [String description = '']) {
  return ActionSchema(name, description: description, params: [PropSchema('text', PropType.string)]);
}

ParseResult _readSpecProgram() {
  return OpenUILangParser(
    specLibrary().schema,
  ).parse('root = Stack([Card("Totals", [Metric("Users", 12), Tag("new", "green")])], "column")');
}

// A library whose only component has a prop with a default.
LibraryDefinition _sizedLibrary() {
  return LibraryDefinition(
    components: [
      _component('Sized', '', [
        defaulted('size', enumeration(['s', 'm']), 'm'),
      ]),
    ],
  );
}
