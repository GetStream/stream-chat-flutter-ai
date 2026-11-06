/// Checking form fields against the validation rules a program gives them.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// One validation rule, such as `required` or `minLength` with `3`.
@immutable
final class ValidationRule {
  /// Creates the rule [type] with its [argument].
  const ValidationRule(this.type, [this.argument]);

  /// The rule's name.
  final String type;

  /// What the rule compares with, such as `3` for `minLength`.
  final OpenUIValue? argument;

  @override
  bool operator ==(Object other) => other is ValidationRule && other.type == type && other.argument == argument;

  @override
  int get hashCode => Object.hash(type, argument);
}

/// The validation rules of OpenUI Lang 1.0 (specification §5.4), as
/// OpenUI's `utils/validation.ts` checks them: `required`, `email`, `url`,
/// `numeric`, `min`, `max`, `minLength`, `maxLength` and `pattern`.
///
/// Every rule but `required` lets an empty value pass — `null`, `""`, an
/// empty list, or an object with no keys — and the first rule that fails
/// gives the field its error.
abstract final class FormValidation {
  static const _numericRules = {'min', 'max', 'minLength', 'maxLength'};

  /// The rules `rules` gives: an object such as `{required: true,
  /// minLength: 3}`, whose `false` and `null` entries are left out, or a list
  /// of strings such as `["required", "minLength:3"]`.
  static List<ValidationRule> parse(OpenUIValue? rules) {
    return switch (rules) {
      OpenUIArray(:final items) => [
        for (final item in items)
          if (item case OpenUIString(:final value)) _parseRule(value),
      ],
      OpenUIObject(:final fields) => [
        for (final MapEntry(:key, :value) in fields.entries)
          if (value == const OpenUIBool(true))
            ValidationRule(key)
          else if (value is! OpenUINull && value != const OpenUIBool(false))
            ValidationRule(key, value),
      ],
      _ => const [],
    };
  }

  static ValidationRule _parseRule(String rule) {
    final colon = rule.indexOf(':');
    if (colon == -1) return ValidationRule(rule);
    final type = rule.substring(0, colon);
    final raw = rule.substring(colon + 1);
    final number = JS.stringToNumber(raw);
    return ValidationRule(
      type,
      _numericRules.contains(type) && !number.isNaN ? OpenUINumber(number) : OpenUIString(raw),
    );
  }

  /// The error of the first of `rules` that `value` fails, or `null` when it
  /// passes them all. A rule of another name is skipped.
  ///
  /// `pattern` is skipped too, for now: the regular expressions the model
  /// writes need a matcher that can't freeze the app, which isn't here yet.
  static String? validate(OpenUIValue? value, List<ValidationRule> rules) {
    for (final rule in rules) {
      if (_check(rule.type, value, rule.argument) case final error?) return error;
    }
    return null;
  }

  /// Whether `value` is empty: `null`, `""`, an empty list, an object with no
  /// keys, or a form field `{value, …}` whose value is.
  static bool isEmpty(OpenUIValue? value) {
    return switch (value) {
      null || OpenUINull() => true,
      OpenUIString(:final value) => value.isEmpty,
      OpenUIArray(:final items) => items.isEmpty,
      OpenUIObject(:final fields) => fields.containsKey('value') ? isEmpty(fields['value']) : fields.isEmpty,
      _ => false,
    };
  }

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? _check(String type, OpenUIValue? value, OpenUIValue? argument) {
    if (type == 'required') return _required(value);
    if (isEmpty(value)) return null;
    final text = value is OpenUIString ? value.value : null;
    switch (type) {
      case 'email':
        return text != null && _email.hasMatch(text) ? null : 'Please enter a valid email';
      case 'url':
        final uri = text == null ? null : Uri.tryParse(text);
        return uri != null && uri.hasScheme && uri.host.isNotEmpty ? null : 'Please enter a valid URL';
      case 'numeric':
        final valid = switch (value) {
          OpenUINumber(:final value) => !value.isNaN,
          OpenUIString(:final value) => JS.trim(value).isNotEmpty && !JS.parseFloat(value).isNaN,
          _ => false,
        };
        return valid ? null : 'Must be a number';
      case 'min':
        final min = JS.toNumber(argument);
        final n = _number(value);
        return n.isNaN || n >= min ? null : 'Must be at least ${JS.numberToString(min)}';
      case 'max':
        final max = JS.toNumber(argument);
        final n = _number(value);
        return n.isNaN || n <= max ? null : 'Must be no more than ${JS.numberToString(max)}';
      case 'minLength':
        final min = JS.toNumber(argument);
        return text == null || text.length >= min ? null : 'Must be at least ${JS.numberToString(min)} characters';
      case 'maxLength':
        final max = JS.toNumber(argument);
        return text == null || text.length <= max ? null : 'Must be no more than ${JS.numberToString(max)} characters';
      default:
        return null;
    }
  }

  static String? _required(OpenUIValue? value) {
    if (isEmpty(value)) return 'This field is required';
    // A group of checkboxes, `{option: bool}`, needs one ticked.
    if (value case OpenUIObject(:final fields) when !fields.containsKey('value') && fields.isNotEmpty) {
      final options = fields.values;
      if (options.every((option) => option is OpenUIBool) && !options.contains(const OpenUIBool(true))) {
        return 'At least one option is required';
      }
    }
    return null;
  }

  static double _number(OpenUIValue? value) {
    return switch (value) {
      OpenUINumber(:final value) => value,
      _ => JS.parseFloat(JS.stringOf(value)),
    };
  }
}
