import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('text without Markdown is drawn as plain text', (tester) async {
    await _pumpText(tester, 'A relaxed weekend');

    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('text with Markdown is drawn as Markdown', (tester) async {
    await _pumpText(tester, '**A relaxed** weekend');

    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('plain text is in the body style', (tester) async {
    await _pumpText(tester, 'Ohrid');

    expect(_styleOf(tester, 'Ohrid').fontSize, lightTheme().body.fontSize);
  });

  testWidgets('plain text is in the text color', (tester) async {
    await _pumpText(tester, 'Ohrid');

    expect(_styleOf(tester, 'Ohrid').color, lightTheme().text);
  });

  testWidgets('a caption is in the caption style', (tester) async {
    await _pumpText(tester, 'Ohrid', variant: 'caption');

    expect(_styleOf(tester, 'Ohrid').fontSize, lightTheme().caption.fontSize);
  });

  testWidgets('a caption is in the secondary text color', (tester) async {
    await _pumpText(tester, 'Ohrid', variant: 'caption');

    expect(_styleOf(tester, 'Ohrid').color, lightTheme().secondaryText);
  });

  testWidgets('a variant the catalog does not have is the body style', (tester) async {
    await _pumpText(tester, 'Ohrid', variant: 'h1');

    expect(_styleOf(tester, 'Ohrid').fontSize, lightTheme().body.fontSize);
  });

  testWidgets('a level 1 heading is in the first heading style', (tester) async {
    await _pumpText(tester, '# Ohrid');

    expect(_spanStyleOf(tester, 'Ohrid').fontSize, lightTheme().heading(1).fontSize);
  });

  testWidgets('a level 2 heading is in the second heading style', (tester) async {
    await _pumpText(tester, '## Ohrid');

    expect(_spanStyleOf(tester, 'Ohrid').fontSize, lightTheme().heading(2).fontSize);
  });

  testWidgets('a level 3 heading is in the third heading style', (tester) async {
    await _pumpText(tester, '### Ohrid');

    expect(_spanStyleOf(tester, 'Ohrid').fontSize, lightTheme().heading(3).fontSize);
  });

  testWidgets('a level 4 heading is in the fourth heading style', (tester) async {
    await _pumpText(tester, '#### Ohrid');

    expect(_spanStyleOf(tester, 'Ohrid').fontSize, lightTheme().heading(4).fontSize);
  });

  testWidgets('a heading is in the text color', (tester) async {
    await _pumpText(tester, '# Ohrid');

    expect(_spanStyleOf(tester, 'Ohrid').color, lightTheme().text);
  });

  testWidgets('bold text is drawn without its markers', (tester) async {
    await _pumpText(tester, '**Ohrid**');

    expect(find.text('Ohrid', findRichText: true), findsOneWidget);
  });

  testWidgets('a link shows its text', (tester) async {
    await _pumpText(tester, '[the lake](https://example.com)');

    expect(find.text('the lake', findRichText: true), findsOneWidget);
  });

  testWidgets('a tap on a link opens nothing', (tester) async {
    await _pumpText(tester, '[the lake](https://example.com)');

    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).onTapLink, isNull);
  });

  testWidgets('a link is in the style of the text around it', (tester) async {
    await _pumpText(tester, 'See [the lake](https://example.com)');

    expect(_spanStyleOf(tester, 'the lake').color, lightTheme().text);
  });

  testWidgets('an image shows its description', (tester) async {
    await _pumpText(tester, '![The lake at dusk](https://example.com/lake.png)');

    expect(find.text('The lake at dusk'), findsOneWidget);
  });

  testWidgets("an image's description is in the style of the text", (tester) async {
    await _pumpText(tester, '![The lake at dusk](https://example.com/lake.png)', variant: 'caption');

    expect(_styleOf(tester, 'The lake at dusk').color, lightTheme().secondaryText);
  });

  testWidgets('an image is not loaded', (tester) async {
    await _pumpText(tester, '![The lake at dusk](https://example.com/lake.png)');

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a quote is in the secondary text color', (tester) async {
    await _pumpText(tester, '> Ohrid');

    expect(_spanStyleOf(tester, 'Ohrid').color, lightTheme().secondaryText);
  });

  testWidgets('a quote has a rule 2 wide along its start', (tester) async {
    await _pumpText(tester, '> Ohrid');

    expect(_quoteDecoration(tester).border, Border(left: BorderSide(color: lightTheme().border, width: 2)));
  });

  testWidgets('a quote is indented 8 from its rule', (tester) async {
    await _pumpText(tester, '> Ohrid');

    expect(_quotePadding(tester), const EdgeInsets.only(left: 8));
  });

  testWidgets('code is in the monospace font', (tester) async {
    await _pumpText(tester, '`ohrid`');

    expect(_spanStyleOf(tester, 'ohrid').fontFamily, 'monospace');
  });

  testWidgets("code falls back to each platform's monospace font", (tester) async {
    await _pumpText(tester, '`ohrid`');

    expect(_spanStyleOf(tester, 'ohrid').fontFamilyFallback, [
      'Menlo',
      'Consolas',
      'Roboto Mono',
      'DejaVu Sans Mono',
      'Courier New',
    ]);
  });

  testWidgets('code is on the subtle surface color', (tester) async {
    await _pumpText(tester, '`ohrid`');

    expect(_spanStyleOf(tester, 'ohrid').backgroundColor, lightTheme().subtleSurface);
  });

  testWidgets('a Text without text shows nothing', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Text',
          'text': {'@path': '/missing'},
        },
      ],
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a bound text shows the new value when the data model changes', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Text',
          'text': {'@path': '/city'},
        },
      ],
      data: {'city': 'Ohrid'},
    );

    processor.apply([updateData('/city', 'Struga')]);
    await tester.pump();

    expect(find.text('Struga'), findsOneWidget);
  });
}

Future<void> _pumpText(WidgetTester tester, String text, {String? variant}) async {
  await pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Text', 'text': text, 'variant': ?variant},
    ],
  );
}

// The style plain [text] is drawn in, with the style around it.
TextStyle _styleOf(WidgetTester tester, String text) {
  final element = tester.element(find.text(text));
  return DefaultTextStyle.of(element).style.merge((element.widget as Text).style);
}

// The style of the span of Markdown that holds [text], with the styles of the
// spans around it.
TextStyle _spanStyleOf(WidgetTester tester, String text) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    TextStyle? found;
    void visit(InlineSpan span, TextStyle inherited) {
      final style = inherited.merge(span.style);
      if (span is TextSpan && span.text == text) found = style;
      if (span is TextSpan) {
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      }
    }

    visit(richText.text, const TextStyle());
    if (found != null) return found!;
  }
  throw StateError('No span holds "$text".');
}

// The decoration of the quote of Ohrid, which draws its rule.
BoxDecoration _quoteDecoration(WidgetTester tester) {
  final quote = find.ancestor(of: find.text('Ohrid', findRichText: true), matching: find.byType(DecoratedBox)).first;
  return tester.widget<DecoratedBox>(quote).decoration as BoxDecoration;
}

// The padding between the rule of the quote of Ohrid and its text.
EdgeInsetsGeometry _quotePadding(WidgetTester tester) {
  final quote = find.ancestor(of: find.text('Ohrid', findRichText: true), matching: find.byType(DecoratedBox)).first;
  return tester.widget<Padding>(find.descendant(of: quote, matching: find.byType(Padding)).first).padding;
}
