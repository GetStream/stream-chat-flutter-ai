import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

final _parts = AIMessagePart.parseAll([
  (type: 'ai_reasoning', payload: const {'id': 'r1', 'status': 'completed'}),
  (type: 'ai_tool_call', payload: const {'id': 'call_1', 'name': 'get_weather'}),
  (type: 'ai_citation', payload: const {'id': 'c1', 'url': 'https://example.com'}),
]);

void main() {
  group('AIMessagePartsView', () {
    testWidgets('shows the placeholder for every part by default', (tester) async {
      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: _parts)));

      expect(find.byType(AIUnsupportedPartView), findsNWidgets(3));
      expect(find.text("A step this app version can't show"), findsNWidgets(3));
    });

    testWidgets('renders parts in order, keyed by id', (tester) async {
      await tester.pumpWidget(
        _wrap(AIMessagePartsView(parts: _parts, partBuilder: (context, part) => Text(part.id))),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('r1'),
        ValueKey<Object>('call_1'),
        ValueKey<Object>('c1'),
      ]);
      final dy = ['r1', 'call_1', 'c1'].map((id) => tester.getTopLeft(find.text(id)).dy).toList();
      expect(dy, orderedEquals([...dy]..sort()));
    });

    testWidgets('a builder returning null falls back to the default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts,
            partBuilder: (context, part) => part.kind.value == 'ai_citation' ? const Text('citation') : null,
          ),
        ),
      );

      expect(find.text('citation'), findsOneWidget);
      expect(find.byType(AIUnsupportedPartView), findsNWidgets(2));
    });

    testWidgets('tells apart parts that share an id', (tester) async {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'id': 'same'}),
        (type: 'ai_tool_call', payload: const {'id': 'same'}),
        (type: 'ai_tool_call', payload: const {'id': 'same'}),
      ]);

      await tester.pumpWidget(_wrap(AIMessagePartsView(parts: parts)));

      expect(tester.takeException(), isNull);
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.children.map((child) => child.key), const [
        ValueKey<Object>('same'),
        ValueKey<Object>(('same', 1)),
        ValueKey<Object>(('same', 2)),
      ]);
    });

    testWidgets('keeps a part state when one is added before it', (tester) async {
      final first = AIMessagePart(id: 'a', kind: AIMessagePartKind.reasoning);
      final second = AIMessagePart(id: 'b', kind: AIMessagePartKind.toolCall);
      Widget build(List<AIMessagePart> parts) => _wrap(
        AIMessagePartsView(
          parts: parts,
          partBuilder: (context, part) => _Stateful(label: part.id),
        ),
      );

      await tester.pumpWidget(build([second]));
      final state = tester.state(find.byType(_Stateful));

      await tester.pumpWidget(build([first, second]));
      expect(tester.state(find.byWidgetPredicate((w) => w is _Stateful && w.label == 'b')), same(state));
    });

    testWidgets('applies the spacing between parts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIMessagePartsView(
            parts: _parts.take(2).toList(),
            spacing: 20,
            partBuilder: (context, part) => SizedBox(height: 10, child: Text(part.id)),
          ),
        ),
      );

      final gap = tester.getTopLeft(find.text('call_1')).dy - tester.getBottomLeft(find.text('r1')).dy;
      expect(gap, 20);
    });

    testWidgets('renders nothing for no parts', (tester) async {
      await tester.pumpWidget(_wrap(const AIMessagePartsView(parts: [])));

      expect(find.byType(Column), findsNothing);
    });
  });

  group('AIUnsupportedPartView', () {
    testWidgets('translates its text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AITranslationsScope(
            translations: _DutchTranslations(),
            child: AIUnsupportedPartView(),
          ),
        ),
      );

      expect(find.text('Onbekende stap'), findsOneWidget);
    });

    testWidgets('uses the given style and icon color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AIUnsupportedPartView(
            textStyle: TextStyle(fontSize: 20, color: Color(0xFFFF0000)),
            iconColor: Color(0xFF00FF00),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.fontSize, 20);
      expect(text.style!.color, const Color(0xFFFF0000));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFF00FF00));
      expect(icon.size, 25);
    });

    goldenTest(
      'unsupported part',
      fileName: 'ai_unsupported_part_view',
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 80),
      builder: () => _wrap(const Padding(padding: EdgeInsets.all(12), child: AIUnsupportedPartView())),
    );
  });
}

class _Stateful extends StatefulWidget {
  const _Stateful({required this.label});

  final String label;

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => Text(widget.label);
}

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String get unsupportedMessagePart => 'Onbekende stap';
}
