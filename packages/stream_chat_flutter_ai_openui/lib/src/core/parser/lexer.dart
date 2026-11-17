/// Reading OpenUI Lang source as tokens.
///
/// Internal to the package.
@internal
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// The reader of OpenUI Lang source as [Token]s.
abstract final class Lexer {
  /// The tokens of `source`, ending with [Token.eof].
  ///
  /// Reading never fails: a character that starts no token, such as `#` or an
  /// emoji, is skipped. Spaces, tabs and carriage returns separate tokens,
  /// while a line feed is a [TokenKind.newline] token of its own.
  ///
  /// A `"…"` string is decoded as JSON decodes a string, or kept as the raw
  /// text between the quotes when that fails; a `'…'` string knows only the
  /// escapes `\'`, `\\`, `\n` and `\t`. A `-` right after a value is
  /// subtraction; elsewhere, with a digit after it, it starts a negative
  /// number. A single `&` or `|` reads as `&&` or `||`.
  static List<Token> tokenize(String source) {
    final tokens = <Token>[];
    final length = source.length;
    var i = 0;

    int at(int index) => index < length ? source.codeUnitAt(index) : 0;

    void addOneOrTwo(int second, TokenKind two, TokenKind one) {
      if (at(i + 1) == second) {
        tokens.add(Token(two));
        i += 2;
      } else {
        tokens.add(Token(one));
        i += 1;
      }
    }

    while (i < length) {
      while (i < length && _isHorizontalSpace(source.codeUnitAt(i))) {
        i += 1;
      }
      if (i >= length) break;

      final unit = source.codeUnitAt(i);
      if (_single[unit] case final kind?) {
        tokens.add(Token(kind));
        i += 1;
        continue;
      }
      switch (unit) {
        case _equals:
          addOneOrTwo(_equals, TokenKind.equalEqual, TokenKind.equals);
          continue;
        case _bang:
          addOneOrTwo(_equals, TokenKind.notEqual, TokenKind.not);
          continue;
        case _greater:
          addOneOrTwo(_equals, TokenKind.greaterEqual, TokenKind.greater);
          continue;
        case _less:
          addOneOrTwo(_equals, TokenKind.lessEqual, TokenKind.less);
          continue;
        case _ampersand:
          addOneOrTwo(_ampersand, TokenKind.and, TokenKind.and);
          continue;
        case _bar:
          addOneOrTwo(_bar, TokenKind.or, TokenKind.or);
          continue;
        case _doubleQuote:
          i = _readDoubleQuoted(source, i, tokens);
          continue;
        case _singleQuote:
          i = _readSingleQuoted(source, i, tokens);
          continue;
      }

      if (unit == _minus) {
        // After a value, `-` subtracts: `[1 -2]` is `1 - 2`, not two items.
        final afterValue = tokens.isNotEmpty && _valueEnders.contains(tokens.last.kind);
        if (afterValue || !_isDigit(at(i + 1))) {
          tokens.add(const Token(TokenKind.minus));
          i += 1;
          continue;
        }
      }

      if (_isDigit(unit) || unit == _minus) {
        final start = i;
        if (unit == _minus) i += 1;
        while (i < length && _isDigit(source.codeUnitAt(i))) {
          i += 1;
        }
        if (i < length && source.codeUnitAt(i) == _dot && _isDigit(at(i + 1))) {
          i += 1;
          while (i < length && _isDigit(source.codeUnitAt(i))) {
            i += 1;
          }
        }
        if (i < length && (source.codeUnitAt(i) == _lowerE || source.codeUnitAt(i) == _upperE)) {
          i += 1;
          if (i < length && (source.codeUnitAt(i) == _plus || source.codeUnitAt(i) == _minus)) i += 1;
          while (i < length && _isDigit(source.codeUnitAt(i))) {
            i += 1;
          }
        }
        // Read as JavaScript's `Number` reads it: a dangling exponent, `1e`, is
        // NaN.
        tokens.add(Token(TokenKind.number, number: JS.stringToNumber(source.substring(start, i))));
        continue;
      }

      if (unit == _dollar && _isIdentifierStart(at(i + 1))) {
        final start = i;
        i += 1;
        while (i < length && _isIdentifierPart(source.codeUnitAt(i))) {
          i += 1;
        }
        tokens.add(Token(TokenKind.stateVariable, text: source.substring(start, i)));
        continue;
      }

      if (_isIdentifierStart(unit)) {
        final start = i;
        while (i < length && _isIdentifierPart(source.codeUnitAt(i))) {
          i += 1;
        }
        final word = source.substring(start, i);
        tokens.add(switch (word) {
          'true' => const Token(TokenKind.trueKeyword),
          'false' => const Token(TokenKind.falseKeyword),
          'null' => const Token(TokenKind.nullKeyword),
          _ => Token(_isUppercase(unit) ? TokenKind.type : TokenKind.identifier, text: word),
        });
        continue;
      }

      if (unit == _at && _isIdentifierStart(at(i + 1))) {
        i += 1;
        final start = i;
        while (i < length && _isIdentifierPart(source.codeUnitAt(i))) {
          i += 1;
        }
        tokens.add(Token(TokenKind.builtinCall, text: source.substring(start, i)));
        continue;
      }

      i += 1;
    }

    tokens.add(Token.eof);
    return tokens;
  }

