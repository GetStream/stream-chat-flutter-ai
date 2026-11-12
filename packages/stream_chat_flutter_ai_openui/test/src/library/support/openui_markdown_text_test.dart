import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';

import '../../openui_test_app.dart';

void main() {
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
