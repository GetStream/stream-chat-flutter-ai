@Tags(['conformance'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_generator.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';

import '../src/core/library/spec_library.dart';

// The system prompts OpenUI's own implementation generates for its chat,
// standard and specification libraries with different options
// (generated/prompt-goldens.json), compared character for character: once
// generated from the specs it wrote, and once from this package's libraries.
void main() {
  final goldens = _goldens();

  test('the prompt goldens have their 14 cases', () {
    expect(goldens, hasLength(14));
  });

  test('the prompt goldens cover the chat, standard and specification libraries', () {
    expect({for (final golden in goldens) golden['library']}, {'chat', 'standard', 'spec'});
  });

  test("a prompt differs from another case's golden", () {
    final first = goldens.first;
    final other = goldens.firstWhere((golden) => golden['library'] == first['library'] && golden != first);

    expect(_libraryPrompt(first), isNot(other['prompt']));
  });

  for (final golden in goldens) {
    final name = golden['name']! as String;

    test('$name: the prompt generated from the spec is the golden', () {
      final spec = _spec(golden['library']! as String);
      final prompt = PromptGenerator.generate(PromptSpec.fromLibrarySpec(spec, options: _options(golden['options'])));

      expect(_firstDifference(prompt, golden['prompt']! as String), isNull);
    });

    test("$name: the package library's prompt is the golden", () {
      expect(_firstDifference(_libraryPrompt(golden), golden['prompt']! as String), isNull);
    });
  }

  test("the chat library's prompt without options is the chat-default golden", () {
    final golden = goldens.firstWhere((golden) => golden['name'] == 'chat-default');

    expect(LibraryDefinition.chat.systemPrompt(), golden['prompt']);
  });

  test("the standard library's prompt without options is the standard-default golden", () {
    final golden = goldens.firstWhere((golden) => golden['name'] == 'standard-default');

    expect(LibraryDefinition.standard.systemPrompt(), golden['prompt']);
  });
}

List<Map<String, Object?>> _goldens() {
  final json = jsonDecode(File('test/conformance/generated/prompt-goldens.json').readAsStringSync()) as List<Object?>;
  return json.cast<Map<String, Object?>>();
}

Map<String, Object?> _spec(String library) {
  final file = switch (library) {
    'chat' => 'upstream-chat-library.spec.json',
    'spec' => 'spec-library.json',
    _ => 'upstream-playground-library.spec.json',
  };
  return jsonDecode(File('test/conformance/generated/$file').readAsStringSync()) as Map<String, Object?>;
}

String _libraryPrompt(Map<String, Object?> golden) {
  final library = switch (golden['library']) {
    'chat' => LibraryDefinition.chat,
    'spec' => specLibrary(),
    _ => LibraryDefinition.standard,
  };
  return library.systemPrompt(_options(golden['options']));
}

// The golden's options, as `generateSystemPrompt` takes them.
PromptOptions _options(Object? json) {
  final options = json! as Map<String, Object?>;
  List<String> strings(String key) => [...(options[key] as List<Object?>? ?? const []).cast<String>()];
  return PromptOptions(
    preamble: options['preamble'] as String?,
    additionalRules: strings('additionalRules'),
    examples: strings('examples'),
    toolExamples: strings('toolExamples'),
    tools: [
      for (final tool in options['tools'] as List<Object?>? ?? const [])
        switch (tool) {
          final String name => NamedTool(name),
          final Map<String, Object?> spec => ToolSpec(
            spec['name']! as String,
            description: spec['description'] as String?,
            inputSchema: spec['inputSchema'] as Map<String, Object?>? ?? const {},
            outputSchema: spec['outputSchema'] as Map<String, Object?>? ?? const {},
          ),
          _ => throw FormatException('Not a tool', tool),
        },
    ],
    editMode: options['editMode'] as bool? ?? false,
    inlineMode: options['inlineMode'] as bool? ?? false,
    toolCalls: options['toolCalls'] as bool?,
    bindings: options['bindings'] as bool?,
    builtinFunctions: options['builtinFunctions'] as bool?,
  );
}

// The first line where `actual` and `expected` differ, or `null` when they
// are the same text.
String? _firstDifference(String actual, String expected) {
  if (actual == expected) return null;
  final actualLines = actual.split('\n');
  final expectedLines = expected.split('\n');
  for (var index = 0; index < actualLines.length || index < expectedLines.length; index += 1) {
    final left = index < actualLines.length ? actualLines[index] : '<missing>';
    final right = index < expectedLines.length ? expectedLines[index] : '<missing>';
    if (left != right) return 'line ${index + 1}:\n  actual:   $left\n  expected: $right';
  }
  return 'the same lines, with different line endings';
}
