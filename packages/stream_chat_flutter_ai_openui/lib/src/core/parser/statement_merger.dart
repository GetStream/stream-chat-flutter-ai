/// Applying an edit-mode answer to the previous program.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/expression_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/preprocessor.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/statements.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// The merge of an edit-mode answer into the previous program (OpenUI's
/// `mergeStatements`).
///
/// Asked to change UI it already wrote, a model can answer with a patch that
/// holds only the statements that change, rather than the whole program.
abstract final class StatementMerger {
  /// The program `existing` with `patch`, an edit-mode answer whose Markdown
  /// fences are read, applied to it.
  ///
  /// Statements are matched by name: a statement of the patch replaces the
  /// one of the same name, keeping its place, or is added at the end when the
  /// name is new, and `name = null` deletes one. Statements the `rootId`
  /// statement, `root` by default, no longer reaches are dropped, except
  /// `$variables`, which are bound at run time rather than by reference; with
  /// no `rootId` statement nothing is dropped.
  ///
  /// The merged statements are written as they were, one on each line, so a
  /// statement that spanned lines is joined by its line breaks as it was. An
  /// `existing` program without statements gives the patch's statements, and
  /// a patch without any gives `existing` unchanged. Each name is
  /// written once, as its last definition, where it first appears, as the
  /// specification asks (iOS and Android write a name `existing` defines
  /// twice twice).
  static String merge(String existing, String patch, {String rootId = 'root'}) {
    final existingStatements = _parse(existing);
    final patchStatements = _parse(Preprocessor.stripFences(patch));
    if (existingStatements.isEmpty) return patchStatements.map((statement) => statement.raw).join('\n');
    if (patchStatements.isEmpty) return existing;

    final order = <String>[];
    final raws = <String, String>{};
    final asts = <String, AstNode>{};
    for (final statement in existingStatements) {
      if (!raws.containsKey(statement.id)) order.add(statement.id);
      raws[statement.id] = statement.raw;
      asts[statement.id] = statement.ast;
    }
    for (final statement in patchStatements) {
      if (statement.ast is AstNull) {
        raws.remove(statement.id);
        asts.remove(statement.id);
        order.remove(statement.id);
        continue;
      }
      if (!raws.containsKey(statement.id)) order.add(statement.id);
      raws[statement.id] = statement.raw;
      asts[statement.id] = statement.ast;
    }

    final reachable = _reachable(asts, rootId);
    return [
      for (final id in order)
        if (reachable == null || reachable.contains(id) || id.startsWith(r'$')) raws[id]!,
    ].join('\n');
  }

  // The statements of [source], each with its name, its expression and the
  // text it was written as.
  static List<({String id, AstNode ast, String raw})> _parse(String source) {
    final trimmed = JS.trim(source);
    if (trimmed.isEmpty) return const [];
    return [
      for (final raw in _splitSource(trimmed))
        if (Statements.split(Lexer.tokenize(raw)).firstOrNull case final statement?)
          (id: statement.id, ast: ExpressionParser.parse(statement.tokens), raw: raw),
    ];
  }

  // [source] split at the line breaks outside strings and brackets, each part
  // trimmed, those that are empty left out.
  static List<String> _splitSource(String source) {
    final statements = <String>[];
    var depth = 0;
    int? quote;
    var escaped = false;
    var start = 0;
    final units = source.codeUnits;
    for (var i = 0; i < units.length; i += 1) {
      final unit = units[i];
      if (escaped) {
        escaped = false;
      } else if (unit == _backslash && quote != null) {
        escaped = true;
      } else if (quote != null) {
        if (unit == quote) quote = null;
      } else if (unit == _doubleQuote || unit == _singleQuote) {
        quote = unit;
      } else if (unit == _openParen || unit == _openBracket || unit == _openBrace) {
        depth += 1;
      } else if (unit == _closeParen || unit == _closeBracket || unit == _closeBrace) {
        depth = depth > 0 ? depth - 1 : 0;
      } else if (unit == _lineFeed && depth <= 0) {
        final statement = JS.trim(source.substring(start, i));
        if (statement.isNotEmpty) statements.add(statement);
        start = i + 1;
      }
    }
    final tail = JS.trim(source.substring(start));
    if (tail.isNotEmpty) statements.add(tail);
    return statements;
  }

  // The names of the statements [rootId] reaches by reference, itself
  // included, or `null` when there is no such statement.
  static Set<String>? _reachable(Map<String, AstNode> asts, String rootId) {
    if (!asts.containsKey(rootId)) return null;
    final reachable = {rootId};
    final queue = [rootId];
    while (queue.isNotEmpty) {
      final ast = asts[queue.removeLast()];
      if (ast == null) continue;
      ast.walk((node) {
        final name = switch (node) {
          AstRef(:final name) => name,
          AstRuntimeRef(:final name) => name,
          _ => null,
        };
        if (name != null && asts.containsKey(name) && reachable.add(name)) queue.add(name);
      });
    }
    return reachable;
  }

  static const _lineFeed = 0x0a;
  static const _doubleQuote = 0x22;
  static const _singleQuote = 0x27;
  static const _backslash = 0x5c;
  static const _openParen = 0x28;
  static const _closeParen = 0x29;
  static const _openBracket = 0x5b;
  static const _closeBracket = 0x5d;
  static const _openBrace = 0x7b;
  static const _closeBrace = 0x7d;
}
