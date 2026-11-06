/// JavaScript semantics OpenUI Lang is defined by.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// The parts of JavaScript's semantics OpenUI Lang relies on.
///
/// OpenUI Lang is defined by a TypeScript implementation, so converting,
/// comparing and printing values follow JavaScript's rules, which differ from
/// Dart's: JavaScript prints `100` where Dart prints `100.0`, and
/// `Number(" 0x1F ")` is `31` where `double.tryParse` gives `null`.
///
/// Dart strings are UTF-16 like JavaScript's, so lengths and indexes agree
/// without conversion. JavaScript's `undefined` is an absent value: a Dart
/// `null`, as opposed to the language's own `null`, [OpenUINull].
abstract final class JS {
  /// Whether `codeUnit` is JavaScript white space or a line terminator, which
  /// `trim` and `Number` skip.
  static bool isWhitespace(int codeUnit) {
    if (_whitespace.contains(codeUnit)) return true;
    return codeUnit >= _enQuad && codeUnit <= _hairSpace;
  }

  /// `string` without the white space JavaScript's `trim` removes from both
  /// ends.
  static String trim(String string) => trimEnd(trimStart(string));

  /// `string` without the white space JavaScript's `trimStart` removes.
  static String trimStart(String string) {
    var start = 0;
    while (start < string.length && isWhitespace(string.codeUnitAt(start))) {
      start += 1;
    }
    return string.substring(start);
  }

  /// `string` without the white space JavaScript's `trimEnd` removes.
  static String trimEnd(String string) {
    var end = string.length;
    while (end > 0 && isWhitespace(string.codeUnitAt(end - 1))) {
      end -= 1;
    }
    return string.substring(0, end);
  }

  /// The text JavaScript's `String(value)` gives for the number `value`
  /// (ECMA-262 `Number::toString`, radix 10).
  ///
  /// Whole numbers have no decimal point, such as `100`, and numbers from
  /// 10²¹ up or below 10⁻⁶ use an exponent, such as `1e+21` or `1e-7`.
  static String numberToString(double value) {
    if (value.isNaN) return 'NaN';
    if (value == 0) return '0';
    if (value.isInfinite) return value < 0 ? '-Infinity' : 'Infinity';
    if (value < 0) return '-${numberToString(-value)}';

    // `k` digits and the point `n` digits from the first, as the
    // specification's own algorithm names them.
    final (digits, n) = _shortestDigits(value);
    final k = digits.length;
    if (k <= n && n <= _maxPlainExponent) return digits + '0' * (n - k);
    if (0 < n && n <= _maxPlainExponent) return '${digits.substring(0, n)}.${digits.substring(n)}';
    if (_minPlainExponent < n && n <= 0) return '0.${'0' * -n}$digits';
    final exponent = n - 1;
    final sign = exponent < 0 ? '-' : '+';
    final mantissa = k == 1 ? digits : '${digits[0]}.${digits.substring(1)}';
    return '${mantissa}e$sign${exponent.abs()}';
  }

  // The shortest digits `s` and exponent `n` with `value = 0.s × 10ⁿ`, read
  // from Dart's `toString`, which already prints the shortest digits that read
  // back as the same double (only its layout differs from JavaScript's).
  static (String, int) _shortestDigits(double value) {
    final text = value.toString();
    final exponentIndex = text.indexOf('e');
    final mantissa = exponentIndex == -1 ? text : text.substring(0, exponentIndex);
    final exponent = exponentIndex == -1 ? 0 : int.parse(text.substring(exponentIndex + 1));
    final dot = mantissa.indexOf('.');
    final integerPart = dot == -1 ? mantissa : mantissa.substring(0, dot);
    final fractionPart = dot == -1 ? '' : mantissa.substring(dot + 1);
    var digits = integerPart + fractionPart;
    var point = integerPart.length;
    var start = 0;
    while (start < digits.length && digits[start] == '0') {
      start += 1;
    }
    point -= start;
    digits = digits.substring(start);
    var end = digits.length;
    while (end > 0 && digits[end - 1] == '0') {
      end -= 1;
    }
    digits = digits.substring(0, end);
    if (digits.isEmpty) return ('0', 1);
    return (digits, point + exponent);
  }

