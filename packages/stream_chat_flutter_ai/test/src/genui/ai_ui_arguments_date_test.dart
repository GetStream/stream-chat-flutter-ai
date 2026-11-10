import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_fixtures.dart';

void main() {
  test('AIUIArguments.date reads an RFC 3339 moment in UTC', () {
    final moments = (_dates()['moments']! as Map<String, Object?>).cast<String, String>();

    final read = {for (final written in moments.keys) written: _date(written).toIso8601String()};

    expect(read, moments);
  });

  test('AIUIArguments.date reads a day as its start in local time', () {
    final days = {
      for (final MapEntry(:key, :value) in (_dates()['days']! as Map<String, Object?>).entries)
        key: (value! as List<Object?>).cast<int>(),
    };

    final read = {for (final written in days.keys) written: _date(written)};

    expect(read, {
      for (final MapEntry(key: written, value: day) in days.entries) written: DateTime(day[0], day[1], day[2]),
    });
  });

  test('AIUIArguments.date reads a day in local time, not UTC', () {
    expect(_date('2026-11-14').isUtc, isFalse);
  });

  test('AIUIArguments.date throws for a day that is not on the calendar', () {
    final impossible = (_dates()['impossible_days']! as List<Object?>).cast<String>();

    expect([for (final day in impossible) () => _date(day)], everyElement(throwsFormatException));
  });

  test('AIUIArguments.date throws for text that is neither a moment nor a yyyy-MM-dd day', () {
    final notDates = (_dates()['not_dates']! as List<Object?>).cast<String>();

    expect([for (final text in notDates) () => _date(text)], everyElement(throwsFormatException));
  });
}

Map<String, Object?> _dates() => genuiFixture('arguments_dates.json');

DateTime _date(String written) => AIUIArguments({'day': written}).date('day');
