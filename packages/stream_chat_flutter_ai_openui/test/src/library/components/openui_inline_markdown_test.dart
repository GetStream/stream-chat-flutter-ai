import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../../openui_test_app.dart';

Future<OpenUIRuntime> _pump(WidgetTester tester, String program, {OpenUILibrary? library}) async {
  library ??= OpenUILibrary.chat;
  final runtime = testRuntime(library: library);
  addTearDown(runtime.dispose);
  await pumpOpenUI(tester, runtime, program: program, library: library);
  await tester.pump();
  return runtime;
}

void main() {
  group('block markers in a title', () {
    testWidgets('a ListBlock title and subtitle draw them as text', (tester) async {
      await _pump(tester, 'root = Card([ListBlock([ListItem("1. Paris", "# of orders")])])');

      expect(find.text('1. Paris'), findsOneWidget);
      expect(find.text('# of orders'), findsOneWidget);
    });

    testWidgets('an Accordion trigger draws them as text', (tester) async {
      await _pump(tester, 'root = Card([Accordion([AccordionItem("a", "1. Paris", [TextContent("First")])])])');

      expect(find.text('1. Paris'), findsOneWidget);
    });

    testWidgets('a SectionBlock trigger draws them as text, foldable or not', (tester) async {
      await _pump(
        tester,
        'root = Card([SectionBlock([SectionItem("a", "1. Paris", [TextContent("First")])]), '
        'SectionBlock([SectionItem("b", "# of orders", [TextContent("Second")])], false)])',
      );

      expect(find.text('1. Paris'), findsOneWidget);
      expect(find.text('# of orders'), findsOneWidget);
    });

    testWidgets('a Steps title draws them as text', (tester) async {
      await _pump(tester, 'root = Card([Steps([StepsItem("# of orders", "Details")])])');

      expect(find.text('# of orders'), findsOneWidget);
    });
  });

  group('Markdown in a choice label', () {
    testWidgets('a CheckBoxGroup and a SwitchGroup bold the label and description', (tester) async {
      await _pump(
        tester,
        'root = Stack([CheckBoxGroup("c", [CheckBoxItem("**Bold** box", "_soft_ note", "a")]), '
        'SwitchGroup("s", [SwitchItem("**Bold** switch", "", "b")])])',
        library: OpenUILibrary.standard,
      );

      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('Bold box', findRichText: true), findsOneWidget);
      expect(find.textContaining('soft note', findRichText: true), findsOneWidget);
      expect(find.textContaining('Bold switch', findRichText: true), findsOneWidget);
    });

    testWidgets('a RadioGroup label is Markdown and still chooses when tapped', (tester) async {
      final runtime = await _pump(
        tester,
        'root = Stack([RadioGroup("p", [RadioItem("**Free** plan", "", "free")])])',
        library: OpenUILibrary.standard,
      );

      expect(find.textContaining('**', findRichText: true), findsNothing);
      await tester.tap(find.textContaining('Free plan', findRichText: true));
      await tester.pump();

      expect(runtime.fieldValue(null, 'p'), const OpenUIString('free'));
    });

    testWidgets('an OptionCard title and subtitle are Markdown and still choose when tapped', (tester) async {
      final runtime = await _pump(
        tester,
        'root = Stack([OptionCards("p", null, [OptionCard("a", "**Basic** plan", "_cheap_ one")])])',
        library: OpenUILibrary.standard,
      );

      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('cheap one', findRichText: true), findsOneWidget);
      await tester.tap(find.textContaining('Basic plan', findRichText: true));
      await tester.pump();

      expect(runtime.fieldValue(null, 'p'), const OpenUIString('a'));
    });
  });
}
