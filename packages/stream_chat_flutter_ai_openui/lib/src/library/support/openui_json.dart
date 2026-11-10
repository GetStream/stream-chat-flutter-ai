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

/// [values] as a JSON object, each value as [openUIJson] gives it.
///
/// Internal to the package.
@internal
Map<String, Object?> openUIJsonObject(Map<String, OpenUIValue> values) => {
  for (final MapEntry(:key, :value) in values.entries) key: openUIJson(value),
};
