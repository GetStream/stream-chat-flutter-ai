import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../openui_test_app.dart';

void main() {
  for (final (name, stream) in [('light', StreamTheme.light()), ('dark', StreamTheme.dark())]) {
    group('drawn with the theme ($name)', () {
      final theme = OpenUIThemeData.defaults(stream);

      testWidgets('Callout tints its surface with its variant color and draws its title and description', (
        tester,
      ) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(
          tester,
          runtime,
          stream: stream,
          program: 'root = Card([Callout("warning", "Careful", "Mind the **gap**")])',
        );

        final box = tester.widget<DecoratedBox>(find.byKey(const ValueKey('callout')));
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, theme.colors!.warning!.withValues(alpha: 0.12));
        expect(decoration.borderRadius, BorderRadius.circular(theme.radius!.medium!));
        final title = tester.widget<Text>(find.text('Careful'));
        expect(title.style!.color, theme.colors!.textPrimary);
        expect(title.style!.fontWeight, FontWeight.w600);
        expect(_styleOf(tester, 'gap').fontWeight, FontWeight.bold);
        expect(_styleOf(tester, 'Mind').color, theme.colors!.textSecondary);
      });

      testWidgets('TextCallout draws a bar of its variant color beside its text', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(
          tester,
          runtime,
          stream: stream,
          program: 'root = Card([TextCallout("danger", "Bad", "Wrong")])',
        );

        final bar = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where((box) => box.color == theme.colors!.danger);
        expect(bar, hasLength(1));
        expect(
          tester.getSize(find.ancestor(of: find.byWidget(bar.single), matching: find.byType(SizedBox)).first).width,
          3,
        );
        expect(tester.widget<Text>(find.text('Bad')).style!.color, theme.colors!.textPrimary);
      });

      testWidgets('Separator draws a line of the border color, across the width or 24 tall', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(
          tester,
          runtime,
          stream: stream,
          program: 'root = Card([Separator(), Separator("vertical")])',
        );

        final lines = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where((box) => box.color == theme.colors!.border);
        expect(lines, hasLength(2));
        expect(tester.getSize(find.byWidget(lines.first)).height, 1);
        expect(tester.getSize(find.byWidget(lines.last)), const Size(1, 24));
      });

      testWidgets('Label and InlineHeader draw in their styles and colors', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(
          tester,
          runtime,
          stream: stream,
          program: 'root = Card([Label("Name"), InlineHeader("Head", "About")])',
        );

        final label = tester.widget<Text>(find.text('Name')).style!;
        expect(label.color, theme.colors!.textPrimary);
        expect(label.fontWeight, FontWeight.w500);
        expect(_styleOf(tester, 'Head').fontSize, theme.textStyles!.heading!.fontSize);
        expect(_styleOf(tester, 'About').color, theme.colors!.textSecondary);
      });
    });
  }

  group('MarkDownRenderer', () {
    testWidgets('draws its Markdown across the width, on a surface for card and sunk, none for clear', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([MarkDownRenderer("a **b**"), MarkDownRenderer("c", "sunk"), MarkDownRenderer("d", "card")])',
      );

      final theme = OpenUIThemeData.defaults(StreamTheme.light());
      expect(_styleOf(tester, 'b').fontWeight, FontWeight.bold);
      final colors = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => (box.decoration as BoxDecoration).color)
          .toList();
      expect(colors, containsAll([theme.colors!.sunkenSurface, theme.colors!.surface]));
      expect(tester.getSize(find.byType(AIMarkdownBody).first).width, lessThanOrEqualTo(360));
    });

    testWidgets('links the citations of the card it is in', (tester) async {
      final opened = <Uri>[];
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        onOpenLink: opened.add,
        program:
            'root = Card([MarkDownRenderer("see [1]")], [{url: "https://a.dev", title: "A", sourceName: "a.dev"}])',
      );

      await tester.tapOnText(find.textRange.ofSubstring('[1]'));
      expect(opened, [Uri.parse('https://a.dev')]);
    });
  });

  group('CodeBlock', () {
    testWidgets('draws its code in a code block with its language', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([CodeBlock("dart", "var x = 1;")])');

      final block = tester.widget<CodeBlockView>(find.byType(CodeBlockView));
      expect(block.code, 'var x = 1;');
      expect(block.language, 'dart');
    });

    testWidgets('gives no language when it is empty', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([CodeBlock("", "x")])');

      expect(tester.widget<CodeBlockView>(find.byType(CodeBlockView)).language, isNull);
    });
  });

  group('Callout visibility', () {
    testWidgets('hides when visible is the literal false and shows when it is true or unset', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Callout("info", "T", "D", false)])');
      expect(find.text('T'), findsNothing);

      runtime.update('root = Card([Callout("info", "T", "D", true)])', isStreaming: false);
      await tester.pump();
      expect(find.text('T'), findsOneWidget);

      runtime.update('root = Card([Callout("info", "T", "D")])', isStreaming: false);
      await tester.pump();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('bound to a variable, it shows while the variable is true and writes false after 3 seconds', (
      tester,
    ) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            r'$show = true'
            '\n'
            r'root = Card([Callout("info", "T", "D", $show)])',
      );
      await tester.pump();
      expect(find.text('T'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('T'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);
    });

    testWidgets('writes nothing when it is not bound, and nothing after it leaves', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            r'$show = true'
            '\n'
            r'root = Card([Callout("info", "T", "D", $show)])',
      );
      await tester.pump();
      runtime.update('root = Card([CardHeader("x")])', isStreaming: false);
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      expect(runtime.fieldValue(null, r'$show'), const OpenUIBool(true));
    });

    testWidgets('shows again for another 3 seconds when the variable becomes true again', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            r'$show = true'
            '\n'
            r'root = Card([Callout("info", "T", "D", $show)])',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      runtime.setFieldValue(null, r'$show', const OpenUIBool(true));
      await tester.pump();
      await tester.pump();
      expect(find.text('T'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);
    });
  });

  group('citations', () {
    Future<List<Uri>> tap(
      WidgetTester tester,
      String text, {
      String sources = '[{url: "https://a.dev", title: "A", sourceName: "a"}]',
    }) async {
      final opened = <Uri>[];
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        onOpenLink: opened.add,
        program: 'root = Card([TextContent("$text")], $sources)',
      );
      return opened;
    }

    testWidgets('a [n] that names a source links to it', (tester) async {
      final opened = await tap(tester, 'Fact [1].');

      await tester.tapOnText(find.textRange.ofSubstring('[1]'));
      expect(opened, [Uri.parse('https://a.dev')]);
    });

    testWidgets('a [n] with no source stays text', (tester) async {
      final opened = await tap(tester, 'Fact [2].');

      await tester.tapOnText(find.textRange.ofSubstring('[2]'));
      expect(opened, isEmpty);
    });

    testWidgets('a source without a web address is counted but not linked', (tester) async {
      final opened = await tap(
        tester,
        'A [1] B [2]',
        sources: '[{title: "No link", sourceName: "n"}, {url: "https://b.dev", title: "B", sourceName: "b"}]',
      );

      await tester.tapOnText(find.textRange.ofSubstring('[1]'));
      expect(opened, isEmpty);
      await tester.tapOnText(find.textRange.ofSubstring('[2]'));
      expect(opened, [Uri.parse('https://b.dev')]);
    });
  });

  group('sources strip', () {
    testWidgets('lists each source with its number, title and name, and opens it on tap', (tester) async {
      final opened = <Uri>[];
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        onOpenLink: opened.add,
        program:
            'root = Card([TextContent("x")], [{url: "https://a.dev", title: "Alpha", sourceName: "a.dev"}, {title: "Beta", sourceName: "b"}, {url: "https://c.dev", title: "C", sourceName: "c"}])',
      );

      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('a.dev'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      expect(find.text('3'), findsOneWidget);
      final theme = OpenUIThemeData.defaults(StreamTheme.light());
      final badge = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) => (box.decoration as BoxDecoration).shape == BoxShape.circle,
          );
      expect(badge.map((box) => (box.decoration as BoxDecoration).color), everyElement(theme.colors!.accent));
      expect(badge, hasLength(3));

      await tester.tap(find.text('Alpha'));
      await tester.tap(find.text('Beta'));
      expect(opened, [Uri.parse('https://a.dev')]);
    });

    testWidgets('draws no strip without sources', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([TextContent("x")])');

      expect(find.text('Sources'), findsNothing);
    });

    testWidgets('the width and the badge grow with the text size', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      runtime.update(
        'root = Card([TextContent("x")], [{url: "https://a.dev", title: "Alpha", sourceName: "a"}])',
        isStreaming: false,
      );
      Future<Size> sizeAt(double scale) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: testApp(OpenUIView(runtime: runtime, library: OpenUILibrary.chat)),
          ),
        );
        return tester.getSize(find.ancestor(of: find.text('Alpha'), matching: find.byType(ConstrainedBox)).first);
      }

      expect((await sizeAt(1)).width, 180);
      expect((await sizeAt(2)).width, 360);
    });
  });

  group('images', () {
    testWidgets('Image draws a box 180 tall with its alt in the failure state, read as an image', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Image("A cat", "ftp://x/cat.png")])');

      expect(find.text('A cat'), findsOneWidget);
      expect(find.byType(StreamNetworkImage), findsNothing);
      expect(tester.getSize(find.byType(ClipRRect).first).height, 180);
      expect(find.bySemanticsLabel('A cat'), findsOneWidget);
    });

    testWidgets('an image without alt is out of the semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Image("", "ftp://x/cat.png")])');

      expect(find.byIcon(StreamTheme.light().icons.image), findsOneWidget);
      expect(tester.getSemantics(find.byIcon(StreamTheme.light().icons.image)).label, isEmpty);
      handle.dispose();
    });

    testWidgets('a web address loads through the view media function, and none loads nothing', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([ImageBlock("https://a.dev/x.png", "X")])');
      expect(find.byType(StreamNetworkImage), findsOneWidget);
      expect(tester.getSize(find.byType(AspectRatio)).aspectRatio, closeTo(16 / 9, 0.01));

      runtime.update('root = Card([ImageBlock("", "X")])', isStreaming: false);
      await tester.pump();
      expect(find.byType(StreamNetworkImage), findsNothing);
      expect(find.text('X'), findsOneWidget);
    });

    testWidgets('ImageGallery wraps tiles by width and opens a preview that Done closes', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([ImageGallery([{src: "https://a.dev/1.png", alt: "One", details: "First"}, {src: "https://a.dev/2.png", alt: "Two"}])])',
      );

      expect(find.byType(StreamNetworkImage), findsNWidgets(2));
      await tester.tap(find.byType(StreamNetworkImage).first);
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('ImageGallery draws nothing without images', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([ImageGallery([])])');

      expect(find.byType(StreamNetworkImage), findsNothing);
    });
  });

  group('replacing a builder', () {
    testWidgets('a replacement for each family still wins', (tester) async {
      final library = OpenUILibrary.chat
          .replacing('Callout', (context, scope) => const Text('mine-callout'))
          .replacing('Tag', (context, scope) => const Text('mine-tag'))
          .replacing('SnippetCardBlock', (context, scope) => const Text('mine-block'));
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        library: library,
        program: 'root = Card([Callout("info", "T", "D"), Tag("x"), SnippetCardBlock([])])',
      );

      expect(find.text('mine-callout'), findsOneWidget);
      expect(find.text('mine-tag'), findsOneWidget);
      expect(find.text('mine-block'), findsOneWidget);
    });
  });
}

TextStyle _styleOf(WidgetTester tester, String text) {
  final paragraph = tester.widget<RichText>(
    find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains(text)).first,
  );
  TextStyle? found;
  paragraph.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.text!.contains(text)) {
      found = span.style;
      return false;
    }
    return true;
  });
  return paragraph.text.style!.merge(found);
}
