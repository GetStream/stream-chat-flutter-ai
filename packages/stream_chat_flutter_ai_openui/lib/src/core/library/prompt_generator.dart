// ignore_for_file: no_adjacent_strings_in_list

/// The system prompt that teaches a model to write OpenUI Lang programs.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_sections.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// A component, function or action step as a system prompt lists it:
/// `signature — description`.
@immutable
final class PromptEntry {
  /// Creates the entry [name], shown as [signature] and, when it isn't empty,
  /// [description].
  const PromptEntry(this.name, this.signature, [this.description = '']);

  /// The name a program calls it by.
  final String name;

  /// How it is called, such as `CardHeader(title?: string)`.
  final String signature;

  /// What it is for; empty when it isn't described.
  final String description;
}

/// Everything a system prompt is generated from: a library's root,
/// components, groups, functions and actions, and the [options].
@immutable
final class PromptSpec {
  /// Creates the spec of a system prompt.
  const PromptSpec({
    required this.root,
    required this.components,
    this.componentGroups = const [],
    this.functions = const [],
    this.actions = const [],
    this.options = const PromptOptions(),
  });

  /// Reads a library spec.
  ///
  /// The spec, as `jsonDecode` gives it, holds `root`, `components` (each
  /// `{signature, description}` by name), `componentGroups`, `functions` and
  /// `actions`. Parts that are missing or of the wrong type read as empty, a
  /// `root` that isn't a string as none.
  factory PromptSpec.fromLibrarySpec(Map<String, Object?> spec, {PromptOptions options = const PromptOptions()}) {
    return PromptSpec(
      root: _string(spec['root']),
      components: _entries(spec['components']),
      componentGroups: [
        for (final group in _list(spec['componentGroups']))
          if (group is Map<String, Object?>)
            ComponentGroup(
              _string(group['name']) ?? '',
              components: _list(group['components']).whereType<String>().toList(),
              notes: _list(group['notes']).whereType<String>().toList(),
            ),
      ],
      functions: _entries(spec['functions']),
      actions: _entries(spec['actions']),
      options: options,
    );
  }

  /// The component a program's root is, or `null` when there is none.
  final String? root;

  /// The components, in library order.
  final List<PromptEntry> components;

  /// How the components are grouped.
  ///
  /// A component no group names is listed under `Other`, and one two groups
  /// name under the first. With no groups, the components are listed in order.
  final List<ComponentGroup> componentGroups;

  /// The library's functions, which the prompt lists after the built-in ones
  /// when it lists those.
  final List<PromptEntry> functions;

  /// The library's action steps, which the prompt lists with the built-in
  /// steps when a component takes an action.
  final List<PromptEntry> actions;

  /// The choices the prompt is generated with.
  final PromptOptions options;

  static String? _string(Object? value) => value is String ? value : null;

  static List<Object?> _list(Object? value) => value is List<Object?> ? value : const [];

  static List<PromptEntry> _entries(Object? section) {
    if (section is! Map<String, Object?>) return const [];
    return [
      for (final MapEntry(key: name, value: entry) in section.entries)
        if (entry is Map<String, Object?>)
          PromptEntry(name, _string(entry['signature']) ?? '', _string(entry['description']) ?? ''),
    ];
  }
}

/// The generator of system prompts.
///
/// The same spec always gives the same text.
abstract final class PromptGenerator {
  /// The preamble of a prompt whose options give none.
  static const defaultPreamble =
      'You are an AI assistant that responds using openui-lang, a declarative UI language. Your ENTIRE response '
      'must be valid openui-lang code — no markdown, no explanations, just openui-lang.';

  static const _actionHeader = '## Action — Button Behavior';

  static const _eachSignature = 'Each(array: any[], varName: string, template: any)';

  static const _eachDescription =
      'Evaluate template for each element. varName is the loop variable — use it ONLY inside the template '
      'expression (inline). Do NOT create a separate statement for the template.';

