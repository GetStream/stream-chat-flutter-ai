import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';

/// [value] as JSON, as `jsonDecode` gives it, with `null` for a component or
/// an expression.
///
/// Internal to the package.
@internal
Object? openUIJson(OpenUIValue? value) {
  return switch (value) {
    OpenUIString(:final value) => value,
    OpenUINumber(:final value) => value,
    OpenUIBool(:final value) => value,
    OpenUIArray(:final items) => [for (final item in items) openUIJson(item)],
    OpenUIObject(:final fields) => {for (final MapEntry(:key, :value) in fields.entries) key: openUIJson(value)},
    OpenUINull() || OpenUIElement() || OpenUIExpression() || null => null,
  };
}

/// [value] as JSON to send out of the reply, as
/// `JSON.parse(JSON.stringify(value))` gives it: a component or an expression
/// in its JSON shape, a whole number of at most 2^53 - 1 either way as an
/// [int], and a number that isn't finite as `null`.
///
/// Internal to the package.
@internal
Object? openUIPlainJson(OpenUIValue? value) => value == null ? null : _plainNumbers(plainJson(value));

/// [values] as a JSON object to send out of the reply, each value as
/// [openUIPlainJson] gives it.
///
/// Internal to the package.
@internal
Map<String, Object?> openUIPlainJsonObject(Map<String, OpenUIValue> values) => {
  for (final MapEntry(:key, :value) in values.entries) key: openUIPlainJson(value),
};

// [json] with its whole numbers as ints, as a JSON parser gives them.
Object? _plainNumbers(Object? json) {
  return switch (json) {
    final double number => _plainNumber(number),
    final List<Object?> items => [for (final item in items) _plainNumbers(item)],
    final Map<String, Object?> fields => {
      for (final MapEntry(:key, :value) in fields.entries) key: _plainNumbers(value),
    },
    _ => json,
  };
}

// [plainJson] gives finite numbers only.
Object _plainNumber(double number) {
  final isWhole = number == number.truncateToDouble() && number.abs() <= _maxSafeInteger;
  return isWhole ? number.toInt() : number;
}

// The largest whole number a JavaScript number holds exactly.
const _maxSafeInteger = 9007199254740991.0;
