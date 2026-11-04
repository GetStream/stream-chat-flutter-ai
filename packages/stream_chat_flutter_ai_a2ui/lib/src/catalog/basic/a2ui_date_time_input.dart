import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `DateTimeInput`: its `label` over a field showing its `value` in
/// the device's own format, which opens a date picker, a time picker, or the
/// date picker and then the time picker, as `enableDate` and `enableTime`
/// say. With neither, it picks a date.
///
/// What the person picks is written in ISO 8601: a date such as
/// `2026-10-02`, a time such as `19:30:00`, or a date and time with its
/// offset from UTC, such as `2026-10-02T19:30:00+02:00`, or `Z` for no
/// offset. A date and time keeps the offset its value was written with, and
/// otherwise takes the device's. Nothing is written until the person picks.
///
/// The date picker offers only the days from `min` to `max`, when they are
/// dates. The messages of the input's failing checks show below it.
///
/// Internal to the package.
@internal
Widget buildA2UIDateTimeInput(BuildContext context, A2UIComponentScope scope) {
  final theme = A2UISurfaceScope.of(context).theme;
  final enableTime = scope.boolean('enableTime') ?? false;
  final enableDate = scope.boolean('enableDate') ?? false;
  final kind = switch ((enableDate, enableTime)) {
    (true, true) => A2UIDateTimeKind.dateTime,
    (false, true) => A2UIDateTimeKind.time,
    _ => A2UIDateTimeKind.date,
  };
  final label = scope.string('label') ?? '';
  final written = a2uiParseDateTime(scope.string('value'));
  // A value that isn't one shows as the agent wrote it.
  final shown = written == null ? scope.string('value') ?? '' : _display(context, written.wall, kind);
  final accessibility = a2uiAccessibilityOf(scope);
  Future<void> handleTap() async {
    final wall = await _pick(context, theme, kind, written: written, scope: scope);
    if (wall == null) return;
    final offset = written?.offset ?? wall.timeZoneOffset;
    scope.write('value', a2uiDateTimeValue(wall, kind, offset: offset));
  }

  return A2UIInputWidth(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: _labelSpacing),
            child: ExcludeSemantics(
              child: Text(label, style: theme.label.copyWith(color: theme.secondaryText)),
            ),
          ),
        A2UIPressable(
          onTap: handleTap,
          label: [accessibility.label ?? label, shown].where((part) => part.isNotEmpty).join(', '),
          hint: accessibility.description,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.subtleSurface,
              borderRadius: BorderRadius.circular(theme.controlCornerRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: Row(
                spacing: _iconSpacing,
                children: [
                  Expanded(
                    child: Text(shown, style: theme.body.copyWith(color: theme.text)),
                  ),
                  Icon(
                    kind == A2UIDateTimeKind.time ? Icons.schedule_rounded : Icons.calendar_today_rounded,
                    color: theme.secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ),
        A2UIValidationMessages(failures: a2uiCheckFailuresOf(scope), theme: theme),
      ],
    ),
  );
}

// The space between the label and the field.
const _labelSpacing = 4.0;

// The space between the field's edge and its value.
const _padding = 10.0;

// The space between the value and the icon.
const _iconSpacing = 8.0;

/// What a `DateTimeInput` picks: a date, a time, or a date and a time.
///
/// Internal to the package.
@internal
enum A2UIDateTimeKind {
  /// A day.
  date,

  /// A time of day.
  time,

  /// A day and a time of day.
  dateTime,
}

/// A date or time as an agent wrote it: its `wall` clock fields, local and
/// unconverted, and the `offset` from UTC it was written with, or `null` when
/// it was written without one.
///
/// Internal to the package.
@internal
typedef A2UIWrittenDateTime = ({DateTime wall, Duration? offset});