  // The built-in functions, in the order the prompt lists them.
  static const _builtinFunctions = [
    PromptEntry('Count', 'Count(array: any[]) → number', 'Returns array length'),
    PromptEntry('First', 'First(array: any[]) → any', 'Returns first element of array'),
    PromptEntry('Last', 'Last(array: any[]) → any', 'Returns last element of array'),
    PromptEntry('Sum', 'Sum(numbers: number[]) → number', 'Sum of numeric array'),
    PromptEntry('Avg', 'Avg(numbers: number[]) → number', 'Average of numeric array'),
    PromptEntry('Min', 'Min(numbers: number[]) → number', 'Minimum value in array'),
    PromptEntry('Max', 'Max(numbers: number[]) → number', 'Maximum value in array'),
    PromptEntry(
      'Sort',
      'Sort(array: any[], field: string, direction?: "asc" | "desc") → any[]',
      'Sort array by field. Direction: "asc" (default) or "desc"',
    ),
    PromptEntry(
      'Filter',
      'Filter(array: any[], field: string, operator: "==" | "!=" | ">" | "<" | ">=" | "<=" | "contains", '
          'value: any) → any[]',
      'Filter array by field value',
    ),
    PromptEntry(
      'Round',
      'Round(number: number, decimals?: number) → number',
      'Round to N decimal places (default 0)',
    ),
    PromptEntry('Abs', 'Abs(number: number) → number', 'Absolute value'),
    PromptEntry('Floor', 'Floor(number: number) → number', 'Round down to nearest integer'),
    PromptEntry('Ceil', 'Ceil(number: number) → number', 'Round up to nearest integer'),
  ];

  // The built-in action steps, in the order the prompt lists them.
  static const _builtinSteps = [
    PromptEntry(
      'Run',
      'Run(ref: Query | Mutation)',
      'Execute a Mutation or re-fetch a Query (ref must be a declared Query/Mutation)',
    ),
    PromptEntry(
      'ToAssistant',
      'ToAssistant(message: string, context?: any)',
      'Send a message to the assistant (for conversational buttons like "Tell me more", "Explain this"). The '
          'optional context is any value (object, array, string, number) passed to the assistant as hidden data, '
          'e.g. @ToAssistant("Show details", {orderId: 42})',
    ),
    PromptEntry('OpenUrl', 'OpenUrl(url: string)', 'Navigate to a URL'),
    PromptEntry('Set', r'Set(variable: $variable, value: any)', r'Set a $variable to a specific value'),
    PromptEntry(
      'Reset',
      r'Reset(variable: $variable)',
      r'Reset $variables to their declared defaults; pass several to reset each (e.g. @Reset($title, $priority) '
          r'restores $title="" and $priority="medium")',
    ),
  ];

  // A slot that takes only some steps, such as
  // `share?: @CopyToClipboard | @OpenUrl`.
  static final _restrictedSlot = RegExp('[:|] @[A-Z]');

  /// The system prompt for `spec`.
  ///
  /// Its sections, in order: the preamble; the syntax rules; the components'
  /// signatures, by group; the built-in and library functions; `Query()` and
  /// `Mutation()`; actions; filters and forms; the tool workflow; the tools;
  /// the streaming order; the examples; edit and inline modes; the closing
  /// rules; and the additional rules. A section the options turn off, or
  /// that would be empty, is left out.
  static String generate(PromptSpec spec) {
    final options = spec.options;
    final rootName = spec.root ?? 'Root';
    final hasTools = options.tools.isNotEmpty;
    final toolCalls = options.toolCalls ?? hasTools;
    final bindings = options.bindings ?? toolCalls;
    final supportsExpressions = toolCalls || bindings;
    final usesActionExpression = spec.components.any(
      (component) => component.signature.contains('ActionExpression') || _hasRestrictedSlot(component.signature),
    );

    final parts = <String>[
      options.preamble ?? defaultPreamble,
      '',
      _syntaxRules(rootName, supportsExpressions: supportsExpressions, bindings: bindings),
      '',
      _componentSignatures(spec, toolCalls: toolCalls, bindings: bindings, usesActionExpression: usesActionExpression),
    ];

    final customFunctions = [for (final function in spec.functions) _callLine(function)];
    if (options.builtinFunctions ?? supportsExpressions) {
      parts.addAll(['', _builtinFunctionsSection(customFunctions, toolCalls: toolCalls)]);
    } else if (customFunctions.isNotEmpty) {
      parts.addAll(['', '## Built-in Functions\n\n${customFunctions.join('\n')}']);
    }
    if (toolCalls) parts.addAll(['', PromptSections.query, '', PromptSections.mutation]);

    final customActions = [for (final action in spec.actions) '- ${_callLine(action)}'];
    if (usesActionExpression) {
      parts.addAll(['', _actionSection(customActions, toolCalls: toolCalls, bindings: bindings)]);
    } else if (customActions.isNotEmpty) {
      parts.addAll([
        '',
        "$_actionHeader\n\nPass one step, or Action([...]) with several steps, as a button's action.\n\n"
            'Available steps:\n${customActions.join('\n')}',
      ]);
    }
    if (toolCalls && bindings) parts.addAll(['', PromptSections.interactiveFilters]);
    if (toolCalls) parts.addAll(['', PromptSections.toolWorkflow]);
    if (hasTools) parts.addAll(['', _toolsSection(options.tools)]);

    parts.addAll(['', _streamingRules(rootName, supportsExpressions: supportsExpressions, toolCalls: toolCalls)]);

    final examples = [...options.examples, ...options.toolExamples];
    if (examples.isNotEmpty) {
      parts.addAll(['', '## Examples', '']);
      for (final example in examples) {
        parts.addAll([example, '']);
      }
    }

    if (options.editMode) parts.addAll(['', PromptSections.editMode]);
    if (options.inlineMode) parts.addAll(['', PromptSections.inlineMode]);

    parts.add(_importantRules(rootName, toolCalls: toolCalls, bindings: bindings));

    if (options.additionalRules.isNotEmpty) {
      parts.add('');
      for (final rule in options.additionalRules) {
        parts.add('- $rule');
      }
    }
    return parts.join('\n');
  }

