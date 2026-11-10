import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_date_time_input.dart';

void main() {
  final evening = DateTime(2026, 9, 25, 19, 30);

  test('a date is written as its day', () {
    expect(a2uiDateTimeValue(evening, A2UIDateTimeKind.date, offset: Duration.zero), '2026-09-25');
  });

  test('a time is written as its hours and minutes, with no seconds', () {
    expect(a2uiDateTimeValue(evening, A2UIDateTimeKind.time, offset: Duration.zero), '19:30:00');
  });

  test('a date and time is written with its offset from UTC', () {
    expect(
      a2uiDateTimeValue(evening, A2UIDateTimeKind.dateTime, offset: const Duration(hours: 2)),
      '2026-09-25T19:30:00+02:00',
    );
  });

  test('a date and time at no offset from UTC is written with Z', () {
    expect(a2uiDateTimeValue(evening, A2UIDateTimeKind.dateTime, offset: Duration.zero), '2026-09-25T19:30:00Z');
  });

  test('a date and time behind UTC is written with a negative offset', () {
    expect(
      a2uiDateTimeValue(evening, A2UIDateTimeKind.dateTime, offset: const Duration(hours: -4)),
      '2026-09-25T19:30:00-04:00',
    );
  });

  test('an offset of a part of an hour is written with its minutes', () {
    expect(
      a2uiDateTimeValue(evening, A2UIDateTimeKind.dateTime, offset: const Duration(hours: 5, minutes: 30)),
      '2026-09-25T19:30:00+05:30',
    );
  });

  test('a year before 1000 is written with four digits', () {
    expect(a2uiDateTimeValue(DateTime(976, 1, 2), A2UIDateTimeKind.date, offset: Duration.zero), '0976-01-02');
  });

  test('a date is read as that day', () {
    expect(a2uiParseDateTime('2026-10-02'), (wall: DateTime(2026, 10, 2), offset: null));
  });

  test('a time with seconds is read as that time', () {
    expect(a2uiParseDateTime('19:00:30')?.wall, DateTime(1970, 1, 1, 19, 0, 30));
  });

  test('a time without seconds is read as that time', () {
    expect(a2uiParseDateTime('19:00')?.wall, DateTime(1970, 1, 1, 19));
  });

  test('a date and time without an offset is read with none', () {
    expect(a2uiParseDateTime('2026-10-02T19:00:00'), (wall: DateTime(2026, 10, 2, 19), offset: null));
  });

  test('a date and time with Z is read at no offset', () {
    expect(a2uiParseDateTime('2026-10-02T19:00:00Z'), (wall: DateTime(2026, 10, 2, 19), offset: Duration.zero));
  });

  test('a date and time with an offset is read with it, at its own clock', () {
    expect(
      a2uiParseDateTime('2026-10-02T19:00:00.123+05:30'),
      (wall: DateTime(2026, 10, 2, 19), offset: const Duration(hours: 5, minutes: 30)),
    );
  });

  test('a negative offset without a colon is read', () {
    expect(a2uiParseDateTime('2026-10-02T19:00:00-0400')?.offset, const Duration(hours: -4));
  });

  test('a date and time without seconds is read', () {
    expect(a2uiParseDateTime('2026-10-02T19:00')?.wall, DateTime(2026, 10, 2, 19));
  });

  test('a date and time with a space between them is read', () {
    expect(a2uiParseDateTime('2026-10-02 19:00')?.wall, DateTime(2026, 10, 2, 19));
  });

  test("a day that doesn't exist isn't read", () {
    expect(a2uiParseDateTime('2026-02-30'), isNull);
  });

  test("a time that doesn't exist isn't read", () {
    expect(a2uiParseDateTime('24:00'), isNull);
  });

  test("an offset of more than 18 hours isn't read", () {
    expect(a2uiParseDateTime('2026-10-02T19:00:00+18:01'), isNull);
    expect(a2uiParseDateTime('2026-10-02T19:00:00-20:00'), isNull);
  });

  test('an offset of 18 hours is read', () {
    expect(a2uiParseDateTime('2026-10-02T19:00:00+18:00'), isNotNull);
    expect(a2uiParseDateTime('2026-10-02T19:00:00-18:00'), isNotNull);
  });

  test("an offset of more than 59 minutes isn't read", () {
    expect(a2uiParseDateTime('2026-10-02T19:00:00+05:75'), isNull);
  });

  test("an empty text isn't read", () {
    expect(a2uiParseDateTime(''), isNull);
  });

  test("a text that isn't a date isn't read", () {
    expect(a2uiParseDateTime('tomorrow'), isNull);
  });

  // A run of the reference parser, at the time zones it was run in; see the
  // fixtures' README. Only the rows with an offset, or in UTC, name one
  // instant whatever zone this test runs in, and only those with a date: a
  // time alone is read on a day of the parser's own.
  final rows = (jsonDecode(File('test/fixtures/ios_date_values.json').readAsStringSync()) as List<Object?>)
      .cast<Map<String, Object?>>()
      .where((row) => row['kind'] == 'parse' && row['epoch'] != null && (row['input']! as String).contains('-'))
      .where((row) => row['zone'] == 'UTC' || RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(row['input']! as String))
      .toList();

  test('the reference run has rows to compare', () {
    expect(rows, isNotEmpty);
  });

  for (final row in rows) {
    final input = row['input']! as String;
    test('$input in ${row['zone']} names the instant the reference run reads', () {
      final written = a2uiParseDateTime(input)!;
      final wall = written.wall;
      final utc = DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second);
      final instant = utc.subtract(written.offset ?? Duration.zero);

      expect(instant.millisecondsSinceEpoch / 1000, (row['epoch']! as num).floorToDouble());
    });
  }
}
