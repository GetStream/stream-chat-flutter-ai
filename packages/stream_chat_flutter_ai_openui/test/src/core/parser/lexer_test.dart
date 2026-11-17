import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';

void main() {
  test('punctuation and operators read as their tokens', () {
    expect(_kinds('( ) [ ] { } , : = . ? + - * / % == != > < >= <= && || !'), [
      TokenKind.leftParen,
      TokenKind.rightParen,
      TokenKind.leftBracket,
      TokenKind.rightBracket,
      TokenKind.leftBrace,
      TokenKind.rightBrace,
      TokenKind.comma,
      TokenKind.colon,
      TokenKind.equals,
      TokenKind.dot,
      TokenKind.question,
      TokenKind.plus,
      TokenKind.minus,
      TokenKind.star,
      TokenKind.slash,
      TokenKind.percent,
      TokenKind.equalEqual,
      TokenKind.notEqual,
      TokenKind.greater,
      TokenKind.less,
      TokenKind.greaterEqual,
      TokenKind.lessEqual,
      TokenKind.and,
      TokenKind.or,
      TokenKind.not,
      TokenKind.eof,
    ]);
  });

  test('a single & reads as &&', () {
    expect(_kinds('a & b'), [TokenKind.identifier, TokenKind.and, TokenKind.identifier, TokenKind.eof]);
  });

  test('a single | reads as ||', () {
    expect(_kinds('a | b'), [TokenKind.identifier, TokenKind.or, TokenKind.identifier, TokenKind.eof]);
  });

  test('a line feed is a token, while spaces, tabs and carriage returns are not', () {
    expect(_kinds('a \t\r\nb'), [TokenKind.identifier, TokenKind.newline, TokenKind.identifier, TokenKind.eof]);
  });

  test('a double-quoted string decodes its JSON escapes', () {
    expect(_text(r'"q\"d\\b\tt\u0041"'), 'q"d\\b\ttA');
  });

  test('a double-quoted string that is not valid JSON keeps its raw text', () {
    expect(_text(r'"a\x"'), r'a\x');
  });

  test('a double-quoted string with a raw line break keeps its raw text', () {
    expect(_text('"line one\nline two"'), 'line one\nline two');
  });

  test('a lone surrogate escape stays a lone surrogate', () {
    expect(_text(r'"\ud800"').codeUnits, [0xd800]);
  });

  test('an unclosed double-quoted string reads as if closed', () {
    expect(_text('"partial'), 'partial');
  });

  test(r"a single-quoted string reads \' \\ \n and \t", () {
    expect(_text(r"'it\'s \\ \n \t'"), "it's \\ \n \t");
  });

  test('a single-quoted string passes any other escaped character through', () {
    expect(_text(r"'\q'"), 'q');
  });

  test('a minus after a value subtracts', () {
    expect(_kinds('1 -2'), [TokenKind.number, TokenKind.minus, TokenKind.number, TokenKind.eof]);
  });

  test('a minus before a digit elsewhere starts a negative number', () {
    expect(Lexer.tokenize('[-5]')[1].number, -5);
  });

  test('a minus before something else is an operator', () {
    expect(_kinds('-x'), [TokenKind.minus, TokenKind.identifier, TokenKind.eof]);
  });

  test('a number reads its fraction and exponent', () {
    expect(Lexer.tokenize('1.5e3')[0].number, 1500);
  });

  test('a point without a digit after it ends the number', () {
    expect(_kinds('1.x'), [TokenKind.number, TokenKind.dot, TokenKind.identifier, TokenKind.eof]);
  });

  test('a dangling exponent reads as NaN', () {
    expect(Lexer.tokenize('1e')[0].number, isNaN);
  });

  test(r'a $name is a state variable, with its $', () {
    expect(Lexer.tokenize(r'$count')[0], const Token(TokenKind.stateVariable, text: r'$count'));
  });

  test(r'a $ without a letter after it is skipped', () {
    expect(_kinds(r'$1'), [TokenKind.number, TokenKind.eof]);
  });

  test('an @name is a built-in call, without its @', () {
    expect(Lexer.tokenize('@Count')[0], const Token(TokenKind.builtinCall, text: 'Count'));
  });

  test('an uppercase name is a type and a lowercase one an identifier', () {
    expect(_kinds('Card card _x'), [TokenKind.type, TokenKind.identifier, TokenKind.identifier, TokenKind.eof]);
  });

  test('true, false and null are keywords', () {
    expect(_kinds('true false null'), [
      TokenKind.trueKeyword,
      TokenKind.falseKeyword,
      TokenKind.nullKeyword,
      TokenKind.eof,
    ]);
  });

  test('characters that start no token are skipped', () {
    expect(_kinds('a ; # 😀 b'), [TokenKind.identifier, TokenKind.identifier, TokenKind.eof]);
  });

  test('reading never fails, whatever the text', () {
    final random = Random(42);
    const alphabet = 'aZ09_\$@"\'\\()[]{},:=.?+-*/%!<>&| \t\r\n#😀';

    for (var i = 0; i < 2000; i += 1) {
      final length = random.nextInt(40);
      final text = String.fromCharCodes([
        for (var j = 0; j < length; j += 1) alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      expect(Lexer.tokenize(text).last, Token.eof);
    }
  });
}

List<TokenKind> _kinds(String source) => [for (final token in Lexer.tokenize(source)) token.kind];

String _text(String source) => Lexer.tokenize(source).first.text!;