  static bool _hasRestrictedSlot(String signature) => _restrictedSlot.hasMatch(signature);

  static String _callLine(PromptEntry call) {
    if (call.description.isEmpty) return '@${call.signature}';
    return '@${call.signature} — ${call.description}';
  }

  static String _syntaxRules(String rootName, {required bool supportsExpressions, required bool bindings}) {
    final lines = [
      '## Syntax Rules',
      '',
      '1. Each statement is on its own line: `identifier = Expression`',
      '2. `root` is the entry point — every program must define `root = $rootName(...)`',
      '3. Expressions are: strings ("..."), numbers, booleans (true/false), null, arrays ([...]), objects ({...}), '
          'or component calls TypeName(arg1, arg2, ...)',
      '4. Use references for readability: define `name = ...` on one line, then use `name` later',
      '5. EVERY variable (except root) MUST be referenced by at least one other variable. Unreferenced variables '
          "are silently dropped and will NOT render. Always include defined variables in their parent's "
          'children/items array.',
      '6. Arguments are POSITIONAL (order matters, not names). Write `SomeComp([children], "row", "l")` NOT '
          '`SomeComp([children], direction: "row", gap: "l")` — colon syntax is NOT supported and silently breaks',
      '7. Optional arguments can be omitted from the end',
    ];
    var ruleNumber = 8;
    if (bindings) {
      lines.add(
        '$ruleNumber. Declare mutable state with `\$varName = defaultValue`. Components marked with `\$binding` '
        r'can read/write these. Undeclared $variables are auto-created with null default.',
      );
      ruleNumber += 1;
    }
    if (supportsExpressions) {
      const rules = [
        r'String concatenation: `"text" + $var + "more"`',
        'Dot member access: `query.field` reads a field; on arrays it extracts that field from every element',
        'Index access: `arr[0]`, `data[index]`',
        'Arithmetic operators: +, -, *, /, % (work on numbers; + is string concat when either side is a string)',
        'Comparison: ==, !=, >, <, >=, <=',
        'Logical: &&, ||, ! (prefix)',
        'Ternary: `condition ? valueIfTrue : valueIfFalse`',
        'Parentheses for grouping: `(a + b) * c`',
      ];
      for (final rule in rules) {
        lines.add('$ruleNumber. $rule');
        ruleNumber += 1;
      }
    }
    lines.add('- Strings use double quotes with backslash escaping');
    return lines.join('\n');
  }

