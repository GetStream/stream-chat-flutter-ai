import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// The values an agent filled in for an [AIUIComponent]'s parameters, with
/// typed getters for reading them.
///
/// Each getter takes a parameter's name from the component's definition, such
/// as `start_date`, and throws a [FormatException] when the value is missing or
/// has the wrong type. The component then shows nothing, which is what should
/// happen while the agent is still writing the values. Values the component
/// doesn't read are ignored.
///
/// ```dart
/// class TripArguments {
///   TripArguments.read(AIUIArguments arguments)
///     : title = arguments.string('title'),
///       startDate = arguments.date('start_date'),
///       nights = arguments.optional('nights', arguments.integer),
///       tags = arguments.optional('tags', arguments.strings) ?? const [],
///       places = [for (final place in arguments.objects('places')) place.string('name')];
///
///   final String title;
///   final DateTime startDate;
///   final int? nights;
///   final List<String> tags;
///   final List<String> places;
/// }
/// ```
///
/// Two [AIUIArguments] are `==` when their [json] is, compared deeply.
@immutable
final class AIUIArguments {
  /// Creates an [AIUIArguments] from the [json] the agent wrote.
  ///
  /// It keeps a copy of [json], so later changes to [json] don't affect it.
  AIUIArguments(Map<String, Object?> json) : json = deepUnmodifiable(json)! as Map<String, Object?>;

  const AIUIArguments._(this.json);

  /// The values exactly as the agent wrote them.
  final Map<String, Object?> json;

  /// The string at [key].
  String string(String key) => _string(_value(key), _where(key));

  /// The number at [key], with or without a fraction.
  double number(String key) => _number(_value(key), _where(key));

  /// The whole number at [key].
  ///
  /// `3.0` also reads as `3`. A number with a fraction, such as `2.5`, throws,
  /// and so does one of 2^63 or more in size.
  int integer(String key) => _integer(_value(key), _where(key));

  /// The `true` or `false` at [key].
  bool boolean(String key) => _boolean(_value(key), _where(key));

  /// The date at [key], written either as a date and time, such as
  /// `2026-11-14T09:30:00Z`, or as a day, such as `2026-11-14`.
  ///
  /// A date and time follows RFC 3339 and is returned in UTC. These variations
  /// are also accepted:
  /// - no time zone offset, which is read as UTC
  /// - an offset without a colon (`+0200`) or with hours only (`+02`)
  /// - no seconds, when the time ends in `Z` (`09:30Z`)
  /// - one-digit fields (`2026-1-4T9:30:00Z`)
  ///
  /// Fractions of a second need an offset: `2026-11-14T09:30:00.5` throws.
  ///
  /// A day must be written exactly as `yyyy-MM-dd`, and is returned as
  /// midnight at the start of that day in the device's time zone.
  ///
  /// Dates that aren't on the calendar, such as `2026-02-30`, throw instead of
  /// rolling over to the next month, and so do years before 1.
  DateTime date(String key) => _date(_value(key), _where(key));

  /// The link at [key], such as an image's address.
  ///
  /// An empty string throws.
  Uri url(String key) => _url(_value(key), _where(key));

  /// The object at [key], whose values are read with the same getters.
  AIUIArguments object(String key) => _object(_value(key), _where(key));

  /// The array of strings at [key].
  List<String> strings(String key) => _list(key, _string);

  /// The array of numbers at [key], each read like [number].
  List<double> numbers(String key) => _list(key, _number);

  /// The array of whole numbers at [key], each read like [integer].
  List<int> integers(String key) => _list(key, _integer);

  /// The array of `true` or `false` at [key].
  List<bool> booleans(String key) => _list(key, _boolean);

  /// The array of dates at [key], each read like [date].
  List<DateTime> dates(String key) => _list(key, _date);

  /// The array of links at [key], each read like [url].
  List<Uri> urls(String key) => _list(key, _url);

  /// The array of objects at [key], whose values are read with the same
  /// getters.
  List<AIUIArguments> objects(String key) => _list(key, _object);

  /// Reads an optional parameter: returns `null` when the agent left [key] out
  /// or wrote `null`, and otherwise reads it with [read].
  ///
  /// It still throws when the value has the wrong type.
  ///
  /// ```dart
  /// final rating = arguments.optional('rating', arguments.number);
  /// ```
  T? optional<T extends Object>(String key, T Function(String key) read) => json[key] == null ? null : read(key);

  Object _value(String key) => json[key] ?? (throw FormatException('"$key" is missing'));

  // Each item of the array at [key], read by [read].
  List<T> _list<T>(String key, _Read<T> read) => switch (_value(key)) {
    final List<Object?> items => List.unmodifiable([
      for (final (index, item) in items.indexed) read(item, '${_where(key)}[$index]'),
    ]),
    _ => throw FormatException('${_where(key)} is not an array'),
  };

