import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/portable_component.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';

// The instructions the Stream agent backend gives its model for the trip
// assistant (test/fixtures/README.md), made the way its generator makes them:
// the chat library without the components `prompt.json` doesn't keep, the
// app's components added as content with its notes, its preamble, its rules
// after the library's, and its examples in place of the library's.
void main() {
  test('the instructions are the ones the agent backend generated', () {
    final expected = File('test/fixtures/vision_agents_instructions.md').readAsStringSync();

    // The generator prints the prompt with a line break after it.
    expect('${_library().systemPrompt(_options())}\n', expected);
  });

  test('the instructions keep the chat components the config keeps and add the ones of the app', () {
    final kept = (_config()['keep']! as List<Object?>).length;
    final added =
        (jsonDecode(File('test/fixtures/ohrid_app_components.json').readAsStringSync()) as List<Object?>).length;

    expect(_library().components, hasLength(kept + added));
  });

  test("every program of the instructions' examples reads with no errors", () {
    expect(
      _exampleResults(),
      allOf(isNotEmpty, everyElement(predicate<ParseResult>((result) => result.meta.errors.isEmpty))),
    );
  });

  test("every program of the instructions' examples leaves nothing unresolved", () {
    expect(
      _exampleResults(),
      allOf(isNotEmpty, everyElement(predicate<ParseResult>((result) => result.meta.unresolved.isEmpty))),
    );
  });

  test("every program of the instructions' examples leaves nothing orphaned", () {
    expect(
      _exampleResults(),
      allOf(isNotEmpty, everyElement(predicate<ParseResult>((result) => result.meta.orphaned.isEmpty))),
    );
  });

  test("every program of the instructions' examples has a root", () {
    expect(_exampleResults(), allOf(isNotEmpty, everyElement(predicate<ParseResult>((result) => result.root != null))));
  });
}

List<ParseResult> _exampleResults() {
  final library = _library();
  return [
    for (final example in _config()['examples']! as List<Object?>)
      for (final block in (example! as String).split('```openui-lang\n').skip(1))
        OpenUILangParser(library.schema).parse(block.split('\n```').first),
  ];
}

Map<String, Object?> _config() {
  return jsonDecode(File('test/fixtures/vision_agents_prompt.json').readAsStringSync()) as Map<String, Object?>;
}

LibraryDefinition _library() {
  final config = _config();
  final keep = {...(config['keep']! as List<Object?>).cast<String>()};
  final chat = LibraryDefinition.chat;
  final definitions = jsonDecode(File('test/fixtures/ohrid_app_components.json').readAsStringSync()) as List<Object?>;
  return chat.removing(chat.componentNames.where((name) => !keep.contains(name))).addingContent(
    [for (final definition in definitions) portableComponentSchema(definition! as Map<String, Object?>)],
    notes: (config['notes']! as List<Object?>).cast<String>(),
  );
}

PromptOptions _options() {
  final config = _config();
  final options = _library().defaultPromptOptions;
  return options.copyWith(
    preamble: config['preamble']! as String,
    additionalRules: [...options.additionalRules, ...(config['rules']! as List<Object?>).cast<String>()],
    examples: (config['examples']! as List<Object?>).cast<String>(),
  );
}
