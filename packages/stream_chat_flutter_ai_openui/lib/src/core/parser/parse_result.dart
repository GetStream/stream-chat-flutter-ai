/// What reading an OpenUI Lang program produces.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// What reading an OpenUI Lang program produced: the tree to render, the
/// statements declaring state and tool calls, and what went wrong.
///
/// Obtained from `OpenUILangParser.parse`.
@immutable
final class ParseResult {
  /// Creates a result with the given parts.
  ParseResult({
    required this.root,
    this.rootExpression,
    required this.meta,
    required Map<String, OpenUIValue> stateDeclarations,
    required List<QueryStatementInfo> queryStatements,
    required List<MutationStatementInfo> mutationStatements,
  }) : stateDeclarations = Map.unmodifiable(stateDeclarations),
       queryStatements = List.unmodifiable(queryStatements),
       mutationStatements = List.unmodifiable(mutationStatements);

  /// The result of text holding no statements: nothing to render, and
  /// incomplete unless `incomplete` is `false`.
  factory ParseResult.empty({bool incomplete = true}) {
    return ParseResult(
      root: null,
      meta: ParseMeta(
        incomplete: incomplete,
        unresolved: const [],
        orphaned: const [],
        statementCount: 0,
        errors: const [],
      ),
      stateDeclarations: const {},
      queryStatements: const [],
      mutationStatements: const [],
    );
  }

  /// The component the entry statement renders, with the components it
  /// contains, or `null` when there is nothing to render.
  ///
  /// It is `null` when the program has no entry, when the entry isn't a
  /// component, when the entry component failed validation, and when the
  /// entry picks a component only when evaluated (see [rootExpression]).
  final ElementNode? root;

  /// The entry's expression when it picks a component only when evaluated,
  /// such as `root = $dark ? darkPage : lightPage`; otherwise `null`.
  final AstNode? rootExpression;

  /// How the text was read: whether it was cut short, which references and
  /// statements went unused, and the errors found.
  final ParseMeta meta;

  /// The default value of every `$variable`: the declared ones in the order
  /// they are declared, then the ones used without a declaration in the order
  /// they are first used.
  ///
  /// A `$variable` the program uses without declaring defaults to `null`.
  final Map<String, OpenUIValue> stateDeclarations;

  /// The `Query(…)` statements, in program order.
  final List<QueryStatementInfo> queryStatements;

  /// The `Mutation(…)` statements, in program order.
  final List<MutationStatementInfo> mutationStatements;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ParseResult &&
        other.root == root &&
        other.rootExpression == rootExpression &&
        other.meta == meta &&
        const MapEquality<String, OpenUIValue>().equals(other.stateDeclarations, stateDeclarations) &&
        const ListEquality<QueryStatementInfo>().equals(other.queryStatements, queryStatements) &&
        const ListEquality<MutationStatementInfo>().equals(other.mutationStatements, mutationStatements);
  }

  @override
  int get hashCode {
    return Object.hash(
      root,
      rootExpression,
      meta,
      const MapEquality<String, OpenUIValue>().hash(stateDeclarations),
      const ListEquality<QueryStatementInfo>().hash(queryStatements),
      const ListEquality<MutationStatementInfo>().hash(mutationStatements),
    );
  }
}

/// How an OpenUI Lang program was read.
@immutable
final class ParseMeta {
  /// Creates the metadata of a read.
  ParseMeta({
    required this.incomplete,
    required List<String> unresolved,
    required List<String> orphaned,
    required this.statementCount,
    required List<ValidationError> errors,
  }) : unresolved = List.unmodifiable(unresolved),
       orphaned = List.unmodifiable(orphaned),
       errors = List.unmodifiable(errors);

  /// Whether the text ended inside a string or bracket, so the end of the
  /// program is missing.
  ///
  /// Text with no program in it yet also counts as incomplete: white space,
  /// comments, or code fences with nothing in them.
  final bool incomplete;

  /// The names referenced but never defined, or reached again through a
  /// cycle, once per use; each reads as `null`, and is left out of arrays.
  final List<String> unresolved;

  /// The value statements the entry never reaches, in program order.
  ///
  /// `$variable`, `Query` and `Mutation` statements are never orphaned, and
  /// nothing is when the program has no entry.
  final List<String> orphaned;

  /// The number of distinct statement names.
  final int statementCount;

  /// The problems found, in the order they were found.
  final List<ValidationError> errors;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ParseMeta &&
        other.incomplete == incomplete &&
        const ListEquality<String>().equals(other.unresolved, unresolved) &&
        const ListEquality<String>().equals(other.orphaned, orphaned) &&
        other.statementCount == statementCount &&
        const ListEquality<ValidationError>().equals(other.errors, errors);
  }

  @override
  int get hashCode {
    return Object.hash(
      incomplete,
      const ListEquality<String>().hash(unresolved),
      const ListEquality<String>().hash(orphaned),
      statementCount,
      const ListEquality<ValidationError>().hash(errors),
    );
  }
}

