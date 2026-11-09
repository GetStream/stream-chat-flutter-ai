import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_instructions.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  group('A2UIRenderer.capabilities', () {
    test('holds the fence, the catalog id and the instructions', () {
      final capabilities = const A2UIRenderer(catalogId: 'app').capabilities(const [], const []);

      expect(capabilities.keys, ['fence', 'catalog_id', 'instructions']);
      expect(capabilities['fence'], 'ui:a2ui@1.0');
      expect(capabilities['catalog_id'], 'app');
      expect(capabilities['instructions'], isA<String>());
    });

    test('the instructions have their sections in order, each once', () {
      final text = _instructions(
        const A2UIRenderer(catalogId: 'app', instructions: 'Show places as cards.'),
        components: [_placeCard],
        tools: _toolList,
      );

      final headings = text.split('\n').where((line) => line.startsWith('#')).toList();
      expect(headings, [
        '## Writing UI in A2UI',
        '# Generating user interfaces with A2UI v1.0',
        '## Catalog Guidelines',
        "## The app's tools",
        '## The catalog `app`',
      ]);
      expect(text, startsWith('Show places as cards.\n\n## Writing UI in A2UI\n\n'));
      expect(text.indexOf('For layout, use the Row and Column'), greaterThan(text.indexOf('# Generating')));
      expect(text.indexOf('For layout, use the Row and Column'), lessThan(text.indexOf('## Catalog Guidelines')));
    });

    test('without instructions of its own, they start with how to write UI', () {
      expect(_instructions(const A2UIRenderer()), startsWith('## Writing UI in A2UI\n\n'));
      expect(_instructions(const A2UIRenderer(instructions: '')), startsWith('## Writing UI in A2UI\n\n'));
    });

    test('the writing section names the fence and the catalog id', () {
      final text = _instructions(const A2UIRenderer(catalogId: 'acme:catalog'));

      expect(text, contains('whose info string is `ui:a2ui@1.0`'));
      expect(text, contains('the `catalogId` `acme:catalog`'));
    });

    test('the catalog is one line of JSON Schema, with sorted keys and without its guidelines', () {
      final text = _instructions(const A2UIRenderer());
      final line = _catalogLine(text, 'getstream.io:app-catalog');

      expect(line, isNot(contains('\n')));
      final catalog = jsonDecode(line) as Map<String, Object?>;
      expect(catalog['catalogId'], 'getstream.io:app-catalog');
      expect(catalog, isNot(contains('instructions')));
      expect(catalog.keys.toList(), [...catalog.keys]..sort());
      expect((catalog['components']! as Map<String, Object?>).keys, containsAll(['Text', 'Video', 'AudioPlayer']));
      expect((catalog['functions']! as Map<String, Object?>).keys, containsAll(['formatString', 'openUrl']));
    });

    test('a component removed from the catalog is not in the catalog the agent is told about', () {
      final text = _instructions(A2UIRenderer(catalog: A2UICatalog.basic.removing(['Video', 'Slider'])));
      final catalog = jsonDecode(_catalogLine(text, 'getstream.io:app-catalog')) as Map<String, Object?>;
      final components = (catalog['components']! as Map<String, Object?>).keys;

      expect(components, isNot(contains('Video')));
      expect(components, isNot(contains('Slider')));
      expect(components, containsAll(['Text', 'AudioPlayer', 'Button']));
      final union = jsonEncode((catalog[r'$defs']! as Map<String, Object?>)['anyComponent']);
      expect(union, isNot(contains('Video')));
      expect(union, contains('AudioPlayer'));
    });

    test("the app's components are in the catalog with their parameters and descriptions", () {
      final text = _instructions(const A2UIRenderer(), components: [_placeCard, _cardNamed]);
      final catalog = jsonDecode(_catalogLine(text, 'getstream.io:app-catalog')) as Map<String, Object?>;
      final components = catalog['components']! as Map<String, Object?>;

      expect(components['PlaceCard'], {
        'type': 'object',
        'description': 'A place. Tapping it asks about the place.',
        'properties': {
          'component': {'const': 'PlaceCard'},
          'title': {'type': 'string'},
        },
        'required': ['component', 'title'],
      });
      // One named like a basic component stays the basic one.
      expect(jsonEncode(components['Card']), isNot(contains("The app's card")));
    });

    test("the app's tools are listed, with whether they only read and their arguments", () {
      final text = _instructions(const A2UIRenderer(), tools: _toolList);

      expect(
        text,
        contains(
          "## The app's tools\n\nThese run on the person's device.",
        ),
      );
      expect(
        text,
        contains(
          '\n\n'
          "- `list_events` (read-only): Lists the person's events. "
          'Arguments: `{"properties":{"day":{"type":"string"}},"type":"object"}`\n'
          '- `add_reminder`: Adds a reminder.\n\n## The catalog',
        ),
      );
    });

    test('without tools, there is no tools section', () {
      expect(_instructions(const A2UIRenderer()), isNot(contains("## The app's tools")));
    });

    test('the same arguments give the same instructions every time', () {
      String once() => _instructions(
        A2UIRenderer(catalog: A2UICatalog.basic.removing(['Video']), instructions: 'Be brief.'),
        components: [_placeCard],
        tools: _toolList,
      );

      expect(once(), once());
    });

    test("the host's capabilities hold the instructions, with the host's tools", () {
      final host = AIUIHost(renderers: [const A2UIRenderer()], send: (_) async {}, tools: [TestTool('add_reminder')]);
      addTearDown(host.dispose);

      final renderers = host.capabilities['renderers']! as List<Object?>;
      final instructions = (renderers.single! as Map<String, Object?>)['instructions']! as String;
      expect(instructions, contains('- `add_reminder` (read-only): A test tool'));
    });
  });

  group("iOS's instructions", () {
    final fixture =
        jsonDecode(File('test/fixtures/ios_a2ui_instructions.json').readAsStringSync()) as Map<String, Object?>;

    test('for the basic catalog read the same, but for the catalog JSON', () {
      final ios = fixture['basic']! as String;
      final flutter = _instructions(const A2UIRenderer());

      _expectSameButCatalog(flutter, ios, 'getstream.io:app-catalog');
    });

    test('with a removed component, a preamble, an app component and tools read the same, but for the catalog '
        'JSON', () {
      final ios = fixture['full']! as String;
      final flutter = _instructions(
        A2UIRenderer(
          catalog: A2UICatalog.basic.removing(['Video']),
          catalogId: 'app',
          instructions: 'Show places as cards.',
        ),
        components: [_placeCard],
        tools: _toolList,
      );

      _expectSameButCatalog(flutter, ios, 'app');
      final iosCatalog = jsonDecode(_catalogLine(ios, 'app')) as Map<String, Object?>;
      final catalog = jsonDecode(_catalogLine(flutter, 'app')) as Map<String, Object?>;
      final iosComponents = iosCatalog['components']! as Map<String, Object?>;
      final components = catalog['components']! as Map<String, Object?>;
      expect(components['PlaceCard'], iosComponents['PlaceCard']);
    });
  });

  group('A2UIInstructions', () {
    test("the guidelines, the app's tools and the catalog come after the protocol, in their places", () {
      const instructions = A2UIInstructions(
        catalogId: 'app',
        document: {'b': 1, 'a': 2},
        fence: 'ui:a2ui@1.0',
        guidelines: 'Guidelines.',
        preamble: 'Preamble.',
        tools: ['- `tool`'],
      );

      final sections = instructions.text.split('\n\n');
      expect(sections.first, 'Preamble.');
      expect(
        instructions.text,
        endsWith(
          'Guidelines.\n\n'
          "## The app's tools\n\n${sections[sections.indexOf("## The app's tools") + 1]}\n\n- `tool`\n\n"
          '## The catalog `app`\n\n```json\n{"a":2,"b":1}\n```',
        ),
      );
    });

    test('a section with nothing to say is left out', () {
      const instructions = A2UIInstructions(catalogId: 'app', document: {}, fence: 'f', guidelines: '');

      expect(
        instructions.text,
        allOf(
          isNot(contains("## The app's tools")),
          endsWith('to change it.\n\n## The catalog `app`\n\n```json\n{}\n```'),
        ),
      );
    });

    test('sortedJson sorts the keys of nested objects, inside lists too', () {
      expect(
        A2UIInstructions.sortedJson({
          'b': [
            {'d': 1, 'c': 2},
          ],
          'a': {'f': 3, 'e': 4},
        }),
        '{"a":{"e":4,"f":3},"b":[{"c":2,"d":1}]}',
      );
    });

    test('a tool that takes no arguments is listed without them', () {
      expect(
        A2UIInstructions.toolLine(const AIToolDefinition(name: 'ping', description: '')),
        '- `ping`',
      );
      expect(
        A2UIInstructions.toolLine(
          const AIToolDefinition(name: 'ping', description: 'Pings.', parameters: {'type': 'object'}),
        ),
        '- `ping`: Pings.',
      );
    });
  });
}