  // Reads the `"…"` string starting at [start], adds its token and returns
  // the index after it. An unclosed string, cut off while it streams, is read
  // as if it were closed.
  static int _readDoubleQuoted(String source, int start, List<Token> tokens) {
    final length = source.length;
    var i = start + 1;
    var closed = false;
    while (i < length) {
      final unit = source.codeUnitAt(i);
      if (unit == _backslash) {
        i += 2;
      } else if (unit == _doubleQuote) {
        i += 1;
        closed = true;
        break;
      } else {
        i += 1;
      }
    }
    final end = i < length ? i : length;
    final raw = source.substring(start, end);
    tokens.add(Token(TokenKind.string, text: _decodeJsonString(closed ? raw : '$raw"') ?? _withoutQuotes(raw)));
    return end;
  }

  static String? _decodeJsonString(String literal) {
    try {
      return jsonDecode(literal) as String;
    } on FormatException {
      return null;
    }
  }

  // [raw] without a leading and a trailing `"`: what a string that isn't
  // valid JSON, such as one holding a raw line break, reads as.
  static String _withoutQuotes(String raw) {
    final start = raw.startsWith('"') ? 1 : 0;
    final end = raw.length > start && raw.endsWith('"') ? raw.length - 1 : raw.length;
    return raw.substring(start, end);
  }

  // Reads the `'…'` string starting at [start], adds its token and returns
  // the index after it.
  static int _readSingleQuoted(String source, int start, List<Token> tokens) {
    final length = source.length;
    final result = StringBuffer();
    var i = start + 1;
    while (i < length) {
      final unit = source.codeUnitAt(i);
      if (unit == _backslash) {
        i += 1;
        if (i < length) {
          final escaped = source.codeUnitAt(i);
          result.writeCharCode(switch (escaped) {
            _lowerN => _lineFeed,
            _lowerT => _tab,
            _ => escaped,
          });
          i += 1;
        }
      } else if (unit == _singleQuote) {
        i += 1;
        break;
      } else {
        result.writeCharCode(unit);
        i += 1;
      }
    }
    tokens.add(Token(TokenKind.string, text: result.toString()));
    return i;
  }

  // The characters that are a token on their own, by code unit; each kind's
  // doc shows its character.
  static const _single = <int, TokenKind>{
    _lineFeed: TokenKind.newline,
    0x28: TokenKind.leftParen,
    0x29: TokenKind.rightParen,
    0x5b: TokenKind.leftBracket,
    0x5d: TokenKind.rightBracket,
    0x7b: TokenKind.leftBrace,
    0x7d: TokenKind.rightBrace,
    0x2c: TokenKind.comma,
    0x3a: TokenKind.colon,
    _dot: TokenKind.dot,
    0x3f: TokenKind.question,
    _plus: TokenKind.plus,
    0x2a: TokenKind.star,
    0x2f: TokenKind.slash,
    0x25: TokenKind.percent,
  };

  // The tokens after which `-` subtracts rather than starts a number.
  static const _valueEnders = {
    TokenKind.number,
    TokenKind.string,
    TokenKind.identifier,
    TokenKind.type,
    TokenKind.rightParen,
    TokenKind.rightBracket,
    TokenKind.trueKeyword,
    TokenKind.falseKeyword,
    TokenKind.nullKeyword,
    TokenKind.stateVariable,
    TokenKind.builtinCall,
  };

  static const _tab = 0x09;
  static const _lineFeed = 0x0a;
  static const _bang = 0x21;
  static const _doubleQuote = 0x22;
  static const _dollar = 0x24;
  static const _ampersand = 0x26;
  static const _singleQuote = 0x27;
  static const _plus = 0x2b;
  static const _minus = 0x2d;
  static const _dot = 0x2e;
  static const _less = 0x3c;
  static const _equals = 0x3d;
  static const _greater = 0x3e;
  static const _at = 0x40;
  static const _upperE = 0x45;
  static const _backslash = 0x5c;
  static const _lowerE = 0x65;
  static const _lowerN = 0x6e;
  static const _lowerT = 0x74;
  static const _bar = 0x7c;

  // A space, a tab or a carriage return.
  static bool _isHorizontalSpace(int unit) => unit == 0x20 || unit == _tab || unit == 0x0d;

  // `0`–`9`.
  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  // `A`–`Z`.
  static bool _isUppercase(int unit) => unit >= 0x41 && unit <= 0x5a;

  // A letter or `_`.
  static bool _isIdentifierStart(int unit) => _isUppercase(unit) || (unit >= 0x61 && unit <= 0x7a) || unit == 0x5f;

  static bool _isIdentifierPart(int unit) => _isIdentifierStart(unit) || _isDigit(unit);
}