/// [wall] as the ISO 8601 value of [kind]: `2026-10-02` for a date,
/// `19:30:00` for a time, and `2026-10-02T19:30:00+02:00` for a date and
/// time at [offset] from UTC, or with `Z` when [offset] is zero.
///
/// Only the calendar and clock fields of [wall] count, to the minute.
///
/// Internal to the package.
@internal
String a2uiDateTimeValue(DateTime wall, A2UIDateTimeKind kind, {required Duration offset}) {
  final date = '${_digits(wall.year, 4)}-${_digits(wall.month, 2)}-${_digits(wall.day, 2)}';
  final time = '${_digits(wall.hour, 2)}:${_digits(wall.minute, 2)}:00';
  return switch (kind) {
    A2UIDateTimeKind.date => date,
    A2UIDateTimeKind.time => time,
    A2UIDateTimeKind.dateTime => '${date}T$time${_offsetText(offset)}',
  };
}

String _digits(int value, int width) => '$value'.padLeft(width, '0');

String _offsetText(Duration offset) {
  final minutes = offset.inMinutes;
  if (minutes == 0) return 'Z';
  final sign = minutes < 0 ? '-' : '+';
  final magnitude = minutes.abs();
  return '$sign${_digits(magnitude ~/ Duration.minutesPerHour, 2)}:${_digits(magnitude % Duration.minutesPerHour, 2)}';
}

/// The date or time [text] holds in ISO 8601, or `null` when it holds none,
/// or one that doesn't exist, such as February 30 or an offset of 20 hours.
///
/// It reads a date (`2026-10-02`), a time with or without seconds (`19:30`,
/// `19:30:00`), and a date and time, with `T` or a space between them, with
/// or without seconds and their fraction, and with an offset (`Z`,
/// `+02:00`, `+0200`) or without one. The fraction of a second is dropped.
///
/// Internal to the package.
@internal
A2UIWrittenDateTime? a2uiParseDateTime(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (_timePattern.firstMatch(trimmed) case final match?) {
    final wall = _wall(1970, 1, 1, match.group(1), match.group(2), match.group(3));
    return wall == null ? null : (wall: wall, offset: null);
  }
  final match = _dateTimePattern.firstMatch(trimmed);
  if (match == null) return null;
  final wall = _wall(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    match.group(4),
    match.group(5),
    match.group(6),
  );
  if (wall == null) return null;
  final offsetText = match.group(7);
  final offset = _offsetOf(offsetText);
  if (offsetText != null && offset == null) return null;
  return (wall: wall, offset: offset);
}

// A time of day: hours and minutes, and seconds when given.
final _timePattern = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?$');

// A date, then a time of day with optional seconds and fraction, and an
// optional offset.
final _dateTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})'
  r'(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,9})?)?(Z|z|[+-]\d{2}:?\d{2})?)?$',
);

// The local date and time of the given fields, or `null` when they name one
// that doesn't exist, such as February 30 or 24:00.
DateTime? _wall(int year, int month, int day, String? hour, String? minute, String? second) {
  final hours = hour == null ? 0 : int.parse(hour);
  final minutes = minute == null ? 0 : int.parse(minute);
  final seconds = second == null ? 0 : int.parse(second);
  if (hours > 23 || minutes > 59 || seconds > 59) return null;
  final wall = DateTime(year, month, day, hours, minutes, seconds);
  // DateTime rolls a day past the end of a month over into the next one.
  if (wall.year != year || wall.month != month || wall.day != day) return null;
  return wall;
}

Duration? _offsetOf(String? text) {
  if (text == null) return null;
  if (text == 'Z' || text == 'z') return Duration.zero;
  final digits = text.substring(1).replaceAll(':', '');
  final minutes = int.parse(digits.substring(2));
  final offset = Duration(hours: int.parse(digits.substring(0, 2)), minutes: minutes);
  // No zone is more than 18 hours from UTC, and an hour has 60 minutes.
  if (offset > _maxOffset || minutes > 59) return null;
  return text.startsWith('-') ? -offset : offset;
}

// [wall] as the device shows a value of [kind].
String _display(BuildContext context, DateTime wall, A2UIDateTimeKind kind) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatShortDate(wall);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(wall),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return switch (kind) {
    A2UIDateTimeKind.date => date,
    A2UIDateTimeKind.time => time,
    A2UIDateTimeKind.dateTime => '$date, $time',
  };
}

