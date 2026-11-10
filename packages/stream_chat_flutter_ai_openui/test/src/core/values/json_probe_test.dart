import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

// What JSON text decodes to, through `jsonDecode` and `OpenUIValue.fromJson`,
// against what Node 23.11's `JSON.parse` gives (test/fixtures/README.md). The
// one difference: `-0`, which Dart's decoder reads as the integer 0, and which
// JavaScript prints as `0` too.
void main() {
  for (final (input, expected) in _cases()) {
    test('${jsonEncode(input)} decodes as JSON.parse decodes it', () {
      expect(_decoded(input), input == '-0' ? 'OK num 0' : expected);
    });
  }

  test('the cases cover the fixture', () {
    expect(_cases(), hasLength(21));
  });
}

String _decoded(String text) {
  try {
    return 'OK ${_describe(OpenUIValue.fromJson(jsonDecode(text)))}';
  } on FormatException {
    return 'ERR';
  }
}

// A value as the fixture writes it.
String _describe(OpenUIValue value) {
  return switch (value) {
    OpenUINull() => 'null',
    OpenUIBool(:final value) => '$value',
    OpenUINumber(:final value) => 'num ${value == 0 && value.isNegative ? '-0' : JS.numberToString(value)}',
    OpenUIString(:final value) => 'str units=${value.codeUnits.map((unit) => unit.toRadixString(16)).join(',')}',
    OpenUIArray(:final items) => '[${items.map(_describe).join('; ')}]',
    OpenUIObject(:final fields) =>
      '{${fields.entries.map((entry) => '${entry.key}:${_describe(entry.value)}').join('; ')}}',
    OpenUIElement() || OpenUIExpression() => '?',
  };
}

List<(String, String)> _cases() {
  return [
    for (final line in File('test/fixtures/node_json_parse.txt').readAsLinesSync())
      if (line.split(' => ') case [final input, final expected]) (jsonDecode(input) as String, expected),
  ];
}