  /// The number JavaScript's `Number(string)` gives for `string` (ECMA-262
  /// `StringToNumber`): `NaN` when it isn't a number.
  ///
  /// White space around the number is ignored, an empty string is `0`, and
  /// `0x`, `0o` and `0b` prefixes, `Infinity` and exponents are read.
  static double stringToNumber(String string) {
    final trimmed = trim(string);
    if (trimmed.isEmpty) return 0;
    if (trimmed.length > 2 && trimmed[0] == '0') {
      final radix = switch (trimmed[1]) {
        'x' || 'X' => 16,
        'o' || 'O' => 8,
        'b' || 'B' => 2,
        _ => null,
      };
      if (radix != null) {
        // Summed digit by digit in a double, as StreamChatOpenUI and the
        // Android SDK read it; past 2⁵³ that rounds at each digit, where
        // JavaScript rounds once.
        var result = 0.0;
        for (final codeUnit in trimmed.codeUnits.skip(2)) {
          final digit = _digitValue(codeUnit);
          if (digit == null || digit >= radix) return double.nan;
          result = result * radix + digit;
        }
        return result;
      }
    }
    final scanned = _scanDecimalLiteral(trimmed);
    if (scanned == null || scanned.$2 != trimmed.length) return double.nan;
    return scanned.$1;
  }

  /// The number JavaScript's `parseFloat(string)` gives: the longest decimal
  /// number, `Infinity` included, at the start of `string` after leading
  /// white space; `NaN` when there is none.
  ///
  /// So `"12abc"` is `12`, `" .5e1x"` is `5`, and `"0x10"` is `0`.
  static double parseFloat(String string) => _scanDecimalLiteral(trimStart(string))?.$1 ?? double.nan;

  /// The number JavaScript's `Math.round(value)` gives: the nearest integer,
  /// with halves rounded up, so `2.5` is `3` and `-2.5` is `-2`; `NaN` and
  /// the infinities stay as they are, and `-0.4` is `-0`.
  static double round(double value) {
    if (!value.isFinite) return value;
    final floor = value.floorToDouble();
    final rounded = value - floor >= 0.5 ? floor + 1 : floor;
    return rounded == 0 && value.isNegative ? -0.0 : rounded;
  }

  /// The smaller of `a` and `b`, as JavaScript's `Math.min`: `NaN` when either
  /// is, and `-0` below `0`.
  static double min(double a, double b) {
    if (a.isNaN || b.isNaN) return double.nan;
    if (a == b) return a.isNegative ? a : b;
    return a < b ? a : b;
  }

  /// The larger of `a` and `b`, as JavaScript's `Math.max`: `NaN` when either
  /// is, and `0` above `-0`.
  static double max(double a, double b) {
    if (a.isNaN || b.isNaN) return double.nan;
    if (a == b) return a.isNegative ? b : a;
    return a > b ? a : b;
  }

  /// JavaScript's `a % b`: the remainder of truncating division, with the
  /// sign of `a`, so `-7 % 3` is `-1`.
  static double remainder(double a, double b) => a.remainder(b);

  /// JavaScript's `String(value ?? "")`: the empty string for a nullish
  /// value, otherwise [stringOf].
  static String toStringOrEmpty(OpenUIValue? value) => isNullish(value) ? '' : stringOf(value);