String _instructions(
  A2UIRenderer renderer, {
  List<AIUIComponent<Object?>> components = const [],
  List<AIToolDefinition> tools = const [],
}) {
  return renderer.capabilities(components, tools)['instructions']! as String;
}

// The catalog's JSON in [text], the instructions for the catalog [catalogId].
String _catalogLine(String text, String catalogId) {
  final start = '## The catalog `$catalogId`\n\n```json\n';
  final from = text.indexOf(start);
  expect(from, isNot(-1), reason: 'no catalog section for $catalogId');
  final rest = text.substring(from + start.length);
  return rest.substring(0, rest.indexOf('\n```'));
}

void _expectSameButCatalog(String flutter, String ios, String catalogId) {
  final flutterLine = _catalogLine(flutter, catalogId);
  final iosLine = _catalogLine(ios, catalogId);
  // iOS's protocol overview also lists `callRendererFunction` and
  // `agentFunctionResponse`, which its writing section tells the model never to
  // write, so ours leaves them out.
  final iosWithoutRendererMessages = ios
      .replaceFirst('- `callRendererFunction`: asks the renderer to run one of its functions.\n', '')
      .replaceFirst('- `agentFunctionResponse`: answers a `callAgentFunction` request from the renderer.\n', '');
  expect(iosWithoutRendererMessages, isNot(ios));
  expect(flutter.replaceFirst(flutterLine, '<catalog>'), iosWithoutRendererMessages.replaceFirst(iosLine, '<catalog>'));

  final catalog = jsonDecode(flutterLine) as Map<String, Object?>;
  final iosCatalog = jsonDecode(iosLine) as Map<String, Object?>;
  for (final key in ['components', 'functions']) {
    expect(
      (catalog[key]! as Map<String, Object?>).keys.toSet(),
      (iosCatalog[key]! as Map<String, Object?>).keys.toSet(),
      reason: key,
    );
  }
  expect(catalog['catalogId'], iosCatalog['catalogId']);
}

const _toolList = [
  AIToolDefinition(
    name: 'list_events',
    description: "Lists the person's events.",
    parameters: {
      'type': 'object',
      'properties': {
        'day': {'type': 'string'},
      },
    },
    isReadOnly: true,
  ),
  AIToolDefinition(name: 'add_reminder', description: 'Adds a reminder.'),
];

const _placeCard = _TestComponent(
  AIUIComponentDefinition(
    name: 'place_card',
    description: 'A place',
    parameters: [AIUIParameter.required('title', AIUIParameterType.string)],
    events: [AIUIComponentEvent(name: 'ask_about', description: 'Tapping it asks about the place')],
  ),
);

const _cardNamed = _TestComponent(AIUIComponentDefinition(name: 'card', description: "The app's card"));

final class _TestComponent extends AIUIComponent<Object?> {
  const _TestComponent(this.definition);

  @override
  final AIUIComponentDefinition definition;

  @override
  Object? readArguments(AIUIArguments arguments) => null;

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) => const SizedBox.shrink();
}
