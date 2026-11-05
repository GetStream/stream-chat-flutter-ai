import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('tapping an unchecked box writes true', (tester) async {
    final processor = await pumpSurface(tester, components: [_box()], data: {'subscribe': false});

    await tester.tap(find.text('Subscribe'));
    await tester.pump();

    expect(processor.surface('s')!.read('/subscribe'), isTrue);
  });

  testWidgets('tapping a checked box writes false', (tester) async {
    final processor = await pumpSurface(tester, components: [_box()], data: {'subscribe': true});

    await tester.tap(find.text('Subscribe'));
    await tester.pump();

    expect(processor.surface('s')!.read('/subscribe'), isFalse);
  });

  testWidgets('a box whose value is written as true stays as it is when tapped', (tester) async {
    final processor = await pumpSurface(tester, components: [_box(value: true)]);

    await tester.tap(find.text('Subscribe'));
    await tester.pump();

    expect(processor.surface('s')!.read('/'), isEmpty);
  });

  testWidgets('a box whose value is written as true is fainter, and reported', (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(tester, components: [_box(value: true)], errors: errors);

    expect(
      tester.widget<Opacity>(find.ancestor(of: find.text('Subscribe'), matching: find.byType(Opacity)).first).opacity,
      lessThan(1),
    );
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('a checked box is drawn in the accent color', (tester) async {
    await pumpSurface(tester, components: [_box()], data: {'subscribe': true});

    expect(tester.widget<Icon>(find.byIcon(Icons.check_box_rounded)).color, lightTheme().accent);
  });

  testWidgets('an unchecked box is drawn empty', (tester) async {
    await pumpSurface(tester, components: [_box()], data: {'subscribe': false});

    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
  });

  testWidgets('a checked box is read as checked', (tester) async {
    await pumpSurface(tester, components: [_box()], data: {'subscribe': true});

    expect(
      tester.getSemantics(find.bySemanticsLabel('Subscribe')),
      isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: true),
    );
  });

  testWidgets('an unchecked box is read as unchecked', (tester) async {
    await pumpSurface(tester, components: [_box()], data: {'subscribe': false});

    expect(
      tester.getSemantics(find.bySemanticsLabel('Subscribe')),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
  });

  testWidgets("a box is read with the agent's accessibility label", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _box(accessibility: {'label': 'Send me the newsletter'}),
      ],
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Send me the newsletter')),
      isSemantics(hasCheckedState: true),
    );
  });

  testWidgets('a box shows the messages of its failing checks', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _box(
          checks: [
            {
              'condition': {'@path': '/subscribe'},
              'message': 'Subscribe to go on.',
            },
          ],
        ),
      ],
      data: {'subscribe': false},
    );

    expect(find.text('Subscribe to go on.'), findsOneWidget);
  });

  testWidgets('a box is at least as tall as a person can tap', (tester) async {
    await pumpSurface(tester, components: [_box()]);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}

Map<String, Object?> _box({
  Object value = const {'@path': '/subscribe'},
  List<Map<String, Object?>>? checks,
  Map<String, Object?>? accessibility,
}) {
  return {
    'id': 'root',
    'component': 'CheckBox',
    'label': 'Subscribe',
    'value': value,
    'checks': ?checks,
    'accessibility': ?accessibility,
  };
}
