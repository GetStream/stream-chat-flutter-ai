import 'package:alchemist/alchemist.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _chartFence = '''
```chartjs
{
  "type": "bar",
  "data": {
    "labels": ["Jan", "Feb", "Mar"],
    "datasets": [{"label": "Sales", "data": [10, 25, 18]}]
  }
}
```
''';

const _mixedContent = '''
Here's a quick summary of the data, with the code used to compute it:

```python
def average(values):
    return sum(values) / len(values)
```

And the resulting trend:

```chartjs
{
  "type": "bar",
  "data": {
    "labels": ["Jan", "Feb", "Mar"],
    "datasets": [{"label": "Sales", "data": [10, 25, 18]}]
  }
}
```
''';

void main() {
  group('AIMarkdownBody', () {
    testWidgets('renders text, code block, and chart together', (tester) async {
      await tester.pumpWidget(_wrap(const AIMarkdownBody(data: _mixedContent)));

      expect(find.textContaining("Here's a quick summary"), findsOneWidget);
      expect(find.byType(CodeBlockView), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });

    group('fence memoization', () {
      // A streaming message rebuilds roughly every 10ms. A completed fence's
      // content can't change, so its widget is reused verbatim: the framework
      // skips the subtree's rebuild on an identical widget, and the
      // RepaintBoundary keeps the raster while the trailing text grows.
      testWidgets('reuses the same widget instance for an unchanged fence', (tester) async {
        Element chartElement() => tester.element(find.byType(ChartView));

        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: _mixedContent)));
        final first = chartElement().widget;

        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: '$_mixedContent\nmore text arriving')));
        expect(chartElement().widget, same(first));
      });

      testWidgets('wraps fences in a RepaintBoundary', (tester) async {
        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: _mixedContent)));

        expect(
          find.ancestor(of: find.byType(ChartView), matching: find.byType(RepaintBoundary)),
          findsWidgets,
        );
      });

      // The caches are capacity-bound, and a fence that is still arriving keys
      // a fresh entry on every tick, because its content has grown. Evicting
      // the oldest *insertion* to make room for those throwaway snapshots threw
      // out the finished fences above them — on screen, and so re-parsed and
      // rebuilt from scratch on every subsequent tick, which is the opposite of
      // what the cache is for. Evicting the least recently *used* entry instead
      // keeps anything still being rendered.
      testWidgets('a streaming fence does not evict the finished fences above it', (tester) async {
        debugClearFenceCaches();

        const preamble = '$_chartFence\nAnd the code:\n\n```python\n';
        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: preamble)));
        final chart = tester.element(find.byType(ChartView)).widget;

        // Streamed a character at a time, for comfortably more ticks than
        // either cache holds entries.
        var data = preamble;
        for (final char in 'def average(values):\n    return sum(values) / len(values)\n'.split('')) {
          data += char;
          await tester.pumpWidget(_wrap(AIMarkdownBody(data: data)));
        }

        expect(tester.element(find.byType(ChartView)).widget, same(chart));
      });

      testWidgets('rebuilds a fence whose content changed', (tester) async {
        const growing = '```python\ndef aver';
        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: growing)));
        final first = tester.element(find.byType(CodeBlockView)).widget;

        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: '${growing}age(values):')));
        final second = tester.element(find.byType(CodeBlockView)).widget;

        expect(second, isNot(same(first)));
        expect((second as CodeBlockView).code, contains('age(values):'));
      });
    });

    goldenTest(
      'mixed text, code block, and chart',
      fileName: 'ai_markdown_body_mixed_content',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 700),
      builder: () => _wrap(const AIMarkdownBody(data: _mixedContent)),
    );

    // These four cases all failed under the previous implementation, which
    // pre-split the markdown on a `RegExp(r'```(\w*)\n([\s\S]*?)```')` and
    // rendered each segment in its own MarkdownBody. Letting `package:markdown`
    // find the fences fixes all of them.
    group('fence handling', () {
      testWidgets('renders a still-unterminated fence as a code block', (tester) async {
        // The old regex needed the *closing* fence to match, so a code block
        // mid-stream showed raw ``` markers until it completed, then snapped
        // into a CodeBlockView. CommonMark requires an unclosed fence to run to
        // the end of the document, so it is a code block from the first line.
        await tester.pumpWidget(
          _wrap(const AIMarkdownBody(data: 'Here you go:\n\n```dart\nvoid main() {\n  print(1);\n')),
        );

        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.textContaining('```'), findsNothing);
        expect(find.textContaining('void main() {'), findsOneWidget);
        // The language label is already known from the opening fence.
        expect(find.text('dart'), findsOneWidget);
      });

      testWidgets('keeps ordered list numbering across an embedded fence', (tester) async {
        // Two separate MarkdownBody widgets share no parser state, so the list
        // used to restart at 1 after the fence.
        await tester.pumpWidget(
          _wrap(
            const AIMarkdownBody(
              data:
                  '1. First\n'
                  '2. Second\n\n'
                  '   ```dart\n'
                  '   var x = 1;\n'
                  '   ```\n\n'
                  '3. Third\n',
            ),
          ),
        );

        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.text('1.'), findsOneWidget);
        expect(find.text('2.'), findsOneWidget);
        expect(find.text('3.'), findsOneWidget);
      });

      testWidgets('routes a fence inside a blockquote to CodeBlockView', (tester) async {
        // Nested fences never matched the top-level split, so they fell through
        // to the default `pre` rendering.
        await tester.pumpWidget(
          _wrap(const AIMarkdownBody(data: '> Try this:\n>\n> ```sh\n> echo hi\n> ```\n')),
        );

        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.textContaining('echo hi'), findsOneWidget);
      });

      testWidgets('handles a tilde fence', (tester) async {
        // `~~~` is valid CommonMark but the old regex only looked for backticks.
        await tester.pumpWidget(
          _wrap(const AIMarkdownBody(data: '~~~python\nprint(1)\n~~~\n')),
        );

        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.text('python'), findsOneWidget);
      });

      testWidgets('renders a fence with no language', (tester) async {
        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: '```\nplain\n```\n')));

        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.textContaining('plain'), findsOneWidget);
      });
    });

    group('math', () {
      testWidgets('hands inline and block LaTeX to mathBuilder', (tester) async {
        final seen = <({String tex, bool inline})>[];

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: r'Mass-energy is \(E\) in \[E = mc^2\]',
              mathBuilder: (context, tex, style, {required inline}) {
                seen.add((tex: tex, inline: inline));
                return Text('tex:$tex');
              },
            ),
          ),
        );

        expect(seen, hasLength(2));
        expect(seen.first, (tex: 'E', inline: true));
        expect(seen.last, (tex: 'E = mc^2', inline: false));
      });

      testWidgets('keeps the prose following a display block on the same line', (tester) async {
        // The block syntax consumed the whole line and kept only what sat
        // between the delimiters, so the rest of the sentence was dropped
        // without trace.
        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: r'\[E = mc^2\] where m is mass.',
              mathBuilder: (context, tex, style, {required inline}) => Text('tex:$tex'),
            ),
          ),
        );

        expect(find.text('tex:E = mc^2'), findsOneWidget);
        expect(find.textContaining('where m is mass.'), findsOneWidget);
      });

      testWidgets('keeps the text of a citation-style line', (tester) async {
        // `\[` at the start of a line is also CommonMark's escape for a literal
        // `[`, so a numbered reference list reaches the block syntax. Losing
        // the tail turned it into a column of bare numbers.
        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: r'\[1\] First source')));

        expect(find.textContaining('First source'), findsOneWidget);
      });

      testWidgets('typesets a second expression on the same line', (tester) async {
        final seen = <String>[];

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: r'\[a\] and \[b\]',
              mathBuilder: (context, tex, style, {required inline}) {
                seen.add(tex);
                return Text('tex:$tex');
              },
            ),
          ),
        );

        expect(seen, ['a', 'b']);
        expect(find.textContaining('and'), findsOneWidget);
      });

      testWidgets('keeps the tail of a multi-line display block', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: '\\[\n  a + b\n\\] and then some.',
              mathBuilder: (context, tex, style, {required inline}) => Text('tex:$tex'),
            ),
          ),
        );

        expect(find.text('tex:a + b'), findsOneWidget);
        expect(find.textContaining('and then some.'), findsOneWidget);
      });

      testWidgets('renders raw TeX when no mathBuilder is supplied', (tester) async {
        await tester.pumpWidget(_wrap(const AIMarkdownBody(data: r'Value \(x^2\) here.')));

        // Degrades to the source rather than dropping the expression.
        expect(find.text('x^2'), findsOneWidget);
      });

      testWidgets('renders a multi-line display block', (tester) async {
        String? captured;

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: '\\[\n  a + b\n  = c\n\\]\n',
              mathBuilder: (context, tex, style, {required inline}) {
                captured = tex;
                return const Text('math');
              },
            ),
          ),
        );

        expect(captured, 'a + b\n  = c');
      });

      testWidgets('typesets an unterminated display block', (tester) async {
        // Same streaming rationale as the unclosed code fence.
        String? captured;

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: '\\[\n  E = mc^',
              mathBuilder: (context, tex, style, {required inline}) {
                captured = tex;
                return const Text('math');
              },
            ),
          ),
        );

        expect(captured, 'E = mc^');
      });

      testWidgets('ignores dollar delimiters by default', (tester) async {
        var called = false;

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: r'It costs $5 to $10.',
              mathBuilder: (context, tex, style, {required inline}) {
                called = true;
                return const Text('math');
              },
            ),
          ),
        );

        expect(called, isFalse);
        expect(find.textContaining(r'costs $5 to $10'), findsOneWidget);
      });

      testWidgets('honours dollar delimiters when opted in', (tester) async {
        final seen = <String>[];

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: r'Inline $x^2$ and display $$y = 1$$',
              useDollarDelimitersForMath: true,
              mathBuilder: (context, tex, style, {required inline}) {
                seen.add(tex);
                return const Text('math');
              },
            ),
          ),
        );

        expect(seen, ['x^2', 'y = 1']);
      });

      testWidgets('leaves dollars inside inline code alone', (tester) async {
        // `package:markdown` evaluates caller-supplied inline syntaxes before
        // its own, so the math syntax would claim `$5` inside backticks unless
        // md.CodeSyntax() is registered ahead of it.
        var called = false;

        await tester.pumpWidget(
          _wrap(
            AIMarkdownBody(
              data: r'Use `$5` literally.',
              useDollarDelimitersForMath: true,
              mathBuilder: (context, tex, style, {required inline}) {
                called = true;
                return const Text('math');
              },
            ),
          ),
        );

        expect(called, isFalse);
        expect(find.textContaining(r'$5'), findsOneWidget);
      });
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}
