part of 'a2ui_adapter.dart';

/// How much a failing check of a component counts.
///
/// Internal to the package.
@internal
enum A2UICheckSeverity {
  /// The check blocks the component, such as a button that stays disabled.
  error,

  /// The check warns without blocking.
  warning,

  /// The check tells the person something without blocking.
  info,
}

/// A check of a component that fails: the message to show, and how much it
/// counts.
///
/// Obtained from [A2UINode.failingChecks]. Two failures are `==` when their
/// fields are.
///
/// Internal to the package.
@internal
@immutable
final class A2UICheckFailure {
  /// Creates an [A2UICheckFailure].
  const A2UICheckFailure({this.message, this.code, this.severity = A2UICheckSeverity.error});

  /// The message, from the agent's check or from the result of its
  /// condition, or `null` when neither has one, such as an `and` of other
  /// checks.
  final String? message;

  /// The code the result of the check's condition gave, or `null`.
  final String? code;

  /// How much the failure counts.
  final A2UICheckSeverity severity;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is A2UICheckFailure && other.message == message && other.code == code && other.severity == severity;
  }

  @override
  int get hashCode => Object.hash(message, code, severity);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'A2UICheckFailure')}(message: $message, code: $code, severity: $severity)';
  }
}

// The message of a check whose condition couldn't be evaluated, such as one
// calling a function that failed.
const _uncheckableMessage = 'This value could not be checked.';

// The checks in [rules] that fail, each condition read with [context]; a
// condition whose evaluation reports a problem fails, which [failures] counts.
List<A2UICheckFailure> _failingChecksOf(
  Object? rules,
  core.DataContext context,
  int Function() failures,
) {
  if (rules is! List<Object?>) return const [];
  return [
    for (final rule in rules)
      if (rule is Map<String, Object?>)
        if (_failureOf(rule, context, failures) case final failure?) failure,
  ];
}

A2UICheckFailure? _failureOf(Map<String, Object?> rule, core.DataContext context, int Function() failures) {
  final condition = rule.containsKey('condition') ? rule['condition'] : rule;
  final ownMessage = _nonEmptyString(rule['message']);
  final before = failures();
  final value = _plain(context.resolveDynamicValue(condition));
  if (failures() != before) return A2UICheckFailure(message: ownMessage ?? _uncheckableMessage);
  if (value case {'valid': final Object? valid}) {
    if (_checkPasses(valid) ?? true) return null;
    final resultMessage = _nonEmptyString(value['message']);
    final code = value['code'];
    return A2UICheckFailure(
      // The agent's own message wins over the one of the function it calls;
      // a result read from the data model keeps its own.
      message: context.isFunctionCall(condition) ? ownMessage ?? resultMessage : resultMessage ?? ownMessage,
      code: code is String ? code : null,
      severity: switch (value['severity']) {
        'warning' => A2UICheckSeverity.warning,
        'info' => A2UICheckSeverity.info,
        _ => A2UICheckSeverity.error,
      },
    );
  }
  // Nothing to read yet, such as data still on its way, passes, so a form
  // isn't blocked while it streams in, as does a value that isn't a
  // boolean.
  if (_checkPasses(value) ?? true) return null;
  return A2UICheckFailure(message: ownMessage);
}

// [value] as whether a check passes: a boolean, a number other than 0, or the
// string `true` or `false` in any capitalization; `null` for anything else.
bool? _checkPasses(Object? value) {
  return switch (value) {
    final bool value => value,
    final num value => value != 0,
    final String value => switch (value.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => null,
    },
    _ => null,
  };
}

String? _nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;
