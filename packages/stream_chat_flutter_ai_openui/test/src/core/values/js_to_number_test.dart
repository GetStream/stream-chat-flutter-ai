import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

// The expected numbers are Node 23.11's `Number(s)`, which StreamChatOpenUI
// also gives (test/fixtures/README.md).
void main() {
  for (final (input, expected) in _cases()) {
    test('${jsonEncode(input)} reads as JavaScript reads it: $expected', () {
      expect(_written(JS.stringToNumber(input)), expected);
    });
  }

  test('the cases cover the fixture', () {
    expect(_cases(), hasLength(39));
  });

  // StreamChatOpenUI's `JS.stringToNumber` (`be3e9db`, run) for prefixed
  // literals past 2^53, summed digit by digit as the Android SDK also does.
  // Node gives 144115188075855900 for the first, rounding once.
  for (final (input, expected) in const [
    ('0x200000000000018', '144115188075855870'),
    ('0x1fffffffffffff', '9007199254740991'),
    ('0x20000000000001', '9007199254740992'),
    ('0b111111111111111111111111111111111111111111111111111111111111', '1152921504606847000'),
    ('0o7777777777777777777777', '73786976294838210000'),
  ]) {
    test('$input reads as StreamChatOpenUI reads it: $expected', () {
      expect(_written(JS.stringToNumber(input)), expected);
    });
  }

  test('a hexadecimal literal past the largest double reads as Infinity', () {
    expect(JS.stringToNumber('0x${'f' * 300}'), double.infinity);
  });

  test('a prefixed literal of a million digits is read in linear time', () {
    final stopwatch = Stopwatch()..start();
    JS.stringToNumber('0o1${'0' * 1000000}');

    // Linear, this takes milliseconds; quadratic, about half a minute.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}

// A number as the fixture writes it: `-0` for negative zero.
String _written(double number) {
  if (number.isNaN) return 'NaN';
  if (number == 0 && number.isNegative) return '-0';
  return JS.numberToString(number);
}

List<(String, String)> _cases() {
  return [
    for (final line in File('test/fixtures/node_to_number.txt').readAsLinesSync())
      if (line.split(' => ') case [final input, final expected]) (jsonDecode(input) as String, expected),
  ];
}