  // The longest ECMAScript `StrDecimalLiteral` at the start of `text`,
  // `Infinity` included, as its value and length; `null` when there is none.
  static (double, int)? _scanDecimalLiteral(String text) {
    var i = 0;
    var negative = false;
    if (i < text.length && (text[i] == '+' || text[i] == '-')) {
      negative = text[i] == '-';
      i += 1;
    }
    if (text.startsWith('Infinity', i)) {
      return (negative ? double.negativeInfinity : double.infinity, i + 'Infinity'.length);
    }
    final digitsStart = i;
    var integerDigits = 0;
    while (i < text.length && _isDigit(text.codeUnitAt(i))) {
      i += 1;
      integerDigits += 1;
    }
    var fractionDigits = 0;
    if (i < text.length && text[i] == '.') {
      var j = i + 1;
      while (j < text.length && _isDigit(text.codeUnitAt(j))) {
        j += 1;
        fractionDigits += 1;
      }
      if (integerDigits > 0 || fractionDigits > 0) i = j;
    }
    if (integerDigits == 0 && fractionDigits == 0) return null;
    var end = i;
    if (i < text.length && (text[i] == 'e' || text[i] == 'E')) {
      var j = i + 1;
      if (j < text.length && (text[j] == '+' || text[j] == '-')) j += 1;
      final exponentStart = j;
      while (j < text.length && _isDigit(text.codeUnitAt(j))) {
        j += 1;
      }
      if (j > exponentStart) end = j;
    }
    final literal = text.substring(digitsStart, end);
    // Dart's parser wants a digit on both sides of the point.
    final magnitude = double.parse('0$literal'.replaceFirst(RegExp(r'\.(?=$|[eE])'), ''));
    return (negative ? -magnitude : magnitude, end);
  }

  static bool _isDigit(int codeUnit) => codeUnit >= _zero && codeUnit <= _nine;

  static int? _digitValue(int codeUnit) {
    if (_isDigit(codeUnit)) return codeUnit - _zero;
    if (codeUnit >= _lowerA && codeUnit <= _lowerZ) return codeUnit - _lowerA + 10;
    if (codeUnit >= _upperA && codeUnit <= _upperZ) return codeUnit - _upperA + 10;
    return null;
  }

  /// The number the language's built-ins coerce `value` to: a number as it is,
  /// a string as `Number` reads it but `0` instead of `NaN`, `true` as `1`, and
  /// anything else as `0`.
  static double toNumber(OpenUIValue? value) {
    return switch (value) {
      OpenUINumber(:final value) => value,
      OpenUIString(:final value) => _zeroForNaN(stringToNumber(value)),
      OpenUIBool(:final value) => value ? 1 : 0,
      null || OpenUINull() || OpenUIArray() || OpenUIObject() || OpenUIElement() || OpenUIExpression() => 0,
    };
  }

  static double _zeroForNaN(double number) => number.isNaN ? 0 : number;

  /// Whether `a` and `b` are the same number to JavaScript's `SameValueZero`:
  /// `NaN` is the same as `NaN`, and `-0` the same as `0`.
  static bool sameValueZero(double a, double b) => a == b || (a.isNaN && b.isNaN);

  /// The text JavaScript's `String(value)` gives for `value`; `undefined` for
  /// an absent value.
  ///
  /// An array's items are joined with `,`, with `null` items written as
  /// nothing, and an object, element or expression is `[object Object]`.
  static String stringOf(OpenUIValue? value) {
    return switch (value) {
      null => 'undefined',
      OpenUINull() => 'null',
      OpenUIBool(:final value) => value ? 'true' : 'false',
      OpenUINumber(:final value) => numberToString(value),
      OpenUIString(:final value) => value,
      OpenUIArray(:final items) => [
        for (final item in items)
          if (item is OpenUINull) '' else stringOf(item),
      ].join(','),
      OpenUIObject() || OpenUIElement() || OpenUIExpression() => '[object Object]',
    };
  }

  /// Whether JavaScript reads `value` as true in a condition.
  ///
  /// An absent value, `null`, `false`, `0`, `NaN` and the empty string are
  /// false; anything else, an empty array or object included, is true.
  static bool isTruthy(OpenUIValue? value) {
    return switch (value) {
      null || OpenUINull() => false,
      OpenUIBool(:final value) => value,
      OpenUINumber(:final value) => value != 0 && !value.isNaN,
      OpenUIString(:final value) => value.isNotEmpty,
      OpenUIArray() || OpenUIObject() || OpenUIElement() || OpenUIExpression() => true,
    };
  }

  /// What JavaScript's `typeof value` gives for `value`.
  static String typeOf(OpenUIValue? value) {
    return switch (value) {
      null => 'undefined',
      OpenUIString() => 'string',
      OpenUINumber() => 'number',
      OpenUIBool() => 'boolean',
      OpenUINull() || OpenUIArray() || OpenUIObject() || OpenUIElement() || OpenUIExpression() => 'object',
    };
  }