/// A component call resolved against the library: its arguments mapped to
/// named props in the order the library declares them.
@immutable
final class ElementNode {
  /// Creates the element of the component [typeName] with [props].
  ElementNode({
    required this.typeName,
    required Map<String, OpenUIValue> props,
    required this.partial,
    required this.hasDynamicProps,
    this.statementId,
  }) : props = Map.unmodifiable(props);

  /// The component's name, such as `Card`.
  final String typeName;

  /// The arguments, named after the parameters they fill, in the library's
  /// order; an argument left out, or dropped as invalid, has no entry unless
  /// its parameter is required and has a default.
  final Map<String, OpenUIValue> props;

  /// Whether the program was cut short, so this element may still change.
  final bool partial;

  /// Whether a prop holds something that must be evaluated, such as an
  /// expression, or an object with a `steps` list.
  final bool hasDynamicProps;

  /// The name of the statement that defines this element, such as `header`
  /// for `header = CardHeader(…)`, or `null` for a call written inline.
  final String? statementId;

  /// This element with [statementId] as the statement that defines it.
  ElementNode withStatementId(String statementId) {
    return ElementNode(
      typeName: typeName,
      props: props,
      partial: partial,
      hasDynamicProps: hasDynamicProps,
      statementId: statementId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ElementNode &&
        other.typeName == typeName &&
        const MapEquality<String, OpenUIValue>().equals(other.props, props) &&
        other.partial == partial &&
        other.hasDynamicProps == hasDynamicProps &&
        other.statementId == statementId;
  }

  @override
  int get hashCode {
    return Object.hash(
      typeName,
      const MapEquality<String, OpenUIValue>().hash(props),
      partial,
      hasDynamicProps,
      statementId,
    );
  }
}

/// A problem found while reading a program.
@immutable
final class ValidationError {
  /// Creates an error of [code] in [component] at [path].
  const ValidationError({
    required this.code,
    required this.component,
    required this.path,
    required this.message,
    this.statementId,
    this.isWarning = false,
  });

  /// The kind of problem, such as [OpenUIErrorCode.unknownComponent].
  final OpenUIErrorCode code;

  /// The component or call the problem is in, or the library's root
  /// component for a `no-root` error; empty when there is none.
  final String component;

  /// Where in the component's props the problem is, as a JSON Pointer such as
  /// `/title`, or empty for the whole component.
  final String path;

  /// A description of the problem, written for the model as much as for
  /// people.
  final String message;

  /// The statement being read when the problem was found, or `null` when
  /// none was.
  final String? statementId;

  /// Whether the program still renders despite the problem.
  final bool isWarning;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ValidationError &&
        other.code == code &&
        other.component == component &&
        other.path == path &&
        other.message == message &&
        other.statementId == statementId &&
        other.isWarning == isWarning;
  }

  @override
  int get hashCode => Object.hash(code, component, path, message, statementId, isWarning);

  @override
  String toString() => '$code: $message';
}

/// A `Query(tool, args, defaults, refresh)` statement, its arguments kept
/// unevaluated.
@immutable
final class QueryStatementInfo {
  /// Creates the query [statementId] with its argument expressions.
  const QueryStatementInfo({
    required this.statementId,
    this.tool,
    this.args,
    this.defaults,
    this.refresh,
    this.deps,
    this.complete = true,
  });

  /// The statement's name.
  final String statementId;

  /// The tool's name, or `null` when the call has no arguments.
  final AstNode? tool;

  /// The arguments the tool is called with, or `null` when not given.
  final AstNode? args;

  /// The data shown until the tool answers, or `null` when not given.
  final AstNode? defaults;

  /// How often, in seconds, the query runs again, or `null` when not given.
  final AstNode? refresh;

  /// The `$variables` [args] reads, or `null` when it reads none.
  final List<String>? deps;

  /// Whether the whole `Query(…)` call has been read; always `true` for text
  /// read in one go.
  final bool complete;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is QueryStatementInfo &&
        other.statementId == statementId &&
        other.tool == tool &&
        other.args == args &&
        other.defaults == defaults &&
        other.refresh == refresh &&
        const ListEquality<String>().equals(other.deps, deps) &&
        other.complete == complete;
  }

  @override
  int get hashCode {
    return Object.hash(statementId, tool, args, defaults, refresh, const ListEquality<String>().hash(deps), complete);
  }
}

/// A `Mutation(tool, args)` statement, its arguments kept unevaluated.
@immutable
final class MutationStatementInfo {
  /// Creates the mutation [statementId] with its argument expressions.
  const MutationStatementInfo({required this.statementId, this.tool, this.args});

  /// The statement's name.
  final String statementId;

  /// The tool's name, or `null` when the call has no arguments.
  final AstNode? tool;

  /// The arguments the tool is called with, or `null` when not given.
  final AstNode? args;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MutationStatementInfo &&
        other.statementId == statementId &&
        other.tool == tool &&
        other.args == args;
  }

  @override
  int get hashCode => Object.hash(statementId, tool, args);
}
