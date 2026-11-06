// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';

void main() {
  test('options given nothing have no preamble', () {
    expect(PromptOptions().preamble, isNull);
  });

  test('options given nothing have no rules', () {
    expect(PromptOptions().additionalRules, isEmpty);
  });

  test('options given nothing have no examples', () {
    expect(PromptOptions().examples, isEmpty);
  });

  test('options given nothing have no tool examples', () {
    expect(PromptOptions().toolExamples, isEmpty);
  });

  test('options given nothing have no tools', () {
    expect(PromptOptions().tools, isEmpty);
  });

  test('options given nothing have edit mode off', () {
    expect(PromptOptions().editMode, isFalse);
  });

  test('options given nothing have inline mode off', () {
    expect(PromptOptions().inlineMode, isFalse);
  });

  test('options given nothing leave tool calls to their default', () {
    expect(PromptOptions().toolCalls, isNull);
  });

  test('options given nothing leave bindings to their default', () {
    expect(PromptOptions().bindings, isNull);
  });

  test('options given nothing leave built-in functions to their default', () {
    expect(PromptOptions().builtinFunctions, isNull);
  });

  _testEquivalent('equal options', _options);

  test('options of other preambles are unequal', () {
    expect(_options(), isNot(_options(preamble: 'Other')));
  });

  test('options of other rules are unequal', () {
    expect(_options(), isNot(_options(rules: ['Other'])));
  });

  test('options of other examples are unequal', () {
    expect(_options(), isNot(_options(examples: ['Other'])));
  });

  test('options of other tool examples are unequal', () {
    expect(_options(), isNot(_options(toolExamples: ['Other'])));
  });

  test('options of other tools are unequal', () {
    expect(_options(), isNot(_options(tools: [NamedTool('other')])));
  });

  test('options that differ in edit mode are unequal', () {
    expect(_options(), isNot(_options(editMode: true)));
  });

  test('options that differ in inline mode are unequal', () {
    expect(_options(), isNot(_options(inlineMode: true)));
  });

  test('options that differ in tool calls are unequal', () {
    expect(_options(), isNot(_options(toolCalls: true)));
  });

  test('options that differ in bindings are unequal', () {
    expect(_options(), isNot(_options(bindings: true)));
  });

  test('options that differ in built-in functions are unequal', () {
    expect(_options(), isNot(_options(builtinFunctions: true)));
  });

  test('a flag left to its default is not equal to one set to false', () {
    expect(_options(), isNot(_options(toolCalls: false)));
  });

  test('options with the rules in another order are unequal', () {
    expect(_options(rules: ['a', 'b']), isNot(_options(rules: ['b', 'a'])));
  });

  test('copying with nothing gives equal options', () {
    expect(_options().copyWith(), _options());
  });

  test('copying with nothing gives options with the same hashCode', () {
    expect(_options().copyWith().hashCode, _options().hashCode);
  });

  test('copying keeps edit mode', () {
    expect(_flagged().copyWith(preamble: 'Other').editMode, isTrue);
  });

  test('copying keeps inline mode', () {
    expect(_flagged().copyWith(preamble: 'Other').inlineMode, isTrue);
  });

  test('copying keeps tool calls', () {
    expect(_flagged().copyWith(preamble: 'Other').toolCalls, isFalse);
  });

  test('copying keeps bindings', () {
    expect(_flagged().copyWith(preamble: 'Other').bindings, isTrue);
  });

  test('copying keeps built-in functions', () {
    expect(_flagged().copyWith(preamble: 'Other').builtinFunctions, isFalse);
  });

  test('copying keeps tool calls left to their default as a default', () {
    expect(_options().copyWith(tools: [NamedTool('x')]).toolCalls, isNull);
  });

  test('copying keeps bindings left to their default as a default', () {
    expect(_options().copyWith(tools: [NamedTool('x')]).bindings, isNull);
  });

  test('copying keeps built-in functions left to their default as a default', () {
    expect(_options().copyWith(tools: [NamedTool('x')]).builtinFunctions, isNull);
  });

  test('copying replaces the preamble', () {
    expect(_options().copyWith(preamble: 'Other').preamble, 'Other');
  });

  test('copying replaces the rules', () {
    expect(_options().copyWith(additionalRules: ['Other']).additionalRules, ['Other']);
  });

  test('copying replaces the examples', () {
    expect(_options().copyWith(examples: ['Other']).examples, ['Other']);
  });

  test('copying replaces the tool examples', () {
    expect(_options().copyWith(toolExamples: ['Other']).toolExamples, ['Other']);
  });

  test('copying replaces the tools', () {
    expect(_options().copyWith(tools: [NamedTool('other')]).tools, [NamedTool('other')]);
  });

  test('copying keeps the rules it is not given', () {
    expect(_options().copyWith(preamble: 'Other').additionalRules, ['rule']);
  });

  test('copying keeps the examples it is not given', () {
    expect(_options().copyWith(preamble: 'Other').examples, ['example']);
  });

  test('copying keeps the tool examples it is not given', () {
    expect(_options().copyWith(preamble: 'Other').toolExamples, ['tool example']);
  });

  test('copying keeps the tools it is not given', () {
    expect(_options().copyWith(preamble: 'Other').tools, [NamedTool('tool')]);
  });

  test('copying keeps the preamble it is not given', () {
    expect(_options().copyWith(tools: []).preamble, 'preamble');
  });

  test('copying with an empty list of rules empties them', () {
    expect(_options().copyWith(additionalRules: []).additionalRules, isEmpty);
  });

  test('copying with an empty list of examples empties them', () {
    expect(_options().copyWith(examples: []).examples, isEmpty);
  });

  test('copying with an empty list of tool examples empties them', () {
    expect(_options().copyWith(toolExamples: []).toolExamples, isEmpty);
  });

  test('copying with an empty list of tools empties them', () {
    expect(_options().copyWith(tools: []).tools, isEmpty);
  });

  _testEquivalent('equal named tools', () => NamedTool('a'));

  test('named tools of other names are unequal', () {
    expect(NamedTool('a'), isNot(NamedTool('b')));
  });

  test('a named tool is not equal to a tool spec of its name', () {
    expect(NamedTool('a'), isNot(ToolSpec('a')));
  });

  test('a tool spec has no description unless given', () {
    expect(ToolSpec('a').description, isNull);
  });

  test('a tool spec has an empty input schema unless given', () {
    expect(ToolSpec('a').inputSchema, isEmpty);
  });

  test('a tool spec has an empty output schema unless given', () {
    expect(ToolSpec('a').outputSchema, isEmpty);
  });

  _testEquivalent('equal tool specs', _spec);

  test('tool specs of other names are unequal', () {
    expect(_spec(), isNot(_spec(name: 'b')));
  });

  test('tool specs of other descriptions are unequal', () {
    expect(_spec(), isNot(_spec(description: 'Other')));
  });

  test('a tool spec with a description is not equal to one without', () {
    expect(_spec(), isNot(ToolSpec('a', inputSchema: _spec().inputSchema, outputSchema: _spec().outputSchema)));
  });

  test('tool specs of other input schemas are unequal', () {
    expect(_spec(), isNot(_spec(input: {'type': 'string'})));
  });

  test('tool specs of other output schemas are unequal', () {
    expect(_spec(), isNot(_spec(output: {'type': 'string'})));
  });

  _testEquivalent(
    'tool specs with equal nested schemas',
    () => _spec(
      input: {
        'properties': {
          'a': {
            'enum': ['x', 'y'],
          },
        },
      },
    ),
  );

  test('a host tool has no description unless given', () {
    expect(HostTool('a').description, isEmpty);
  });

  test('a host tool changes something unless it is read-only', () {
    expect(HostTool('a').isReadOnly, isFalse);
  });

  test('a host tool takes no arguments unless given', () {
    expect(HostTool('a').inputSchema, isNull);
  });

  test('a read-only tool says a Query may run it after its description', () {
    final spec = HostTool('a', description: 'Lists trips.', isReadOnly: true).toToolSpec();

    expect(spec.description, 'Lists trips. Read-only: use it in Query() or Mutation().');
  });

  test('a tool that changes something says to use it only in a Mutation after its description', () {
    final spec = HostTool('a', description: 'Books a trip.').toToolSpec();

    expect(
      spec.description,
      'Books a trip. It changes something: use it only in Mutation(), which runs when the person taps.',
    );
  });

  test('a read-only tool without a description has only the wording', () {
    expect(HostTool('a', isReadOnly: true).toToolSpec().description, 'Read-only: use it in Query() or Mutation().');
  });

  test('a changing tool without a description has only the wording', () {
    expect(
      HostTool('a').toToolSpec().description,
      'It changes something: use it only in Mutation(), which runs when the person taps.',
    );
  });

  test('the read-only constant is the wording of the specs', () {
    expect(HostTool.readOnlyUse, 'Read-only: use it in Query() or Mutation().');
  });

  test('the changing constant is the wording of the specs', () {
    expect(HostTool.changingUse, 'It changes something: use it only in Mutation(), which runs when the person taps.');
  });

  test('a tool spec has the name of the host tool', () {
    expect(HostTool('search_trips').toToolSpec().name, 'search_trips');
  });

  test('a tool without an input schema has an empty one', () {
    expect(HostTool('a').toToolSpec().inputSchema, <String, Object?>{});
  });

  test('a tool with an input schema keeps it', () {
    final schema = {
      'type': 'object',
      'properties': {
        'q': {'type': 'string'},
      },
    };

    expect(HostTool('a', inputSchema: schema).toToolSpec().inputSchema, schema);
  });

  test('a tool spec has no output schema', () {
    expect(HostTool('a').toToolSpec().outputSchema, isEmpty);
  });

  _testEquivalent('equal host tools', _host);

  test('host tools of other names are unequal', () {
    expect(_host(), isNot(_host(name: 'b')));
  });

  test('host tools of other descriptions are unequal', () {
    expect(_host(), isNot(_host(description: 'Other')));
  });

  test('host tools that differ in being read-only are unequal', () {
    expect(_host(), isNot(_host(isReadOnly: true)));
  });

  test('host tools of other input schemas are unequal', () {
    expect(_host(), isNot(_host(input: {'type': 'string'})));
  });

  test('a host tool with an input schema is not equal to one without', () {
    expect(_host(), isNot(HostTool('a', description: 'Does it.')));
  });
}