  /// [typeOf] of `value`, except `array` for an array.
  static String jsType(OpenUIValue? value) => value is OpenUIArray ? 'array' : typeOf(value);

  /// Whether JavaScript's loose `a == b` holds.
  ///
  /// `null` equals only `null` and an absent value; a number and a string
  /// compare as numbers; a boolean compares as `1` or `0`; an array or object
  /// compares with a number or string as its text. Two arrays or objects are
  /// equal when their contents are, where JavaScript compares them by
  /// identity, which values here don't have.
  static bool looseEquals(OpenUIValue? a, OpenUIValue? b) {
    final aNullish = isNullish(a);
    final bNullish = isNullish(b);
    if (aNullish || bNullish) return aNullish && bNullish;
    return switch ((a!, b!)) {
      (OpenUINumber(value: final x), OpenUINumber(value: final y)) => x == y,
      (OpenUIString(value: final x), OpenUIString(value: final y)) => x == y,
      (OpenUIBool(value: final x), OpenUIBool(value: final y)) => x == y,
      (OpenUINumber(value: final x), OpenUIString(value: final y)) => x == stringToNumber(y),
      (OpenUIString(value: final x), OpenUINumber(value: final y)) => stringToNumber(x) == y,
      (OpenUIBool(value: final x), final other) => looseEquals(OpenUINumber(x ? 1 : 0), other),
      (final other, OpenUIBool(value: final y)) => looseEquals(other, OpenUINumber(y ? 1 : 0)),
      (OpenUINumber() || OpenUIString(), final other) => looseEquals(a, OpenUIString(stringOf(other))),
      (final other, OpenUINumber() || OpenUIString()) => looseEquals(OpenUIString(stringOf(other)), b),
      _ => a == b,
    };
  }

  /// Whether `value` is `null` or absent.
  static bool isNullish(OpenUIValue? value) => value == null || value is OpenUINull;

  /// What JavaScript's `value[key]` reads from `value`, own properties only;
  /// absent (Dart `null`) when there is nothing.
  ///
  /// An array and a string have a `length` and items at their indexes, a
  /// string's item being one UTF-16 code unit. An element has the fields of
  /// its JSON form, such as `typeName` and `props`.
  static OpenUIValue? property(OpenUIValue? value, String key) {
    switch (value) {
      case OpenUIObject(:final fields):
        return fields[key];
      case OpenUIArray(:final items):
        if (key == 'length') return OpenUINumber(items.length.toDouble());
        final index = arrayIndex(key);
        if (index == null || index >= items.length) return null;
        return items[index];
      case OpenUIString(value: final string):
        if (key == 'length') return OpenUINumber(string.length.toDouble());
        final index = arrayIndex(key);
        if (index == null || index >= string.length) return null;
        return OpenUIString(string[index]);
      case OpenUIElement(:final node):
        return switch (key) {
          'type' => const OpenUIString('element'),
          'typeName' => OpenUIString(node.typeName),
          'props' => OpenUIObject(node.props),
          'partial' => OpenUIBool(node.partial),
          'hasDynamicProps' => OpenUIBool(node.hasDynamicProps),
          'statementId' => switch (node.statementId) {
            final String id => OpenUIString(id),
            null => null,
          },
          _ => null,
        };
      case null || OpenUINull() || OpenUIBool() || OpenUINumber() || OpenUIExpression():
        return null;
    }
  }

  /// The index `key` names when it is a non-negative integer written without
  /// leading zeros, such as `0` or `12` but not `01` or `-1`; otherwise `null`.
  static int? arrayIndex(String key) {
    if (key.isEmpty || !key.codeUnits.every(_isDigit)) return null;
    if (key.length > 1 && key.startsWith('0')) return null;
    return int.tryParse(key);
  }

  /// The text JavaScript's `JSON.stringify(value)` gives for `value`; `null`
  /// for an absent value.
  ///
  /// Numbers print as [numberToString] does, a number that isn't finite prints
  /// `null`, and an element or expression prints as its JSON form. Object keys
  /// keep the order they were added in, where JavaScript lists keys that are
  /// array indexes first. A call's argument that also fills one of its named
  /// props is written once, so the text grows with the size of the value, not
  /// with the depth of its calls.
  static String? jsonStringify(OpenUIValue? value) {
    if (value == null) return null;
    final output = StringBuffer();
    writeJson(plainJson(value), output);
    return output.toString();
  }

