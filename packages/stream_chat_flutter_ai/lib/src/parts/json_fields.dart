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

  /// The RFC 3339 time at [key], such as `2026-10-26T12:00:00.123Z`, in UTC.
  /// It needs a `Z` or a `±hh:mm` offset (hours up to 23, minutes up to 59),
  /// and takes any number of fractional
  /// digits, keeping microseconds. Other text reads as `null`: Dart's own
  /// parser would take a time without an offset as local, and roll an
  /// impossible date such as 30 February over into March.
  DateTime? date(String key) {
    final value = string(key);
    if (value == null) return null;
    final parsed = _parseRfc3339(value);
    if (parsed == null) _reject(key, value, 'an RFC 3339 time');
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

final _rfc3339 = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(?:([Zz])|([+-])(\d{2}):(\d{2}))$',
);

DateTime? _parseRfc3339(String text) {
  final match = _rfc3339.firstMatch(text);
  if (match == null) return null;
  int part(int group) => int.parse(match.group(group)!);
  final (year, month, day, hour, minute, second) = (part(1), part(2), part(3), part(4), part(5), part(6));
  // RFC 3339 allows a leap second (60), which DateTime can't hold.
  if (month < 1 || month > 12 || day < 1 || hour > 23 || minute > 59 || second > 59) return null;
  final micros = int.parse((match.group(7) ?? '').padRight(6, '0').substring(0, 6));
  final utc = DateTime.utc(year, month, day, hour, minute, second, 0, micros);
  // DateTime.utc rolls 31 February over into March; RFC 3339 has no such day.
  if (utc.day != day) return null;
  if (match.group(8) != null) return utc;
  final (offsetHours, offsetMinutes) = (part(10), part(11));
  if (offsetHours > 23 || offsetMinutes > 59) return null;
  final offset = Duration(hours: offsetHours, minutes: offsetMinutes);
  final instant = match.group(9) == '-' ? utc.add(offset) : utc.subtract(offset);
  // An offset can push the first or last day of year 0000 or 9999 out of
  // the four-digit years RFC 3339 writes.
  return instant.year < 0 || instant.year > 9999 ? null : instant;
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
