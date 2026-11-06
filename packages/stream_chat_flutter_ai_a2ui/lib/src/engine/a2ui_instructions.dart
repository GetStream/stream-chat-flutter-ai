import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// What an agent is told so that its model writes replies' UI in A2UI: how a
/// reply carries the UI, the protocol, the catalog it writes with, the app's
/// own components and tools, and examples, in Markdown.
///
/// The sections come in a fixed order, each only when it has something to
/// say: [preamble], how a reply's UI is written in the [fence], the protocol,
/// the catalog's [guidelines], the [notes] on the app's components, the app's
/// [tools], the catalog [document], the [rules] and the [examples].
///
/// Internal to the package.
@internal
@immutable
final class A2UIInstructions {
  /// Creates the instructions for the catalog [catalogId], whose JSON Schema
  /// document, without its guidelines, is [document].
  const A2UIInstructions({
    required this.catalogId,
    required this.document,
    required this.fence,
    this.guidelines,
    this.preamble,
    this.notes = const [],
    this.tools = const [],
    this.rules = const [],
    this.examples = const [],
  });

  /// The id the agent names the catalog by.
  final String catalogId;

  /// The catalog the agent writes with, as JSON, without its guidelines.
  final Map<String, Object?> document;

  /// The info string of the fenced block a reply's UI is written in.
  final String fence;

  /// The catalog's own guidelines, or `null` for none.
  final String? guidelines;

  /// What the model is told first, such as which answers to write as UI, or
  /// `null` for nothing.
  final String? preamble;

  /// Guidance on using the app's components, each a line of Markdown.
  final List<String> notes;

  /// The app's tools the UI can call, each a line of Markdown; see [toolLine].
  final List<String> tools;

  /// Rules added after the protocol's, numbered in their order.
  final List<String> rules;

  /// Examples of replies with their UI.
  final List<String> examples;

  /// The instructions, in Markdown.
  String get text {
    final preamble = this.preamble;
    final guidelines = this.guidelines;
    return [
      if (preamble != null && preamble.isNotEmpty) preamble,
      _writing,
      protocolOverview,
      if (guidelines != null && guidelines.isNotEmpty) guidelines,
      if (notes.isNotEmpty) "## The app's components\n\n${notes.join('\n')}",
      if (tools.isNotEmpty) '$_toolsIntroduction\n\n${tools.join('\n')}',
      '## The catalog `$catalogId`\n\n```json\n${sortedJson(document)}\n```',
      if (rules.isNotEmpty)
        '## Rules\n\n${[for (final (index, rule) in rules.indexed) '${index + 1}. $rule'].join('\n')}',
      if (examples.isNotEmpty) '## Examples\n\n${examples.join('\n\n')}',
    ].join('\n\n');
  }

  String get _writing =>
      '''
## Writing UI in A2UI

Write a reply's UI in one fenced block whose info string is `$fence`, after one short sentence saying what it shows, which is what people read wherever the UI can't show. In the block, write A2UI messages, one JSON object per line, and nothing else:

1. First a `createSurface` with a `surfaceId` new to this reply, the `catalogId` `$catalogId`, and the `dataModel` the UI's inputs start from.
2. Then `updateComponents` messages for that surface with a few components each, `root` first, so the UI shows as you write it.

A reply's UI is shown as you wrote it: never write `callRendererFunction` or `agentFunctionResponse`, and never change an earlier reply's UI, but write a new one. What the person does in it comes back as their next message, which says what the button they tapped says. Give every event action a `userMessage` saying what it asks of you, such as "Update the plan", which comes back with it, and a `context` with what you need to know, bound to the data model.''';

  static const _toolsIntroduction = '''
## The app's tools

These run on the person's device. Call one as you call a function the catalog doesn't define, with `{"@call": "<name>", "args": {…}}`, and its output is the call's value. A read-only tool runs wherever you call it, such as in a binding that shows its output. Any other runs only from a button's `functionCall` action, when the person taps it.''';

