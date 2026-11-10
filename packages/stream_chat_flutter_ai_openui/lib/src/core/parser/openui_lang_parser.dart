/// Reading a whole OpenUI Lang program.
///
/// Internal to the package.
@internal
library;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/expression_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materialization_cache.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materializer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/preprocessor.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/schema_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/statements.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// A parser of OpenUI Lang programs written for one component library.
///
/// It reads a whole program in one pass: it prepares the text, splits it into
/// statements, picks the entry statement and resolves it into a tree of
/// components, checking each component's arguments against [schema].
///
/// Reading never fails. Lines that aren't statements are skipped, and
/// anything that can't be resolved or doesn't match the schema is left out of
/// the tree and reported in the result.
///
/// ```dart
/// final parser = OpenUILangParser(OpenUILibrarySchema.fromSpec(spec));
/// final result = parser.parse('root = Card([TextContent("Hi")])');
/// print(result.root?.typeName); // Card
/// ```
///
/// See also:
///
///  * [ParseResult], which describes what a program renders and what went
///    wrong.
///  * [OpenUILibrarySchema], which describes the components a program can
///    call.
@immutable
final class OpenUILangParser {
  /// Creates a parser for programs that call the components of [schema].
  const OpenUILangParser(this.schema);

  /// The components, functions and actions programs can call, and the
  /// library's root component.
  final OpenUILibrarySchema schema;

  /// Parses `text`, a whole program or the start of one.
  ///
  /// When `text` holds Markdown code fences, only the fenced blocks are read,
  /// joined in order; otherwise all of it is. Comments starting with `//` or
  /// `#` outside strings are removed.
  ///
  /// Each statement is a line `name = expression`; a statement continues on
  /// the next line while a bracket or string is open, or while a ternary is
  /// unfinished. When a name is defined twice, the later definition wins, in
  /// the place of the earlier one.
  ///
  /// A program that ends inside a string or bracket is read as if they were
  /// closed, and the result is marked [ParseMeta.incomplete].
  ///
  /// The entry is the statement named `root`. Without one, the first
  /// statement that calls the library's root component is used and a warning
  /// is reported; with neither, nothing renders and an error is reported.
  ParseResult parse(String text) {
    final read = readStatements(Preprocessor.prepare(text));
    if (read.statements.isEmpty) return ParseResult.empty(incomplete: read.incomplete);
    return buildResult(
      read.statements,
      schema,
      incomplete: read.incomplete,
      statementCount: read.statements.length,
    );
  }

  /// The statements of `prepared`, a whole program as [Preprocessor.prepare]
  /// gives it, by name in program order, with how many definitions it holds
  /// and whether it ended inside a string or bracket.
  ///
  /// A name defined twice takes the later definition, in the place of the
  /// earlier one, and counts as two definitions. Empty text counts as ending
  /// inside one: no program has arrived yet.
  static ({Map<String, Statement> statements, int definitions, bool incomplete}) readStatements(String prepared) {
    if (prepared.isEmpty) return (statements: const {}, definitions: 0, incomplete: true);
    final (closed, :wasIncomplete) = Statements.autoClose(prepared);
    final raw = Statements.split(Lexer.tokenize(closed));
    return (
      statements: {
        for (final statement in raw) statement.id: classify(statement, ExpressionParser.parse(statement.tokens)),
      },
      definitions: raw.length,
      incomplete: wasIncomplete,
    );
  }

  /// The kind of statement `raw` is, given its parsed `expression`: a query
  /// or mutation by its call (even when the name is a `$name`), a `$variable`
  /// by its name, and otherwise a value.
  static Statement classify(RawStatement raw, AstNode expression) {
    if (expression is AstCall && expression.name == BuiltinCalls.query) {
      final deps = expression.args.length > 1 ? expression.args[1].stateReferences() : const <String>[];
      return QueryStatement(raw.id, expression, deps.isEmpty ? null : deps);
    }
    if (expression is AstCall && expression.name == BuiltinCalls.mutation) {
      return MutationStatement(raw.id, expression);
    }
    if (raw.idKind == TokenKind.stateVariable) return StateStatement(raw.id, expression);
    return ValueStatement(raw.id, expression);
  }

