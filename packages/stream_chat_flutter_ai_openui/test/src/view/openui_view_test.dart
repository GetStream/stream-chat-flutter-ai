import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../core/runtime/fake_tools.dart';
import '../openui_test_app.dart';

const _card = 'root = Card([CardHeader("Title", "Sub"), TextContent("Body")])';

void main() {
  testWidgets('draws nothing while the program has no root', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: 'root = Ca', isStreaming: true);

    expect(runtime.root.value, isNull);
    expect(find.byType(AIUIEntrance), findsNothing);
    expect(tester.getSize(find.byType(OpenUIView)).height, 0);
  });

  testWidgets('draws the program and follows it as the reply streams', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: 'root = Card([CardHeader("Title")])', isStreaming: true);

    expect(find.text('Title'), findsOneWidget);
    runtime.update(_card, isStreaming: false);
    await tester.pump();
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Body', findRichText: true), findsOneWidget);
  });

  testWidgets('each component comes in with its own entrance, and a type without a builder draws nothing', (
    tester,
  ) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: 'root = Card([CardHeader("Title"), Table([]), TextContent("Body")])');

    // The card, its header and its text; the table has no builder.
    expect(find.byType(AIUIEntrance), findsNWidgets(3));
    expect(find.ancestor(of: find.text('Title'), matching: find.byType(AIUIEntrance)), findsNWidgets(2));
  });

  testWidgets('a component keeps its state when an item before it arrives later', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: 'root = Card([a, b])\nb = TextContent("B")', isStreaming: true);
    final before = tester.element(find.byType(AIMarkdownBody));

    runtime.update('root = Card([a, b])\nb = TextContent("B")\na = TextContent("A")', isStreaming: false);
    await tester.pump();

    final markdown = find.byType(AIMarkdownBody);
    expect(markdown, findsNWidgets(2));
    expect(tester.element(markdown.last), same(before));
    expect(find.descendant(of: markdown.last, matching: find.text('B', findRichText: true)), findsOneWidget);
  });

  testWidgets('the same statement placed twice draws twice', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: 'root = Card([h, h])\nh = CardHeader("Twice")');

    expect(find.text('Twice'), findsNWidgets(2));
  });

  testWidgets("keeps the app's icon theme", (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    late IconThemeData inside;
    final library = OpenUILibrary.chat.replacing('CardHeader', (context, scope) {
      inside = IconTheme.of(context);
      return const SizedBox();
    });
    runtime.update('root = Card([CardHeader("t")])', isStreaming: false);
    await tester.pumpWidget(
      testApp(
        IconTheme(
          data: const IconThemeData(size: 40),
          child: OpenUIView(runtime: runtime, library: library),
        ),
      ),
    );

    expect(inside.size, 40);
    expect(inside.color, OpenUIThemeData.defaults(StreamTheme.light()).text);
  });

  group('a component type without a builder', () {
    testWidgets('is reported once per runtime in debug builds', (tester) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, program: 'root = Card([Table([]), Table([]), Accordion([])])');
        runtime.update('root = Card([Table([]), Accordion([]), TextContent("x")])', isStreaming: false);
        await tester.pump();

        expect(logs.where((log) => log.contains("'Table'")), hasLength(1));
        expect(logs.where((log) => log.contains("'Accordion'")), hasLength(1));
        expect(logs, hasLength(2));

        final other = testRuntime();
        addTearDown(other.dispose);
        await pumpOpenUI(tester, other, program: 'root = Card([Table([])])');
        expect(logs.where((log) => log.contains("'Table'")), hasLength(2));
      } finally {
        // Restored before the test ends, where Flutter checks it.
        debugPrint = original;
      }
    });
  });

  group('while a query is loading', () {
    const program = '$_card\nq = Query("list", {}, null)';

    testWidgets('dims the view and shows a 16 px spinner at its top end, until it loads', (tester) async {
      final tools = FakeTools();
      final runtime = testRuntime(tools: tools);
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: program);
      await tester.pump(const Duration(milliseconds: 300));

      expect(runtime.isQueryLoading.value, isTrue);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.7);
      final spinner = find.byType(StreamLoadingSpinner);
      expect(spinner, findsOneWidget);
      expect(tester.getSize(spinner), const Size(16, 16));
      final view = tester.getRect(find.byType(OpenUIView));
      final spacing = OpenUIThemeData.defaults(StreamTheme.light()).sSpacing!;
      expect(tester.getTopRight(spinner), view.topRight + Offset(-spacing, spacing));

      tools.calls.single.answer.complete(const OpenUINumber(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.isQueryLoading.value, isFalse);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1);
      expect(find.byType(StreamLoadingSpinner), findsNothing);
    });

    testWidgets('puts the spinner at the top left in a right-to-left layout', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      runtime.update(program, isStreaming: false);
      await tester.pumpWidget(
        testApp(
          Directionality(
            textDirection: TextDirection.rtl,
            child: OpenUIView(runtime: runtime, library: OpenUILibrary.chat),
          ),
        ),
      );

      final spacing = OpenUIThemeData.defaults(StreamTheme.light()).sSpacing!;
      expect(
        tester.getTopLeft(find.byType(StreamLoadingSpinner)),
        tester.getTopLeft(find.byType(OpenUIView)) + Offset(spacing, spacing),
      );
    });
  });

  testWidgets('a change of the Stream theme reaches the design system components inside', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: '$_card\nq = Query("list", {}, null)');
    final light = StreamTheme.light().colorScheme.accentPrimary;
    expect(_spinnerTheme(tester).colorScheme.accentPrimary, light);

    await pumpOpenUI(tester, runtime, stream: StreamTheme.dark());
    // The app animates to its new theme.
    await tester.pump(const Duration(seconds: 1));
    expect(_spinnerTheme(tester).colorScheme.accentPrimary, StreamTheme.dark().colorScheme.accentPrimary);
  });

  testWidgets('the view theme restyles the design system components inside', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    const teal = Color(0xFF008080);
    final theme = OpenUIThemeData(
      accent: teal,
      border: teal,
      mSpacing: 99,
      pillCornerRadius: 7,
      body: const TextStyle(fontSize: 31),
    );
    await pumpOpenUI(tester, runtime, theme: theme, program: '$_card\nq = Query("list", {}, null)');

    final stream = _spinnerTheme(tester);
    expect(stream.colorScheme.accentPrimary, teal);
    expect(stream.colorScheme.borderDefault, teal);
    expect(stream.spacing.sm, 99);
    expect(stream.radius.max, const Radius.circular(7));
    expect(stream.textTheme.bodyDefault.fontSize, 31);
    // The color the design system gives body text stays.
    expect(stream.textTheme.bodyDefault.color, StreamTheme.light().textTheme.bodyDefault.color);
  });

  testWidgets('without a theme, the design system components inside are unchanged', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: '$_card\nq = Query("list", {}, null)');

    final inside = _spinnerTheme(tester);
    final outside = StreamTheme.of(tester.element(find.byType(OpenUIView)));
    expect(inside, isNot(same(outside)));
    expect(inside.colorScheme, outside.colorScheme);
    expect(inside.spacing, outside.spacing);
    expect(inside.radius, outside.radius);
    expect(inside.textTheme.bodyDefault, outside.textTheme.bodyDefault);
    expect(inside.textTheme.headingMd, outside.textTheme.headingMd);
    expect(inside.textTheme.captionDefault, outside.textTheme.captionDefault);
  });

  testWidgets("the app's design system component builders apply inside", (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      program: '$_card\nq = Query("list", {}, null)',
      builders: StreamComponentBuilders(loadingSpinner: (context, props) => const Text('app spinner')),
    );

    expect(find.text('app spinner'), findsOneWidget);
  });

  testWidgets('stops listening to the runtime once it is gone', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: _card);
    await tester.pumpWidget(const SizedBox());

    // A listener left behind would rebuild a widget that is gone and throw.
    runtime.update('root = Card([CardHeader("Other")])', isStreaming: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    // ignore: invalid_use_of_protected_member, the test checks what the view leaves behind.
    expect((runtime.root as ChangeNotifier).hasListeners, isFalse);
  });

  testWidgets('each component is its own node for assistive technologies', (tester) async {
    final handle = tester.ensureSemantics();
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, program: _card);

    final header = tester.getSemantics(find.byType(MergeSemantics));
    expect(header.label, 'Title\nSub');
    expect(header.flagsCollection.isHeader, isTrue);
    final body = tester.getSemantics(find.text('Body', findRichText: true));
    expect(body.label, contains('Body'));
    expect(body, isNot(header));
    handle.dispose();
  });
}

// The design system's theme the loading spinner is drawn with.
StreamTheme _spinnerTheme(WidgetTester tester) => StreamTheme.of(tester.element(find.byType(StreamLoadingSpinner)));
