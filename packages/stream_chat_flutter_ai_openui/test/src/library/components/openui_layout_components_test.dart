import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../openui_test_app.dart';

final _standard = OpenUILibrary.standard;
final _theme = OpenUIThemeData.defaults(StreamTheme.light());

Future<(OpenUIRuntime, List<OpenUIActionEvent>)> _pump(
  WidgetTester tester,
  String program, {
  bool isStreaming = false,
  OpenUILibrary? library,
}) async {
  final lib = library ?? _standard;
  final runtime = testRuntime(library: lib);
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  await pumpOpenUI(tester, runtime, program: program, isStreaming: isStreaming, library: lib);
  await tester.pump();
  return (runtime, events);
}

// Rebuilds the view after [runtime] reads [program].
Future<void> _update(
  WidgetTester tester,
  OpenUIRuntime runtime,
  String program, {
  bool isStreaming = false,
  OpenUILibrary? library,
}) async {
  runtime.update(program, isStreaming: isStreaming);
  await pumpOpenUI(tester, runtime, library: library ?? _standard);
  await tester.pump();
}

class _Counted extends SingleChildRenderObjectWidget {
  const _Counted() : super(child: const SizedBox(height: 10));

  static int layouts = 0;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCounted();
}

class _RenderCounted extends RenderProxyBox {
  @override
  void performLayout() {
    _Counted.layouts++;
    super.performLayout();
  }
}