  /// What the program of `statements`, in program order, renders and
  /// declares when read against `schema`.
  ///
  /// The result is marked incomplete (see [ParseMeta.incomplete]) when
  /// `incomplete` is `true`, and counts `statementCount` statements.
  ///
  /// A `$variable` that is used but never declared gets a `null` default,
  /// except the one `partialReference` names in the statements it lists:
  /// the end of a name still arriving.
  ///
  /// With a `cache`, statements whose text and reads are unchanged since an
  /// earlier pass resolve to what they did then. `versions` gives each
  /// statement's version for that cache, and is set on it before anything is
  /// resolved.
  static ParseResult buildResult(
    Map<String, Statement> statements,
    OpenUILibrarySchema schema, {
    required bool incomplete,
    required int statementCount,
    PartialReference? partialReference,
    MaterializationCache? cache,
    Map<String, int>? versions,
  }) {
    if (cache != null && versions != null) cache.versions = versions;
    final entry = _pickEntry(statements, schema.root);
    final symbols = {for (final MapEntry(:key, value: statement) in statements.entries) key: statement.symbol};
    final context = MaterializeContext(
      symbols: symbols,
      schema: schema,
      partial: incomplete,
      currentStatementId: entry?.id,
      unreached: [
        for (final statement in statements.values)
          if (statement is ValueStatement && statement.id != entry?.id) statement.id,
      ],
      cache: cache,
    );

    ElementNode? root;
    AstNode? rootExpression;
    if (entry != null) {
      switch (Materializer.materializeValue(symbols[entry.id]!, context)) {
        case OpenUIElement(:final node):
          root = node.withStatementId(entry.id);
        case OpenUIExpression(:final node) when _containsComponent(node):
          rootExpression = node;
        case OpenUINull() ||
            OpenUIBool() ||
            OpenUINumber() ||
            OpenUIString() ||
            OpenUIArray() ||
            OpenUIObject() ||
            OpenUIExpression():
          break;
      }
    }

    final stateDeclarations = <String, OpenUIValue>{};
    final queries = <QueryStatementInfo>[];
    final mutations = <MutationStatementInfo>[];
    for (final statement in statements.values) {
      switch (statement) {
        case StateStatement(:final id, :final initial):
          stateDeclarations[id] = Materializer.materializeValue(initial, context);
        case QueryStatement(:final id, :final call, :final deps):
          final args = Materializer.nameRawCallArgs(call.args, context, id);
          queries.add(
            QueryStatementInfo(
              statementId: id,
              tool: args.elementAtOrNull(0),
              args: args.elementAtOrNull(1),
              defaults: args.elementAtOrNull(2),
              refresh: args.elementAtOrNull(3),
              deps: deps,
            ),
          );
        case MutationStatement(:final id, :final call):
          final args = Materializer.nameRawCallArgs(call.args, context, id);
          mutations.add(
            MutationStatementInfo(statementId: id, tool: args.elementAtOrNull(0), args: args.elementAtOrNull(1)),
          );
        case ValueStatement():
          break;
      }
    }

    for (final statement in statements.values) {
      for (final name in _stateReferences(statement, cache)) {
        if (partialReference != null && partialReference.holdsBack(name, statement.id)) continue;
        stateDeclarations.putIfAbsent(name, () => OpenUINull.instance);
      }
    }
    if (cache != null) cache.debugResolvedNodes += context.debugResolvedNodes;

    context.currentStatementId = entry?.id;
    final component = schema.root ?? '';
    if (entry == null) {
      context.report(OpenUIErrorCode.noRoot, component, '', _missingRootMessage(component));
    } else if (root == null && rootExpression == null && !_resolvesToComponentCall(symbols[entry.id], symbols)) {
      context.report(OpenUIErrorCode.noRoot, component, '', 'root does not evaluate to a component');
    } else if (entry.isFallback) {
      if (root != null) {
        context.report(
          OpenUIErrorCode.noRoot,
          component,
          '',
          'No root statement. Rendering the first statement that calls the root component $component',
          isWarning: true,
        );
      } else {
        context.report(OpenUIErrorCode.noRoot, component, '', _missingRootMessage(component));
      }
    }

    return ParseResult(
      root: root,
      rootExpression: rootExpression,
      meta: ParseMeta(
        incomplete: incomplete,
        unresolved: context.unresolved,
        // With no entry nothing is reachable, and `no-root` alone says so.
        orphaned: entry == null ? const [] : context.unreached.toList(),
        statementCount: statementCount,
        errors: context.errors,
      ),
      stateDeclarations: stateDeclarations,
      queryStatements: queries,
      mutationStatements: mutations,
    );
  }

