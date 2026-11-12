// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_generator.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';

import 'spec_library.dart';

const _query = '## Query — Live Data Fetching';
const _bindingRule = 'Declare mutable state with';
const _builtins = '## Built-in Functions';
const _count = '@Count(array: any[]) → number';
const _filters = '## Interactive Filters';
const _tools = '## Available Tools';
const _defaults = '### Default values for Query results';

void main() {
  test('without tools or flags the prompt teaches no queries', () {
    expect(_prompt(), isNot(contains(_query)));
  });

  test('without tools or flags the prompt teaches no bindings', () {
    expect(_prompt(), isNot(contains(_bindingRule)));
  });

  test('without tools or flags the prompt has no built-in functions section', () {
    expect(_prompt(), isNot(contains(_builtins)));
  });

  test('without tools or flags the prompt lists no built-in function', () {
    expect(_prompt(), isNot(contains(_count)));
  });

  test('tool calls default to whether there are tools', () {
    expect(_prompt(tools: [NamedTool('a')]), contains(_query));
  });

  test('tool calls on without tools teach queries', () {
    expect(_prompt(toolCalls: true), contains(_query));
  });

  test('tool calls on without tools list no tools', () {
    expect(_prompt(toolCalls: true), isNot(contains(_tools)));
  });

  test('tool calls off with tools teach no queries', () {
    expect(_prompt(tools: [NamedTool('a')], toolCalls: false), isNot(contains(_query)));
  });

  test('tool calls off with tools still list the tools', () {
    expect(_prompt(tools: [NamedTool('a')], toolCalls: false), contains(_tools));
  });

  test('bindings default to tool calls when they are on', () {
    expect(_prompt(toolCalls: true), contains(_bindingRule));
  });

  test('bindings default to tool calls when they are off', () {
    expect(_prompt(toolCalls: false), isNot(contains(_bindingRule)));
  });

  test('bindings default to tool calls when they come from tools', () {
    expect(_prompt(tools: [NamedTool('a')]), contains(_bindingRule));
  });

  test('bindings off with tool calls on teach no bindings', () {
    expect(_prompt(toolCalls: true, bindings: false), isNot(contains(_bindingRule)));
  });

  test('bindings on with tool calls off teach bindings', () {
    expect(_prompt(toolCalls: false, bindings: true), contains(_bindingRule));
  });

  test('bindings on with tool calls off teach no queries', () {
    expect(_prompt(toolCalls: false, bindings: true), isNot(contains(_query)));
  });

  test('interactive filters are taught with both tool calls and bindings', () {
    expect(_prompt(toolCalls: true, bindings: true), contains(_filters));
  });

  test('interactive filters are not taught with tool calls and no bindings', () {
    expect(_prompt(toolCalls: true, bindings: false), isNot(contains(_filters)));
  });

  test('interactive filters are not taught with bindings and no tool calls', () {
    expect(_prompt(toolCalls: false, bindings: true), isNot(contains(_filters)));
  });

  test('built-in functions default to on when tool calls are on', () {
    expect(_prompt(toolCalls: true, bindings: false), contains(_count));
  });

  test('built-in functions default to on when bindings are on', () {
    expect(_prompt(toolCalls: false, bindings: true), contains(_count));
  });

  test('built-in functions default to off when both are off', () {
    expect(_prompt(toolCalls: false, bindings: false), isNot(contains(_count)));
  });

  test('built-in functions on without tool calls or bindings are listed', () {
    expect(_prompt(builtinFunctions: true), contains(_count));
  });

  test('built-in functions off with tool calls on are not listed', () {
    expect(_prompt(toolCalls: true, builtinFunctions: false), isNot(contains(_count)));
  });

  test('built-in functions are listed for Query results with tool calls on', () {
    expect(_prompt(toolCalls: true), contains('on Query results.'));
  });

  test('built-in functions are listed for data with tool calls off', () {
    expect(_prompt(bindings: true), contains('on data.'));
  });

  test('the root is the first step of the streaming order', () {
    expect(_prompt(), contains('1. `root = Card(...)` — UI shell appears immediately'));
  });

  test('the streaming order without expressions has component and data steps', () {
    final prompt = _prompt();

    expect(prompt, contains('2. Component definitions — fill in as they stream'));
    expect(prompt, contains('3. Data values — leaf content last'));
  });

  test('the streaming order with tool calls has variable and query steps', () {
    final prompt = _prompt(toolCalls: true);

    expect(prompt, contains(r'2. $variable declarations — state ready for bindings'));
    expect(prompt, contains('3. Query statements'));
    expect(prompt, contains('4. Component definitions — fill in with data already available'));
    expect(prompt, contains('5. Data values — leaf content last'));
  });

  test('the streaming order with bindings only has no query step', () {
    final prompt = _prompt(toolCalls: false, bindings: true);

    expect(prompt, contains('3. Component definitions — fill in with data already available'));
    expect(prompt, isNot(contains('Query statements')));
  });

  test('the closing rules number the defined names check 2 with nothing on', () {
    expect(_prompt(), contains('2. Every referenced name is defined.'));
  });

  test('the closing rules number the Query results check 3 with tool calls only', () {
    expect(_prompt(toolCalls: true, bindings: false), contains('3. Every Query result is referenced'));
  });

  test('the closing rules number the bindings check 3 with bindings only', () {
    expect(_prompt(toolCalls: false, bindings: true), contains(r'3. Every $binding appears'));
  });

  test('the closing rules number the bindings check 4 with tool calls and bindings', () {
    expect(_prompt(toolCalls: true, bindings: true), contains(r'4. Every $binding appears'));
  });

  test('the closing rules number the filters check 5 with tool calls and bindings', () {
    expect(_prompt(toolCalls: true, bindings: true), contains(r'5. Every visible filter $binding'));
  });

  test('a tool listed by name is a bullet with its name', () {
    expect(_prompt(tools: [NamedTool('list_trips')]), contains('\n- list_trips\n'));
  });

  test('tools listed by name have no default values section', () {
    expect(_prompt(tools: [NamedTool('list_trips')]), isNot(contains(_defaults)));
  });

  test('a tool listed with a spec shows its arguments and result as a signature', () {
    final prompt = _prompt(tools: [_search()]);

    expect(prompt, contains('- search(query: string, limit?: number) → {items: {id: string}[], total?: number}\n'));
  });

  test('the description of a tool is on the next line indented two spaces', () {
    final prompt = _prompt(tools: [_search()]);

    expect(
      prompt,
      contains('- search(query: string, limit?: number) → {items: {id: string}[], total?: number}\n  Finds trips.\n'),
    );
  });

  test('a tool spec with no description has no second line', () {
    final prompt = _prompt(
      tools: [
        ToolSpec('ping', outputSchema: {'type': 'string'}),
      ],
    );

    expect(prompt, contains('- ping() → string\n\n'));
  });

  test('a tool spec with an empty description has no second line', () {
    final prompt = _prompt(
      tools: [
        ToolSpec('ping', description: '', outputSchema: {'type': 'string'}),
      ],
    );

    expect(prompt, contains('- ping() → string\n\n'));
  });

  test('a tool spec with no schemas takes no arguments and gives any value', () {
    expect(_prompt(tools: [ToolSpec('ping')]), contains('- ping() → any\n'));
  });

  test('an argument is optional when required does not name it', () {
    final tool = ToolSpec(
      'a',
      inputSchema: {
        'properties': {
          'x': {'type': 'string'},
          'y': {'type': 'string'},
        },
        'required': ['y'],
      },
    );

    expect(_prompt(tools: [tool]), contains('- a(x?: string, y: string) → any'));
  });

  test('arguments are all optional when required is not a list', () {
    final tool = ToolSpec(
      'a',
      inputSchema: {
        'properties': {
          'x': {'type': 'string'},
        },
        'required': 'x',
      },
    );

    expect(_prompt(tools: [tool]), contains('- a(x?: string) → any'));
  });

  test('arguments are written with the types of their schemas', () {
    final tool = ToolSpec(
      'a',
      inputSchema: {
        'properties': {
          's': {'type': 'string'},
          'e': {
            'type': 'string',
            'enum': ['x', 'y'],
          },
          'n': {'type': 'number'},
          'i': {'type': 'integer'},
          'b': {'type': 'boolean'},
          'l': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'u': {'type': 'array'},
          'o': {'type': 'object'},
          'z': <String, Object?>{},
        },
      },
    );

    expect(
      _prompt(tools: [tool]),
      contains(
        '- a(s?: string, e?: "x" | "y", n?: number, i?: number, b?: boolean, l?: string[], u?: any[], o?: object, z?: any) → any',
      ),
    );
  });

  test('an argument that is not a schema is shown as any', () {
    final tool = ToolSpec(
      'a',
      inputSchema: {
        'properties': {'x': 5},
      },
    );

    expect(_prompt(tools: [tool]), contains('- a(x?: any) → any'));
  });

  test('an object result is shown with its fields and which are optional', () {
    final tool = ToolSpec(
      'a',
      outputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'string'},
          'y': {'type': 'number'},
        },
        'required': ['x'],
      },
    );

    expect(_prompt(tools: [tool]), contains('- a() → {x: string, y?: number}'));
  });

  test('a tool output schema nested deeper than the JSON depth limit is written', () {
    final prompt = _prompt(tools: [ToolSpec('deep', outputSchema: _deepArray())]);

    expect(prompt, contains('- deep() → '));
  });

  test('a tool output schema nested deeper than the JSON depth limit is read as any', () {
    final prompt = _prompt(tools: [ToolSpec('deep', outputSchema: _deepArray())]);

    expect(prompt, contains('any[]'));
  });

  test('a tool output schema nested deeper than the JSON depth limit is written quickly', () {
    final stopwatch = Stopwatch()..start();

    _prompt(tools: [ToolSpec('deep', outputSchema: _deepArray())]);

    expect(stopwatch.elapsed, lessThan(Duration(seconds: 5)));
  });

  test('a tool input schema nested deeper than the JSON depth limit is written', () {
    final prompt = _prompt(
      tools: [
        ToolSpec(
          'deep',
          inputSchema: {
            'properties': {'x': _deepArray()},
          },
        ),
      ],
    );

    expect(prompt, contains('- deep(x?: '));
  });

  test('a tool input schema nested deeper than the JSON depth limit is written quickly', () {
    final stopwatch = Stopwatch()..start();

    _prompt(
      tools: [
        ToolSpec(
          'deep',
          inputSchema: {
            'properties': {'x': _deepArray()},
          },
        ),
      ],
    );

    expect(stopwatch.elapsed, lessThan(Duration(seconds: 5)));
  });

  test('tools by name come before tools with a spec', () {
    final prompt = _prompt(tools: [ToolSpec('with_spec'), NamedTool('by_name')]);

    expect(prompt.indexOf('- by_name'), lessThan(prompt.indexOf('- with_spec(')));
  });

  test('each tool with a spec gets its default value under the default values section', () {
    final prompt = _prompt(
      tools: [
        _search(),
        ToolSpec('ping', outputSchema: {'type': 'string'}),
      ],
    );

    expect(prompt, contains('$_defaults\n\nUse these shapes as minimal Query defaults:\n'));
  });

  test('a tool with a spec gets its default value as an empty object of its fields', () {
    expect(_prompt(tools: [_search()]), contains('- search: `{"items":[],"total":0}`'));
  });

  test('a tool with a string result gets an empty string as its default value', () {
    final tool = ToolSpec('ping', outputSchema: {'type': 'string'});

    expect(_prompt(tools: [tool]), contains('- ping: `""`'));
  });

  test('default values are the empty value of each type', () {
    final tool = ToolSpec(
      'a',
      outputSchema: {
        'type': 'object',
        'properties': {
          's': {'type': 'string'},
          'n': {'type': 'number'},
          'i': {'type': 'integer'},
          'b': {'type': 'boolean'},
          'l': {'type': 'array'},
          'o': {
            'type': 'object',
            'properties': {
              'x': {'type': 'string'},
            },
          },
          'p': {'type': 'object'},
          'z': <String, Object?>{},
        },
      },
    );

    expect(
      _prompt(tools: [tool]),
      contains('- a: `{"s":"","n":0,"i":0,"b":false,"l":[],"o":{"x":""},"p":{},"z":null}`'),
    );
  });

  test('a tool with no output schema has a null default value', () {
    expect(_prompt(tools: [ToolSpec('ping')]), contains('- ping: `null`'));
  });

  test('the section ends with the warning not to invent tools', () {
    final prompt = _prompt(tools: [NamedTool('a')]);

    expect(prompt, contains('CRITICAL: Use ONLY the tools listed above in Query() and Mutation() calls.'));
  });

  test('no tools section is written without tools', () {
    expect(_prompt(toolCalls: true), isNot(contains(_tools)));
  });

  test('the edit mode section is not written without edit mode', () {
    expect(_prompt(), isNot(contains('## Edit Mode')));
  });

  test('the edit mode section is written when edit mode is set', () {
    expect(_prompt(editMode: true), contains('## Edit Mode'));
  });

  test('the inline mode section is not written without inline mode', () {
    expect(_prompt(), isNot(contains('## Inline Mode')));
  });

  test('the inline mode section is written when inline mode is set', () {
    expect(_prompt(inlineMode: true), contains('## Inline Mode'));
  });

  test('edit mode does not write the inline section', () {
    expect(_prompt(editMode: true), isNot(contains('## Inline Mode')));
  });

  test('the edit section comes before the inline section and both before the closing rules', () {
    final prompt = _prompt(editMode: true, inlineMode: true);

    expect(prompt.indexOf('## Edit Mode'), lessThan(prompt.indexOf('## Inline Mode')));
    expect(prompt.indexOf('## Inline Mode'), lessThan(prompt.indexOf('## Important Rules')));
  });

  test('the examples section is not written without examples', () {
    expect(_prompt(), isNot(contains('## Examples')));
  });

  test('the examples section is written when there are examples', () {
    expect(_prompt(examples: ['root = Card([])']), contains('## Examples'));
  });

  test('each example is written as it is', () {
    expect(_prompt(examples: ['first\nsecond']), contains('## Examples\n\nfirst\nsecond\n\n'));
  });

  test('examples come before tool examples', () {
    final prompt = _prompt(examples: ['EXAMPLE-ONE', 'EXAMPLE-TWO'], toolExamples: ['TOOL-EXAMPLE']);

    expect(prompt.indexOf('EXAMPLE-ONE'), lessThan(prompt.indexOf('EXAMPLE-TWO')));
    expect(prompt.indexOf('EXAMPLE-TWO'), lessThan(prompt.indexOf('TOOL-EXAMPLE')));
  });

  test('tool examples alone make the examples section', () {
    expect(_prompt(toolExamples: ['TOOL-EXAMPLE']), contains('## Examples\n\nTOOL-EXAMPLE\n'));
  });

  test('the examples come before the closing rules', () {
    final prompt = _prompt(examples: ['EXAMPLE']);

    expect(prompt.indexOf('EXAMPLE'), lessThan(prompt.indexOf('## Important Rules')));
  });

  test('additional rules are bullets at the end', () {
    final prompt = _prompt(rules: ['Rule one', 'Rule two']);

    expect(prompt, endsWith('\n\n- Rule one\n- Rule two'));
  });

  test('without additional rules the prompt ends with the last closing check', () {
    final prompt = _prompt();

    expect(prompt, endsWith('is reachable from root.'));
  });

  test('the default preamble starts the prompt when none is given', () {
    expect(_prompt(), startsWith(PromptGenerator.defaultPreamble));
  });

  test('a preamble given starts the prompt instead', () {
    expect(_prompt(preamble: 'Be brief.'), startsWith('Be brief.\n'));
  });

  test('a preamble given replaces the default one', () {
    expect(_prompt(preamble: 'Be brief.'), isNot(contains(PromptGenerator.defaultPreamble)));
  });

  test('the root is named in the rules and the closing checks', () {
    expect(_prompt(root: 'Stack'), contains('every program must define `root = Stack(...)`'));
  });

  test('the root is named in the first closing check', () {
    expect(_prompt(root: 'Stack'), contains('1. root = Stack(...) is the FIRST line'));
  });

  test('a spec without a root names Root', () {
    expect(_prompt(root: null), contains('every program must define `root = Root(...)`'));
  });

  test('a spec without a root names Root in the streaming order', () {
    expect(_prompt(root: null), contains('1. `root = Root(...)` — UI shell appears immediately'));
  });

  test('generating the same spec twice gives the same prompt', () {
    final first = _prompt();

    expect(_prompt(), allOf(isNotEmpty, first));
  });

  test('without groups the components are listed in order after the intro', () {
    expect(_prompt(), contains('Card(title: string) — A titled container\nText(text: string) — A run of text\n'));
  });

  test('without groups the components have no heading', () {
    expect(_prompt(), isNot(contains('### ')));
  });

  test('a component without a description is listed by its signature only', () {
    final prompt = PromptGenerator.generate(PromptSpec(root: 'A', components: [PromptEntry('A', 'A()')]));

    expect(prompt, contains('\nA()\n'));
    expect(prompt, isNot(contains('A() —')));
  });

  test('a group is a heading with its components and then its notes', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('Layout', components: ['Card'], notes: ['Note one.', 'Note two.']),
      ],
    );

    expect(prompt, contains('### Layout\nCard(title: string) — A titled container\nNote one.\nNote two.\n'));
  });

  test('the components of a group are listed in the order of the group', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('G', components: ['Text', 'Card']),
      ],
    );

    expect(prompt, contains('### G\nText(text: string) — A run of text\nCard(title: string) — A titled container\n'));
  });

  test('components in no group are listed under Other after the groups', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('Layout', components: ['Card']),
      ],
    );

    expect(
      prompt,
      contains(
        '### Layout\nCard(title: string) — A titled container\n\n### Other\nText(text: string) — A run of text\n',
      ),
    );
  });

  test('there is no Other heading when every component is in a group', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('All', components: ['Card', 'Text']),
      ],
    );

    expect(prompt, isNot(contains('### Other')));
  });

  test('a group that names an unknown component lists the others', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('Layout', components: ['Missing', 'Card']),
      ],
    );

    expect(prompt, contains('### Layout\nCard(title: string) — A titled container\n'));
  });

  test('a group that names an unknown component does not list it', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('Layout', components: ['Missing', 'Card']),
      ],
    );

    expect(prompt, isNot(contains('Missing')));
  });

  test('a group that names only unknown components is a heading with its notes', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('Ghosts', components: ['Missing'], notes: ['A note.']),
      ],
    );

    expect(prompt, contains('### Ghosts\nA note.\n'));
  });

  test('a component named by two groups is listed under the first only', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('First', components: ['Card']),
        ComponentGroup('Second', components: ['Card', 'Text']),
      ],
    );

    expect('Card(title: string)'.allMatches(prompt), hasLength(1));
  });

  test('a component named by two groups leaves the later group its other components', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('First', components: ['Card']),
        ComponentGroup('Second', components: ['Card', 'Text']),
      ],
    );

    expect(prompt, contains('### Second\nText(text: string)'));
  });

  test('a component named twice in a group is listed once', () {
    final prompt = _prompt(
      groups: [
        ComponentGroup('G', components: ['Card', 'Card', 'Text']),
      ],
    );

    expect('Card(title: string)'.allMatches(prompt), hasLength(1));
  });

  test('the components that name an action expression get the action section and its note', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(root: 'A', components: [PromptEntry('A', 'A(action?: ActionExpression)')]),
    );

    expect(prompt, contains('## Action — Button Behavior'));
  });

  test('a component that takes an action expression gets a note about its props', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(root: 'A', components: [PromptEntry('A', 'A(action?: ActionExpression)')]),
    );

    expect(prompt, contains('Props typed `ActionExpression` accept one @step'));
  });

  test('a component that takes only some steps gets the action section and a note about it', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(root: 'A', components: [PromptEntry('A', 'A(share?: @CopyToClipboard | @OpenUrl)')]),
    );

    expect(prompt, contains('## Action — Button Behavior'));
  });

  test('a component that takes only some steps gets a note about it', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(root: 'A', components: [PromptEntry('A', 'A(share?: @CopyToClipboard | @OpenUrl)')]),
    );

    expect(prompt, contains('Props typed like `@OpenUrl | @ToAssistant` accept only the steps listed.'));
  });

  test('no note about steps is written for components that take any action', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(root: 'A', components: [PromptEntry('A', 'A(action?: ActionExpression)')]),
    );

    expect(prompt, isNot(contains('accept only the steps listed')));
  });

  test('the binding note is written when a component signature has a binding', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(root: 'A', components: [PromptEntry('A', r'A(value?: $binding<string>)')]),
    );

    expect(prompt, contains(r'Props marked `$binding<type>` accept a `$variable` reference for two-way binding.'));
  });

  test('no binding note is written without bindings', () {
    expect(_prompt(), isNot(contains('two-way binding')));
  });

  test('a custom function is listed after the built-in ones', () {
    final prompt = _prompt(
      toolCalls: true,
      functions: [PromptEntry('Upper', 'Upper(text: string) → string', 'Upper case')],
    );

    expect(prompt.indexOf(_count), lessThan(prompt.indexOf('@Upper(text: string) → string — Upper case')));
  });

  test('a custom function without a description is listed by its signature', () {
    final prompt = _prompt(toolCalls: true, functions: [PromptEntry('Upper', 'Upper(text: string) → string')]);

    expect(prompt, contains('\n@Upper(text: string) → string\n'));
  });

  test('a custom function alone makes the built-in functions section when the built-ins are off', () {
    final prompt = _prompt(functions: [PromptEntry('Upper', 'Upper(text: string) → string', 'Upper case')]);

    expect(prompt, contains('$_builtins\n\n@Upper(text: string) → string — Upper case\n'));
  });

  test('a custom function alone lists no built-in function when the built-ins are off', () {
    final prompt = _prompt(functions: [PromptEntry('Upper', 'Upper(text: string) → string', 'Upper case')]);

    expect(prompt, isNot(contains(_count)));
  });

  test('custom functions alone are listed one to a line', () {
    final prompt = _prompt(
      functions: [PromptEntry('A', 'A() → any'), PromptEntry('B', 'B() → any')],
    );

    expect(prompt, contains('$_builtins\n\n@A() → any\n@B() → any\n'));
  });

  test('a custom action is listed in the action section with the built-in steps', () {
    expect(_customActionPrompt(), contains('- @CopyToClipboard(text: string) — Copies'));
  });

  test('a custom action is listed in the action section after the built-in steps', () {
    expect(_customActionPrompt(), contains('- @OpenUrl(url: string) — Navigate to a URL\n'));
  });

  test('a custom action is named among the steps a prop takes', () {
    expect(_customActionPrompt(), contains('(@ToAssistant, @OpenUrl, @CopyToClipboard)'));
  });

  test('custom actions alone make a section of their own when no component takes an action', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(
        root: 'A',
        components: [PromptEntry('A', 'A()')],
        actions: [PromptEntry('Copy', 'Copy(text: string)', 'Copies')],
      ),
    );

    expect(
      prompt,
      contains(
        "## Action — Button Behavior\n\nPass one step, or Action([...]) with several steps, as a button's action.\n\n"
        'Available steps:\n- @Copy(text: string) — Copies',
      ),
    );
  });

  test('custom actions alone list no built-in step when no component takes an action', () {
    final prompt = PromptGenerator.generate(
      PromptSpec(
        root: 'A',
        components: [PromptEntry('A', 'A()')],
        actions: [PromptEntry('Copy', 'Copy(text: string)', 'Copies')],
      ),
    );

    expect(prompt, isNot(contains('@OpenUrl')));
  });

  test('there is no action section without actions or action expressions', () {
    expect(_prompt(), isNot(contains('## Action')));
  });

  test('the run step is not listed without tool calls', () {
    expect(_actionPrompt(), isNot(contains('- @Run(')));
  });

  test('the run step is listed with tool calls', () {
    expect(_actionPrompt(PromptOptions(toolCalls: true)), contains('- @Run('));
  });

  test('the set step is not listed without bindings', () {
    expect(_actionPrompt(), isNot(contains('- @Set(')));
  });

  test('the reset step is not listed without bindings', () {
    expect(_actionPrompt(), isNot(contains('- @Reset(')));
  });

  test('the set step is listed with bindings', () {
    expect(_actionPrompt(PromptOptions(bindings: true)), contains('- @Set('));
  });

  test('the reset step is listed with bindings', () {
    expect(_actionPrompt(PromptOptions(bindings: true)), contains('- @Reset('));
  });

  test('a library spec gives the root of the spec', () {
    expect(_librarySpec().root, 'Card');
  });

  test('a library spec gives the components of the spec', () {
    expect(
      [for (final c in _librarySpec().components) (c.name, c.signature, c.description)],
      [('Card', 'Card(title: string)', 'A card')],
    );
  });

  test('a library spec gives the component groups of the spec', () {
    expect(_librarySpec().componentGroups, [
      ComponentGroup('Layout', components: ['Card'], notes: ['Note']),
    ]);
  });

  test('a library spec gives the functions of the spec', () {
    expect(
      [for (final f in _librarySpec().functions) (f.name, f.signature, f.description)],
      [('Upper', 'Upper(text: string)', 'Upper case')],
    );
  });

  test('a library spec gives the actions of the spec', () {
    expect(
      [for (final a in _librarySpec().actions) (a.name, a.signature, a.description)],
      [('Copy', 'Copy(text: string)', 'Copies')],
    );
  });

  test('a spec keeps the options it is given', () {
    final options = PromptOptions(preamble: 'x');

    expect(promptSpecFromLibrarySpec(const {}, options: options).options, options);
  });

  test('an empty library spec has no root', () {
    expect(promptSpecFromLibrarySpec(const {}).root, isNull);
  });

  test('an empty library spec has no components', () {
    expect(promptSpecFromLibrarySpec(const {}).components, isEmpty);
  });

  test('an empty library spec has no component groups', () {
    expect(promptSpecFromLibrarySpec(const {}).componentGroups, isEmpty);
  });

  test('an empty library spec has no functions', () {
    expect(promptSpecFromLibrarySpec(const {}).functions, isEmpty);
  });

  test('an empty library spec has no actions', () {
    expect(promptSpecFromLibrarySpec(const {}).actions, isEmpty);
  });

  test('a root that is a number reads as none', () {
    expect(promptSpecFromLibrarySpec({'root': 5}).root, isNull);
  });

  test('a root that is a list reads as none', () {
    expect(
      promptSpecFromLibrarySpec({
        'root': ['Card'],
      }).root,
      isNull,
    );
  });

  test('a root that is a string is the root', () {
    expect(promptSpecFromLibrarySpec({'root': 'Card'}).root, 'Card');
  });

  test('components that are a list read as empty', () {
    expect(
      promptSpecFromLibrarySpec({
        'components': ['Card'],
      }).components,
      isEmpty,
    );
  });

  test('component groups that are an object read as empty', () {
    expect(
      promptSpecFromLibrarySpec({
        'componentGroups': {'name': 'x'},
      }).componentGroups,
      isEmpty,
    );
  });

  test('functions that are a string read as empty', () {
    expect(promptSpecFromLibrarySpec({'functions': 'Upper'}).functions, isEmpty);
  });

  test('actions that are a number read as empty', () {
    expect(promptSpecFromLibrarySpec({'actions': 5}).actions, isEmpty);
  });

  test('a component entry that is not an object is left out', () {
    final spec = promptSpecFromLibrarySpec({
      'components': {
        'Bad': 'Bad()',
        'Good': {'signature': 'Good()'},
      },
    });

    expect([for (final c in spec.components) c.name], ['Good']);
  });

  test('a signature that is not a string reads as empty', () {
    final spec = promptSpecFromLibrarySpec({
      'components': {
        'A': {'signature': 1, 'description': 2},
      },
    });

    expect(spec.components.single.signature, isEmpty);
  });

  test('a description that is not a string reads as empty', () {
    final spec = promptSpecFromLibrarySpec({
      'components': {
        'A': {'signature': 1, 'description': 2},
      },
    });

    expect(spec.components.single.description, isEmpty);
  });

  test('a group that is not an object is left out', () {
    final spec = promptSpecFromLibrarySpec({
      'componentGroups': [
        'x',
        5,
        {'name': 'G'},
      ],
    });

    expect(spec.componentGroups, [ComponentGroup('G', components: const [])]);
  });

  test('a group name that is not a string reads as empty', () {
    final spec = promptSpecFromLibrarySpec({
      'componentGroups': [
        {'name': 5},
      ],
    });

    expect(spec.componentGroups.single.name, isEmpty);
  });

  test('the components of a group that are not strings are left out', () {
    final spec = promptSpecFromLibrarySpec({
      'componentGroups': [
        {
          'name': 'G',
          'components': ['A', 1, null, 'B'],
          'notes': ['n', 2],
        },
      ],
    });

    expect(spec.componentGroups.single.components, ['A', 'B']);
  });

  test('the notes of a group that are not strings are left out', () {
    final spec = promptSpecFromLibrarySpec({
      'componentGroups': [
        {
          'name': 'G',
          'components': ['A', 1, null, 'B'],
          'notes': ['n', 2],
        },
      ],
    });

    expect(spec.componentGroups.single.notes, ['n']);
  });

  test('the components of a group that are not a list read as empty', () {
    final spec = promptSpecFromLibrarySpec({
      'componentGroups': [
        {'name': 'G', 'components': 'A', 'notes': 'n'},
      ],
    });

    expect(spec.componentGroups.single.components, isEmpty);
  });

  test('the notes of a group that are not a list read as empty', () {
    final spec = promptSpecFromLibrarySpec({
      'componentGroups': [
        {'name': 'G', 'components': 'A', 'notes': 'n'},
      ],
    });

    expect(spec.componentGroups.single.notes, isEmpty);
  });

  test('the prompt of a library spec is the prompt of the library', () {
    final library = specLibrary();
    final options = PromptOptions(examples: ['root = Stack([])'], additionalRules: ['A rule'], editMode: true);

    final generated = PromptGenerator.generate(promptSpecFromLibrarySpec(library.toSpec(), options: options));

    expect(generated, library.systemPrompt(options));
  });
}

