// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/portable_component.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/skipped_component_log.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';

import 'library/spec_library.dart';

void main() {
  test('a readable definition with a callable name is placeable', () {
    final placeable = placeableComponents(specLibrary(), [_definition('place_card')]);

    expect(placeable.map((entry) => entry.$2.name), ['PlaceCard']);
  });

  test('a placeable component is the one portableComponentSchema reads', () {
    final definition = _definition('place_card');

    expect(placeableComponents(specLibrary(), [definition]).single.$2, portableComponentSchema(definition));
  });

  group('a definition that is left out is logged', () {
    late List<String> logs;
    late void Function(String) original;

    setUp(() {
      logs = [];
      original = skippedComponentLog;
      skippedComponentLog = logs.add;
    });

    tearDown(() => skippedComponentLog = original);

    test('when it can not be read, with its name', () {
      placeableComponents(specLibrary(), [
        {'name': ''},
        {'description': 'no name'},
      ]);

      expect(logs, hasLength(2));
      expect(logs[0], contains('""'));
      expect(logs[1], contains('index 1'));
    });

    test('when its name can not be called, with the name', () {
      placeableComponents(specLibrary(), [_definition('open_url')]);

      expect(logs.single, allOf(contains('"OpenUrl"'), contains("can't be called")));
    });

    test('when its name is taken, with the name', () {
      placeableComponents(specLibrary(), [_definition('stack'), _definition('place_card'), _definition('place_card')]);

      expect(logs, hasLength(2));
      expect(logs[0], allOf(contains('"Stack"'), contains('already')));
      expect(logs[1], allOf(contains('"PlaceCard"'), contains('already')));
    });

    test('not when it is placed', () {
      placeableComponents(specLibrary(), [_definition('place_card')]);

      expect(logs, isEmpty);
    });
  });

  test('no definitions give no components', () {
    expect(placeableComponents(specLibrary(), const []), isEmpty);
  });

  test('a definition that can not be read is left out', () {
    final placeable = placeableComponents(specLibrary(), [
      {'description': 'no name'},
    ]);

    expect(placeable, isEmpty);
  });

  test('a definition whose name is not a string is left out', () {
    final placeable = placeableComponents(specLibrary(), [
      {'name': 5},
      {'name': null},
    ]);

    expect(placeable, isEmpty);
  });

  test('a definition with an empty name is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('')]), isEmpty);
  });

  for (final name in ['_', 'ünder', '1st', 'place.card']) {
    test('a definition named $name, which can not be called, is left out', () {
      expect(placeableComponents(specLibrary(), [_definition(name)]), isEmpty);
    });
  }

  for (final name in ['action_expression', 'open_url', 'to_assistant']) {
    test('a definition named $name, like the shape of an action, is left out', () {
      expect(placeableComponents(specLibrary(), [_definition(name)]), isEmpty);
    });
  }

  for (final name in ['open_urls', 'action_expressions']) {
    test('a definition named $name, which only looks like the shape of an action, is placeable', () {
      expect(placeableComponents(specLibrary(), [_definition(name)]), hasLength(1));
    });
  }

  test('a definition with a value that is not JSON data is left out', () {
    final definition = {..._definition('place_card'), 'description': DateTime(2026)};

    expect(placeableComponents(specLibrary(), [definition]), isEmpty);
  });

  test('a definition nested deeper than the JSON depth limit is left out', () {
    expect(placeableComponents(specLibrary(), [_nestedDefinition(600)]), isEmpty);
  });

  test('a definition nested well under the JSON depth limit is placeable', () {
    expect(placeableComponents(specLibrary(), [_nestedDefinition(20)]), hasLength(1));
  });

  test('a definition nested well under the JSON depth limit builds a library schema', () {
    final components = placeableComponents(LibraryDefinition.chat, [_nestedDefinition(20)]);

    expect(() => LibraryDefinition.chat.addingContent([components.single.$2]).schema, returnsNormally);
  });

  test('a definition nested deep enough to be placeable at all is deeper than a hundred levels', () {
    expect(_deepestPlaceableLevels(), greaterThan(100));
  });

  test('the deepest placeable definition builds a library schema', () {
    final components = placeableComponents(LibraryDefinition.chat, [_nestedDefinition(_deepestPlaceableLevels())]);

    expect(() => LibraryDefinition.chat.addingContent([components.single.$2]).schema, returnsNormally);
  });

  test('a definition one level deeper than the deepest placeable one is left out', () {
    expect(placeableComponents(LibraryDefinition.chat, [_nestedDefinition(_deepestPlaceableLevels() + 1)]), isEmpty);
  });

  test('a definition named like a built-in function is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('count')]), isEmpty);
  });

  test('a definition named like a built-in step is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('open_url')]), isEmpty);
  });

  test('a definition named Query is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('query')]), isEmpty);
  });

  test('a definition named Mutation is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('mutation')]), isEmpty);
  });

  test('a definition whose name only looks like a reserved one is placeable', () {
    final placeable = placeableComponents(specLibrary(), [_definition('queries'), _definition('counter')]);

    expect(placeable.map((entry) => entry.$2.name), ['Queries', 'Counter']);
  });

  test('a definition named like a component of the library is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('card')]), isEmpty);
  });

  test('a definition named like a component of the library by its converted name is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('select_item')]), isEmpty);
  });

  test('a definition named like a function of the library is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('upper')]), isEmpty);
  });

  test('a definition named like an action of the library is left out', () {
    expect(placeableComponents(specLibrary(), [_definition('copy_to_clipboard')]), isEmpty);
  });

  test('a definition named like an earlier definition is left out', () {
    final placeable = placeableComponents(specLibrary(), [
      _definition('place_card', 'first'),
      _definition('place-card', 'second'),
    ]);

    expect(placeable.map((entry) => entry.$1), [0]);
  });

  test('a definition named like an earlier definition leaves the earlier one placed', () {
    final placeable = placeableComponents(specLibrary(), [
      _definition('place_card', 'first'),
      _definition('place-card', 'second'),
    ]);

    expect(placeable.single.$2.description, 'first.');
  });

  test('a definition named like an earlier one by an equal converted name is left out', () {
    final placeable = placeableComponents(specLibrary(), [_definition('PlaceCard'), _definition('place card')]);

    expect(placeable, hasLength(1));
  });

  test('a definition whose name only differs from an earlier one is placeable', () {
    final placeable = placeableComponents(specLibrary(), [_definition('place_card'), _definition('place_card_2')]);

    expect(placeable.map((entry) => entry.$2.name), ['PlaceCard', 'PlaceCard2']);
  });

  test('a definition that was left out does not stop a later one of its name', () {
    final placeable = placeableComponents(specLibrary(), [
      {'description': 'unreadable'},
      _definition('place_card'),
    ]);

    expect(placeable.map((entry) => entry.$1), [1]);
  });

  test('a definition left out as not callable does not stop a later one of its converted name', () {
    final placeable = placeableComponents(specLibrary(), [_definition('count'), _definition('place_card')]);

    expect(placeable.map((entry) => entry.$2.name), ['PlaceCard']);
  });

  test('each component comes with the index of its definition', () {
    final placeable = placeableComponents(specLibrary(), [
      _definition('first_one'),
      {'description': 'unreadable'},
      _definition('second_one'),
      _definition('card'),
      _definition('third_one'),
    ]);

    expect(placeable.map((entry) => (entry.$1, entry.$2.name)), [(0, 'FirstOne'), (2, 'SecondOne'), (4, 'ThirdOne')]);
  });

  test('placing components does not change the library', () {
    final library = specLibrary();

    placeableComponents(library, [_definition('place_card')]);

    expect(library.componentNames, specLibrary().componentNames);
  });

  test('without app instructions the instructions are the system prompt of the library', () {
    final library = _library();

    expect(openUIInstructions(library), library.systemPrompt());
  });

  test('app instructions that are null add nothing', () {
    final library = _library();

    expect(openUIInstructions(library, appInstructions: null), library.systemPrompt());
  });

  test('app instructions that are empty add nothing', () {
    final library = _library();

    expect(openUIInstructions(library, appInstructions: ''), library.systemPrompt());
  });

  test('app instructions that are blank add nothing', () {
    final library = _library();

    expect(openUIInstructions(library, appInstructions: ' \n\t '), library.systemPrompt());
  });

  test('app instructions come first, then a blank line, then the prompt', () {
    final library = _library();

    expect(openUIInstructions(library, appInstructions: 'Be kind.'), 'Be kind.\n\n${library.systemPrompt()}');
  });

  test('app instructions are kept as they are', () {
    final library = _library();

    expect(
      openUIInstructions(library, appInstructions: '  Be kind.\n'),
      '  Be kind.\n\n\n${library.systemPrompt()}',
    );
  });

  test('app instructions that are not blank but have blank edges are added', () {
    expect(openUIInstructions(_library(), appInstructions: '\nX'), startsWith('\nX\n\n'));
  });

  test('the components are added as content', () {
    final instructions = openUIInstructions(_library(), components: [_placeCard()]);

    expect(instructions, contains('Card(children: (TextContent | PlaceCard)[])'));
  });

  test('the components are listed under App components', () {
    final instructions = openUIInstructions(_library(), components: [_placeCard()]);

    expect(instructions, contains('### App components\nPlaceCard(title: string) — A place'));
  });

  test('components that can not be added change nothing', () {
    final library = _library();

    expect(
      openUIInstructions(library, components: [_component('place_card'), _component('Count')]),
      library.systemPrompt(),
    );
  });

  test('tools are listed with the wording for read-only ones', () {
    final instructions = openUIInstructions(
      _library(),
      tools: [HostTool('list_trips', description: 'Lists trips.', isReadOnly: true)],
    );

    expect(instructions, contains('- list_trips() → any\n  Lists trips. ${HostTool.readOnlyUse}\n'));
  });

  test('tools are listed with the wording for ones that change something', () {
    final instructions = openUIInstructions(_library(), tools: [HostTool('book_trip', description: 'Books a trip.')]);

    expect(instructions, contains('- book_trip() → any\n  Books a trip. ${HostTool.changingUse}\n'));
  });

  test('a tool without a description is listed with the wording only', () {
    final instructions = openUIInstructions(_library(), tools: [HostTool('ping', isReadOnly: true)]);

    expect(instructions, contains('- ping() → any\n  ${HostTool.readOnlyUse}\n'));
  });

  test('the arguments of a tool are listed from its input schema', () {
    final instructions = openUIInstructions(
      _library(),
      tools: [
        HostTool(
          'list_trips',
          inputSchema: {
            'type': 'object',
            'properties': {
              'city': {'type': 'string'},
            },
            'required': ['city'],
          },
        ),
      ],
    );

    expect(instructions, contains('- list_trips(city: string) → any'));
  });

  test('tools are listed after the default tools of the library', () {
    final library = _library(options: PromptOptions(tools: [NamedTool('library_tool')]));

    final instructions = openUIInstructions(library, tools: [HostTool('app_tool')]);

    expect(instructions.indexOf('- library_tool'), lessThan(instructions.indexOf('- app_tool(')));
  });

  test('the default tools of the library stay listed when tools are added', () {
    final library = _library(options: PromptOptions(tools: [NamedTool('library_tool')]));

    expect(openUIInstructions(library, tools: [HostTool('app_tool')]), contains('- library_tool\n'));
  });

  test('tools in the order given are listed in that order', () {
    final instructions = openUIInstructions(_library(), tools: [HostTool('b_tool'), HostTool('a_tool')]);

    expect(instructions.indexOf('- b_tool('), lessThan(instructions.indexOf('- a_tool(')));
  });

  test('tools turn on tool calls', () {
    expect(openUIInstructions(_library(), tools: [HostTool('a')]), contains('## Query — Live Data Fetching'));
  });

  test('the library default examples are kept', () {
    expect(openUIInstructions(_library()), contains('## Examples\n\nroot = Card([TextContent("Hi")])\n'));
  });

  test('the library default rules are kept', () {
    expect(openUIInstructions(_library()), endsWith('- Library rule'));
  });

  test('the library default preamble is kept', () {
    expect(openUIInstructions(_library()), startsWith('Library preamble\n'));
  });

  test('the library default tool examples are kept next to added tools', () {
    final library = _library(options: PromptOptions(toolExamples: ['TOOL-EXAMPLE']));

    expect(openUIInstructions(library, tools: [HostTool('a')]), contains('TOOL-EXAMPLE'));
  });

  test('the default edit mode of the library is kept', () {
    final library = _library(options: PromptOptions(editMode: true));

    expect(openUIInstructions(library, tools: [HostTool('a')]), contains('## Edit Mode'));
  });

  test('the default flags of the library are kept when tools are added', () {
    final library = _library(options: PromptOptions(toolCalls: false));

    expect(openUIInstructions(library, tools: [HostTool('a')]), isNot(contains('## Query — Live Data Fetching')));
  });

  test('the library is not changed', () {
    final library = _library();

    openUIInstructions(library, components: [_placeCard()], tools: [HostTool('a')]);

    expect(library.componentNames, ['Card', 'TextContent']);
  });

  test('instructions do not change the default tools of the library', () {
    final library = _library();

    openUIInstructions(library, components: [_placeCard()], tools: [HostTool('a')]);

    expect(library.defaultPromptOptions.tools, isEmpty);
  });

  test('components and tools together are both in the instructions', () {
    final instructions = openUIInstructions(_library(), components: [_placeCard()], tools: [HostTool('a')]);

    expect(instructions, allOf(contains('PlaceCard(title: string)'), contains('- a() → any')));
  });

  test('the chat library places the three components of the Ohrid app', () {
    expect(placeableComponents(LibraryDefinition.chat, _ohridDefinitions()).map((entry) => entry.$2.name), [
      'PlaceCard',
      'TripMap',
      'CalendarCheck',
    ]);
  });

  test('the instructions of the chat library list the Ohrid components under App components', () {
    final instructions = _ohridInstructions();

    expect(instructions, contains('### App components\nPlaceCard('));
  });

  test('the instructions of the chat library list the Ohrid components after its own', () {
    final instructions = _ohridInstructions();

    expect(instructions.indexOf('Card('), lessThan(instructions.indexOf('### App components')));
  });

  test('the instructions of the chat library start with the app instructions', () {
    expect(_ohridInstructions(), startsWith('You plan trips.\n\n'));
  });

  test('the instructions of the chat library are the prompt of the library with the components added', () {
    final components = [
      for (final (_, schema) in placeableComponents(LibraryDefinition.chat, _ohridDefinitions())) schema,
    ];

    expect(
      _ohridInstructions(),
      'You plan trips.\n\n${LibraryDefinition.chat.addingContent(components).systemPrompt()}',
    );
  });
}

