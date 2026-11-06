import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

void main() {
  test('parseFloat reads the number at the start, after white space', () {
    expect(JS.parseFloat('12abc'), 12);
    expect(JS.parseFloat('  .5e1x'), 5);
    expect(JS.parseFloat('-Infinityx'), double.negativeInfinity);
    expect(JS.parseFloat('0x10'), 0);
    expect(JS.parseFloat('abc'), isNaN);
    expect(JS.parseFloat(''), isNaN);
  });

  test('round rounds halves up and keeps NaN, infinities and negative zero', () {
    expect(JS.round(2.5), 3);
    expect(JS.round(-2.5), -2);
    expect(JS.round(-2.6), -3);
    expect(JS.round(0.49999999999999994), 0);
    expect(JS.round(-0.4).isNegative, isTrue);
    expect(JS.round(double.nan), isNaN);
    expect(JS.round(double.infinity), double.infinity);
  });

  test('min and max propagate NaN and order the zeros', () {
    expect(JS.min(1, double.nan), isNaN);
    expect(JS.min(double.nan, 1), isNaN);
    expect(JS.max(1, double.nan), isNaN);
    expect(JS.max(double.nan, 1), isNaN);
    expect(JS.min(0, -0).isNegative, isTrue);
    expect(JS.min(-0, 0).isNegative, isTrue);
    expect(JS.max(-0, 0).isNegative, isFalse);
    expect(JS.max(0, -0).isNegative, isFalse);
    expect(JS.min(2, 1), 1);
    expect(JS.max(2, 1), 2);
  });

  test('remainder takes the sign of the dividend', () {
    expect(JS.remainder(-7, 3), -1);
    expect(JS.remainder(7, -3), 1);
    expect(JS.remainder(5.5, 2), 1.5);
  });

  test('toStringOrEmpty writes nullish values as nothing', () {
    expect(JS.toStringOrEmpty(null), '');
    expect(JS.toStringOrEmpty(OpenUINull.instance), '');
    expect(JS.toStringOrEmpty(const OpenUINumber(1)), '1');
  });
}
