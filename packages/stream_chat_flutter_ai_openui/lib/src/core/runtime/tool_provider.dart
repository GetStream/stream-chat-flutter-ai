/// Running the tools a program's queries and mutations call.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// Runs the tools `Query(…)` and `Mutation(…)` statements name.
///
/// Internal: the app's tools reach it through the host, not by implementing
/// it.
abstract interface class OpenUIToolProvider {
  /// The result of running the tool `name` with `args`.
  ///
  /// `userInitiated` is `true` for a mutation, which the person runs from a
  /// tap, and `false` for a query, which runs by itself as the UI shows.
  /// Fails with [ToolNotFoundException] for a tool it doesn't have; any other
  /// failure, or a throw, fails the call.
  Future<OpenUIValue> callTool(String name, Map<String, OpenUIValue> args, {required bool userInitiated});
}

/// Thrown by a tool provider that has no tool of the name asked for.
final class ToolNotFoundException implements Exception {
  /// Creates the exception for [toolName], listing [availableTools].
  const ToolNotFoundException(this.toolName, {this.availableTools = const []});

  /// The tool asked for.
  final String toolName;

  /// The tools the provider has.
  final List<String> availableTools;

  @override
  String toString() {
    final available = availableTools.isEmpty ? '(none)' : availableTools.join(', ');
    return '[openui] No handler for tool "$toolName". Available: $available';
  }
}

/// Thrown when an MCP tool answers with an error result.
final class McpToolException implements Exception {
  /// Creates the exception with the tool's error [text].
  const McpToolException(this.text);

  /// What the tool said went wrong.
  final String text;

  @override
  String toString() => 'MCP tool error: ${text.isEmpty ? 'Unknown error' : text}';
}
