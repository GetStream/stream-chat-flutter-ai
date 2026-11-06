import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

// The expected texts are Node 23.11's `String(n)`, which StreamChatOpenUI
// also gives (test/fixtures/README.md).
void main() {
  for (final (input, expected) in _cases()) {
    test('$input prints as JavaScript prints it: $expected', () {
      expect(JS.numberToString(double.parse(input)), expected);
    });
  }

  test('NaN prints as NaN', () {
    expect(JS.numberToString(double.nan), 'NaN');
  });

  test('infinity prints as Infinity', () {
    expect(JS.numberToString(double.infinity), 'Infinity');
  });

  test('negative infinity prints as -Infinity', () {
    expect(JS.numberToString(double.negativeInfinity), '-Infinity');
  });

  test('the cases cover the fixture', () {
    expect(_cases(), hasLength(32));
  });
}

List<(String, String)> _cases() {
  return [
    for (final line in File('test/fixtures/node_number_to_string.txt').readAsLinesSync())
      if (line.split(' => ') case [final input, final expected]) (input, expected),
  ];
}