  /// The guidelines for writing with the basic catalog.
  ///
  /// They are iOS's, not the ones the basic catalog's document has, whose
  /// examples write a surface's messages as one JSON array and name the basic
  /// catalog, where a reply writes one message per line and names the app's
  /// catalog.
  static const basicGuidelines = r'''
For layout, use the Row and Column components to organize other components.

## Catalog Guidelines

1. String Concatenation & Formatting: A2UI does not support binary operators like '+' or formatting symbols. To concatenate strings or dynamically inject data bindings into text, you must use the catalog function `formatString(value)` where the value string contains placeholders formatted as `${expression}`:
   formatString("Hello ${/user/name}")

2. Strict Hierarchy: You must strictly adhere to the requested component nesting and hierarchy. If the prompt specifies that a component is 'inside' or 'contained in' another component, you MUST place it as a child of that specific component, not as a sibling or in a different container.

3. Validation Checks: When components support validation checks, specify any custom error messages directly as the 'message' inside the check. Do NOT create separate text-display components to display validation errors.

4. Text Hierarchy: The Text component only offers the 'body' and 'caption' variants. Use Markdown headings ('#' to '####') inside the text for visual hierarchy.

5. Component Ids: Every surface must contain exactly one component with the id 'root'. Children are always referenced by id; components are never nested inline.''';

  /// A description of the A2UI 1.0 message envelope and its rules.
  static const protocolOverview = '''
# Generating user interfaces with A2UI v1.0

You render user interfaces by emitting A2UI messages. Every message is a JSON object with a `"version": "1.0"` field plus exactly one of these keys:

- `createSurface`: creates a surface. Requires `surfaceId`, and accepts `catalogId`, `sendDataModel`, `components` and `dataModel` so a complete UI can be sent in one message.
- `updateComponents`: adds or replaces components of an existing surface. Requires `surfaceId` and `components`.
- `updateDataModel`: writes to the surface data model. Requires `surfaceId` and `value`, and accepts a JSON Pointer `path`. Setting `value` to `null` deletes the entry at `path`.
- `deleteSurface`: removes a surface. Requires `surfaceId`.
- `callRendererFunction`: asks the renderer to run one of its functions.
- `agentFunctionResponse`: answers a `callAgentFunction` request from the renderer.

Rules:

1. Components are a flat adjacency list. Each component has a unique `id`, a `component` type, and its properties inline. Exactly one component must have the id `root`. An id is an identifier: letters, digits and underscores, not starting with a digit, such as `saturday_plan` (never `saturday-plan`).
2. Children are referenced by id, never nested inline. Use an array of ids, or `{"componentId": "...", "path": "/items"}` to repeat a template for every item of a data model list.
3. Any property may be a literal, a data binding `{"@path": "/a/b"}` or a function call `{"@call": "name", "args": {...}}`. Inside a list template, paths without a leading slash resolve relative to the current item, and `{"@call": "@index"}` returns the item's position. A literal object key that starts with `@` is written with `@@`, so `"@@type"` means `"@type"`.
4. Put content that changes in the data model and bind to it, so you can update values with `updateDataModel` instead of resending components.
5. Interactive components declare an `action`, which either dispatches an event to you (`{"event": {"name": "...", "context": {...}}}`) or runs a renderer function (`{"functionCall": {"@call": "openUrl", "args": {"url": "..."}}}`).
6. Surface ids must be unique for the lifetime of the renderer. Creating a surface that already exists is an error: delete it first, or send `updateComponents` and `updateDataModel` to change it.''';

  /// The [tool] as the instructions list it: its name, whether it only reads,
  /// what it does, and the JSON Schema of its arguments when it takes any.
  static String toolLine(AIToolDefinition tool) {
    final line = StringBuffer('- `${tool.name}`');
    if (tool.isReadOnly) line.write(' (read-only)');
    if (tool.description.isNotEmpty) line.write(': ${tool.description}');
    if (_takesArguments(tool.parameters)) line.write(' Arguments: `${sortedJson(tool.parameters)}`');
    return line.toString();
  }

  // Whether a tool whose arguments are [schema] takes any. A tool declares
  // none with an object schema without properties, which is the default.
  static bool _takesArguments(Map<String, Object?> schema) {
    return switch (schema['properties']) {
      final Map<Object?, Object?> properties => properties.isNotEmpty,
      _ => schema.keys.any((key) => key != 'type' && key != 'properties'),
    };
  }

  /// [value] as one line of JSON with the keys of each object sorted, so the
  /// same value always reads the same.
  static String sortedJson(Object? value) => jsonEncode(_sorted(value));

  static Object? _sorted(Object? value) {
    return switch (value) {
      final Map<Object?, Object?> map => {
        for (final key in map.keys.map((key) => key.toString()).toList()..sort()) key: _sorted(map[key]),
      },
      final List<Object?> list => [for (final item in list) _sorted(item)],
      _ => value,
    };
  }
}
