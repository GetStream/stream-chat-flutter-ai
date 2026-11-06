/// The tokens OpenUI Lang source is read as.
///
/// Internal to the package.
@internal
library;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// The kind of a [Token].
enum TokenKind {
  /// A line break, which ends a statement outside brackets.
  newline,

  /// `(`
  leftParen,

  /// `)`
  rightParen,

  /// `[`
  leftBracket,

  /// `]`
  rightBracket,

  /// `{`
  leftBrace,

  /// `}`
  rightBrace,

  /// `,`
  comma,

  /// `:`
  colon,

  /// `=`
  equals,

  /// `true`
  trueKeyword,

  /// `false`
  falseKeyword,

  /// `null`
  nullKeyword,

  /// The end of the source.
  eof,

  /// A string literal; [Token.text] holds its value.
  string,

  /// A number literal; [Token.number] holds its value.
  number,

  /// A name starting with a lowercase letter or `_`: a reference.
  identifier,

  /// A name starting with an uppercase letter: a component or a reference.
  type,

  /// A `$name`, with the `$` in [Token.text].
  stateVariable,

  /// `.`
  dot,

  /// `+`
  plus,

  /// `-`
  minus,

  /// `*`
  star,

  /// `/`
  slash,

  /// `%`
  percent,

  /// `==`
  equalEqual,

  /// `!=`
  notEqual,

  /// `>`
  greater,

  /// `<`
  less,

  /// `>=`
  greaterEqual,

  /// `<=`
  lessEqual,

  /// `&&`, or a single `&`.
  and,

  /// `||`, or a single `|`.
  or,

  /// `!`
  not,

  /// `?`
  question,

  /// An `@name`, without the `@` in [Token.text].
  builtinCall,
}

/// One token of OpenUI Lang source.
@immutable
final class Token {
  /// Creates a token of [kind], with the [text] or [number] it carries.
  const Token(this.kind, {this.text, this.number});

  /// The token that ends the source.
  static const eof = Token(TokenKind.eof);

  /// What kind of token this is.
  final TokenKind kind;

  /// The value of a string, a name, a `$name` with its `$`, or an `@name`
  /// without its `@`; otherwise `null`.
  final String? text;

  /// The value of a number, or `null`.
  final double? number;

  /// The token's [text], its [number] as JavaScript prints it, or
  /// `undefined` when it carries neither.
  String get valueString {
    if (text case final text?) return text;
    if (number case final number?) return JS.numberToString(number);
    return 'undefined';
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Token && other.kind == kind && other.text == text && _sameNumber(other.number, number);
  }

  @override
  int get hashCode => Object.hash(kind, text, (number?.isNaN ?? false) ? double.nan.hashCode : number);

  // Numbers compare as `AstNumber` and `OpenUINumber` compare them: NaN equals
  // NaN.
  static bool _sameNumber(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return JS.sameValueZero(a, b);
  }

  @override
  String toString() => 'Token(${kind.name}${text == null ? '' : ', $text'}${number == null ? '' : ', $number'})';
}
