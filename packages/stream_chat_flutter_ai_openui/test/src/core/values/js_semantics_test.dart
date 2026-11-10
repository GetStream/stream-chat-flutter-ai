import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

// Expected values are what Node 23.11 gives for the JavaScript in each test's
// name.
void main() {
  test('toNumber reads a numeric string as its number', () {
    expect(JS.toNumber(const OpenUIString(' 4.5 ')), 4.5);
  });

  test('toNumber reads a string that is no number as 0', () {
    expect(JS.toNumber(const OpenUIString('abc')), 0);
  });

  test('toNumber reads true as 1', () {
    expect(JS.toNumber(const OpenUIBool(true)), 1);
  });

  test('toNumber reads an array as 0', () {
    expect(JS.toNumber(OpenUIArray(const [OpenUINumber(3)])), 0);
  });

  test('String([1, null, "a"]) is "1,,a"', () {
    final array = OpenUIArray(const [OpenUINumber(1), OpenUINull.instance, OpenUIString('a')]);

    expect(JS.stringOf(array), '1,,a');
  });

  test('String({}) is "[object Object]"', () {
    expect(JS.stringOf(OpenUIObject(const {})), '[object Object]');
  });

  test('String(undefined) is "undefined"', () {
    expect(JS.stringOf(null), 'undefined');
  });

  test('String(null) is "null"', () {
    expect(JS.stringOf(OpenUINull.instance), 'null');
  });

  test('an empty string is false in a condition', () {
    expect(JS.isTruthy(const OpenUIString('')), isFalse);
  });

  test('"0" is true in a condition', () {
    expect(JS.isTruthy(const OpenUIString('0')), isTrue);
  });

  test('NaN is false in a condition', () {
    expect(JS.isTruthy(const OpenUINumber(double.nan)), isFalse);
  });

  test('an empty array is true in a condition', () {
    expect(JS.isTruthy(OpenUIArray(const [])), isTrue);
  });

  test('undefined is false in a condition', () {
    expect(JS.isTruthy(null), isFalse);
  });

  test('null == undefined', () {
    expect(JS.looseEquals(OpenUINull.instance, null), isTrue);
  });

  test('null != 0', () {
    expect(JS.looseEquals(OpenUINull.instance, const OpenUINumber(0)), isFalse);
  });

  test('1 == "1"', () {
    expect(JS.looseEquals(const OpenUINumber(1), const OpenUIString('1')), isTrue);
  });

  test('true == 1', () {
    expect(JS.looseEquals(const OpenUIBool(true), const OpenUINumber(1)), isTrue);
  });

  test('"" == 0', () {
    expect(JS.looseEquals(const OpenUIString(''), const OpenUINumber(0)), isTrue);
  });

  test('"1,2" == [1, 2]', () {
    final array = OpenUIArray(const [OpenUINumber(1), OpenUINumber(2)]);

    expect(JS.looseEquals(const OpenUIString('1,2'), array), isTrue);
  });

  test('two arrays with the same items are loosely equal, where JavaScript compares identity', () {
    final a = OpenUIArray(const [OpenUINumber(1)]);
    final b = OpenUIArray(const [OpenUINumber(1)]);

    expect(JS.looseEquals(a, b), isTrue);
  });

  test('typeof null is "object"', () {
    expect(JS.typeOf(OpenUINull.instance), 'object');
  });

  test('jsType of an array is "array"', () {
    expect(JS.jsType(OpenUIArray(const [])), 'array');
  });

  test('[1, 2].length is 2', () {
    final array = OpenUIArray(const [OpenUINumber(1), OpenUINumber(2)]);

    expect(JS.property(array, 'length'), const OpenUINumber(2));
  });

  test('"😀".length counts UTF-16 code units: 2', () {
    expect(JS.property(const OpenUIString('😀'), 'length'), const OpenUINumber(2));
  });

  test('"abc"["01"] is undefined: 01 is not an index', () {
    expect(JS.property(const OpenUIString('abc'), '01'), isNull);
  });

  test('"abc"[1] is "b"', () {
    expect(JS.property(const OpenUIString('abc'), '1'), const OpenUIString('b'));
  });

  test("an element's typeName reads as a property", () {
    final element = OpenUIElement(
      ElementNode(typeName: 'Card', props: const {}, partial: false, hasDynamicProps: false),
    );

    expect(JS.property(element, 'typeName'), const OpenUIString('Card'));
  });

  test('({a: 1}).a is 1', () {
    expect(JS.property(OpenUIObject(const {'a': OpenUINumber(1)}), 'a'), const OpenUINumber(1));
  });

  test('({a: 1}).b is undefined', () {
    expect(JS.property(OpenUIObject(const {'a': OpenUINumber(1)}), 'b'), isNull);
  });

  test('[5, 6][1] is 6', () {
    expect(JS.property(OpenUIArray(const [OpenUINumber(5), OpenUINumber(6)]), '1'), const OpenUINumber(6));
  });

  test('[5][9] is undefined', () {
    expect(JS.property(OpenUIArray(const [OpenUINumber(5)]), '9'), isNull);
  });

  test('"abc".length is 3', () {
    expect(JS.property(const OpenUIString('abc'), 'length'), const OpenUINumber(3));
  });

  test('(1).a is undefined', () {
    expect(JS.property(const OpenUINumber(1), 'a'), isNull);
  });

  test("an element's type reads as element", () {
    expect(JS.property(_element(), 'type'), const OpenUIString('element'));
  });

  test("an element's props read as an object", () {
    expect(JS.property(_element(), 'props'), OpenUIObject(const {'title': OpenUIString('T')}));
  });

  test("an element's partial reads as a boolean", () {
    expect(JS.property(_element(), 'partial'), const OpenUIBool(true));
  });

  test("an element's hasDynamicProps reads as a boolean", () {
    expect(JS.property(_element(), 'hasDynamicProps'), const OpenUIBool(false));
  });

  test("an element's statementId reads as a string", () {
    expect(JS.property(_element(statementId: 'c'), 'statementId'), const OpenUIString('c'));
  });

  test("an element's missing statementId is undefined", () {
    expect(JS.property(_element(), 'statementId'), isNull);
  });

  test("an element's other properties are undefined", () {
    expect(JS.property(_element(), 'other'), isNull);
  });

  test('JSON.stringify({b: 1, a: [1.5, NaN]}) keeps key order and writes NaN as null', () {
    final object = OpenUIObject({
      'b': const OpenUINumber(1),
      'a': OpenUIArray(const [OpenUINumber(1.5), OpenUINumber(double.nan)]),
    });

    expect(JS.jsonStringify(object), '{"b":1,"a":[1.5,null]}');
  });

  test('JSON.stringify escapes a control character in lowercase hex and keeps U+2028', () {
    expect(JS.jsonStringify(const OpenUIString('\u0001\u2028')), '"\\u0001\u2028"');
  });

  test('JSON.stringify escapes a lone surrogate', () {
    expect(JS.jsonStringify(const OpenUIString('\ud800')), r'"\ud800"');
  });

  for (final (character, escaped) in const [
    ('"', r'\"'),
    (r'\', r'\\'),
    ('\b', r'\b'),
    ('\f', r'\f'),
    ('\n', r'\n'),
    ('\r', r'\r'),
    ('\t', r'\t'),
  ]) {
    test('JSON.stringify escapes ${jsonEncode(character)} as $escaped', () {
      expect(JS.jsonStringify(OpenUIString(character)), '"$escaped"');
    });
  }

  test('JSON.stringify escapes a lone low surrogate', () {
    expect(JS.jsonStringify(const OpenUIString('\udc00')), r'"\udc00"');
  });

  test('JSON.stringify([true, false, null]) is [true,false,null]', () {
    expect(
      JS.jsonStringify(OpenUIArray(const [OpenUIBool(true), OpenUIBool(false), OpenUINull.instance])),
      '[true,false,null]',
    );
  });

  test('writing a value that is not plain JSON throws', () {
    expect(() => JS.writeJson(DateTime(2026), StringBuffer()), throwsA(isA<ArgumentError>()));
  });

  test('JSON.stringify(undefined) is undefined', () {
    expect(JS.jsonStringify(null), isNull);
  });

  test('trim removes JavaScript white space, U+FEFF and U+3000 included', () {
    expect(JS.trim('\ufeff\u3000 a b\u2028\t'), 'a b');
  });
}

OpenUIElement _element({String? statementId}) {
  return OpenUIElement(
    ElementNode(
      typeName: 'Card',
      props: const {'title': OpenUIString('T')},
      partial: true,
      hasDynamicProps: false,
      statementId: statementId,
    ),
  );
}
