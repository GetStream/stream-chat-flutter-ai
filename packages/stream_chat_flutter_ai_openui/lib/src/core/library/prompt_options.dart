/// What a system prompt says besides the library: its preamble, rules,
/// examples, tools and the parts of the language it teaches.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The choices a system prompt is generated with.
///
/// [toolCalls] defaults to whether there are [tools], [bindings] to
/// [toolCalls], and [builtinFunctions] to whether either of them is on.
@immutable
final class PromptOptions {
  /// Creates the options of a system prompt.
  const PromptOptions({
    this.preamble,
    this.additionalRules = const [],
    this.examples = const [],
    this.toolExamples = const [],
    this.tools = const [],
    this.editMode = false,
    this.inlineMode = false,
    this.toolCalls,
    this.bindings,
    this.builtinFunctions,
  });

  /// What the model is told first, or `null` for the default preamble.
  final String? preamble;

  /// The rules listed at the end, one per line.
  final List<String> additionalRules;

  /// The example programs, each as written.
  final List<String> examples;

  /// The example programs that use tools, listed after [examples].
  final List<String> toolExamples;

  /// The tools a program can call from `Query()` and `Mutation()`.
  final List<PromptTool> tools;

  /// Whether the model answers with only the statements that change an
  /// earlier program.
  final bool editMode;

  /// Whether the model may answer in text, with programs in fenced blocks.
  final bool inlineMode;

  /// Whether the prompt teaches `Query()`, `Mutation()` and `@Run`, or `null`
  /// for whether there are [tools].
  final bool? toolCalls;

  /// Whether the prompt teaches `$variables`, `@Set` and `@Reset`, or `null`
  /// for the value of [toolCalls].
  final bool? bindings;

  /// Whether the prompt lists the built-in functions, such as `@Count`, or
  /// `null` for whether [toolCalls] or [bindings] is on.
  final bool? builtinFunctions;

  /// A copy of these options with the given preamble, rules, examples, tool
  /// examples and tools in place of the current ones; the modes and flags
  /// are kept.
  PromptOptions copyWith({
    String? preamble,
    List<String>? additionalRules,
    List<String>? examples,
    List<String>? toolExamples,
    List<PromptTool>? tools,
  }) {
    return PromptOptions(
      preamble: preamble ?? this.preamble,
      additionalRules: additionalRules ?? this.additionalRules,
      examples: examples ?? this.examples,
      toolExamples: toolExamples ?? this.toolExamples,
      tools: tools ?? this.tools,
      editMode: editMode,
      inlineMode: inlineMode,
      toolCalls: toolCalls,
      bindings: bindings,
      builtinFunctions: builtinFunctions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PromptOptions &&
        other.preamble == preamble &&
        const ListEquality<String>().equals(other.additionalRules, additionalRules) &&
        const ListEquality<String>().equals(other.examples, examples) &&
        const ListEquality<String>().equals(other.toolExamples, toolExamples) &&
        const ListEquality<PromptTool>().equals(other.tools, tools) &&
        other.editMode == editMode &&
        other.inlineMode == inlineMode &&
        other.toolCalls == toolCalls &&
        other.bindings == bindings &&
        other.builtinFunctions == builtinFunctions;
  }

  @override
  int get hashCode {
    return Object.hash(
      preamble,
      const ListEquality<String>().hash(additionalRules),
      const ListEquality<String>().hash(examples),
      const ListEquality<String>().hash(toolExamples),
      const ListEquality<PromptTool>().hash(tools),
      editMode,
      inlineMode,
      toolCalls,
      bindings,
      builtinFunctions,
    );
  }
}

/// A tool a system prompt lists for `Query()` and `Mutation()`: by name only
/// ([NamedTool]) or with its description and schemas ([ToolSpec]).
@immutable
sealed class PromptTool {
  /// Creates the tool [name].
  const PromptTool(this.name);

  /// The name a program calls the tool by.
  final String name;
}

/// A tool listed by its name only.
final class NamedTool extends PromptTool {
  /// Creates the tool [name].
  const NamedTool(super.name);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NamedTool && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

/// A tool listed with its arguments, result and what it does.
final class ToolSpec extends PromptTool {
  /// Creates the tool [name], whose arguments are described by the JSON
  /// Schema [inputSchema] and whose result by [outputSchema].
  const ToolSpec(super.name, {this.description, this.inputSchema = const {}, this.outputSchema = const {}});

  /// What the tool does, or `null` when it isn't described.
  final String? description;

  /// The JSON Schema of the tool's arguments.
  final Map<String, Object?> inputSchema;

  /// The JSON Schema of the tool's result.
  final Map<String, Object?> outputSchema;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ToolSpec &&
        other.name == name &&
        other.description == description &&
        const DeepCollectionEquality().equals(other.inputSchema, inputSchema) &&
        const DeepCollectionEquality().equals(other.outputSchema, outputSchema);
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      description,
      const DeepCollectionEquality().hash(inputSchema),
      const DeepCollectionEquality().hash(outputSchema),
    );
  }
}

/// One of the app's tools, as the app describes it.
@immutable
final class HostTool {
  /// Creates the tool [name].
  const HostTool(this.name, {this.description = '', this.isReadOnly = false, this.inputSchema});

  /// The name a program calls the tool by.
  final String name;

  /// What the tool does; empty when it isn't described.
  final String description;

  /// Whether the tool only reads, so a `Query()` may run it without the
  /// person asking.
  final bool isReadOnly;

  /// The JSON Schema of the tool's arguments, or `null` when it takes none.
  final Map<String, Object?>? inputSchema;

  /// What a system prompt says of a tool that only reads.
  static const readOnlyUse = 'Read-only: use it in Query() or Mutation().';

  /// What a system prompt says of a tool that changes something.
  static const changingUse = 'It changes something: use it only in Mutation(), which runs when the person taps.';

  /// This tool as a system prompt lists it, its description followed by
  /// whether a `Query()` may run it.
  ToolSpec toToolSpec() {
    final use = isReadOnly ? readOnlyUse : changingUse;
    return ToolSpec(
      name,
      description: description.isEmpty ? use : '$description $use',
      inputSchema: inputSchema ?? const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is HostTool &&
        other.name == name &&
        other.description == description &&
        other.isReadOnly == isReadOnly &&
        const DeepCollectionEquality().equals(other.inputSchema, inputSchema);
  }

  @override
  int get hashCode => Object.hash(name, description, isReadOnly, const DeepCollectionEquality().hash(inputSchema));
}