void main() {
  group('Stack', () {
    testWidgets('a column stretches its children, gap apart', (tester) async {
      await _pump(tester, 'root = Stack([TextContent("A"), TextContent("B")], "column", "l")');

      final a = tester.getRect(find.text('A'));
      final b = tester.getRect(find.text('B'));
      expect(b.top - a.bottom, greaterThanOrEqualTo(_theme.lSpacing!));
      final column = tester.widget<Column>(find.ancestor(of: find.text('A'), matching: find.byType(Column)).last);
      expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
    });

    testWidgets('a row of cards shares its width equally', (tester) async {
      await _pump(tester, 'root = Stack([Card([TextContent("A")]), Card([TextContent("B")])], "row", "none")');

      final cards = tester.widgetList<Expanded>(find.byType(Expanded));
      expect(cards, hasLength(greaterThanOrEqualTo(2)));
      final left = tester.getRect(find.ancestor(of: find.text('A'), matching: find.byType(DecoratedBox)).last);
      final right = tester.getRect(find.ancestor(of: find.text('B'), matching: find.byType(DecoratedBox)).last);
      expect(left.width, closeTo(right.width, 0.01));
      expect(left.width, closeTo(180, 0.01));
    });

    testWidgets('a row is laid out from the right in a right-to-left app', (tester) async {
      final runtime = testRuntime(library: _standard);
      addTearDown(runtime.dispose);
      runtime.update('root = Stack([Tag("A"), Tag("B")], "row")', isStreaming: false);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: testApp(
            Directionality(
              textDirection: TextDirection.rtl,
              child: OpenUIView(runtime: runtime, library: _standard),
            ),
          ),
        ),
      );

      expect(tester.getCenter(find.text('A')).dx, greaterThan(tester.getCenter(find.text('B')).dx));
    });

    testWidgets('a wrapping row of cards is a grid of equal columns', (tester) async {
      await _pump(
        tester,
        'root = Stack([Card([TextContent("A")]), Card([TextContent("B")]), Card([TextContent("C")])], "row", "none", null, null, true)',
      );

      // 360 wide, 140 at least: two columns of 180, the third card below.
      expect(tester.getTopLeft(find.text('C')).dy, greaterThan(tester.getBottomLeft(find.text('A')).dy));
      expect(tester.getTopLeft(find.text('B')).dx, greaterThan(170));
    });

    testWidgets('a justified row spreads its children', (tester) async {
      await _pump(tester, 'root = Stack([Tag("A"), Tag("B")], "row", "none", null, "between")');

      expect(tester.getTopRight(find.text('B')).dx, greaterThan(340));
    });

    testWidgets('twelve nested stacks lay their content out once', (tester) async {
      final library = _standard.replacing('TextContent', (context, scope) => const _Counted());
      final program = StringBuffer('root = ');
      for (var i = 0; i < 12; i++) {
        program.write('Stack([');
      }
      program.write('TextContent("x")');
      for (var i = 0; i < 12; i++) {
        program.write('], "row")');
      }
      _Counted.layouts = 0;

      await _pump(tester, program.toString(), library: library);

      expect(find.byType(_Counted), findsOneWidget);
      expect(_Counted.layouts, 1);
    });
  });

  group('standard Card', () {
    testWidgets('draws its variant surface', (tester) async {
      await _pump(
        tester,
        'root = Stack([Card([TextContent("A")]), Card([TextContent("B")], "sunk"), Card([TextContent("C")], "clear")])',
      );

      BoxDecoration? surface(String text) => tester
          .widgetList<DecoratedBox>(find.ancestor(of: find.text(text), matching: find.byType(DecoratedBox)))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.color != null)
          .firstOrNull;
      expect(surface('A')!.color, _theme.surface);
      expect(surface('A')!.borderRadius, BorderRadius.circular(_theme.cornerRadius!));
      expect(surface('B')!.color, _theme.sunkenSurface);
      expect(surface('C'), isNull);
    });
  });

  group('Tabs', () {
    const program =
        'root = Stack([Tabs([TabItem("a", "One", [TextContent("First")]), TabItem("b", "Two", [TextContent("Second")])])])';

    testWidgets('shows the first tab, and the one tapped', (tester) async {
      await _pump(tester, program);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);

      await tester.tap(find.text('Two'));
      await tester.pump();

      expect(find.text('Second'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Two')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Two',
        ),
      );
    });

    for (final (name, stream) in [('light', StreamTheme.light()), ('dark', StreamTheme.dark())]) {
      testWidgets("draws the bar in the theme's subtle fill, outlined, in $name mode", (tester) async {
        final theme = OpenUIThemeData.defaults(stream);
        final runtime = testRuntime(library: _standard);
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, program: program, library: _standard, stream: stream);
        await tester.pump();

        BoxDecoration decorationOf(String label, int index) =>
            tester
                    .widget<DecoratedBox>(
                      find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)).at(index),
                    )
                    .decoration
                as BoxDecoration;

        // The pill of the selected tab, then the bar around all the tabs.
        final pill = decorationOf('One', 0);
        final bar = decorationOf('One', 1);
        expect(bar.color, theme.subtleFill);
        expect(bar.border, Border.all(color: theme.border!));
        expect(pill.color, theme.surface);
        expect(pill.border, Border.all(color: theme.border!));
        expect(decorationOf('Two', 0).color, isNull);
        expect(bar.color, isNot(theme.sunkenSurface));
      });
    }

    testWidgets('follows the tab that grows while streaming, until one is tapped', (tester) async {
      final (runtime, _) = await _pump(
        tester,
        'root = Stack([Tabs([TabItem("a", "One", [TextContent("First")])])])',
        isStreaming: true,
      );
      await _update(tester, runtime, program, isStreaming: true);
      expect(find.text('Second'), findsOneWidget);

      await tester.tap(find.text('One'));
      await tester.pump();
      await _update(
        tester,
        runtime,
        'root = Stack([Tabs([TabItem("a", "One", [TextContent("First")]), TabItem("b", "Two", [TextContent("Second more")])])])',
        isStreaming: true,
      );
      expect(find.text('First'), findsOneWidget);
    });
  });

  group('Accordion', () {
    testWidgets('opens one item at a time', (tester) async {
      await _pump(
        tester,
        'root = Stack([Accordion([AccordionItem("a", "One", [TextContent("First")]), AccordionItem("b", "Two", [TextContent("Second")])])])',
      );
      expect(find.text('First'), findsNothing);

      await tester.tap(find.text('One'));
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      expect(tester.getSemantics(find.text('One')).flagsCollection.isExpanded, Tristate.isTrue);

      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('opens each item that arrives while streaming', (tester) async {
      final (runtime, _) = await _pump(
        tester,
        'root = Stack([Accordion([AccordionItem("a", "One", [TextContent("First")])])])',
        isStreaming: true,
      );
      expect(find.text('First'), findsOneWidget);

      await _update(
        tester,
        runtime,
        'root = Stack([Accordion([AccordionItem("a", "One", [TextContent("First")]), AccordionItem("b", "Two", [TextContent("Second")])])])',
        isStreaming: true,
      );
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
    });
  });

  group('SectionBlock', () {
    const two =
        'root = Card([SectionBlock([SectionItem("a", "One", [TextContent("First")]), SectionItem("b", "Two", [TextContent("Second")])])])';

    testWidgets('opens arriving sections while streaming and only the first once it ends', (tester) async {
      final (runtime, _) = await _pump(
        tester,
        'root = Card([SectionBlock([SectionItem("a", "One", [TextContent("First")])])])',
        isStreaming: true,
        library: OpenUILibrary.chat,
      );
      await _update(tester, runtime, two, isStreaming: true, library: OpenUILibrary.chat);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      await _update(tester, runtime, two, library: OpenUILibrary.chat);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('a section block that does not fold shows every section under its heading', (tester) async {
      await _pump(
        tester,
        'root = Card([SectionBlock([SectionItem("a", "One", [TextContent("First")]), SectionItem("b", "Two", [TextContent("Second")])], false)])',
        library: OpenUILibrary.chat,
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });
  });

  testWidgets('Steps number their items', (tester) async {
    await _pump(tester, 'root = Stack([Steps([StepsItem("Open", "the app"), StepsItem("Tap", "the button")])])');

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Tap')).dy, greaterThan(tester.getTopLeft(find.text('Open')).dy));
  });

  testWidgets('a Carousel shows one slide and moves to the next', (tester) async {
    await _pump(tester, 'root = Stack([Carousel([[TextContent("First")], [TextContent("Second")]])])');
    expect(find.text('First'), findsOneWidget);
    expect(find.bySemanticsLabel('Slide 1 of 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    expect(find.bySemanticsLabel('Slide 2 of 2'), findsOneWidget);
  });

  group('Modal', () {
    const program = r'''
$open = false
root = Stack([Button("Show", @Set($open, true)), Modal("Details", $open, [TextContent("Inside")])])
''';

    testWidgets('opens when its variable turns true and writes false when dismissed', (tester) async {
      final (runtime, _) = await _pump(tester, program);
      expect(find.text('Inside'), findsNothing);

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Inside'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsNothing);
      expect(runtime.state.value[r'$open'], const OpenUIBool(false));
    });

    testWidgets('closes when its variable turns false', (tester) async {
      final (runtime, _) = await _pump(tester, r'''
$open = true
root = Stack([Modal("Details", $open, [Button("Hide", @Set($open, false))])])
''');
      await tester.pumpAndSettle();
      expect(find.text('Hide'), findsOneWidget);

      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(find.text('Hide'), findsNothing);
      expect(runtime.state.value[r'$open'], const OpenUIBool(false));
    });

    testWidgets('without a binding opens when open is true and stays closed once dismissed', (tester) async {
      final (runtime, _) = await _pump(tester, 'root = Stack([Modal("Note", true, [TextContent("Hi")])])');
      await tester.pumpAndSettle();
      expect(find.text('Hi'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _update(tester, runtime, 'root = Stack([Modal("Note", true, [TextContent("Hi")])])');
      await tester.pumpAndSettle();

      expect(find.text('Hi'), findsNothing);
      expect(runtime.state.value.keys, isNot(contains('open')));
    });

    testWidgets('closes when it leaves the reply, and its content updates while open', (tester) async {
      final (runtime, _) = await _pump(tester, 'root = Stack([Modal("Note", true, [TextContent("Hi")])])');
      await tester.pumpAndSettle();

      await _update(tester, runtime, 'root = Stack([Modal("Note", true, [TextContent("Hello")])])');
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);

      await _update(tester, runtime, 'root = Stack([TextContent("Gone")])');
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });
  });

  group('Table', () {
    testWidgets('pages its rows ten at a time', (tester) async {
      final data = [for (var i = 1; i <= 12; i++) '"r$i"'].join(', ');
      await _pump(tester, 'root = Stack([Table([Col("Name", [$data])])])');
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('r10'), findsOneWidget);
      expect(find.text('r11'), findsNothing);
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();

      expect(find.text('r11'), findsOneWidget);
      expect(find.text('r1'), findsNothing);
    });

    testWidgets('aligns a numeric column to the end and shows a dash for a missing cell', (tester) async {
      await _pump(tester, 'root = Stack([Table([Col("Name", ["a", "b"]), Col("Count", [1])])])');

      expect(tester.widget<Text>(find.text('1')).textAlign, TextAlign.end);
      expect(find.text('—'), findsOneWidget);
    });
  });

  testWidgets('an EditableTable counts edits and saves them under its name', (tester) async {
    final (runtime, events) = await _pump(
      tester,
      'root = Stack([EditableTable("items", [{type: "text", key: "name", header: "Name"}], [{id: "1", values: ["Pen"]}])])',
    );

    await tester.enterText(find.byType(TextField), 'Ink');
    await tester.pump();
    expect(find.text('1 change'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pump();

    expect(events.single.label, 'Save Changes');
    expect(events.single.formName, 'items');
    expect(
      runtime.fieldValue('items', 'items'),
      OpenUIValue.fromJson(const [
        {
          'id': '1',
          'values': ['Ink'],
        },
      ]),
    );
    expect(find.text('1 change'), findsNothing);
  });

  testWidgets('EditableTable columns without a key keep their own cells', (tester) async {
    await _pump(
      tester,
      'root = Stack([EditableTable("t", [{type: "text", header: "A"}, {type: "text", header: "B"}], [{id: "1", values: ["x", "y"]}])])',
    );

    expect(tester.widgetList<EditableText>(find.byType(EditableText)).map((field) => field.controller.text), [
      'x',
      'y',
    ]);
  });

  group('actions', () {
    testWidgets('a list item with an action runs it labelled with its title', (tester) async {
      final (_, events) = await _pump(
        tester,
        'root = Stack([ListBlock([ListItem("Paris", "France", null, "Go", @ToAssistant("Tell me about Paris")), ListItem("Rome")])])',
      );

      await tester.tap(find.text('Paris'));
      await tester.pump();
      await tester.tap(find.text('Rome'));
      await tester.pump();

      expect(events.single.label, 'Paris');
      expect(events.single.message, 'Tell me about Paris');
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('a follow-up sends its text', (tester) async {
      final (_, events) = await _pump(
        tester,
        'root = Card([FollowUpBlock([FollowUpItem("And Rome?")])])',
        library: OpenUILibrary.chat,
      );

      await tester.tap(find.text('And Rome?'));
      await tester.pump();

      expect(events.single.message, 'And Rome?');
    });

    testWidgets('nothing runs while the reply streams', (tester) async {
      final (_, events) = await _pump(
        tester,
        'root = Card([FollowUpBlock([FollowUpItem("And Rome?")]), ListBlock([ListItem("Paris", null, null, null, @ToAssistant("x"))]), SnippetCardBlock([SnippetCardItem("s", IconText(Icon("star"), "soft", "s", "Tip"))], null, null, {type: "pick"})])',
        isStreaming: true,
        library: OpenUILibrary.chat,
      );

      await tester.tap(find.text('And Rome?'));
      await tester.tap(find.text('Paris'));
      await tester.tap(find.text('Tip'));
      await tester.pump();

      expect(events, isEmpty);
    });

    testWidgets('a card item runs its block action with what the item shows', (tester) async {
      final (_, events) = await _pump(
        tester,
        'root = Card([SnippetCardBlock([SnippetCardItem("s1", IconText(Icon("star"), "soft", "s", "Tip", "Daily"), Text("text", "42"))], null, null, {type: "pick", params: {from: "card"}})])',
        library: OpenUILibrary.chat,
      );

      await tester.tap(find.text('Tip'));
      await tester.pump();

      final event = events.single;
      expect(event.type, 'pick');
      expect(event.label, 'Tip');
      expect(event.params, {
        'from': const OpenUIString('card'),
        'itemIndex': const OpenUINumber(0),
        'itemId': const OpenUIString('s1'),
        'itemTitle': const OpenUIString('Tip'),
        'itemSubtitle': const OpenUIString('Daily'),
        'itemValue': const OpenUIString('42'),
      });
    });

    testWidgets('a composite card footer button runs its own action', (tester) async {
      final (_, events) = await _pump(
        tester,
        'root = Card([CompositeCardBlock([CompositeCardItem("a", null, [], {button: Button("Buy", @ToAssistant("Buy it"))})])])',
        library: OpenUILibrary.chat,
      );

      await tester.tap(find.text('Buy'));
      await tester.pump();

      expect(events.single.message, 'Buy it');
    });
  });
}
