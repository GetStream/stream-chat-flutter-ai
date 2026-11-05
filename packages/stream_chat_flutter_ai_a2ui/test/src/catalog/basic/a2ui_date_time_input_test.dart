import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_date_time_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('an input shows its date in the device format', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    expect(find.text(const DefaultMaterialLocalizations().formatShortDate(DateTime(2026, 10, 2))), findsOneWidget);
  });

  testWidgets('an input has no fill', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    expect(_frameOf(tester).color, isNull);
  });

  testWidgets('an input is outlined in the border color', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    expect((_frameOf(tester).shape as RoundedSuperellipseBorder).side.color, lightTheme().border);
  });

  testWidgets('an input is at least as tall as a person can tap', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('an input is as tall as a text field', (tester) async {
    await pumpSurface(
      tester,
      components: inColumn([
        _input(id: 'when'),
        {
          'id': 'name',
          'component': 'TextField',
          'label': 'Name',
          'value': {'@path': '/name'},
        },
      ]),
      data: {'day': '2026-10-02'},
    );

    expect(
      tester.getSize(find.byType(A2UIStreamFieldFrame)).height,
      tester.getSize(find.byType(StreamTextInput)).height,
    );
  });

  testWidgets('tapping an input of a date opens the date picker', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('picking a day writes it as a date', (tester) async {
    final processor = await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    await _pickDay(tester, '15');

    expect(_value(processor), '2026-10-15');
  });

  testWidgets('closing the date picker writes nothing', (tester) async {
    final processor = await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});
    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    await tester.tap(find.text(const DefaultMaterialLocalizations().cancelButtonLabel));
    await tester.pumpAndSettle();

    expect(_value(processor), '2026-10-02');
  });

  testWidgets('an input of a date and a time opens the time picker after the day', (tester) async {
    await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true)],
      data: {'day': '2026-10-02T19:30:00+05:45'},
    );

    await _pickDay(tester, '15');

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets("picking a day and a time writes them with the device's offset, at the time the value showed", (
    tester,
  ) async {
    final processor = await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true)],
      data: {'day': '2026-10-02T19:30:00+05:45'},
    );

    await _pickDay(tester, '15');
    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    final shown = DateTime.utc(2026, 10, 2, 13, 45).toLocal();
    final picked = DateTime(2026, 10, 15, shown.hour, shown.minute);
    expect(_value(processor), a2uiDateTimeValue(picked, A2UIDateTimeKind.dateTime, offset: picked.timeZoneOffset));
  });

  testWidgets('a date and time written in UTC shows as the same moment on the device clock', (tester) async {
    await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true)],
      data: {'day': '2026-10-02T17:30:00Z'},
    );

    final local = DateTime.utc(2026, 10, 2, 17, 30).toLocal();
    const localizations = DefaultMaterialLocalizations();
    final shown =
        '${localizations.formatShortDate(local)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    expect(find.text(shown), findsOneWidget);
  });

  testWidgets('a time picked before the minimum on its day becomes the minimum', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true, min: '2026-10-15T10:00:00')],
      data: {'day': '2026-10-15T08:00:00'},
    );

    await _pickDay(tester, '15');
    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    final kept = DateTime(2026, 10, 15, 10);
    expect(_value(processor), a2uiDateTimeValue(kept, A2UIDateTimeKind.dateTime, offset: kept.timeZoneOffset));
  });

  testWidgets('a time picked after the maximum on its day becomes the maximum', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true, max: '2026-10-15T17:00:00')],
      data: {'day': '2026-10-15T19:00:00'},
    );

    await _pickDay(tester, '15');
    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    final kept = DateTime(2026, 10, 15, 17);
    expect(_value(processor), a2uiDateTimeValue(kept, A2UIDateTimeKind.dateTime, offset: kept.timeZoneOffset));
  });

  testWidgets('a time picked on a day before the maximum day keeps its time', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true, max: '2026-10-15T17:00:00')],
      data: {'day': '2026-10-14T19:00:00'},
    );

    await _pickDay(tester, '14');
    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    final kept = DateTime(2026, 10, 14, 19);
    expect(_value(processor), a2uiDateTimeValue(kept, A2UIDateTimeKind.dateTime, offset: kept.timeZoneOffset));
  });

  testWidgets('a time picked before a minimum time becomes the minimum', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_input(enableTime: true, min: '09:00:00')],
      data: {'day': '08:00:00'},
    );
    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    expect(_value(processor), '09:00:00');
  });

  testWidgets("a minimum that isn't a date is reported, and limits nothing", (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(
      tester,
      // Bound, as a2ui_core rejects a written minimum that isn't a date.
      components: [
        {
          ..._input(),
          'min': {'@path': '/min'},
        },
      ],
      data: {'day': '2026-10-10', 'min': 'soon'},
      errors: errors,
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate, DateTime(1900));
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('a minimum after the maximum is reported', (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(
      tester,
      components: [_input(min: '2026-10-20', max: '2026-10-05')],
      data: {'day': '2026-10-10'},
      errors: errors,
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets("the time picker is themed from the surface's theme", (tester) async {
    await pumpSurface(tester, components: [_input(enableTime: true)], data: {'day': '19:30:00'});

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    final theme = lightTheme();
    final picker = Theme.of(tester.element(find.byType(TimePickerDialog))).timePickerTheme;
    Color? selected(Color? color) => WidgetStateProperty.resolveAs(color, {WidgetState.selected});
    Color? unselected(Color? color) => WidgetStateProperty.resolveAs(color, const {});
    expect(picker.backgroundColor, theme.surface);
    expect(picker.dialHandColor, theme.accent);
    expect(picker.dialBackgroundColor, theme.subtleSurface);
    expect(picker.entryModeIconColor, theme.secondaryText);
    expect(selected(picker.hourMinuteTextColor), theme.accent);
    expect(unselected(picker.hourMinuteTextColor), theme.text);
    expect(unselected(picker.hourMinuteColor), theme.subtleSurface);
    expect(selected(picker.dayPeriodTextColor), theme.accent);
    expect(unselected(picker.dayPeriodColor), Colors.transparent);
    expect(selected(picker.dialTextColor), theme.onAccent);
    expect(unselected(picker.dialTextColor), theme.text);
  });

  testWidgets('the date picker is themed with the accent color', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(DatePickerDialog))).colorScheme.primary, lightTheme().accent);
  });

  testWidgets('an input of a time opens only the time picker', (tester) async {
    await pumpSurface(tester, components: [_input(enableTime: true)], data: {'day': '19:30:00'});

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('picking a time writes it as a time', (tester) async {
    final processor = await pumpSurface(tester, components: [_input(enableTime: true)], data: {'day': '19:30:00'});
    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    expect(_value(processor), '19:30:00');
  });

  testWidgets('an input with neither a date nor a time picks a date', (tester) async {
    await pumpSurface(tester, components: [_input(enableDate: false, enableTime: false)]);

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('the date picker starts at the minimum day', (tester) async {
    await pumpSurface(
      tester,
      components: [_input(min: '2026-10-05', max: '2026-10-20')],
      data: {'day': '2026-10-10'},
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate, DateTime(2026, 10, 5));
  });

  testWidgets('the date picker ends at the maximum day', (tester) async {
    await pumpSurface(
      tester,
      components: [_input(min: '2026-10-05', max: '2026-10-20')],
      data: {'day': '2026-10-10'},
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate, DateTime(2026, 10, 20));
  });

  testWidgets('the date picker starts at the minimum day for a value before it', (tester) async {
    await pumpSurface(
      tester,
      components: [_input(min: '2026-10-05', max: '2026-10-20')],
      data: {'day': '2026-09-01'},
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).initialDate, DateTime(2026, 10, 5));
  });

  testWidgets("a date and time written without an offset is written back with the device's", (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true)],
      data: {'day': '2026-10-02T19:30:00'},
    );

    await _pickDay(tester, '15');
    await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
    await tester.pumpAndSettle();

    final picked = DateTime(2026, 10, 15, 19, 30);
    expect(_value(processor), a2uiDateTimeValue(picked, A2UIDateTimeKind.dateTime, offset: picked.timeZoneOffset));
  });

  testWidgets("a maximum time doesn't limit the days", (tester) async {
    await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true, max: '17:00:00')],
      data: {'day': '2026-10-10T09:00:00Z'},
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate, DateTime(2100, 12, 31));
  });

  testWidgets("a minimum time doesn't limit the days", (tester) async {
    await pumpSurface(
      tester,
      components: [_input(enableDate: true, enableTime: true, min: '09:00:00')],
      data: {'day': '2026-10-10T19:00:00Z'},
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate, DateTime(1900));
  });

  testWidgets("a minimum after the maximum doesn't limit the days", (tester) async {
    await pumpSurface(
      tester,
      components: [_input(min: '2026-10-20', max: '2026-10-05')],
      data: {'day': '2026-10-10'},
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate, DateTime(1900));
  });

  testWidgets('an input whose value is written as a date opens no picker, and is reported', (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(
      tester,
      components: [
        {..._input(), 'value': '2026-10-02'},
      ],
      errors: errors,
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets("a value that isn't a date shows as it is written", (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': 'next Friday'});

    expect(find.text('next Friday'), findsOneWidget);
  });

  testWidgets('an input beside a text in a row without weights fills the rest of the row', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['caption', 'day'],
        },
        {'id': 'caption', 'component': 'Text', 'text': 'Due'},
        _input(id: 'day'),
      ],
      data: {'day': '2026-10-02'},
    );

    expect(tester.getTopRight(find.byType(A2UIPressable)).dx, tester.getTopRight(find.byType(A2UISurfaceView)).dx);
  });

  testWidgets('an empty input writes nothing until the person picks', (tester) async {
    final processor = await pumpSurface(tester, components: [_input()]);
    await tester.pump();

    expect(_value(processor), isNull);
  });

  testWidgets('an input is read as one button with its label and value', (tester) async {
    await pumpSurface(tester, components: [_input()], data: {'day': '2026-10-02'});

    final shown = const DefaultMaterialLocalizations().formatShortDate(DateTime(2026, 10, 2));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Arrival, $shown')),
      isSemantics(isButton: true, hasTapAction: true),
    );
  });

  testWidgets("an input with the agent's label is read with its label and value", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          ..._input(),
          'accessibility': {'label': 'Arrival day'},
        },
      ],
      data: {'day': '2026-10-02'},
    );

    final shown = const DefaultMaterialLocalizations().formatShortDate(DateTime(2026, 10, 2));
    expect(find.bySemanticsLabel('Arrival day, $shown'), findsOneWidget);
  });
}

Map<String, Object?> _input({
  String id = 'root',
  bool? enableDate,
  bool? enableTime,
  String? min,
  String? max,
}) {
  return {
    'id': id,
    'component': 'DateTimeInput',
    'label': 'Arrival',
    'value': {'@path': '/day'},
    'enableDate': ?enableDate,
    'enableTime': ?enableTime,
    'min': ?min,
    'max': ?max,
  };
}

ShapeDecoration _frameOf(WidgetTester tester) {
  final frame = find.descendant(of: find.byType(A2UIStreamFieldFrame), matching: find.byType(Container));
  return tester.widget<Container>(frame).decoration! as ShapeDecoration;
}

Object? _value(A2UIProcessor processor) => processor.surface('s')!.read('/day');

Future<void> _pickDay(WidgetTester tester, String day) async {
  await tester.tap(find.byType(Icon));
  await tester.pumpAndSettle();
  await tester.tap(find.text(day));
  await tester.tap(find.text(const DefaultMaterialLocalizations().okButtonLabel));
  await tester.pumpAndSettle();
}
