import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import '../a2ui_test_app.dart';

void main() {
  testWidgets('a surface shows nothing before its root arrives', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'title', 'component': 'Text', 'text': 'Ohrid'},
      ],
    );

    expect(find.text('Ohrid'), findsNothing);
  });

  testWidgets('a surface shows its root once it arrives', (tester) async {
    final processor = await pumpSurface(tester, components: const []);

    processor.apply([
      updateComponents([
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ]),
    ]);
    await tester.pump();

    expect(find.text('Ohrid'), findsOneWidget);
  });

  testWidgets('a component of a type the agent made up shows nothing', (tester) async {
    await pumpSurface(
      tester,
      components: inColumn([
        {'id': 'map', 'component': 'TripMap'},
        {'id': 'title', 'component': 'Text', 'text': 'Ohrid'},
      ]),
    );

    expect(find.byType(AIUIEntrance), findsNWidgets(2));
  });

  testWidgets('a child that has not arrived shows once it arrives', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Card', 'child': 'title'},
      ],
    );

    processor.apply([
      updateComponents([
        {'id': 'title', 'component': 'Text', 'text': 'Ohrid'},
      ]),
    ]);
    await tester.pump();

    expect(find.text('Ohrid'), findsOneWidget);
  });

  testWidgets('every component comes in with an entrance', (tester) async {
    await pumpSurface(
      tester,
      components: inColumn([
        {'id': 'a', 'component': 'Text', 'text': 'a'},
        {'id': 'b', 'component': 'Divider'},
      ]),
    );

    expect(find.byType(AIUIEntrance), findsNWidgets(3));
  });

  testWidgets("a replaced builder's component also comes in with an entrance", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
      catalog: A2UICatalog.basic.replacing('Text', (context, scope) => const Text('replaced')),
    );

    expect(find.ancestor(of: find.text('replaced'), matching: find.byType(AIUIEntrance)), findsOneWidget);
  });

  testWidgets('without a theme, text takes the primary text color of the Stream theme', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
    );

    expect(_colorOf(tester, 'Ohrid'), StreamTheme.light().colorScheme.textPrimary);
  });

  testWidgets('without a theme, a dark Stream theme gives dark colors', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
      brightness: Brightness.dark,
    );

    expect(_colorOf(tester, 'Ohrid'), StreamTheme.dark().colorScheme.textPrimary);
  });

  testWidgets("a given theme's values are used instead of the Stream theme's", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
      theme: A2UIThemeData(text: const Color(0xFF123456)),
    );

    expect(_colorOf(tester, 'Ohrid'), const Color(0xFF123456));
  });

  testWidgets("a given theme's unset values follow a dark Stream theme", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
      theme: A2UIThemeData(cornerRadius: 3),
      brightness: Brightness.dark,
    );

    expect(_colorOf(tester, 'Ohrid'), StreamTheme.dark().colorScheme.textPrimary);
  });

  testWidgets('an A2UITheme above the surface is used', (tester) async {
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      createSurface([
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ]),
    ]);
    await tester.pumpWidget(
      A2UITheme(
        data: A2UIThemeData(text: const Color(0xFF654321)),
        child: surfaceApp(processor.surface('s')!),
      ),
    );

    expect(_colorOf(tester, 'Ohrid'), const Color(0xFF654321));
  });

  testWidgets('a surface whose tree is released shows nothing', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
    );

    processor.apply([
      updateComponents([
        {'id': 'root', 'component': 'Column', 'children': List.filled(5000, 'leaf')},
        {'id': 'leaf', 'component': 'Text', 'text': 'x'},
      ]),
    ]);
    await tester.pump();

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a deleted surface shows nothing', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
      ],
    );

    processor.apply([_deleteSurface]);
    await tester.pump();

    expect(find.text('Ohrid'), findsNothing);
  });
}

const _deleteSurface = '{"version": "1.0", "deleteSurface": {"surfaceId": "s"}}';

Color? _colorOf(WidgetTester tester, String text) {
  final element = tester.element(find.text(text));
  final widget = element.widget as Text;
  return DefaultTextStyle.of(element).style.merge(widget.style).color;
}
