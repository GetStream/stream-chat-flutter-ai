/// Splitting OpenUI Lang source into statements, and closing a cut-off one.
///
/// Internal to the package.
@internal
library;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';

/// A statement `name = expression` before its expression is parsed.
@immutable
final class RawStatement {
  /// Creates the statement [id] `=` [tokens], whose name was a token of
  /// [idKind].
  const RawStatement(this.id, this.idKind, this.tokens);

  /// The name the statement defines, such as `header` or `$count`.
  final String id;

  /// The kind of the name's token: [TokenKind.stateVariable] for a `$name`.
  final TokenKind idKind;

  /// The tokens of the expression, without line breaks.
  final List<Token> tokens;
}

/// Splitting a program into statements, and closing a program cut short.
abstract final class Statements {
  /// `text` with its open string and brackets closed, and whether anything
  /// was open.
  ///
  /// A string open at the end is closed with its own quote, after a `\` when
  /// the text ends in the middle of an escape. Then each open bracket is
  /// closed, innermost first. A closing bracket that doesn't match the
  /// innermost open one is ignored. Text with nothing open comes back
  /// unchanged.
  static (String, {bool wasIncomplete}) autoClose(String text) {
    final stack = <int>[];
    int? quote;
    var escaped = false;
    for (final c in text.codeUnits) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == _backslash && quote != null) {
        escaped = true;
        continue;
      }
      if (quote != null) {
        if (c == quote) quote = null;
        continue;
      }
      switch (c) {
        case _doubleQuote || _singleQuote:
          quote = c;
        case _leftParen || _leftBracket || _leftBrace:
          stack.add(c);
        case _rightParen:
          if (stack.isNotEmpty && stack.last == _leftParen) stack.removeLast();
        case _rightBracket:
          if (stack.isNotEmpty && stack.last == _leftBracket) stack.removeLast();
        case _rightBrace:
          if (stack.isNotEmpty && stack.last == _leftBrace) stack.removeLast();
      }
    }
    if (quote == null && stack.isEmpty) return (text, wasIncomplete: false);

    final output = StringBuffer(text);
    if (quote != null) {
      if (escaped) output.writeCharCode(_backslash);
      output.writeCharCode(quote);
    }
    for (final opener in stack.reversed) {
      output.write(switch (opener) {
        _leftParen => ')',
        _leftBracket => ']',
        _ => '}',
      });
    }
    return (output.toString(), wasIncomplete: true);
  }

  /// The statements in `tokens`.
  ///
  /// A statement is a name (`name`, `Name` or `$name`), `=`, and an
  /// expression running to a line break outside brackets. A statement with a
  /// `?` still waiting for its `:` continues across line breaks, and so does
  /// one whose next line starts with `?`. Blank lines are skipped, and so is a
  /// line that doesn't start with a name and `=`, or whose expression is
  /// empty.
  static List<RawStatement> split(List<Token> tokens) {
    final statements = <RawStatement>[];
    final count = tokens.length;
    var position = 0;

    void skipLine() {
      while (position < count && tokens[position].kind != TokenKind.newline && tokens[position].kind != TokenKind.eof) {
        position += 1;
      }
    }

    while (position < count) {
      while (position < count && tokens[position].kind == TokenKind.newline) {
        position += 1;
      }
      if (position >= count || tokens[position].kind == TokenKind.eof) break;

      final name = tokens[position];
      if (!_names.contains(name.kind)) {
        skipLine();
        continue;
      }
      position += 1;
      if (position >= count || tokens[position].kind != TokenKind.equals) {
        skipLine();
        continue;
      }
      position += 1;

      final expression = <Token>[];
      var depth = 0;
      var ternaryDepth = 0;
      while (position < count && tokens[position].kind != TokenKind.eof) {
        final kind = tokens[position].kind;
        if (kind == TokenKind.newline && depth <= 0 && ternaryDepth <= 0) {
          var peek = position + 1;
          while (peek < count && tokens[peek].kind == TokenKind.newline) {
            peek += 1;
          }
          if (peek < count && tokens[peek].kind == TokenKind.question) {
            // The blank lines up to the `?` are skipped at once, so a long run
            // of them is read in one pass.
            position = peek;
            continue;
          }
          break;
        }
        if (kind == TokenKind.newline) {
          position += 1;
          continue;
        }
        switch (kind) {
          case TokenKind.leftParen || TokenKind.leftBracket || TokenKind.leftBrace:
            depth += 1;
          case TokenKind.rightParen || TokenKind.rightBracket || TokenKind.rightBrace:
            if (depth > 0) depth -= 1;
          case TokenKind.question:
            if (depth == 0) ternaryDepth += 1;
          case TokenKind.colon:
            if (depth == 0 && ternaryDepth > 0) ternaryDepth -= 1;
          default:
            break;
        }
        expression.add(tokens[position]);
        position += 1;
      }
      if (expression.isNotEmpty) statements.add(RawStatement(name.text!, name.kind, List.unmodifiable(expression)));
    }
    return statements;
  }

  static const _names = {TokenKind.identifier, TokenKind.type, TokenKind.stateVariable};

  static const _doubleQuote = 0x22;
  static const _singleQuote = 0x27;
  static const _leftParen = 0x28;
  static const _rightParen = 0x29;
  static const _leftBracket = 0x5b;
  static const _backslash = 0x5c;
  static const _rightBracket = 0x5d;
  static const _leftBrace = 0x7b;
  static const _rightBrace = 0x7d;
}
