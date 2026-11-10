/// The state of one rendered program: its `$variables` and form fields.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// A flat map of a program's state, as OpenUI's `store.ts` keeps it:
/// `$variables` at the top level, and form fields under their form's name,
/// `{form: {field: {value, componentType[, secret]}}}`; a field outside any
/// form sits at the top level.
final class OpenUIStore {
  /// Creates an empty store that calls [onChange] with each key whose value
  /// changes.
  OpenUIStore({this.onChange});

  /// Called with each key whose value changes.
  void Function(String key)? onChange;

  final _values = <String, OpenUIValue>{};

  // Keys that still hold the default of their declaration.
  final _defaulted = <String>{};

  /// Every key and its value, in the order the keys were added.
  Map<String, OpenUIValue> get snapshot => Map.unmodifiable(_values);

  /// The value of `key`; absent when it has none.
  OpenUIValue? get(String key) => _values[key];

  /// Sets `key` to `value`; `null` removes it. An equal value changes
  /// nothing. A `pristine` value, such as one `@Reset` restored, keeps
  /// following its declaration's default.
  void set(String key, OpenUIValue? value, {bool pristine = false}) {
    pristine ? _defaulted.add(key) : _defaulted.remove(key);
    if (_values[key] == value) return;
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    onChange?.call(key);
  }

  /// Applies `persisted` values, then the declarations' `defaults`.
  ///
  /// A default never replaces a value the user set or one restored, and no
  /// key is ever removed: a declaration can vanish for a moment while the
  /// program streams in. A key still holding its default follows the
  /// declaration as it changes.
  void initialize({required Map<String, OpenUIValue> defaults, Map<String, OpenUIValue> persisted = const {}}) {
    final changed = <String>[];
    void put(String key, OpenUIValue value) {
      if (_values[key] != value) changed.add(key);
      _values[key] = value;
    }

    for (final MapEntry(:key, :value) in persisted.entries) {
      put(key, value);
      _defaulted.remove(key);
    }
    for (final MapEntry(:key, :value) in defaults.entries) {
      if (_values.containsKey(key) && !_defaulted.contains(key)) continue;
      put(key, value);
      _defaulted.add(key);
    }
    changed.forEach(onChange?.call ?? (_) {});
  }

  /// `value` without the form fields marked `secret: true`, at any depth.
  static OpenUIValue withoutSecrets(OpenUIValue value) {
    return switch (value) {
      OpenUIObject(:final fields) => OpenUIObject({
        for (final MapEntry(:key, value: field) in fields.entries)
          if (!isSecret(field)) key: withoutSecrets(field),
      }),
      OpenUIArray(:final items) => OpenUIArray([
        for (final item in items)
          if (!isSecret(item)) withoutSecrets(item),
      ]),
      _ => value,
    };
  }

  /// Whether `value` is a form field marked `secret: true`.
  static bool isSecret(OpenUIValue? value) {
    return value is OpenUIObject && value.fields['secret'] == const OpenUIBool(true);
  }
}