  static String _componentSignatures(
    PromptSpec spec, {
    required bool toolCalls,
    required bool bindings,
    required bool usesActionExpression,
  }) {
    final lines = [
      '## Component Signatures',
      '',
      'Arguments marked with ? are optional. Sub-components can be inline or referenced; prefer references for '
          'better streaming.',
    ];
    if (usesActionExpression) {
      final steps = [
        for (final step in _listedSteps(toolCalls: toolCalls, bindings: bindings)) '@${step.name}',
        for (final action in spec.actions) '@${action.name}',
      ];
      lines.add(
        'Props typed `ActionExpression` accept one @step, or Action([@steps...]) for several. See the Action '
        'section for available steps (${steps.join(', ')}).',
      );
      if (spec.components.any((component) => _hasRestrictedSlot(component.signature))) {
        lines.add('Props typed like `@OpenUrl | @ToAssistant` accept only the steps listed.');
      }
    }
    if (bindings || spec.components.any((component) => component.signature.contains(r'$binding'))) {
      lines.add(r'Props marked `$binding<type>` accept a `$variable` reference for two-way binding.');
    }

    final byName = <String, PromptEntry>{};
    for (final component in spec.components) {
      byName.putIfAbsent(component.name, () => component);
    }
    if (spec.componentGroups.isEmpty) {
      lines
        ..add('')
        ..addAll(spec.components.map(_componentLine));
      return lines.join('\n');
    }
    final grouped = <String>{};
    for (final group in spec.componentGroups) {
      lines.addAll(['', '### ${group.name}']);
      for (final name in group.components) {
        final component = byName[name];
        if (component == null || !grouped.add(name)) continue;
        lines.add(_componentLine(component));
      }
      lines.addAll(group.notes);
    }
    final ungrouped = [
      for (final component in spec.components)
        if (!grouped.contains(component.name)) component,
    ];
    if (ungrouped.isNotEmpty) {
      lines.addAll(['', '### Other', ...ungrouped.map(_componentLine)]);
    }
    return lines.join('\n');
  }

  static String _componentLine(PromptEntry component) {
    if (component.description.isEmpty) return component.signature;
    return '${component.signature} — ${component.description}';
  }

  // The built-in steps the prompt lists: `@Run` needs tool calls, `@Set` and
  // `@Reset` bindings.
  static List<PromptEntry> _listedSteps({required bool toolCalls, required bool bindings}) {
    return [
      for (final step in _builtinSteps)
        if (switch (step.name) {
          'Run' => toolCalls,
          'Set' || 'Reset' => bindings,
          _ => true,
        })
          step,
    ];
  }

  static String _builtinFunctionsSection(List<String> customFunctions, {required bool toolCalls}) {
    final lines = [
      for (final function in _builtinFunctions) _callLine(function),
      _callLine(const PromptEntry('Each', _eachSignature, _eachDescription)),
      ...customFunctions,
    ];
    return PromptSections.builtinFunctions(target: toolCalls ? 'Query results' : 'data', lines: lines.join('\n'));
  }

  static String _actionSection(List<String> customActions, {required bool toolCalls, required bool bindings}) {
    final steps = [
      for (final step in _listedSteps(toolCalls: toolCalls, bindings: bindings)) '- ${_callLine(step)}',
      ...customActions,
    ];
    final examples = [if (toolCalls) PromptSections.actionMutationExample, PromptSections.actionNavExample];
    final rules = [
      '- An action can be assigned to a variable or inlined: Button("Go", onSubmit) and Button("Go", Action([...])) '
          'both work',
      if (toolCalls) ...[
        '- If a @Run(mutation) step fails, remaining steps are skipped (halt on failure)',
        '- @Run(queryRef) re-fetches the query (fire-and-forget, cannot fail)',
      ],
    ];
    return PromptSections.action(steps: steps.join('\n'), examples: examples.join('\n\n'), rules: rules.join('\n'));
  }

  static String _streamingRules(String rootName, {required bool supportsExpressions, required bool toolCalls}) {
    final steps = ['1. `root = $rootName(...)` — UI shell appears immediately'];
    if (supportsExpressions) {
      steps.add(r'2. $variable declarations — state ready for bindings');
      if (toolCalls) steps.add('3. Query statements — defaults resolve immediately so components render with data');
      final count = steps.length;
      steps
        ..add('${count + 1}. Component definitions — fill in with data already available')
        ..add('${count + 2}. Data values — leaf content last');
    } else {
      steps
        ..add('2. Component definitions — fill in as they stream')
        ..add('3. Data values — leaf content last');
    }
    return PromptSections.streaming(steps: steps.join('\n'), rootName: rootName);
  }

  static String _importantRules(String rootName, {required bool toolCalls, required bool bindings}) {
    final lines = [
      '1. root = $rootName(...) is the FIRST line (for optimal streaming).',
      '2. Every referenced name is defined. Every defined name (other than root) is reachable from root.',
      if (toolCalls) '3. Every Query result is referenced by at least one component.',
      if (bindings) '${toolCalls ? 4 : 3}. Every \$binding appears in at least one component or expression.',
      if (toolCalls && bindings) r'5. Every visible filter $binding appears in at least one Query args object.',
    ];
    return PromptSections.importantRules(verifyLines: lines.join('\n'));
  }