  /// Writes `json`, a plain JSON value (`null`, [bool], [num], [String], or a
  /// [List] or [Map] of them), to `output` as `JSON.stringify` writes it.
  ///
  /// Throws an [ArgumentError] when `json` holds anything else.
  static void writeJson(Object? json, StringBuffer output) {
    switch (json) {
      case null:
        output.write('null');
      case final bool value:
        output.write(value ? 'true' : 'false');
      case final num value:
        final number = value.toDouble();
        output.write(number.isFinite ? numberToString(number) : 'null');
      case final String value:
        writeJsonString(value, output);
      case final List<Object?> items:
        output.write('[');
        for (final (index, item) in items.indexed) {
          if (index > 0) output.write(',');
          writeJson(item, output);
        }
        output.write(']');
      case final Map<String, Object?> fields:
        output.write('{');
        var first = true;
        for (final MapEntry(:key, :value) in fields.entries) {
          if (!first) output.write(',');
          first = false;
          writeJsonString(key, output);
          output.write(':');
          writeJson(value, output);
        }
        output.write('}');
      default:
        throw ArgumentError.value(json, 'json', 'Not a plain JSON value');
    }
  }

  /// Writes `string` to `output` quoted as `JSON.stringify` quotes it
  /// (ECMA-262 `QuoteJSONString`), lone surrogates escaped.
  static void writeJsonString(String string, StringBuffer output) {
    output.write('"');
    for (var i = 0; i < string.length; i += 1) {
      final unit = string.codeUnitAt(i);
      if (_escapes[unit] case final escape?) {
        output.write(escape);
      } else if (unit < _firstPrintable || _isLoneSurrogate(string, i)) {
        output.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
      } else {
        output.writeCharCode(unit);
      }
    }
    output.write('"');
  }

  static bool _isLoneSurrogate(String string, int index) {
    final unit = string.codeUnitAt(index);
    if (unit >= _highSurrogateStart && unit <= _highSurrogateEnd) {
      final next = index + 1 < string.length ? string.codeUnitAt(index + 1) : 0;
      return next < _lowSurrogateStart || next > _lowSurrogateEnd;
    }
    if (unit >= _lowSurrogateStart && unit <= _lowSurrogateEnd) {
      final previous = index > 0 ? string.codeUnitAt(index - 1) : 0;
      return previous < _highSurrogateStart || previous > _highSurrogateEnd;
    }
    return false;
  }

  // ECMA-262 `Number::toString` writes a number without an exponent while its
  // integer part has up to 21 digits, or up to 5 zeros follow its decimal
  // point before the first digit (`0.000001`).
  static const _maxPlainExponent = 21;
  static const _minPlainExponent = -6;

  static const _zero = 0x30;
  static const _nine = 0x39;
  static const _lowerA = 0x61;
  static const _lowerZ = 0x7a;
  static const _upperA = 0x41;
  static const _upperZ = 0x5a;
  static const _highSurrogateStart = 0xd800;
  static const _highSurrogateEnd = 0xdbff;
  static const _lowSurrogateStart = 0xdc00;
  static const _lowSurrogateEnd = 0xdfff;

  // ECMA-262 `WhiteSpace` and `LineTerminator`: tab, line feed, vertical tab,
  // form feed, carriage return, space, no-break space, Ogham space mark, line
  // and paragraph separators, narrow no-break space, medium mathematical
  // space, ideographic space and the byte order mark; the spaces from en quad
  // to hair space follow as a range.
  static const _whitespace = {
    0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x20, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff, //
  };
  static const _enQuad = 0x2000;
  static const _hairSpace = 0x200a;

  static const _escapes = {
    0x22: r'\"',
    0x5c: r'\\',
    0x08: r'\b',
    0x0c: r'\f',
    0x0a: r'\n',
    0x0d: r'\r',
    0x09: r'\t',
  };

  // Code units below this are control characters, which JSON escapes.
  static const _firstPrintable = 0x20;
}
