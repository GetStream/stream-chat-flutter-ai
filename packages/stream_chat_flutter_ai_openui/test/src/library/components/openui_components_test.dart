import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';

import '../../openui_test_app.dart';

void main() {
  for (final (name, stream) in [('light', StreamTheme.light()), ('dark', StreamTheme.dark())]) {
    group('drawn with the theme ($name)', () {
      final theme = OpenUIResolvedTheme.fromData(const OpenUIThemeData.empty(), stream);

      testWidgets('Card is a bordered surface as wide as its space, with its children in a column', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, stream: stream, program: 'root = Card([CardHeader("A"), CardHeader("B")])');

        final box = find.byType(DecoratedBox).first;
        final decoration = tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
        expect(decoration.color, theme.surface);
        expect(decoration.borderRadius, BorderRadius.circular(theme.cornerRadius));
        final border = (decoration.border! as Border).top;
        expect(border.width, 0.5);
        expect(border.color, theme.border.withValues(alpha: theme.border.a * 0.6));
        expect(tester.getSize(box).width, 360);
        final padding = theme.lSpacing;
        expect(tester.getTopLeft(find.text('A')), tester.getTopLeft(box) + Offset(padding, padding));
        final gap = tester.getTopLeft(find.text('B')).dy - tester.getBottomLeft(find.text('A')).dy;
        expect(gap, theme.mSpacing);
      });

      testWidgets('CardHeader draws its title and subtitle in their styles', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, stream: stream, program: 'root = Card([CardHeader("Title", "Sub")])');

        final title = tester.widget<Text>(find.text('Title'));
        expect(title.style!.color, theme.text);
        expect(title.style!.fontSize, theme.title.fontSize);
        expect(title.style!.fontWeight, theme.title.fontWeight);
        final subtitle = tester.widget<Text>(find.text('Sub'));
        expect(subtitle.style!.color, theme.secondaryText);
        expect(subtitle.style!.fontSize, theme.bodySmall.fontSize);
        final gap = tester.getTopLeft(find.text('Sub')).dy - tester.getBottomLeft(find.text('Title')).dy;
        expect(gap, theme.xsSpacing);
      });

      testWidgets('TextContent draws its Markdown in body text of the primary color', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, stream: stream, program: 'root = Card([TextContent("Hello")])');

        final style = _styleOf(tester, 'Hello');
        expect(style.color, theme.text);
        expect(style.fontSize, theme.body.fontSize);
        expect(style.fontWeight, theme.body.fontWeight);
      });
    });
  }

  testWidgets('a theme given to the view restyles the components', (tester) async {
    const teal = Color(0xFF008080);
    final theme = OpenUIThemeData(
      surface: teal,
      text: teal,
      body: const TextStyle(fontSize: 23),
    );
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, theme: theme, program: 'root = Card([CardHeader("T"), TextContent("Hi")])');

    expect((tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as BoxDecoration).color, teal);
    expect(tester.widget<Text>(find.text('T')).style!.color, teal);
    expect(_styleOf(tester, 'Hi').color, teal);
    expect(_styleOf(tester, 'Hi').fontSize, 23);
  });

  group('CardHeader', () {
    testWidgets('leaves out an empty title or subtitle, and draws nothing with neither', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([CardHeader("", "Only")])');

      expect(find.byType(Text), findsOneWidget);
      runtime.update('root = Card([CardHeader("", "")])', isStreaming: false);
      await tester.pump();
      expect(find.byType(Text), findsNothing);
      expect(find.byType(MergeSemantics), findsNothing);
    });
  });

  group('TextContent', () {
    final styles = OpenUIResolvedTheme.fromData(const OpenUIThemeData.empty(), StreamTheme.light());

    for (final (size, expected, weight) in [
      ('small', styles.bodySmall, styles.bodySmall.fontWeight),
      ('large', styles.bodyLarge, styles.bodyLarge.fontWeight),
      ('small-heavy', styles.bodySmall, FontWeight.w600),
      ('large-heavy', styles.title, FontWeight.w700),
      ('default', styles.body, styles.body.fontWeight),
    ]) {
      testWidgets('the size $size draws in its style', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, program: 'root = Card([TextContent("Hi", "$size")])');

        expect(_styleOf(tester, 'Hi').fontSize, expected.fontSize);
        expect(_styleOf(tester, 'Hi').fontWeight, weight);
      });
    }

    testWidgets('draws Markdown', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([TextContent("a **bold** b")])');

      expect(find.byType(AIMarkdownBody), findsOneWidget);
      expect(_styleOf(tester, 'bold').fontWeight, FontWeight.bold);
    });

    for (final (href, opens) in [
      ('https://getstream.io', true),
      ('http://getstream.io', true),
      ('mailto:hi@getstream.io', true),
      ('tel:123', false),
      ('javascript:alert(1)', false),
      ('https://', false),
    ]) {
      testWidgets('a link to $href ${opens ? 'opens' : 'does not open'}', (tester) async {
        final opened = <Uri>[];
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, onOpenLink: opened.add, program: 'root = Card([TextContent("[go]($href)")])');

        await tester.tapOnText(find.textRange.ofSubstring('go'));
        expect(opened, opens ? [Uri.parse(href)] : isEmpty);
      });
    }

    testWidgets('a link takes the accent of a theme that changes it, and the design system link color otherwise', (
      tester,
    ) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      const program = 'root = Card([TextContent("[go](https://getstream.io)")])';
      await pumpOpenUI(tester, runtime, program: program);
      expect(_styleOf(tester, 'go').color, StreamTheme.light().colorScheme.textLink);

      const red = Color(0xFFFF0000);
      await pumpOpenUI(
        tester,
        runtime,
        theme: OpenUIThemeData(accent: red),
      );
      expect(_styleOf(tester, 'go').color, red);
    });

    testWidgets('a link does nothing when the view has no way to open links', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([TextContent("[go](https://getstream.io)")])');

      await tester.tapOnText(find.textRange.ofSubstring('go'));
      expect(tester.takeException(), isNull);
    });
  });
}

// The style the text [text] is drawn with, inside rich text.
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