  // The `$variables` [statement] uses, kept in [cache] while the statement
  // is unchanged.
  static List<String> _stateReferences(Statement statement, MaterializationCache? cache) {
    final version = cache?.versions[statement.id];
    if (version != null) {
      if (cache!.stateReferences[statement.id] case (version: final kept, :final names) when kept == version) {
        return names;
      }
    }
    final nodes = switch (statement) {
      StateStatement(:final initial) => [initial],
      ValueStatement(:final expression) => [expression],
      QueryStatement(:final call) || MutationStatement(:final call) => call.args,
    };
    final names = [for (final node in nodes) ...node.stateReferences()];
    if (version != null) cache!.stateReferences[statement.id] = (version: version, names: names);
    return names;
  }

  static String _missingRootMessage(String component) {
    if (component.isEmpty) return 'No root statement';
    return 'No root statement, and no statement calls the root component $component';
  }

  // The statement named `root`, or else the first value statement that calls
  // the root component, which is a fallback.
  static ({String id, bool isFallback})? _pickEntry(Map<String, Statement> statements, String? rootName) {
    if (statements.containsKey(_rootStatement)) return (id: _rootStatement, isFallback: false);
    if (rootName == null) return null;
    for (final statement in statements.values) {
      if (statement is ValueStatement && _componentCallName(statement.expression) == rootName) {
        return (id: statement.id, isFallback: true);
      }
    }
    return null;
  }

  static const _rootStatement = 'root';

  // The component [node] calls, when it is a call of a library component
  // rather than an `@` function, a built-in, `Query` or `Mutation`.
  static String? _componentCallName(AstNode? node) {
    if (node is! AstCall || node.isFunction) return null;
    if (BuiltinCalls.isBuiltin(node.name) || BuiltinCalls.isReservedCall(node.name)) return null;
    return node.name;
  }

  // Whether [node], followed through references, is a component call: such
  // an entry that didn't render failed its own checks, which are reported.
  static bool _resolvesToComponentCall(AstNode? node, Map<String, AstNode> symbols) {
    var current = node;
    final seen = <String>{};
    while (current is AstRef && seen.add(current.name)) {
      current = symbols[current.name];
    }
    return _componentCallName(current) != null;
  }

  // Whether evaluating [node] can give a component, as `$t ? a : b` can.
  static bool _containsComponent(AstNode node) {
    var found = false;
    node.walk((current) {
      if (_componentCallName(current) != null) found = true;
    });
    return found;
  }
}

/// A `$name` that ends a text still streaming in, which more of its name may
/// follow, so it isn't declared yet.
@immutable
final class PartialReference {
  /// Creates the reference to [name] at the end of the text, used by the
  /// statements [statementIds].
  const PartialReference(this.name, this.statementIds);

  /// The name so far, such as `$d` of what may become `$dishes`.
  final String name;

  /// The statements still arriving, the only ones that can hold it.
  final Set<String> statementIds;

  /// Whether the use of `variable` in the statement `statementId` is this
  /// reference, which isn't declared yet.
  bool holdsBack(String variable, String statementId) => variable == name && statementIds.contains(statementId);
}
