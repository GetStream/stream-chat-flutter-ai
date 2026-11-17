import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_core_flutter/core.dart';

import '../../openui_test_app.dart';

Future<void> _pump(WidgetTester tester, String program) async {
  final library = OpenUILibrary.standard;
  final runtime = testRuntime(library: library);
  addTearDown(runtime.dispose);
  await pumpOpenUI(tester, runtime, program: program, library: library);
  await tester.pump();
}

void main() {
  final icons = StreamTheme.light().icons;

  group('OptionCards topContent', () {
    testWidgets('an icon the name does not find draws the category icon', (tester) async {
      await _pump(
        tester,
        'root = Stack([OptionCards("p", null, [OptionCard("a", "Basic", null, Icon("no-such-icon", "mail"))])])',
      );

      expect(find.byIcon(openUIIconOf(icons, 'mail')), findsOneWidget);
    });

    testWidgets('an icon the name does not find, with no category, draws the generic icon', (tester) async {
      await _pump(
        tester,
        'root = Stack([OptionCards("p", null, [OptionCard("a", "Basic", null, Icon("no-such-icon"))])])',
      );

      expect(find.byIcon(openUIIconOf(icons, 'no-such-icon')), findsOneWidget);
    });
  });

  group('semantics of a choice', () {
    testWidgets('Chips that choose several are checkboxes', (tester) async {
      await _pump(tester, 'root = Stack([Chips("t", "multiple", [ChipItem("a", "A"), ChipItem("b", "B")])])');
      await tester.tap(find.text('A'));
      await tester.pump();

      final chosen = tester.getSemantics(find.text('A')).flagsCollection;
      expect(chosen.isChecked, CheckedState.isTrue);
      expect(chosen.isInMutuallyExclusiveGroup, isFalse);
      final other = tester.getSemantics(find.text('B')).flagsCollection;
      expect(other.isChecked, CheckedState.isFalse);
    });

    testWidgets('Chips that choose one are radio buttons', (tester) async {
      await _pump(tester, 'root = Stack([Chips("t", "single", [ChipItem("a", "A"), ChipItem("b", "B")])])');
      await tester.tap(find.text('A'));
      await tester.pump();

      final chosen = tester.getSemantics(find.text('A')).flagsCollection;
      expect(chosen.isChecked, CheckedState.isTrue);
      expect(chosen.isInMutuallyExclusiveGroup, isTrue);
      expect(tester.getSemantics(find.text('B')).flagsCollection.isChecked, CheckedState.isFalse);
    });

    testWidgets('OptionCards that choose one are radio buttons', (tester) async {
      await _pump(
        tester,
        'root = Stack([OptionCards("p", null, [OptionCard("a", "Basic"), OptionCard("b", "Plus")])])',
      );
      await tester.tap(find.text('Basic'));
      await tester.pump();

      final chosen = tester.getSemantics(find.text('Basic')).flagsCollection;
      expect(chosen.isChecked, CheckedState.isTrue);
      expect(chosen.isInMutuallyExclusiveGroup, isTrue);
    });

    testWidgets('OptionCards that choose several are checkboxes', (tester) async {
      await _pump(tester, 'root = Stack([OptionCards("p", "multiple", [OptionCard("a", "Basic")])])');

      final card = tester.getSemantics(find.text('Basic')).flagsCollection;
      expect(card.isChecked, CheckedState.isFalse);
      expect(card.isInMutuallyExclusiveGroup, isFalse);
    });

    testWidgets('a CheckBoxGroup item reads as a checked or unchecked box', (tester) async {
      await _pump(
        tester,
        'root = Stack([CheckBoxGroup("c", [CheckBoxItem("A", "", "a", true), CheckBoxItem("B", "", "b")])])',
      );

      expect(tester.getSemantics(find.text('A')).flagsCollection.isChecked, CheckedState.isTrue);
      expect(tester.getSemantics(find.text('B')).flagsCollection.isChecked, CheckedState.isFalse);
    });

    testWidgets('a SwitchGroup item reads as a switch that is on or off', (tester) async {
      await _pump(
        tester,
        'root = Stack([SwitchGroup("s", [SwitchItem("A", "", "a", true), SwitchItem("B", "", "b")])])',
      );

      expect(tester.getSemantics(find.text('A')).flagsCollection.isToggled, Tristate.isTrue);
      expect(tester.getSemantics(find.text('B')).flagsCollection.isToggled, Tristate.isFalse);
    });
  });
}
