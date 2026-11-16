import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';

import '../../openui_test_app.dart';

void main() {
  group('openUIImagesAsLinks', () {
    test('turns an image into a link of its alt text', () {
      expect(openUIImagesAsLinks('See ![x](https://a.dev/x.png) now'), 'See [x](https://a.dev/x.png) now');
    });

    test('turns a reference image into a reference link', () {
      expect(openUIImagesAsLinks('![x][r]\n\n[r]: https://a.dev/x.png'), '[x][r]\n\n[r]: https://a.dev/x.png');
    });

    test('leaves an escaped image marker', () {
      expect(openUIImagesAsLinks(r'\![x](y)'), r'\![x](y)');
    });

    test('turns an image after an escaped backslash into a link', () {
      expect(openUIImagesAsLinks(r'\\![x](y)'), r'\\[x](y)');
    });

    test('leaves an image marker in a code span', () {
      expect(openUIImagesAsLinks('`![x](y)` and ``a ` ![x](y)``'), '`![x](y)` and ``a ` ![x](y)``');
    });

    test('leaves an image marker in a fenced code block', () {
      const fenced = '```\n![x](y)\n```\n~~~md\n![x](y)\n~~~';
      expect(openUIImagesAsLinks(fenced), fenced);
      expect(openUIImagesAsLinks('$fenced\n![x](y)'), '$fenced\n[x](y)');
    });

    test('reads a backtick fence whose info string has a backtick as text', () {
      expect(openUIImagesAsLinks('```a`\n![x](y)'), '```a`\n[x](y)');
    });

    test('turns images into links after a code span left open on its line, until a blank line', () {
      expect(openUIImagesAsLinks('a `b\nc` ![x](y) `d`'), 'a `b\nc` [x](y) `d`');
      expect(openUIImagesAsLinks('a `b\n\n`![x](y)`'), 'a `b\n\n`![x](y)`');
    });

    test('turns images into links on a line with a <, whatever its backticks', () {
      expect(openUIImagesAsLinks('<a title="`">![x](y)<b title="`">'), '<a title="`">[x](y)<b title="`">');
    });

    test('leaves text without images alone', () {
      expect(openUIImagesAsLinks('Wow! [link](u) `code`'), 'Wow! [link](u) `code`');
    });
  });

  group('openUIEscapeBlockMarkers', () {
    test('escapes the markers that start a block', () {
      expect(openUIEscapeBlockMarkers('# of orders'), r'\# of orders');
      expect(openUIEscapeBlockMarkers('###### six'), r'\###### six');
      expect(openUIEscapeBlockMarkers('1. Paris'), r'1\. Paris');
      expect(openUIEscapeBlockMarkers('2) Rome'), r'2\) Rome');
      expect(openUIEscapeBlockMarkers('- x'), r'\- x');
      expect(openUIEscapeBlockMarkers('+ x'), r'\+ x');
      expect(openUIEscapeBlockMarkers('* x'), r'\* x');
      expect(openUIEscapeBlockMarkers('> q'), r'\> q');
      expect(openUIEscapeBlockMarkers('---'), r'\---');
      expect(openUIEscapeBlockMarkers('==='), r'\===');
      expect(openUIEscapeBlockMarkers('***'), r'\***');
      expect(openUIEscapeBlockMarkers('```dart'), r'\```dart');
      expect(openUIEscapeBlockMarkers('~~~'), r'\~~~');
    });

    test('escapes each line, and the lines indented', () {
      expect(openUIEscapeBlockMarkers('a\n# b\n   - c\n      1. d'), 'a\n\\# b\n\\- c\n1\\. d');
    });

    test('leaves inline Markdown and ordinary text alone', () {
      for (final text in [
        '**bold** and _it_',
        '[a link](https://getstream.io)',
        '`code`',
        '#hashtag',
        '1.5 million',
        '2024-01-01',
        '-5%',
        '**',
        'a > b',
        'plain',
        '',
      ]) {
        expect(openUIEscapeBlockMarkers(text), text, reason: text);
      }
    });
  });

  group('inline Markdown in components', () {
    for (final (title, shown) in [
      ('# of orders', '# of orders'),
      ('1. Paris', '1. Paris'),
      ('- x', '- x'),
      ('> q', '> q'),
    ]) {
      testWidgets('CardHeader draws "$title" as text', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, program: 'root = Card([CardHeader("$title")])');

        expect(_plainTexts(tester), contains(shown));
        expect(find.byType(Table), findsNothing);
      });

      testWidgets('TextContent still reads "$title" as block Markdown', (tester) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, program: 'root = Card([TextContent("$title")])');

        expect(_plainTexts(tester), isNot(contains(shown)));
      });
    }

    for (final (component, program) in [
      ('InlineHeader heading', 'InlineHeader("{}")'),
      ('InlineHeader description', 'InlineHeader("Head", "{}")'),
      ('TextCallout description', 'TextCallout("info", "Title", "{}")'),
      ('ContextCardBlock body', 'ContextCardBlock([ContextCardItem("a", "T", "{}")])'),
    ]) {
      for (final text in ['# of orders', '1. Paris']) {
        testWidgets('$component draws "$text" as text', (tester) async {
          final runtime = testRuntime();
          addTearDown(runtime.dispose);
          await pumpOpenUI(tester, runtime, program: 'root = Card([${program.replaceFirst('{}', text)}])');

          expect(_plainTexts(tester), contains(text));
        });
      }
    }

    testWidgets('a metric value draws a leading # as text', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Text("text", "# of orders")])');

      expect(_plainTexts(tester), contains('# of orders'));
    });

    testWidgets('a title still draws bold, links and code inline', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'root = Card([CardHeader("**Big** [site](https://getstream.io) `x`")])',
      );

      expect(_plainTexts(tester), contains('Big site x'));
      final span = tester.widget<RichText>(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'Big site x'),
      );
      expect(_styles(span.text).any((s) => s.fontWeight == FontWeight.bold || s.fontWeight == FontWeight.w700), isTrue);
    });
  });

  testWidgets('an image in Markdown draws its alt text and loads nothing', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      program: '\$q = "cat"\nroot = Card([TextContent("![A cat](https://a.dev/x.png?q=" + \$q + ")")])',
    );

    expect(find.byType(Image), findsNothing);
    expect(_plainTexts(tester), contains('A cat'));
  });

  testWidgets('a reference image in Markdown loads nothing', (tester) async {
    final runtime = testRuntime();
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      program: r'root = Card([TextContent("![A cat][c]\n\n[c]: https://a.dev/x.png")])',
    );

    expect(find.byType(Image), findsNothing);
    expect(_plainTexts(tester), contains('A cat'));
  });
}

List<String> _plainTexts(WidgetTester tester) => [
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) rich.text.toPlainText(),
];

List<TextStyle> _styles(InlineSpan root) {
  final styles = <TextStyle>[];
  root.visitChildren((span) {
    if (span is TextSpan && span.style != null) styles.add(span.style!);
    return true;
  });
  return styles;
}