PromptSpec _librarySpec() {
  return promptSpecFromLibrarySpec({
    'root': 'Card',
    'components': {
      'Card': {'signature': 'Card(title: string)', 'description': 'A card'},
    },
    'componentGroups': [
      {
        'name': 'Layout',
        'components': ['Card'],
        'notes': ['Note'],
      },
    ],
    'functions': {
      'Upper': {'signature': 'Upper(text: string)', 'description': 'Upper case'},
    },
    'actions': {
      'Copy': {'signature': 'Copy(text: string)', 'description': 'Copies'},
    },
  });
}

String _customActionPrompt() {
  return PromptGenerator.generate(
    PromptSpec(
      root: 'A',
      components: [PromptEntry('A', 'A(action?: ActionExpression)')],
      actions: [PromptEntry('CopyToClipboard', 'CopyToClipboard(text: string)', 'Copies')],
    ),
  );
}

String _actionPrompt([PromptOptions options = const PromptOptions()]) {
  return PromptGenerator.generate(
    PromptSpec(root: 'A', components: [PromptEntry('A', 'A(action?: ActionExpression)')], options: options),
  );
}

String _prompt({
  String? root = 'Card',
  List<ComponentGroup> groups = const [],
  List<PromptEntry> functions = const [],
  String? preamble,
  List<String> rules = const [],
  List<String> examples = const [],
  List<String> toolExamples = const [],
  List<PromptTool> tools = const [],
  bool editMode = false,
  bool inlineMode = false,
  bool? toolCalls,
  bool? bindings,
  bool? builtinFunctions,
}) {
  return PromptGenerator.generate(
    PromptSpec(
      root: root,
      components: [
        PromptEntry('Card', 'Card(title: string)', 'A titled container'),
        PromptEntry('Text', 'Text(text: string)', 'A run of text'),
      ],
      componentGroups: groups,
      functions: functions,
      options: PromptOptions(
        preamble: preamble,
        additionalRules: rules,
        examples: examples,
        toolExamples: toolExamples,
        tools: tools,
        editMode: editMode,
        inlineMode: inlineMode,
        toolCalls: toolCalls,
        bindings: bindings,
        builtinFunctions: builtinFunctions,
      ),
    ),
  );
}

// An array of arrays of strings, 100000 levels deep, built from the inside out.
Map<String, Object?> _deepArray() {
  var schema = <String, Object?>{'type': 'string'};
  for (var i = 0; i < 100000; i++) {
    schema = {'type': 'array', 'items': schema};
  }
  return schema;
}

ToolSpec _search() {
  return ToolSpec(
    'search',
    description: 'Finds trips.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'limit': {'type': 'number'},
      },
      'required': ['query'],
    },
    outputSchema: {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
            },
            'required': ['id'],
          },
        },
        'total': {'type': 'number'},
      },
      'required': ['items'],
    },
  );
}
