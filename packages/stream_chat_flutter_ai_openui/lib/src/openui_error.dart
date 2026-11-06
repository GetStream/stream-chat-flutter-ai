import 'package:flutter/foundation.dart';

/// A problem found while reading or running an OpenUI Lang program.
///
/// Each error says where it comes from, which statement, component and prop to
/// change, and, when it helps, how: the components available, or the arguments
/// a component takes. Most can be fixed by changing the program, which makes
/// errors suitable for sending back to the model so it can correct it.
///
/// Two errors are `==` when all their fields are.
@immutable
final class OpenUIError {
  /// Creates an error from [source] with [code] and [message].
  ///
  /// The [statementId], [component] and [path] say where the problem is,
  /// [toolName] names the tool a query or mutation called, [hint] says how to
  /// fix it, and [isWarning] marks a problem the program still renders
  /// despite.
  const OpenUIError({
    required this.source,
    required this.code,
    required this.message,
    this.statementId,
    this.component,
    this.path,
    this.toolName,
    this.hint,
    this.isWarning = false,
  });

  /// The part of reading or running the program that found this error.
  final OpenUIErrorSource source;

  /// The kind of problem, such as [OpenUIErrorCode.unknownComponent].
  final OpenUIErrorCode code;

  /// A description of the problem, written for the model as much as for
  /// people.
  final String message;

  /// The name of the statement to change, such as `header`, or `null` when
  /// none applies.
  final String? statementId;

  /// The component or call the problem is in, or `null` when none applies.
  final String? component;

  /// Where in the component's props the problem is, as a JSON Pointer such as
  /// `/title`, or `null` for the whole component.
  final String? path;

  /// The tool a query or mutation called, for errors from
  /// [OpenUIErrorSource.query] and [OpenUIErrorSource.mutation]; otherwise
  /// `null`.
  final String? toolName;

  /// How the program can be fixed, such as the components available or the
  /// arguments a component takes, or `null` when there is nothing to add.
  final String? hint;

  /// Whether the program still renders despite this error, as when it has no
  /// `root` statement but calls the library's root component.
  final bool isWarning;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIError &&
        other.source == source &&
        other.code == code &&
        other.message == message &&
        other.statementId == statementId &&
        other.component == component &&
        other.path == path &&
        other.toolName == toolName &&
        other.hint == hint &&
        other.isWarning == isWarning;
  }

  @override
  int get hashCode => Object.hash(source, code, message, statementId, component, path, toolName, hint, isWarning);

  @override
  String toString() => '$source/$code: $message';
}

/// Where an [OpenUIError] comes from.
///
/// The constants are the sources OpenUI Lang names. Any other string is a
/// valid source too.
extension type const OpenUIErrorSource(String _) implements String {
  /// Reading the program: unknown components, missing arguments, no root.
  static const parser = OpenUIErrorSource('parser');

  /// Evaluating the program.
  static const runtime = OpenUIErrorSource('runtime');

  /// The tool call of a `Query`.
  static const query = OpenUIErrorSource('query');

  /// The tool call of a `Mutation`.
  static const mutation = OpenUIErrorSource('mutation');
}

/// The code of an [OpenUIError].
///
/// The constants are OpenUI Lang's own codes. Any other string is a valid code
/// too, such as one a later version of the language adds.
extension type const OpenUIErrorCode(String _) implements String {
  /// A call of a component the library doesn't have.
  static const unknownComponent = OpenUIErrorCode('unknown-component');

  /// A component call without an argument the component requires.
  static const missingRequired = OpenUIErrorCode('missing-required');

  /// A component call passing `null` for an argument the component requires.
  static const nullRequired = OpenUIErrorCode('null-required');

  /// A value of a kind its argument doesn't take, such as a list where a
  /// string goes.
  static const typeMismatch = OpenUIErrorCode('type-mismatch');

  /// A call passing more arguments than it takes; the extra ones are dropped.
  static const excessArgs = OpenUIErrorCode('excess-args');

  /// A `Query(…)` or `Mutation(…)` written inside a value rather than as a
  /// statement of its own.
  static const inlineReserved = OpenUIErrorCode('inline-reserved');

  /// An `@Name(…)` call that is not a built-in, nor a function or action of
  /// the library; it reads as `null`.
  static const unknownFunction = OpenUIErrorCode('unknown-function');

  /// No `root` statement, or a `root` that isn't a component.
  static const noRoot = OpenUIErrorCode('no-root');

  /// A reply that gave nothing to render.
  ///
  /// Reading a whole reply in one go doesn't report it.
  static const parseFailed = OpenUIErrorCode('parse-failed');

  /// Reading the program failed unexpectedly.
  static const parseException = OpenUIErrorCode('parse-exception');

  /// Evaluating an expression or a library function failed.
  static const runtimeError = OpenUIErrorCode('runtime-error');

  /// Drawing a component failed.
  static const renderError = OpenUIErrorCode('render-error');

  /// A query or mutation called a tool the app doesn't have.
  static const toolNotFound = OpenUIErrorCode('tool-not-found');

  /// A tool a query or mutation called failed.
  static const toolError = OpenUIErrorCode('tool-error');

  /// A tool served over MCP failed.
  static const mcpError = OpenUIErrorCode('mcp-error');
}
