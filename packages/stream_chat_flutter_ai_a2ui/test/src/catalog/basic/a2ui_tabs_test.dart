import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('the first tab is selected at first', (tester) async {
    await _pumpTabs(tester);

    expect(find.text('Saturday plan'), findsOneWidget);
  });

  testWidgets("the selected tab's child is at the start", (tester) async {
    await _pumpTabs(tester);

    expect(tester.getTopLeft(find.text('Saturday plan')).dx, 0);
  });

  testWidgets("only the selected tab's child shows", (tester) async {
    await _pumpTabs(tester);

    expect(find.text('Sunday plan'), findsNothing);
  });

  testWidgets("tapping a tab's title shows its child", (tester) async {
    await _pumpTabs(tester);

    await tester.tap(find.text('Sunday'));
    await tester.pump();

    expect(find.text('Sunday plan'), findsOneWidget);
  });

  testWidgets('every tab shows its title', (tester) async {
    await _pumpTabs(tester);

    expect([find.text('Saturday'), find.text('Sunday')], everyElement(findsOneWidget));
  });

  testWidgets("the selected tab's title is in the accent color", (tester) async {
    await _pumpTabs(tester);

    expect(tester.widget<Text>(find.text('Saturday')).style?.color, lightTheme().accent);
  });

  testWidgets('another tab title is in the secondary text color', (tester) async {
    await _pumpTabs(tester);

    expect(tester.widget<Text>(find.text('Sunday')).style?.color, lightTheme().secondaryText);
  });

  testWidgets('a title bound to the data model shows its value', (tester) async {
    await _pumpTabs(
      tester,
      saturdayTitle: {'@path': '/day'},
      data: {'day': 'Sat'},
    );

    expect(find.text('Sat'), findsOneWidget);
  });

  testWidgets('a tab whose child has not arrived shows its title', (tester) async {
    await _pumpTabs(tester, sundayChild: 'later');

    expect(find.text('Sunday'), findsOneWidget);
  });

  testWidgets("selecting a tab whose child has not arrived shows no other tab's child", (tester) async {
    await _pumpTabs(tester, sundayChild: 'later');

    await tester.tap(find.text('Sunday'));
    await tester.pump();

    expect(find.text('Saturday plan'), findsNothing);
  });

  testWidgets('the selected tab stays selected when the child of a tab before it arrives', (tester) async {
    final processor = await _pumpTabs(tester, sundayChild: 'later', withMonday: true);
    await tester.tap(find.text('Monday'));
    await tester.pump();

    processor.apply([
      updateComponents([_text('later', 'Sunday plan')]),
    ]);
    await tester.pump();

    expect(find.text('Monday plan'), findsOneWidget);
  });

  testWidgets('a selected tab that the agent removes selects the last tab', (tester) async {
    final processor = await _pumpTabs(tester, withMonday: true);
    await tester.tap(find.text('Monday'));
    await tester.pump();

    processor.apply([
      updateComponents([_tabs(saturdayTitle: 'Saturday')]),
    ]);
    await tester.pump();

    expect(find.text('Sunday plan'), findsOneWidget);
  });

  testWidgets('a selected tab that the agent removes and adds back is selected again', (tester) async {
    final processor = await _pumpTabs(tester, withMonday: true);
    await tester.tap(find.text('Monday'));
    await tester.pump();

    processor.apply([
      updateComponents([_tabs(saturdayTitle: 'Saturday')]),
    ]);
    await tester.pump();
    processor.apply([
      updateComponents([_tabs(saturdayTitle: 'Saturday', withMonday: true)]),
    ]);
    await tester.pump();

    expect(find.text('Monday plan'), findsOneWidget);
  });

  testWidgets('the selected tab stays selected when the agent adds accessibility to the Tabs', (tester) async {
    final processor = await _pumpTabs(tester);
    await tester.tap(find.text('Sunday'));
    await tester.pump();

    processor.apply([
      updateComponents([
        _tabs(
          saturdayTitle: 'Saturday',
          accessibility: {'label': 'Weekend'},
        ),
      ]),
    ]);
    await tester.pump();

    expect(find.text('Sunday plan'), findsOneWidget);
  });

  testWidgets('the selected tab stays selected when the agent removes accessibility from the Tabs', (tester) async {
    final processor = await _pumpTabs(tester, accessibility: {'label': 'Weekend'});
    await tester.tap(find.text('Sunday'));
    await tester.pump();

    processor.apply([
      updateComponents([_tabs(saturdayTitle: 'Saturday')]),
    ]);
    await tester.pump();

    expect(find.text('Sunday plan'), findsOneWidget);
  });

  testWidgets('a Tabs in a horizontal list lays out without an error', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'List',
          'direction': 'horizontal',
          'children': ['tabs'],
        },
        {..._tabs(saturdayTitle: 'Saturday'), 'id': 'tabs'},
        _text('saturday', 'Saturday plan'),
        _text('sunday', 'Sunday plan'),
      ],
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets("a tab's title is a button", (tester) async {
    await _pumpTabs(tester);

    expect(
      tester.getSemantics(find.text('Sunday')),
      matchesSemantics(label: 'Sunday', isButton: true, hasTapAction: true, hasSelectedState: true),
    );
  });

  testWidgets("the selected tab's title is selected", (tester) async {
    await _pumpTabs(tester);

    expect(
      tester.getSemantics(find.text('Saturday')),
      matchesSemantics(label: 'Saturday', isButton: true, hasTapAction: true, hasSelectedState: true, isSelected: true),
    );
  });

  testWidgets("a tab's title is as tall as a finger can tap", (tester) async {
    await _pumpTabs(tester);

    // `androidTapTargetGuideline` skips a target at the screen's edge, as the
    // titles here are, so the height is checked against its least, 48.
    expect(tester.getSemantics(find.text('Sunday')).rect.height, greaterThanOrEqualTo(48));
  });
}

// A text component.
Map<String, Object?> _text(String id, String text) => {'id': id, 'component': 'Text', 'text': text};

// The root Tabs: Saturday, Sunday, and Monday when [withMonday], each showing
// the component of its day's id unless [sundayChild] names another for
// Sunday.
Map<String, Object?> _tabs({
  required Object saturdayTitle,
  String sundayChild = 'sunday',
  bool withMonday = false,
  Map<String, Object?>? accessibility,
}) => {
  'id': 'root',
  'component': 'Tabs',
  'tabs': [
    {'title': saturdayTitle, 'child': 'saturday'},
    {'title': 'Sunday', 'child': sundayChild},
    if (withMonday) {'title': 'Monday', 'child': 'monday'},
  ],
  'accessibility': ?accessibility,
};

// Shows the root Tabs of [_tabs] with a text plan for each day, and returns
// the processor.
Future<A2UIProcessor> _pumpTabs(
  WidgetTester tester, {
  Object saturdayTitle = 'Saturday',
  String sundayChild = 'sunday',
  bool withMonday = false,
  Map<String, Object?>? accessibility,
  Map<String, Object?> data = const {},
}) {
  return pumpSurface(
    tester,
    components: [
      _tabs(
        saturdayTitle: saturdayTitle,
        sundayChild: sundayChild,
        withMonday: withMonday,
        accessibility: accessibility,
      ),
      _text('saturday', 'Saturday plan'),
      if (sundayChild == 'sunday') _text('sunday', 'Sunday plan'),
      if (withMonday) _text('monday', 'Monday plan'),
    ],
    data: data,
  );
}