// Shows the pickers of [kind], starting at what is [written], and returns
// what the person picked, as local wall clock fields, or `null` when they
// closed a picker without picking.
Future<DateTime?> _pick(
  BuildContext context,
  A2UITheme theme,
  A2UIDateTimeKind kind, {
  required A2UIWrittenDateTime? written,
  required A2UIComponentScope scope,
}) async {
  final start = written?.wall ?? DateTime.now();
  Widget themed(BuildContext context, Widget? child) => Theme(data: _pickerTheme(context, theme), child: child!);
  var day = start;
  if (kind != A2UIDateTimeKind.time) {
    final (:first, :last) = _days(scope);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDay(start, first, last),
      firstDate: first,
      lastDate: last,
      builder: themed,
    );
    if (picked == null || !context.mounted) return null;
    if (kind == A2UIDateTimeKind.date) return picked;
    day = picked;
  }
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start), builder: themed);
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

// The first and the last day the date picker offers: the days of `min` and
// `max` when they are dates and `min` isn't after `max`, else a range wide
// enough for any date a form asks for.
({DateTime first, DateTime last}) _days(A2UIComponentScope scope) {
  final min = _dayOf(scope.string('min'));
  final max = _dayOf(scope.string('max'));
  final first = min == null ? _earliestDay : DateTime(min.year, min.month, min.day);
  final last = max == null ? _latestDay : DateTime(max.year, max.month, max.day);
  if (first.isAfter(last)) return (first: _earliestDay, last: _latestDay);
  return (first: first, last: last);
}

// The day [text] names, or `null` when it names none, such as a time alone.
DateTime? _dayOf(String? text) {
  if (text == null || _timePattern.hasMatch(text.trim())) return null;
  return a2uiParseDateTime(text)?.wall;
}

// The largest offset from UTC a date and time is read with.
const _maxOffset = Duration(hours: 18);

// The days the date picker offers when the agent gives no bounds.
final _earliestDay = DateTime(1900);
final _latestDay = DateTime(2100, 12, 31);

DateTime _clampDay(DateTime day, DateTime first, DateTime last) {
  final date = DateTime(day.year, day.month, day.day);
  if (date.isBefore(first)) return first;
  if (date.isAfter(last)) return last;
  return date;
}

// The theme of the pickers: the app's, with the colors, corners and font of
// [theme].
ThemeData _pickerTheme(BuildContext context, A2UITheme theme) {
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.cornerRadius));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: theme.accent,
      onPrimary: theme.onAccent,
      surface: theme.surface,
      onSurface: theme.text,
      onSurfaceVariant: theme.secondaryText,
      outline: theme.border,
      outlineVariant: theme.border,
    ),
    textTheme: base.textTheme.apply(fontFamily: theme.body.fontFamily, bodyColor: theme.text, displayColor: theme.text),
    datePickerTheme: DatePickerThemeData(backgroundColor: theme.surface, shape: shape),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: theme.surface,
      shape: shape,
      hourMinuteColor: _whenSelected(theme.accent.withValues(alpha: _selectedOpacity), theme.subtleSurface),
      hourMinuteTextColor: _whenSelected(theme.accent, theme.text),
      dayPeriodColor: _whenSelected(theme.accent.withValues(alpha: _selectedOpacity), Colors.transparent),
      dayPeriodTextColor: _whenSelected(theme.accent, theme.text),
      dayPeriodBorderSide: BorderSide(color: theme.border),
      dialBackgroundColor: theme.subtleSurface,
      dialHandColor: theme.accent,
      dialTextColor: _whenSelected(theme.onAccent, theme.text),
      entryModeIconColor: theme.secondaryText,
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: theme.accent)),
  );
}

// [selected] for a part of a picker that is selected, such as the hour being
// picked, and [other] for the rest.
WidgetStateColor _whenSelected(Color selected, Color other) {
  return WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? selected : other);
}

// How strongly a selected part of a picker shows the accent color behind it.
const _selectedOpacity = 0.15;
