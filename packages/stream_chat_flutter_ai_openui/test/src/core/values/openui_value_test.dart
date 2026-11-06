import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

void main() {
  test('fromJson reads each kind of JSON value', () {
    final value = OpenUIValue.fromJson(jsonDecode('[null, true, 1, 1.5, "a", [], {}]'));

    expect(
      value,
      OpenUIArray([
        OpenUINull.instance,
        const OpenUIBool(true),
        const OpenUINumber(1),
        const OpenUINumber(1.5),
        const OpenUIString('a'),
        OpenUIArray(const []),
        OpenUIObject(const {}),
      ]),
    );
  });

  test('fromJson reads an integer as a double', () {
    expect((OpenUIValue.fromJson(3) as OpenUINumber).value, isA<double>());
  });

  test('a decoded object keeps its key order', () {
    final value = OpenUIValue.fromJson(jsonDecode('{"b": 1, "a": 2}')) as OpenUIObject;

    expect(value.fields.keys, ['b', 'a']);
  });

  test('a repeated key keeps its first position and its last value', () {
    final value = OpenUIValue.fromJson(jsonDecode('{"b": 1, "a": 2, "b": 3}')) as OpenUIObject;

    expect(value.fields.entries.map((entry) => (entry.key, entry.value)), [
      ('b', const OpenUINumber(3)),
      ('a', const OpenUINumber(2)),
    ]);
  });

  test('fromJson reads lists nested maxJsonDepth levels deep', () {
    final json = jsonDecode('${'[' * OpenUIValue.maxJsonDepth}${']' * OpenUIValue.maxJsonDepth}');

    expect(() => OpenUIValue.fromJson(json), returnsNormally);
  });

  test('fromJson throws for lists nested deeper than maxJsonDepth', () {
    const depth = OpenUIValue.maxJsonDepth + 1;
    final json = jsonDecode('${'[' * depth}${']' * depth}');

    expect(() => OpenUIValue.fromJson(json), throwsA(isA<FormatException>()));
  });

  test('fromJson throws for maps nested deeper than maxJsonDepth', () {
    const depth = OpenUIValue.maxJsonDepth + 1;
    final json = jsonDecode('${'{"a":' * depth}1${'}' * depth}');

    expect(() => OpenUIValue.fromJson(json), throwsA(isA<FormatException>()));
  });

  test('fromJson throws for a value JSON has no kind for', () {
    expect(() => OpenUIValue.fromJson(DateTime(2026)), throwsA(isA<FormatException>()));
  });

  test('fromJson throws for a map whose key is not a string', () {
    expect(() => OpenUIValue.fromJson(const {1: 'a'}), throwsA(isA<FormatException>()));
  });

  test('objects with the same entries in another order are equal', () {
    final ab = OpenUIObject(const {'a': OpenUINumber(1), 'b': OpenUINumber(2)});
    final ba = OpenUIObject(const {'b': OpenUINumber(2), 'a': OpenUINumber(1)});

    expect(ab, ba);
  });

  test('objects with the same entries in another order hash alike', () {
    final ab = OpenUIObject(const {'a': OpenUINumber(1), 'b': OpenUINumber(2)});
    final ba = OpenUIObject(const {'b': OpenUINumber(2), 'a': OpenUINumber(1)});

    expect(ab.hashCode, ba.hashCode);
  });

  test('NaN equals NaN', () {
    expect(OpenUINumber(double.parse('NaN')), OpenUINumber(double.parse('NaN')));
  });

  test('NaN hashes alike', () {
    expect(const OpenUINumber(double.nan).hashCode, OpenUINumber(_otherNaN()).hashCode);
  });

  test('-0 equals 0', () {
    expect(OpenUINumber(double.parse('-0')), OpenUINumber(double.parse('0')));
  });

  test("an array's items can't be changed", () {
    final array = OpenUIArray(const [OpenUINumber(1)]);

    expect(() => array.items.add(const OpenUINumber(2)), throwsUnsupportedError);
  });

  test("an object's fields can't be changed", () {
    final object = OpenUIObject(const {});

    expect(() => object.fields['a'] = const OpenUINumber(1), throwsUnsupportedError);
  });

  test('an array copies the items it is made of', () {
    final items = [const OpenUINumber(1)];
    final array = OpenUIArray(items);

    items.add(const OpenUINumber(2));

    expect(array.items, hasLength(1));
  });

  test('a value prints as JSON', () {
    expect(
      OpenUIObject({
        'a': OpenUIArray(const [OpenUINumber(1)]),
      }).toString(),
      '{"a":[1]}',
    );
  });

  test('a mapped prop that is an argument of its call prints as a reference to the argument', () {
    const rows = AstRef('rows');
    final call = AstCall('Count', const [rows], mappedProps: const {'array': rows});

    expect(
      OpenUIExpression(call).toString(),
      '{"k":"Comp","name":"Count","args":[{"k":"Ref","n":"rows"}],"mappedProps":{"array":{"k":"Arg","i":0}}}',
    );
  });

  test('a mapped prop of its own prints in full', () {
    final call = AstCall('Count', const [AstRef('rows')], mappedProps: const {'array': AstRef('other')});

    expect(
      OpenUIExpression(call).toString(),
      '{"k":"Comp","name":"Count","args":[{"k":"Ref","n":"rows"}],"mappedProps":{"array":{"k":"Ref","n":"other"}}}',
    );
  });
}

// A NaN whose bits differ from `double.nan`'s, so its `hashCode` differs too.
double _otherNaN() => (ByteData(8)..setUint64(0, 0x7ff8000000000001)).getFloat64(0);