  static String _where(String key) => '"$key"';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIUIArguments && const DeepCollectionEquality().equals(other.json, json);

  @override
  int get hashCode => const DeepCollectionEquality().hash(json);

  // The keys only: the values are whatever the agent wrote about the person.
  @override
  String toString() => 'AIUIArguments(keys: [${json.keys.join(', ')}])';
}

// Reads one argument, named [where] in the error it throws when it doesn't
// fit.
typedef _Read<T> = T Function(Object? value, String where);

String _string(Object? value, String where) =>
    value is String ? value : throw FormatException('$where is not a string');

double _number(Object? value, String where) =>
    value is num ? value.toDouble() : throw FormatException('$where is not a number');

// The size a whole number must be below to read as an `int`: 2^63, the limit
// of an `int` on the VM. The web, whose `int`s go further, gets the same limit.
const _kIntLimit = 9223372036854775808.0;

int _integer(Object? value, String where) {
  if (value is num && value.isFinite && value.abs() < _kIntLimit) {
    if (value is int) return value;
    if (value == value.truncateToDouble()) return value.toInt();
  }
  throw FormatException('$where is not a whole number');
}

bool _boolean(Object? value, String where) =>
    value is bool ? value : throw FormatException('$where is not `true` or `false`');

DateTime _date(Object? value, String where) =>
    _parseDate(_string(value, where)) ?? (throw FormatException('$where is not a date'));

Uri _url(Object? value, String where) {
  final text = _string(value, where);
  if (text.isNotEmpty) {
    if (Uri.tryParse(text) case final url?) return url;
  }
  throw FormatException('$where is not a link');
}

AIUIArguments _object(Object? value, String where) => switch (value) {
  final Map<String, Object?> fields => AIUIArguments._(fields),
  _ => throw FormatException('$where is not an object'),
};

final _day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

// The latest year whose every moment a `DateTime` holds.
const _kLatestYear = 275759;

final _moment = RegExp(
  r'^(\d{4,6})-(\d{1,2})-(\d{1,2})[Tt](\d{1,2}):(\d{1,2})(?::(\d{1,2})(?:\.(\d+))?)?'
  r'(?:([Zz])|([+-])(\d{2})(?::?(\d{2}))?)?$',
);

// A moment, or the start of a day written as `yyyy-MM-dd` and nothing else,
// when the calendar has it.
DateTime? _parseDate(String text) => _parseMoment(text) ?? _parseDay(text);

// A moment in RFC 3339, or one of the variations agents write: no offset,
// read as UTC; an offset without a colon or with hours only; no seconds before
// a `Z`; one-digit fields.
DateTime? _parseMoment(String text) {
  final match = _moment.firstMatch(text);
  if (match == null) return null;
  int? part(int group) => switch (match.group(group)) {
    final digits? => int.parse(digits),
    null => null,
  };
  final seconds = part(6);
  final fraction = match.group(7);
  final isUtc = match.group(8) != null;
  final hasOffset = isUtc || match.group(9) != null;
  // Without seconds the moment needs a `Z`, and a fraction needs an offset.
  if (seconds == null && !isUtc) return null;
  if (fraction != null && !hasOffset) return null;
  final [year, month, day, hour, minute] = [for (var group = 1; group <= 5; group++) part(group)!];
  if (year < 1 || year > _kLatestYear || month < 1 || month > 12 || day < 1) return null;
  if (hour > 23 || minute > 59 || (seconds ?? 0) > 59) return null;
  final microseconds = int.parse((fraction ?? '').padRight(6, '0').substring(0, 6));
  final utc = DateTime.utc(year, month, day, hour, minute, seconds ?? 0, 0, microseconds);
  // DateTime.utc rolls 31 February over into March.
  if (utc.day != day) return null;
  if (match.group(9) == null) return utc;
  final (offsetHours, offsetMinutes) = (part(10)!, part(11) ?? 0);
  if (offsetHours > 23 || offsetMinutes > 59) return null;
  final offset = Duration(hours: offsetHours, minutes: offsetMinutes);
  return match.group(9) == '-' ? utc.add(offset) : utc.subtract(offset);
}

DateTime? _parseDay(String text) {
  final match = _day.firstMatch(text);
  if (match == null) return null;
  final [year, month, day] = [for (var group = 1; group <= 3; group++) int.parse(match.group(group)!)];
  if (year < 1) return null;
  final start = DateTime(year, month, day);
  // DateTime rolls 30 February over into March, and month 13 into January.
  if (start.year != year || start.month != month || start.day != day) return null;
  return start;
}
