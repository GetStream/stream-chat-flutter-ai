import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('tapping an option of a single choice picks it', (tester) async {
    final processor = await pumpSurface(tester, components: [_picker()], data: _relaxed);

    await tester.tap(find.text('Packed'));
    await tester.pump();

    expect(_picked(processor), ['packed']);
  });

  testWidgets('tapping the picked option of a single choice keeps it picked', (tester) async {
    final processor = await pumpSurface(tester, components: [_picker()], data: _relaxed);

    await tester.tap(find.text('Relaxed'));
    await tester.pump();

    expect(_picked(processor), ['relaxed']);
  });

  testWidgets('tapping an option of a multiple choice adds it', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_picker(variant: 'multipleSelection')],
      data: _relaxed,
    );

    await tester.tap(find.text('Packed'));
    await tester.pump();

    expect(_picked(processor), ['relaxed', 'packed']);
  });

  testWidgets("tapping an option of a multiple choice leaves out a pick that isn't among the options", (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_picker(variant: 'multipleSelection')],
      data: {
        'pace': ['relaxed', 'gone'],
      },
    );

    await tester.tap(find.text('Packed'));
    await tester.pump();

    expect(_picked(processor), ['relaxed', 'packed']);
  });

  testWidgets('a picker whose value is written as a list picks nothing, and is reported', (tester) async {
    final errors = <A2UIError>[];
    final processor = await pumpSurface(
      tester,
      components: [
        {
          ..._picker(),
          'value': ['relaxed'],
        },
      ],
      errors: errors,
    );

    await tester.tap(find.text('Packed'));
    await tester.pump();

    expect(processor.surface('s')!.read('/'), isEmpty);
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('tapping a picked option of a multiple choice removes it', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_picker(variant: 'multipleSelection')],
      data: _relaxed,
    );

    await tester.tap(find.text('Relaxed'));
    await tester.pump();

    expect(_picked(processor), isEmpty);
  });

  testWidgets('a single choice shows its options with radio buttons', (tester) async {
    await pumpSurface(tester, components: [_picker()], data: _relaxed);

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
  });

  testWidgets("a multiple choice shows its options with the design system's check boxes", (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(variant: 'multipleSelection')],
      data: _relaxed,
    );

    final boxes = tester.widgetList<StreamCheckbox>(find.byType(StreamCheckbox));
    expect(boxes, hasLength(2));
    expect(boxes.where((box) => box.props.value), hasLength(1));
  });

  testWidgets('a row of a multiple choice is one stop when moving focus with the keyboard', (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(variant: 'multipleSelection')],
      data: _relaxed,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final first = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    // Two options, two stops: the third press is back on the first row.
    expect(FocusManager.instance.primaryFocus, first);
  });

  testWidgets('a single choice shows no check boxes', (tester) async {
    await pumpSurface(tester, components: [_picker()], data: _relaxed);

    expect(find.byType(StreamCheckbox), findsNothing);
  });

  testWidgets('chips show their options without radio buttons or checkboxes', (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(displayStyle: 'chips')],
      data: _relaxed,
    );

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('chips are side by side', (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(displayStyle: 'chips')],
      data: _relaxed,
    );

    expect(tester.getTopLeft(find.text('Packed')).dy, tester.getTopLeft(find.text('Relaxed')).dy);
  });

  testWidgets('a picked chip is drawn in the accent color', (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(displayStyle: 'chips')],
      data: _relaxed,
    );

    expect(tester.widget<Text>(find.text('Relaxed')).style?.color, lightTheme().accent);
  });

  testWidgets('a picker shows its label', (tester) async {
    await pumpSurface(tester, components: [_picker()], data: _relaxed);

    expect(find.text('Pace'), findsOneWidget);
  });

  testWidgets("an option is read as checked when it's picked", (tester) async {
    await pumpSurface(tester, components: [_picker()], data: _relaxed);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Relaxed')),
      isSemantics(hasCheckedState: true, isChecked: true, isInMutuallyExclusiveGroup: true),
    );
  });

  testWidgets('the options of a multiple choice are not one of a group', (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(variant: 'multipleSelection')],
      data: _relaxed,
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Relaxed')),
      isSemantics(hasCheckedState: true, isInMutuallyExclusiveGroup: false),
    );
  });

  testWidgets("the options are read as a group with the agent's label and description", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          ..._picker(),
          'accessibility': {'label': 'Trip pace', 'description': 'How much to fit in a day'},
        },
      ],
      data: _relaxed,
    );

    expect(tester.getSemantics(find.bySemanticsLabel('Trip pace')), isSemantics(hint: 'How much to fit in a day'));
  });

  testWidgets('the options are read as a group named by the label', (tester) async {
    await pumpSurface(tester, components: [_picker()], data: _relaxed);

    expect(find.bySemanticsLabel('Pace'), findsOneWidget);
  });

  testWidgets("an option whose bound label isn't there yet shows its value", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _picker(
          options: [
            {
              'label': {'@path': '/labels/relaxed'},
              'value': 'relaxed',
            },
          ],
        ),
      ],
      data: _relaxed,
    );

    expect(find.text('relaxed'), findsOneWidget);
  });

  testWidgets("an option's label bound to the data model shows the data model's value", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _picker(
          options: [
            {
              'label': {'@path': '/labels/relaxed'},
              'value': 'relaxed',
            },
          ],
        ),
      ],
      data: {
        ..._relaxed,
        'labels': {'relaxed': 'Take it slow'},
      },
    );

    expect(find.text('Take it slow'), findsOneWidget);
  });

  testWidgets('the filter field has no fill', (tester) async {
    await pumpSurface(tester, components: [_picker(filterable: true)], data: _relaxed);

    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.filled, isFalse);
  });

  testWidgets('the filter field is outlined in the border color', (tester) async {
    await pumpSurface(tester, components: [_picker(filterable: true)], data: _relaxed);

    final border = tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, lightTheme().border);
  });

  testWidgets('a filterable picker shows only the options whose label holds the filter', (tester) async {
    await pumpSurface(tester, components: [_picker(filterable: true)], data: _relaxed);

    await tester.enterText(find.byType(TextField), 'pack');
    await tester.pump();

    expect(find.text('Relaxed'), findsNothing);
  });

  testWidgets('the filter keeps the options whose label holds it in any capitalization', (tester) async {
    await pumpSurface(tester, components: [_picker(filterable: true)], data: _relaxed);

    await tester.enterText(find.byType(TextField), 'PACK');
    await tester.pump();

    expect(find.text('Packed'), findsOneWidget);
  });

  testWidgets("the filter field's placeholder is the device's word for search", (tester) async {
    await pumpSurface(tester, components: [_picker(filterable: true)], data: _relaxed);

    expect(find.text(const DefaultMaterialLocalizations().searchFieldLabel), findsOneWidget);
  });

  testWidgets("a picker that isn't filterable has no filter field", (tester) async {
    await pumpSurface(tester, components: [_picker()], data: _relaxed);

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a filterable picker beside a text in a row without weights fills the rest of the row', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['caption', 'pace'],
        },
        {'id': 'caption', 'component': 'Text', 'text': 'How'},
        _picker(id: 'pace', filterable: true),
      ],
      data: _relaxed,
    );

    expect(tester.getTopRight(find.byType(TextField)).dx, 400);
  });

  testWidgets('a picker shows the messages of its failing checks', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _picker(
          checks: [
            {
              'condition': {
                '@call': 'required',
                'args': {
                  'value': {'@path': '/pace'},
                },
              },
              'message': 'Pick a pace.',
            },
          ],
        ),
      ],
      data: {'pace': <String>[]},
    );

    expect(find.text('Pick a pace.'), findsOneWidget);
  });

  testWidgets('every option is at least as tall as a person can tap', (tester) async {
    await pumpSurface(
      tester,
      components: [_picker(displayStyle: 'chips')],
      data: _relaxed,
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}

const _relaxed = {
  'pace': ['relaxed'],
};

Map<String, Object?> _picker({
  String id = 'root',
  String? variant,
  String? displayStyle,
  bool? filterable,
  List<Map<String, Object?>> options = const [
    {'label': 'Relaxed', 'value': 'relaxed'},
    {'label': 'Packed', 'value': 'packed'},
  ],
  List<Map<String, Object?>>? checks,
}) {
  return {
    'id': id,
    'component': 'ChoicePicker',
    'label': 'Pace',
    'options': options,
    'value': {'@path': '/pace'},
    'variant': ?variant,
    'displayStyle': ?displayStyle,
    'filterable': ?filterable,
    'checks': ?checks,
  };
}

Object? _picked(A2UIProcessor processor) => processor.surface('s')!.read('/pace');