List<Map<String, Object?>> _ohridDefinitions() {
  final decoded = jsonDecode(File('test/fixtures/ohrid_app_components.json').readAsStringSync()) as List<Object?>;
  return [for (final definition in decoded) definition! as Map<String, Object?>];
}

String _ohridInstructions() {
  final components = [
    for (final (_, schema) in placeableComponents(LibraryDefinition.chat, _ohridDefinitions())) schema,
  ];
  return openUIInstructions(LibraryDefinition.chat, appInstructions: 'You plan trips.', components: components);
}

// A definition whose only parameter is a list of lists, `levels` of them deep,
// built from the inside out.
Map<String, Object?> _nestedDefinition(int levels) {
  var schema = <String, Object?>{'type': 'string'};
  for (var i = 0; i < levels; i++) {
    schema = {'type': 'array', 'items': schema};
  }
  return {
    'name': 'deep',
    'parameters': {
      'type': 'object',
      'properties': {'x': schema},
    },
  };
}

// The most levels a nested definition can have and still be placeable.
int _deepestPlaceableLevels() {
  for (var levels = 600; levels > 0; levels--) {
    if (placeableComponents(LibraryDefinition.chat, [_nestedDefinition(levels)]).isNotEmpty) return levels;
  }
  return 0;
}

Map<String, Object?> _definition(String name, [String description = '']) {
  return {
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'parameters': {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
      },
      'required': ['title'],
    },
  };
}

LibraryDefinition _library({PromptOptions? options}) {
  return LibraryDefinition(
    root: 'Card',
    components: [
      _component('Card', [
        PropSchema('children', PropType.array(PropType.components(['TextContent']))),
      ]),
      _component('TextContent', [PropSchema('text', PropType.string)]),
    ],
    defaultPromptOptions: (options ?? PromptOptions()).copyWith(
      preamble: 'Library preamble',
      examples: ['root = Card([TextContent("Hi")])'],
      additionalRules: ['Library rule'],
    ),
  );
}

ComponentSchema _placeCard() {
  return ComponentSchema('PlaceCard', description: 'A place', props: [PropSchema('title', PropType.string)]);
}

ComponentSchema _component(String name, [List<PropSchema> props = const []]) {
  return ComponentSchema(name, description: '', props: props);
}
