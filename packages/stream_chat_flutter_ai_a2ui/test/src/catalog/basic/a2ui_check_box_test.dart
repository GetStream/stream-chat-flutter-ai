import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('tapping an unchecked box writes true', (tester) async {
    final processor = await pumpSurface(tester, components: [_box()], data: {'subscribe': false});

    await tester.tap(find.text('Subscribe'));
    await tester.pump();

    expect(processor.surface('s')!.read('/subscribe'), isTrue);
  });

  testWidgets('tapping the box itself writes the other value', (tester) async {
    final processor = await pumpSurface(tester, components: [_box()], data: {'subscribe': false});

    await tester.tap(find.byType(StreamCheckbox));
    await tester.pump();

    expect(processor.surface('s')!.read('/subscribe'), isTrue);
  });

  testWidgets('a box is one stop when moving focus with the keyboard', (tester) async {
    await pumpSurface(tester, components: [_box()]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final first = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, first);
  });

  testWidgets("the app's check box builder draws the box", (tester) async {
    await pumpSurface(
      tester,
      components: [_box()],
      data: {'subscribe': true},
      builders: StreamComponentBuilders(checkbox: (context, props) => Text('App box ${props.value}')),
    );

    expect(find.text('App box true'), findsOneWidget);
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
    const accent = Color(0xFF123456);
    await pumpSurface(
      tester,
      components: [_box()],
      data: {'subscribe': true},
      theme: A2UIThemeData(accent: accent),
    );

    final style = tester.widget<IconButton>(find.byType(IconButton)).style!;

    expect(style.backgroundColor!.resolve({WidgetState.selected}), accent);
  });

  testWidgets("the app's check box builder writes the value through the props", (tester) async {
    late StreamCheckboxProps props;
    final processor = await pumpSurface(
      tester,
      components: [_box()],
      data: {'subscribe': false},
      builders: StreamComponentBuilders(
        checkbox: (context, value) {
          props = value;
          return const SizedBox();
        },
      ),
    );

    props.onChanged!(true);

    expect(processor.surface('s')!.read('/subscribe'), isTrue);
  });

  testWidgets("the app's check box builder is given no way to change a box whose value isn't bound", (tester) async {
    late StreamCheckboxProps props;
    await pumpSurface(
      tester,
      components: [_box(value: true)],
      builders: StreamComponentBuilders(
        checkbox: (context, value) {
          props = value;
          return const SizedBox();
        },
      ),
    );

    expect(props.onChanged, isNull);
  });

  testWidgets('a box shows under a Material 2 theme with no Material around it', (tester) async {
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      createSurface([_box()], data: {'subscribe': true}),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false, extensions: [StreamTheme.light()]),
        home: A2UISurfaceView(surface: processor.surface('s')!),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StreamCheckbox), findsOneWidget);
  });

  testWidgets('an unchecked box is drawn empty', (tester) async {
    await pumpSurface(tester, components: [_box()], data: {'subscribe': false});

    expect(tester.widget<StreamCheckbox>(find.byType(StreamCheckbox)).props.value, isFalse);
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
