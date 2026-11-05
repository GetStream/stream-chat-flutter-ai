import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_slider.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('dragging the slider writes the value it is at', (tester) async {
    final processor = await pumpSurface(tester, components: [_slider()], data: {'size': 1});

    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), 8);
  });

  testWidgets('a slider with steps writes only the value of a step', (tester) async {
    final processor = await pumpSurface(tester, components: [_slider()], data: {'size': 1});

    await tester.tap(find.byType(Slider));
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), anyOf(4, 5));
  });

  testWidgets('a step of whole ends is written as a whole number', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Slider',
          'min': 0,
          'max': 75,
          'steps': 15,
          'value': {'@path': '/size'},
        },
      ],
      data: {'size': 0},
    );

    tester.widget<Slider>(find.byType(Slider)).onChanged!(54.99999999999999);

    expect(processor.surface('s')!.read('/size'), 55);
  });

  testWidgets('a slider with steps has a division for each step', (tester) async {
    await pumpSurface(tester, components: [_slider()], data: {'size': 1});

    expect(tester.widget<Slider>(find.byType(Slider)).divisions, 7);
  });

  testWidgets('a slider without steps has no divisions', (tester) async {
    await pumpSurface(tester, components: [_slider(steps: null)], data: {'size': 1});

    expect(tester.widget<Slider>(find.byType(Slider)).divisions, isNull);
  });

  testWidgets('a slider shows its value', (tester) async {
    await pumpSurface(tester, components: [_slider()], data: {'size': 3});

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a slider shows its label', (tester) async {
    await pumpSurface(tester, components: [_slider()], data: {'size': 3});

    expect(find.text('Party size'), findsOneWidget);
  });

  testWidgets('a slider without a value writes its minimum once it shows', (tester) async {
    final processor = await pumpSurface(tester, components: [_slider()]);
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), 1);
  });

  testWidgets('a slider writing its minimum throws nothing while the surface builds', (tester) async {
    await pumpSurface(tester, components: [_slider()]);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a value above the maximum shows at the end', (tester) async {
    await pumpSurface(tester, components: [_slider()], data: {'size': 20});

    expect(tester.widget<Slider>(find.byType(Slider)).value, 8);
  });

  testWidgets('a value above the maximum is written as the end once it shows', (tester) async {
    final processor = await pumpSurface(tester, components: [_slider()], data: {'size': 20});
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), 8);
  });

  testWidgets('a value below the minimum is written as the start once it shows', (tester) async {
    final processor = await pumpSurface(tester, components: [_slider()], data: {'size': -3});
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), 1);
  });

  testWidgets("a value that isn't a number is written as the minimum, and reported", (tester) async {
    final errors = <A2UIError>[];
    final processor = await pumpSurface(tester, components: [_slider()], data: {'size': 'big'}, errors: errors);
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), 1);
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('a value within the range is left as it is', (tester) async {
    final processor = await pumpSurface(tester, components: [_slider()], data: {'size': 3});
    await tester.pump();

    expect(processor.surface('s')!.read('/size'), 3);
  });

  testWidgets("a slider whose value is written as a number can't be moved, and is reported", (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(
      tester,
      components: [
        {..._slider(), 'value': 3},
      ],
      errors: errors,
    );
    await tester.pump();

    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('a slider is read with its label and its value', (tester) async {
    await pumpSurface(tester, components: [_slider()], data: {'size': 3});

    expect(
      tester.getSemantics(find.byType(Slider)),
      isSemantics(label: 'Party size', value: '3', isSlider: true, hasIncreaseAction: true),
    );
  });

  testWidgets("a slider is read with the agent's label and description", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          ..._slider(),
          'accessibility': {'label': 'Guests', 'description': 'How many are coming'},
        },
      ],
      data: {'size': 3},
    );

    expect(
      tester.getSemantics(find.byType(Slider)),
      isSemantics(label: 'Guests', hint: 'How many are coming', isSlider: true),
    );
  });

  testWidgets('a slider shows the messages of its failing checks', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          ..._slider(),
          'checks': [
            {
              'condition': {'@path': '/enough'},
              'message': 'Pick two or more.',
            },
          ],
        },
      ],
      data: {'size': 1, 'enough': false},
    );

    expect(find.text('Pick two or more.'), findsOneWidget);
  });

  testWidgets('a slider beside a text in a row without weights fills the rest of the row', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['caption', 'size'],
        },
        {'id': 'caption', 'component': 'Text', 'text': 'Guests'},
        _slider(id: 'size'),
      ],
      data: {'size': 2},
    );

    expect(tester.getTopRight(find.byType(Slider)).dx, 400);
  });

  test('the range starts at 0 without a minimum', () {
    expect(a2uiSliderRange(null, 10), (min: 0.0, max: 10.0));
  });

  test('the range ends one past its start when the maximum is not above it', () {
    expect(a2uiSliderRange(5, 5), (min: 5.0, max: 6.0));
  });

  test('the range ends one past its start without a maximum', () {
    expect(a2uiSliderRange(5, null), (min: 5.0, max: 6.0));
  });

  test('the range is kept within 10 to the 15th either way', () {
    expect(a2uiSliderRange(-1e300, 1e300), (min: -1e15, max: 1e15));
  });
}

Map<String, Object?> _slider({String id = 'root', int? steps = 7}) {
  return {
    'id': id,
    'component': 'Slider',
    'label': 'Party size',
    'min': 1,
    'max': 8,
    'steps': ?steps,
    'value': {'@path': '/size'},
  };
}