  static String _toolsSection(List<PromptTool> tools) {
    final specs = tools.whereType<ToolSpec>().toList();
    final lines = [
      '## Available Tools',
      '',
      'Use these with Query() for read operations or Mutation() for write operations. The LLM decides which is '
          "appropriate based on the tool's purpose.",
      '',
      for (final tool in tools.whereType<NamedTool>()) '- ${tool.name}',
      for (final tool in specs) _toolLine(tool),
      if (specs.isNotEmpty) ...[
        '',
        '### Default values for Query results',
        '',
        'Use these shapes as minimal Query defaults:',
        for (final tool in specs) '- ${tool.name}: `${_json(_defaultValue(tool.outputSchema))}`',
      ],
      '',
      'CRITICAL: Use ONLY the tools listed above in Query() and Mutation() calls. Do NOT invent or guess tool '
          "names. If the user asks for functionality that doesn't match any available tool, use realistic mock "
          'data instead of fabricating a tool call.',
    ];
    return lines.join('\n');
  }

  static String _toolLine(ToolSpec tool) {
    final line = '- ${tool.name}(${_fields(tool.inputSchema, 0) ?? ''}) → ${_typeString(tool.outputSchema)}';
    final description = tool.description;
    if (description == null || description.isEmpty) return line;
    return '$line\n  $description';
  }

  // The properties of the JSON Schema object `schema`, as `a: T, b?: U`, or
  // `null` when it has none.
  static String? _fields(Map<String, Object?> schema, int depth) {
    final properties = schema['properties'];
    if (properties is! Map<String, Object?> || properties.isEmpty) return null;
    final required = _requiredNames(schema);
    return [
      for (final MapEntry(:key, :value) in properties.entries)
        '$key${required.contains(key) ? '' : '?'}: ${_typeString(value, depth + 1)}',
    ].join(', ');
  }

  static Set<String> _requiredNames(Map<String, Object?> schema) {
    final required = schema['required'];
    if (required is! List<Object?>) return const {};
    return required.whereType<String>().toSet();
  }

  // The type of a JSON Schema as the tools section writes it.
  static String _typeString(Object? schema, [int depth = 0]) {
    if (schema is! Map<String, Object?> || depth > OpenUIValue.maxJsonDepth) return 'any';
    switch (schema['type']) {
      case 'string':
        final values = schema['enum'];
        if (values is! List<Object?>) return 'string';
        return values.map((value) => '"${_jsString(value)}"').join(' | ');
      case 'number' || 'integer':
        return 'number';
      case 'boolean':
        return 'boolean';
      case 'array':
        final items = schema['items'];
        if (items == null) return 'any[]';
        return '${_typeString(items, depth + 1)}[]';
      case 'object':
        final fields = _fields(schema, depth);
        if (fields == null) return 'object';
        return '{$fields}';
      default:
        return 'any';
    }
  }

  // The empty value of a JSON Schema's type, the shape a Query starts with.
  static Object? _defaultValue(Object? schema, [int depth = 0]) {
    if (schema is! Map<String, Object?> || depth > OpenUIValue.maxJsonDepth) return null;
    switch (schema['type']) {
      case 'string':
        return '';
      case 'number' || 'integer':
        return 0;
      case 'boolean':
        return false;
      case 'array':
        return const <Object?>[];
      case 'object':
        final properties = schema['properties'];
        if (properties is! Map<String, Object?>) return const <String, Object?>{};
        return {for (final MapEntry(:key, :value) in properties.entries) key: _defaultValue(value, depth + 1)};
      default:
        return null;
    }
  }

  // A JSON value as JavaScript's `String(value)` writes it.
  static String _jsString(Object? value) {
    return switch (value) {
      null => 'null',
      final String text => text,
      final bool flag => '$flag',
      final num number => JS.numberToString(number.toDouble()),
      final List<Object?> items => items.map((item) => item == null ? '' : _jsString(item)).join(','),
      _ => '[object Object]',
    };
  }

  static String _json(Object? value) {
    final output = StringBuffer();
    JS.writeJson(value, output);
    return output.toString();
  }
}
