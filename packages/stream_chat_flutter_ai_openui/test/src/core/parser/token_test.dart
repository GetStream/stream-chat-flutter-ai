// Equal values are built as separate instances, never `const`, which would
// make them one instance and the equality checks pass without comparing.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';

void main() {
  test('two NaN number tokens are equal', () {
    expect(Token(TokenKind.number, number: double.nan), Token(TokenKind.number, number: _otherNaN()));
  });

  test('two NaN number tokens share a hash code', () {
    expect(
      Token(TokenKind.number, number: double.nan).hashCode,
      Token(TokenKind.number, number: _otherNaN()).hashCode,
    );
  });

  test('tokens of different numbers are not equal', () {
    expect(Token(TokenKind.number, number: 1), isNot(Token(TokenKind.number, number: 2)));
  });

  test('a number token is not equal to a token without a number', () {
    expect(Token(TokenKind.number, number: 1), isNot(Token(TokenKind.number)));
  });

  test('a string token gives its text as its value', () {
    expect(Token(TokenKind.string, text: 'a').valueString, 'a');
  });

  test('a number token gives its number as JavaScript prints it', () {
    expect(Token(TokenKind.number, number: 1e21).valueString, '1e+21');
  });

  test('a token without text or number gives undefined', () {
    expect(Token(TokenKind.comma).valueString, 'undefined');
  });
}

// A NaN whose bits differ from `double.nan`'s, so its `hashCode` differs too.
double _otherNaN() => (ByteData(8)..setUint64(0, 0x7ff8000000000001)).getFloat64(0);
