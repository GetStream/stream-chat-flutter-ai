import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Where [reportPartIssue] sends its messages in debug builds. `null` means
/// [debugPrint]. Tests set it to capture the messages.
///
/// Not exported.
@visibleForTesting
void Function(String message)? debugPartIssueReporter;

/// Reports something odd about an agent step's payload — a field that is
/// present but unusable, a call that can never be answered — so a backend
/// author notices it during development.
///
/// Debug builds only: the whole call sits inside an `assert`, so release
/// builds stay silent and never build the message.
void reportPartIssue(String Function() message) {
  assert(() {
    (debugPartIssueReporter ?? debugPrint)('stream_chat_flutter_ai: ${message()}');
    return true;
  }(), 'unreachable');
}

/// Returns [value], after [reportPartIssue] has said it is not one this
/// package knows. An unknown value is kept, since a newer agent may send it,
/// but a typo (`"complete"`) would otherwise stall a step with no sign why.
T reportUnknown<T>(T value, bool Function(T value) isKnown, String context, String key) {
  if (!isKnown(value)) reportPartIssue(() => '$context: `$key` "$value" is not one this package knows.');
  return value;
}

/// Lenient reads from a step's decoded JSON payload: a field that is missing
/// or `null` (or an empty string) reads as `null`, and one of the wrong type
/// reads as `null` too, after [reportPartIssue] has said so. Nothing here
/// throws.
///
/// Not exported — the parts' `fromJson` factories are the public surface.
class PartFields {
  /// Reads [json], naming the step as [context] (such as
  /// `ai_tool_call "call_1"`) in any report.
  const PartFields(this.json, this.context);

  /// The payload.
  final Map<String, Object?> json;

  /// The step, as reports name it.
  final String context;

  void _reject(String key, Object value, String expected) =>
      reportPartIssue(() => '$context: ignored `$key`, expected $expected but got ${value.runtimeType} ($value).');

  /// The non-empty string at [key].
  String? string(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    _reject(key, value, 'a string');
    return null;
  }

  /// The non-negative whole number at [key]. A double reads as the nearest
  /// int (timers in Python and JavaScript send `812.37`), and an integer string
  /// (`"1200"`) as an int too.
  int? count(String key) {
    final value = json[key];
    if (value == null) return null;
    final parsed = switch (value) {
      final int value => value,
      final double value when value.isFinite => value.round(),
      final String value => int.tryParse(value),
      _ => null,
    };
    if (parsed == null || parsed < 0) {
      _reject(key, value, 'a non-negative integer');
      return null;
    }
    return parsed;
  }

  /// The JSON object at [key], or — for a backend that sends it JSON-encoded —
  /// the object a string at [key] decodes to, deeply unmodifiable either way.
  Map<String, Object?>? object(String key) {
    final value = json[key];
    if (value == null) return null;
    Object? decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        _reject(key, value, 'a JSON object');
        return null;
      }
    }
    if (deepUnmodifiable(decoded) case final Map<String, Object?> object) return object;
    _reject(key, value, 'a JSON object');
    return null;
  }
}

/// A deeply unmodifiable copy of a decoded JSON value: maps (with their
/// non-string keys dropped) and lists are copied all the way down, and
/// everything else is returned as is.
Object? deepUnmodifiable(Object? value) => switch (value) {
  final Map<Object?, Object?> map => Map<String, Object?>.unmodifiable({
    for (final MapEntry(:key, :value) in map.entries)
      if (key is String) key: deepUnmodifiable(value),
  }),
  final List<Object?> list => List<Object?>.unmodifiable(list.map(deepUnmodifiable)),
  _ => value,
};
