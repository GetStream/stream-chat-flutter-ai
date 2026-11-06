import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `DateTimeInput`: its `label` over a field showing its `value` in
/// the device's own format, which opens a date picker, a time picker, or the
/// date picker and then the time picker, as `enableDate` and `enableTime`
/// say. With neither, it picks a date.
///
/// A date and time written with an offset from UTC, such as
/// `2026-10-02T17:30:00Z`, shows as the same moment on the device's clock,
/// such as 19:30 two hours east of UTC; one written without an offset shows
/// as it is written.
///
/// What the person picks is written in ISO 8601: a date such as
/// `2026-10-02`, a time such as `19:30:00`, or a date and time with the
/// device's offset from UTC, such as `2026-10-02T19:30:00+02:00`, or `Z` for
/// UTC itself. Nothing is written until the person picks.
///
/// What the person picks stays from `min` to `max`, read as the value is: the
/// date picker offers only the days between them, and a time picked before
/// `min` or after `max` on those days becomes that bound. A time input is
/// limited by a `min` and `max` that are times, and the other inputs by ones
/// that are dates or dates and times. A bound that isn't a date or time, or a
/// `min` after the `max`, limits nothing, and is reported through the
/// processor's `onError`. An input whose `value` isn't bound to the data
/// model shows fainter, and a tap opens nothing. The messages of the input's
/// failing checks show below it.
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
  final local = written == null ? null : a2uiLocalWall(written, kind);
  // A value that isn't one shows as the agent wrote it.
  final shown = local == null ? scope.string('value') ?? '' : _display(context, local, kind);
  final accessibility = a2uiAccessibilityOf(scope);
  final canEdit = a2uiCanEdit(scope);
  final failures = a2uiCheckFailuresOf(scope);
  final hasError = a2uiBlocks(failures);
  Future<void> handleTap() async {
    final bounds = _bounds(scope, kind);
    final wall = await _pick(context, theme, kind, start: local, bounds: bounds);
    if (wall == null) return;
    final kept = a2uiClampDateTime(wall, kind, min: bounds.min, max: bounds.max);
    scope.write('value', a2uiDateTimeValue(kept, kind, offset: kept.timeZoneOffset));
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
              child: Text(label, style: theme.label.copyWith(color: hasError ? theme.error : theme.secondaryText)),
            ),
          ),
        A2UIPressable(
          onTap: canEdit ? handleTap : null,
          label: [accessibility.label ?? label, shown].where((part) => part.isNotEmpty).join(', '),
          hint: accessibility.description,
          // The field is as tall as a text field, inside the taller area a
          // person can tap.
          child: Opacity(
            opacity: canEdit ? 1 : a2uiReadOnlyOpacity,
            child: Center(
              heightFactor: 1,
              child: A2UIStreamFieldFrame(
                hasError: hasError,
                child: Row(
                  spacing: _iconSpacing,
                  children: [
                    Expanded(
                      child: Text(shown, style: theme.body.copyWith(color: theme.text)),
                    ),
                    Icon(
                      kind == A2UIDateTimeKind.time ? Icons.schedule_rounded : Icons.calendar_today_rounded,
                      size: _iconSize,
                      color: theme.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        A2UIValidationMessages(failures: failures, theme: theme),
      ],
    ),
  );
}

// The space between the label and the field.
const _labelSpacing = 4.0;

// The size of the icon, which keeps the field as tall as a text field.
const _iconSize = 20.0;

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

/// A date or time as an agent wrote it: its `wall` clock fields, as written
/// and unconverted, and the `offset` from UTC it was written with, or `null`
/// when it was written without one.
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

/// [written] on the device's clock, for an input of [kind]: a date and time
/// written with an offset becomes the same moment in the device's time zone,
/// and anything else keeps the fields it was written with.
///
/// Internal to the package.
@internal
DateTime a2uiLocalWall(A2UIWrittenDateTime written, A2UIDateTimeKind kind) {
  final (:wall, :offset) = written;
  if (kind != A2UIDateTimeKind.dateTime || offset == null) return wall;
  final moment = DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).subtract(offset);
  final local = moment.toLocal();
  return DateTime(local.year, local.month, local.day, local.hour, local.minute, local.second);
}

/// [picked], what the person picked on an input of [kind], kept from [min]
/// to [max] on the device's clock, to the minute: a time before [min]
/// becomes [min], or the minute after it when [min] has seconds, and a time
/// after [max] becomes [max]. A date input's days are already limited by its
/// date picker, so it is returned as it is.
///
/// Internal to the package.
@internal
DateTime a2uiClampDateTime(DateTime picked, A2UIDateTimeKind kind, {DateTime? min, DateTime? max}) {
  if (kind == A2UIDateTimeKind.date) return picked;
  // A time is compared as a time of day, on the same day.
  DateTime align(DateTime bound) => kind == A2UIDateTimeKind.time
      ? DateTime(picked.year, picked.month, picked.day, bound.hour, bound.minute, bound.second)
      : bound;
  if (min != null) {
    final lowest = align(min);
    // What is written counts whole minutes, so a bound with seconds is kept
    // by the next whole minute.
    final earliest = lowest.second == 0
        ? lowest
        : DateTime(lowest.year, lowest.month, lowest.day, lowest.hour, lowest.minute + 1);
    if (picked.isBefore(earliest)) return earliest;
  }
  if (max != null) {
    final highest = align(max);
    if (picked.isAfter(highest)) {
      return DateTime(highest.year, highest.month, highest.day, highest.hour, highest.minute);
    }
  }
  return picked;
}

// The earliest and latest an input of [kind] picks, on the device's clock,
// from its `min` and `max`; see [buildA2UIDateTimeInput]. A date that is
// the `max` counts to the end of its day. A bound that isn't a date or
// time, or a `min` after the `max`, is reported, and limits nothing.
({DateTime? min, DateTime? max}) _bounds(A2UIComponentScope scope, A2UIDateTimeKind kind) {
  DateTime? read(String name) {
    final text = scope.string(name);
    if (text == null || text.trim().isEmpty) return null;
    final written = a2uiParseDateTime(text);
    if (written == null) {
      a2uiReportOnce(scope, name, "Its '$name' isn't a date or time in ISO 8601, so it limits nothing.");
      return null;
    }
    final isTime = _timePattern.hasMatch(text.trim());
    // A time limits a time input, and a date or a date and time limits the
    // others.
    if (isTime != (kind == A2UIDateTimeKind.time)) return null;
    final local = a2uiLocalWall(written, kind == A2UIDateTimeKind.time ? kind : A2UIDateTimeKind.dateTime);
    if (name == 'max' && !isTime && _datePattern.hasMatch(text.trim())) {
      return DateTime(local.year, local.month, local.day, 23, 59, 59);
    }
    return local;
  }

  final min = read('min');
  final max = read('max');
  if (min != null && max != null && min.isAfter(max)) {
    a2uiReportOnce(scope, 'min after max', "Its 'min' is after its 'max', so they limit nothing.");
    return (min: null, max: null);
  }
  return (min: min, max: max);
}

// Shows the pickers of [kind], starting at [start] or now, and returns what
// the person picked, as local wall clock fields, or `null` when they closed a
// picker without picking. The date picker offers the days from the day of
// [bounds]' `min` to the day of its `max`.
Future<DateTime?> _pick(
  BuildContext context,
  A2UIResolvedTheme theme,
  A2UIDateTimeKind kind, {
  required DateTime? start,
  required ({DateTime? min, DateTime? max}) bounds,
}) async {
  final from = start ?? DateTime.now();
  Widget themed(BuildContext context, Widget? child) => Theme(data: _pickerTheme(context, theme), child: child!);
  var day = from;
  if (kind != A2UIDateTimeKind.time) {
    final first = bounds.min == null ? _earliestDay : _dayOf(bounds.min!);
    final last = bounds.max == null ? _latestDay : _dayOf(bounds.max!);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDay(from, first, last),
      firstDate: first,
      lastDate: last,
      builder: themed,
    );
    if (picked == null || !context.mounted) return null;
    if (kind == A2UIDateTimeKind.date) return picked;
    day = picked;
  }
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(from), builder: themed);
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

DateTime _dayOf(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

// A date alone.
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

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
ThemeData _pickerTheme(BuildContext context, A2UIResolvedTheme theme) {
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
