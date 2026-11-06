import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_core_flutter/core.dart';

/// [date] as `yyyy-MM-dd`.
///
/// Internal to the package.
@internal
String openUIDateString(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}

/// The day [text] starts with, written `yyyy-MM-dd`, or `null` when it holds
/// none.
///
/// Internal to the package.
@internal
DateTime? openUIParseDate(String? text) {
  if (text == null || text.length < 10) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.substring(0, 10));
  if (match == null) return null;
  final (year, month, day) = (int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  // A year before 1000 is a typo, not a day a date picker can show.
  if (year < 1000) return null;
  final date = DateTime(year, month, day);
  // Rolled over, such as February 30th: no such day.
  if (date.month != month || date.day != day) return null;
  return date;
}

/// The day the person picks in a date picker drawn with the reply's theme,
/// starting at [initial] and no earlier than [first]; `null` when they
/// cancel.
///
/// Internal to the package.
@internal
Future<DateTime?> pickOpenUIDate(BuildContext context, {DateTime? initial, DateTime? first}) {
  final theme = OpenUITheme.of(context);
  final colors = theme;
  final firstDate = first ?? DateTime(1900);
  var start = initial ?? DateTime.now();
  if (start.isBefore(firstDate)) start = firstDate;
  final lastDate = DateTime(2200);
  if (start.isAfter(lastDate)) start = lastDate;
  final base = Theme.of(context);
  final brightness = ThemeData.estimateBrightnessForColor(colors.surface!);
  final picker = base.copyWith(
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.accent!,
      onPrimary: colors.onAccent!,
      secondary: colors.accent!,
      onSecondary: colors.onAccent!,
      error: colors.error!,
      onError: colors.onAccent!,
      surface: colors.surface!,
      onSurface: colors.text!,
      onSurfaceVariant: colors.secondaryText,
      outline: colors.border,
      outlineVariant: colors.border,
      surfaceContainerHigh: colors.surface,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.surface,
      headerBackgroundColor: colors.surface,
      headerForegroundColor: colors.text,
      surfaceTintColor: const Color(0x00000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.cornerRadius!)),
    ),
  );
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) => Theme(data: picker, child: child!),
  );
}

/// The value of the option the person picks in a sheet of [options], each a
/// value and its label, with [selected] checked; `null` when they close it.
///
/// Internal to the package.
@internal
Future<String?> pickOpenUIOption(
  BuildContext context, {
  required List<(String, String)> options,
  required String? selected,
}) {
  return showStreamSheet<String>(
    context: context,
    isDismissible: true,
    builder: (context, scrollController) {
      final theme = OpenUITheme.of(context);
      final colors = theme;
      return ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: theme.mSpacing!),
        children: [
          for (final (value, label) in options)
            OpenUIPressable(
              selected: value == selected,
              onTap: () => Navigator.of(context).pop(value),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.lSpacing!, vertical: theme.mSpacing!),
                child: Row(
                  spacing: theme.sSpacing!,
                  children: [
                    Expanded(
                      child: Text(label, style: theme.body!.copyWith(color: colors.text)),
                    ),
                    if (value == selected)
                      ExcludeSemantics(
                        child: Icon(
                          context.streamIcons.checkmark,
                          size: openUIScaled(context, 20),
                          color: colors.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