PromptOptions _flagged() {
  return _options(editMode: true, inlineMode: true, toolCalls: false, bindings: true, builtinFunctions: false);
}

PromptOptions _options({
  String preamble = 'preamble',
  List<String> rules = const ['rule'],
  List<String> examples = const ['example'],
  List<String> toolExamples = const ['tool example'],
  List<PromptTool>? tools,
  bool editMode = false,
  bool inlineMode = false,
  bool? toolCalls,
  bool? bindings,
  bool? builtinFunctions,
}) {
  return PromptOptions(
    preamble: preamble,
    additionalRules: [...rules],
    examples: [...examples],
    toolExamples: [...toolExamples],
    tools: tools ?? [NamedTool('tool')],
    editMode: editMode,
    inlineMode: inlineMode,
    toolCalls: toolCalls,
    bindings: bindings,
    builtinFunctions: builtinFunctions,
  );
}

ToolSpec _spec({
  String name = 'a',
  String description = 'Does it.',
  Map<String, Object?>? input,
  Map<String, Object?>? output,
}) {
  return ToolSpec(
    name,
    description: description,
    inputSchema: input ?? {'type': 'object'},
    outputSchema: output ?? {'type': 'object'},
  );
}

HostTool _host({
  String name = 'a',
  String description = 'Does it.',
  bool isReadOnly = false,
  Map<String, Object?>? input,
}) {
  return HostTool(
    name,
    description: description,
    isReadOnly: isReadOnly,
    inputSchema: input ?? {'type': 'object'},
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
