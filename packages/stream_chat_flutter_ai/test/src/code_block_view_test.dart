import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// A short Dart snippet with a keyword, a string, a comment and a number, so
/// any highlighter has to emit several distinct runs for it.
const _dartSnippet = '''
// Greets the world.
void greet() {
  const times = 3;
  const message = 'hello';
}''';

/// The color [_wordHighlighter] paints word runs.
const _tokenColor = Color(0xFFFF0000);

/// A stand-in [CodeHighlighter]: colors every run of word characters and leaves
/// the punctuation between them to inherit.
///
/// Deliberately not a real grammar — these tests are about the seam, not about
/// anyone's tokenizer. It reproduces the two properties that matter: the text
/// comes back intact, and more than one color is used.
TextSpan _wordHighlighter(CodeHighlightRequest request) {
  final children = <TextSpan>[];
  for (final match in RegExp(r'\w+|\W+').allMatches(request.code)) {
    final text = match[0]!;
    final isWord = RegExp(r'^\w').hasMatch(text);
    children.add(
      TextSpan(
        text: text,
        style: isWord ? const TextStyle(color: _tokenColor) : null,
      ),
    );
  }
  return TextSpan(style: request.baseStyle, children: children);
}

/// Records every call, so a test can assert the highlighter was *not* reached.
class _RecordingHighlighter {
  final calls = <({String code, String language})>[];
  final requests = <CodeHighlightRequest>[];

  TextSpan? call(CodeHighlightRequest request) {
    calls.add((code: request.code, language: request.language));
    requests.add(request);
    return _wordHighlighter(request);
  }
}

/// Runs [body] with [FlutterError.onError] collecting instead of failing, and
/// returns what it collected.
///
/// The override is lifted before returning, deliberately: left in place for the
/// rest of the test it would also intercept the test framework's own failure
/// reporting, turning a failed expectation below into a ten-minute hang.
Future<List<FlutterErrorDetails>> _collectingErrors(Future<void> Function() body) async {
  final reported = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previousOnError;
  }
  return reported;
}

/// Every distinct color the span tree paints, ignoring spans that inherit.
Set<Color> _colorsOf(InlineSpan span) {
  final colors = <Color>{};
  span.visitChildren((child) {
    final color = child.style?.color;
    if (color != null) colors.add(color);
    return true;
  });
  return colors;
}

/// The concatenated text of a span tree, so highlighting can be checked not to
/// have dropped or reordered any of the code.
String _textOf(InlineSpan span) => span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
void main() {
  group('CodeBlockView', () {
    /// Captures what the widget writes to the clipboard, since the real platform
    /// channel isn't available under `flutter test`.
    List<String> mockClipboard() {
      final written = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            written.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return written;
    }

    Widget wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    testWidgets('shows the language label, omitting it when absent', (tester) async {
      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart')));
      expect(find.text('dart'), findsOneWidget);

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x')));
      expect(find.text('dart'), findsNothing);
    });

    testWidgets('copies the code and confirms, then reverts', (tester) async {
      final written = mockClipboard();

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'var x = 1;', language: 'dart')));

      expect(find.byIcon(Icons.content_copy), findsOneWidget);

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();

      expect(written, ['var x = 1;']);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('the copy tooltip is translated in both states', (tester) async {
      mockClipboard();

      await tester.pumpWidget(
        wrap(
          const AITranslationsScope(
            translations: _TestTranslations(),
            child: CodeBlockView(code: 'var x = 1;', language: 'dart'),
          ),
        ),
      );

      expect(find.byTooltip('KOPIEER'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();

      expect(find.byTooltip('GEKOPIEERD'), findsOneWidget);
    });

    testWidgets('a second tap extends the confirmation instead of racing it', (tester) async {
      // Regression test: the reset used to be a `Future.delayed` per tap, so the
      // first tap's delay resolved mid-way through the second tap's window and
      // cleared the check mark early.
      mockClipboard();

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart')));

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // 1s past the *first* tap's deadline, but only 1s into the second's.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('disposal mid-copy does not throw', (tester) async {
      // Regression test: `setState` ran unguarded right after the clipboard
      // round-trip, so a block scrolled away (or a replaced message) between tap
      // and completion tore down the state object first.
      //
      // The write has to still be in flight at disposal for this to bite, so the
      // mock handler is held open on a gate rather than resolving immediately.
      final gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') await gate.future;
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart')));

      await tester.tap(find.byIcon(Icons.content_copy));
      // Tear the block down while the clipboard write is still pending.
      await tester.pumpWidget(wrap(const SizedBox()));
      gate.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    group('highlighting', () {
      /// The body's span tree, or null when the code was rendered plain.
      InlineSpan? spanOf(WidgetTester tester) {
        // The header's language label is a `Text`, so the `SelectableText` the
        // body renders is the only one in the tree.
        return tester.widget<SelectableText>(find.byType(SelectableText)).textSpan;
      }

      String? plainOf(WidgetTester tester) => tester.widget<SelectableText>(find.byType(SelectableText)).data;

      testWidgets('renders plain text when no highlighter is given', (tester) async {
        // The package ships no grammars, so this is what a host gets until it
        // supplies one.
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')));

        expect(spanOf(tester), isNull);
        expect(plainOf(tester), _dartSnippet);
      });

      testWidgets('renders the highlighter output, keeping every character', (tester) async {
        await tester.pumpWidget(
          wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', highlighter: _wordHighlighter)),
        );

        final span = spanOf(tester);
        expect(span, isNotNull);
        expect(_colorsOf(span!), contains(_tokenColor));
        expect(_textOf(span), _dartSnippet);
      });

      testWidgets('passes the code and language through verbatim', (tester) async {
        // Case folding and alias resolution are the highlighter's business, so
        // the label must arrive exactly as the fence wrote it.
        final highlighter = _RecordingHighlighter();

        await tester.pumpWidget(
          wrap(CodeBlockView(code: 'var x = 1;', language: 'DarT', highlighter: highlighter.call)),
        );

        expect(highlighter.calls, [(code: 'var x = 1;', language: 'DarT')]);
      });

      testWidgets('falls back to plain text when the highlighter declines', (tester) async {
        // A null return is the documented "I don't know this one" answer.
        await tester.pumpWidget(
          wrap(CodeBlockView(code: _dartSnippet, language: 'pseudocode', highlighter: (_) => null)),
        );

        expect(tester.takeException(), isNull);
        expect(spanOf(tester), isNull);
        expect(plainOf(tester), _dartSnippet);
      });

      testWidgets('does not call the highlighter without a language', (tester) async {
        final highlighter = _RecordingHighlighter();

        await tester.pumpWidget(wrap(CodeBlockView(code: _dartSnippet, highlighter: highlighter.call)));

        expect(highlighter.calls, isEmpty);
        expect(plainOf(tester), _dartSnippet);
      });

      testWidgets('does not call the highlighter past the length cap', (tester) async {
        // Highlighting re-runs for every frame a streaming fence grows by, so
        // the cost is quadratic in the block's length; past the cap the code is
        // shown plain rather than paying it.
        final huge = '$_dartSnippet\n' * 1000;
        expect(huge.length, greaterThan(20000));
        final highlighter = _RecordingHighlighter();

        // Scrollable, as a message list would be: 5000 lines don't fit the test
        // viewport, and an overflow here would be the harness's, not the
        // widget's.
        await tester.pumpWidget(
          wrap(
            SingleChildScrollView(
              child: CodeBlockView(code: huge, language: 'dart', highlighter: highlighter.call),
            ),
          ),
        );

        expect(highlighter.calls, isEmpty);
        expect(spanOf(tester), isNull);
      });

      testWidgets('re-highlights when the code changes', (tester) async {
        await tester.pumpWidget(
          wrap(const CodeBlockView(code: 'var x = 1;', language: 'dart', highlighter: _wordHighlighter)),
        );
        expect(_textOf(spanOf(tester)!), 'var x = 1;');

        // The streaming case: the same widget position, more code.
        await tester.pumpWidget(
          wrap(const CodeBlockView(code: 'var x = 1;\nvar y = 2;', language: 'dart', highlighter: _wordHighlighter)),
        );
        expect(_textOf(spanOf(tester)!), 'var x = 1;\nvar y = 2;');
      });

      testWidgets('reports and falls back when the highlighter throws', (tester) async {
        // Third-party code, called once per fence per tick. A code block must
        // not take down a message list, but nor should it fail invisibly.
        final reported = await _collectingErrors(
          () => tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: _dartSnippet,
                language: 'dart',
                highlighter: (_) => throw StateError('highlighter blew up'),
              ),
            ),
          ),
        );

        expect(spanOf(tester), isNull);
        expect(plainOf(tester), _dartSnippet);
        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.byIcon(Icons.content_copy), findsOneWidget);

        expect(reported, hasLength(1));
        expect(reported.single.library, 'stream_chat_flutter_ai');
        expect(reported.single.exception, isStateError);
      });

      testWidgets('reports and falls back when the highlighter drops text', (tester) async {
        // The failure mode a real highlighter is most likely to hit:
        // `re_highlight` reports a mid-parse grammar failure on its result
        // rather than throwing, and hands back only the tokens it managed to
        // produce. Rendering that loses the reader their code.
        final reported = await _collectingErrors(
          () => tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: _dartSnippet,
                language: 'dart',
                highlighter: (request) => TextSpan(text: request.code.substring(0, 4), style: request.baseStyle),
              ),
            ),
          ),
        );

        expect(spanOf(tester), isNull);
        expect(plainOf(tester), _dartSnippet);
        expect(reported, hasLength(1));
        expect(reported.single.library, 'stream_chat_flutter_ai');
      });

      testWidgets('reports a failing highlighter once, not once per rebuild', (tester) async {
        // A fence that fails while it is still streaming rebuilds on every
        // typewriter tick; a report per tick would flood the host's crash
        // reporter with hundreds of copies.
        final reported = await _collectingErrors(() async {
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'var', language: 'dart', highlighter: _boom)));
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'var x', language: 'dart', highlighter: _boom)));
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'var x = 1;', language: 'dart', highlighter: _boom)));
        });

        expect(reported, hasLength(1));
      });

      testWidgets('reports a failing inline closure once, though each rebuild passes a new one', (tester) async {
        // The usual streaming host builds its highlighter inline, so every
        // tick hands over a closure that isn't identical to the last.
        final reported = await _collectingErrors(() async {
          for (var i = 1; i <= 5; i++) {
            await tester.pumpWidget(
              wrap(CodeBlockView(code: 'var x = $i;', language: 'dart', highlighter: (_) => throw StateError('boom'))),
            );
          }
        });

        expect(reported, hasLength(1));
      });

      testWidgets('reports again after a theme change or a new highlighter', (tester) async {
        // A palette-specific failure on the new frame, or a different
        // highlighter's failure, must not be swallowed by the first report.
        Widget app(CodeBlockThemeData data, CodeHighlighter highlighter) => wrap(
          CodeBlockTheme(
            data: data,
            child: CodeBlockView(code: 'var x', language: 'dart', highlighter: highlighter),
          ),
        );
        const light = CodeBlockThemeData(backgroundColor: Color(0xFFFAFAFA));

        final reported = await _collectingErrors(() async {
          await tester.pumpWidget(app(const CodeBlockThemeData(), _boom));
          await tester.pumpWidget(app(light, _boom));
          await tester.pumpWidget(app(light, _boom2));
        });

        expect(reported, hasLength(3));
        expect(reported[0].context.toString(), contains('dark background'));
        expect(reported[1].context.toString(), contains('light background'));
      });

      testWidgets('says where a highlighter altered the text', (tester) async {
        final reported = await _collectingErrors(
          () => tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: 'var x = 1;',
                language: 'dart',
                highlighter: (request) => TextSpan(text: 'var y = 1;', style: request.baseStyle),
              ),
            ),
          ),
        );

        final message = (reported.single.exception as StateError).message;
        expect(message, contains('expected 10 characters, got 10'));
        expect(message, contains('first difference at index 4'));
      });

      testWidgets('uses its default colors when none are given', (tester) async {
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')));

        final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
        final decoration = tester.widget<Container>(container.first).decoration! as BoxDecoration;
        expect(decoration.color, kDefaultCodeBackgroundColor);
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).style?.color, kDefaultCodeForegroundColor);
      });

      testWidgets('takes its chrome from the given theme', (tester) async {
        const background = Color(0xFF102030);
        const foreground = Color(0xFFAABBCC);

        await tester.pumpWidget(
          wrap(
            const CodeBlockView(
              code: _dartSnippet,
              language: 'dart',
              theme: CodeBlockThemeData(
                backgroundColor: background,
                codeTextStyle: TextStyle(color: foreground),
              ),
            ),
          ),
        );

        final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
        final decoration = tester.widget<Container>(container.first).decoration! as BoxDecoration;
        expect(decoration.color, background);
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).style?.color, foreground);

        // The label and copy icon follow the foreground at reduced opacity
        // rather than a hardcoded grey.
        final expectedLabel = foreground.withValues(alpha: 0.6);
        expect(tester.widget<Text>(find.text('dart')).style?.color, expectedLabel);
        expect(tester.widget<Icon>(find.byIcon(Icons.content_copy)).color, expectedLabel);
      });

      testWidgets('hands the highlighter the block base style', (tester) async {
        // So a highlighter that only sets per-token colors still inherits the
        // block's font, size and foreground.
        await tester.pumpWidget(
          wrap(const CodeBlockView(code: 'var x = 1;', language: 'dart', highlighter: _captureStyle)),
        );

        expect(_capturedStyle?.color, kDefaultCodeForegroundColor);
        expect(_capturedStyle?.fontFamily, 'monospace');
        expect(_capturedStyle?.fontFamilyFallback, contains('Menlo'));
      });

      testWidgets('keeps a monospace stack that resolves off Android', (tester) async {
        // `flutter_test_config.dart` registers a real font under `monospace`,
        // so the fallbacks are never consulted in tests and a revert here would
        // be invisible in every golden. Assert the property directly.
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')));

        final body = tester.widget<SelectableText>(find.byType(SelectableText)).style!;
        expect(body.fontFamily, 'monospace');
        expect(body.fontFamilyFallback, contains('Menlo'));

        // The header label carries its own copy of the stack.
        final label = tester.widget<Text>(find.text('dart')).style!;
        expect(label.fontFamily, 'monospace');
        expect(label.fontFamilyFallback, contains('Menlo'));
      });

      group('throttling a growing fence', () {
        /// A fence body of exactly [n] characters, all word characters so
        /// `_wordHighlighter` colors the lot.
        String code(int n) => 'a' * n;

        testWidgets('a small gain reuses the last pass and renders the tail plain', (tester) async {
          final highlighter = _RecordingHighlighter();

          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(100), language: 'dart', highlighter: highlighter.call)),
          );
          expect(highlighter.calls, hasLength(1));

          // Ten more characters is far too little to pay for another pass.
          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(110), language: 'dart', highlighter: highlighter.call)),
          );

          expect(highlighter.calls, hasLength(1), reason: 'should not have re-highlighted');

          // But the reader must still see all 110 characters: the tail is
          // appended unhighlighted rather than dropped.
          final span = tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!;
          expect(_textOf(span), code(110));
          // The prefix keeps its colors while the tail waits.
          expect(_colorsOf(span), contains(_tokenColor));
        });

        testWidgets('a gain past the threshold re-highlights at once', (tester) async {
          final highlighter = _RecordingHighlighter();

          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(100), language: 'dart', highlighter: highlighter.call)),
          );
          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(164), language: 'dart', highlighter: highlighter.call)),
          );

          expect(highlighter.calls, hasLength(2));
          expect(highlighter.calls.last.code, code(164));
        });

        testWidgets('a fence that stops growing gets its tail highlighted', (tester) async {
          // Without the settle pass, a stream ending mid-threshold would leave
          // its last characters uncolored for good.
          final highlighter = _RecordingHighlighter();

          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(100), language: 'dart', highlighter: highlighter.call)),
          );
          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(110), language: 'dart', highlighter: highlighter.call)),
          );
          expect(highlighter.calls, hasLength(1));

          await tester.pump(const Duration(milliseconds: 200));

          expect(highlighter.calls, hasLength(2));
          expect(highlighter.calls.last.code, code(110));
          // Fully colored now, with nothing appended plain.
          final span = tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!;
          expect(_textOf(span), code(110));
        });

        testWidgets('each further gain restarts the settle delay', (tester) async {
          final highlighter = _RecordingHighlighter();

          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(100), language: 'dart', highlighter: highlighter.call)),
          );
          for (var i = 1; i <= 5; i++) {
            await tester.pumpWidget(
              wrap(CodeBlockView(code: code(100 + i * 5), language: 'dart', highlighter: highlighter.call)),
            );
            // Short of the settle delay, so the pass keeps being deferred.
            await tester.pump(const Duration(milliseconds: 60));
          }

          expect(highlighter.calls, hasLength(1), reason: 'a still-growing fence should not settle');

          await tester.pump(const Duration(milliseconds: 200));
          expect(highlighter.calls, hasLength(2));
          expect(highlighter.calls.last.code, code(125));
        });

        testWidgets('replaced, non-extending code re-highlights immediately', (tester) async {
          // A regenerated or edited message can be shorter than what is on
          // screen. The pending-tail arithmetic assumes the new code extends the
          // old, so this has to invalidate rather than throttle.
          final highlighter = _RecordingHighlighter();

          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(200), language: 'dart', highlighter: highlighter.call)),
          );
          await tester.pumpWidget(
            wrap(CodeBlockView(code: 'totally different', language: 'dart', highlighter: highlighter.call)),
          );

          expect(tester.takeException(), isNull);
          expect(highlighter.calls, hasLength(2));
          expect(highlighter.calls.last.code, 'totally different');
          expect(_textOf(tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!), 'totally different');
        });

        testWidgets('disposal with a pending settle pass does not throw', (tester) async {
          final highlighter = _RecordingHighlighter();

          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(100), language: 'dart', highlighter: highlighter.call)),
          );
          await tester.pumpWidget(
            wrap(CodeBlockView(code: code(110), language: 'dart', highlighter: highlighter.call)),
          );

          // Tear the block down while the settle timer is still armed.
          await tester.pumpWidget(wrap(const SizedBox()));
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
          expect(highlighter.calls, hasLength(1));
        });

        testWidgets('the pending tail never costs the reader a character', (tester) async {
          // The property that matters most, across the whole growth range.
          final highlighter = _RecordingHighlighter();

          for (var n = 1; n <= 300; n += 7) {
            await tester.pumpWidget(
              wrap(CodeBlockView(code: code(n), language: 'dart', highlighter: highlighter.call)),
            );
            final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
            final shown = selectable.textSpan != null ? _textOf(selectable.textSpan!) : selectable.data!;
            expect(shown, code(n), reason: 'lost text at $n characters');
          }
        });
      });

      group('theming', () {
        const lightTheme = CodeBlockThemeData(
          backgroundColor: Color(0xFFFAFAFA),
          headerBackgroundColor: Color(0xFFEAEAEA),
        );

        /// The header's own fill, identified by its top-only rounding rather
        /// than by how many boxes Material happens to build around it.
        Finder headerFill() => find.descendant(
          of: find.byType(CodeBlockView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).borderRadius ==
                    const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        );

        BoxDecoration frameOf(WidgetTester tester) {
          final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
          return tester.widget<Container>(container.first).decoration! as BoxDecoration;
        }

        Widget themed(Widget child, {CodeBlockThemeData? aiTheme, Brightness brightness = Brightness.light}) =>
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: brightness,
                extensions: [if (aiTheme != null) AITheme(codeBlockTheme: aiTheme)],
              ),
              home: Scaffold(body: child),
            );

        for (final brightness in Brightness.values) {
          testWidgets('defaults to the dark frame in ${brightness.name} mode', (tester) async {
            mockClipboard();
            await tester.pumpWidget(
              themed(
                const CodeBlockView(code: 'x', language: 'dart'),
                brightness: brightness,
              ),
            );

            expect(frameOf(tester).color, kDefaultCodeBackgroundColor);
            expect(
              tester.widget<SelectableText>(find.byType(SelectableText)).style?.color,
              kDefaultCodeForegroundColor,
            );
            final chrome = kDefaultCodeForegroundColor.withValues(alpha: 0.6);
            expect(tester.widget<Text>(find.text('dart')).style?.color, chrome);
            expect(tester.widget<Icon>(find.byIcon(Icons.content_copy)).color, chrome);
            expect(headerFill(), findsNothing, reason: 'no separate header fill by default');

            await tester.tap(find.byIcon(Icons.content_copy));
            await tester.pump();
            expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, Colors.greenAccent);
            await tester.pump(const Duration(seconds: 2));
          });
        }

        testWidgets('the widget theme beats CodeBlockTheme, which beats AITheme', (tester) async {
          await tester.pumpWidget(
            themed(
              aiTheme: const CodeBlockThemeData(
                backgroundColor: Color(0xFF000001),
                copyIconColor: Color(0xFF000011),
                copiedIconColor: Color(0xFF000111),
              ),
              const CodeBlockTheme(
                data: CodeBlockThemeData(backgroundColor: Color(0xFF000002), copyIconColor: Color(0xFF000022)),
                child: CodeBlockView(
                  code: 'x',
                  language: 'dart',
                  theme: CodeBlockThemeData(backgroundColor: Color(0xFF000003)),
                ),
              ),
            ),
          );

          expect(frameOf(tester).color, const Color(0xFF000003), reason: 'the widget theme wins');
          expect(
            tester.widget<Icon>(find.byIcon(Icons.content_copy)).color,
            const Color(0xFF000022),
            reason: 'the scope beats the extension',
          );
        });

        testWidgets('a light background gets dark default text and chrome', (tester) async {
          // A host setting only a light fill must not get the dark frame's
          // pale grey text on it.
          mockClipboard();
          await tester.pumpWidget(
            wrap(
              const CodeBlockView(
                code: 'x',
                language: 'dart',
                theme: CodeBlockThemeData(backgroundColor: Color(0xFFFAFAFA)),
              ),
            ),
          );

          final text = tester.widget<SelectableText>(find.byType(SelectableText)).style!.color!;
          expect(ThemeData.estimateBrightnessForColor(text), Brightness.dark);
          expect(tester.widget<Icon>(find.byIcon(Icons.content_copy)).color, text.withValues(alpha: 0.6));

          await tester.tap(find.byIcon(Icons.content_copy));
          await tester.pump();
          expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, isNot(Colors.greenAccent));
          await tester.pump(const Duration(seconds: 2));
        });

        testWidgets('paints a distinct header fill only when one is set', (tester) async {
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart', theme: lightTheme)));

          final header = tester.widget<DecoratedBox>(headerFill());
          expect((header.decoration as BoxDecoration).color, const Color(0xFFEAEAEA));
          expect(frameOf(tester).color, const Color(0xFFFAFAFA));
        });

        testWidgets('applies the label and code text styles over the monospace defaults', (tester) async {
          await tester.pumpWidget(
            wrap(
              const CodeBlockView(
                code: 'x',
                language: 'dart',
                theme: CodeBlockThemeData(
                  languageLabelStyle: TextStyle(fontWeight: FontWeight.bold),
                  codeTextStyle: TextStyle(fontSize: 20),
                ),
              ),
            ),
          );

          final label = tester.widget<Text>(find.text('dart')).style!;
          expect(label.fontWeight, FontWeight.bold);
          expect(label.fontFamily, 'monospace', reason: 'merged, not replaced');
          final body = tester.widget<SelectableText>(find.byType(SelectableText)).style!;
          expect(body.fontSize, 20);
          expect(body.fontFamily, 'monospace');
          expect(body.color, kDefaultCodeForegroundColor);
        });

        testWidgets('an inherit: false text style keeps the default color', (tester) async {
          await tester.pumpWidget(
            wrap(
              const CodeBlockView(
                code: 'x',
                language: 'dart',
                theme: CodeBlockThemeData(
                  codeTextStyle: TextStyle(inherit: false, fontSize: 14, textBaseline: TextBaseline.alphabetic),
                ),
              ),
            ),
          );

          expect(tester.widget<SelectableText>(find.byType(SelectableText)).style?.color, kDefaultCodeForegroundColor);
        });

        testWidgets('an inherit: false label style keeps a color', (tester) async {
          await tester.pumpWidget(
            wrap(
              const CodeBlockView(
                code: 'x',
                language: 'dart',
                theme: CodeBlockThemeData(
                  languageLabelStyle: TextStyle(inherit: false, fontSize: 12, textBaseline: TextBaseline.alphabetic),
                ),
              ),
            ),
          );

          expect(
            tester.widget<Text>(find.text('dart')).style?.color,
            kDefaultCodeForegroundColor.withValues(alpha: 0.6),
          );
        });

        testWidgets('a foreground paint on the code style drives the chrome', (tester) async {
          const paintColor = Color(0xFF00C853);
          final paint = Paint()..color = paintColor;
          await tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: 'x',
                language: 'dart',
                theme: CodeBlockThemeData(codeTextStyle: TextStyle(foreground: paint)),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          final body = tester.widget<SelectableText>(find.byType(SelectableText)).style!;
          expect(body.foreground, same(paint));
          expect(body.fontFamily, 'monospace');
          // Paint keeps its color at float32 precision, so compare loosely.
          final chrome = paintColor.withValues(alpha: 0.6);
          expect(tester.widget<Text>(find.text('dart')).style!.color, isSameColorAs(chrome));
          expect(tester.widget<Icon>(find.byIcon(Icons.content_copy)).color, isSameColorAs(chrome));
        });

        testWidgets('a foreground paint on the label style is kept', (tester) async {
          final paint = Paint()..color = const Color(0xFF00C853);
          await tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: 'x',
                language: 'dart',
                theme: CodeBlockThemeData(languageLabelStyle: TextStyle(foreground: paint)),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(tester.widget<Text>(find.text('dart')).style?.foreground, same(paint));
        });

        testWidgets('the highlighter is told the default frame is dark', (tester) async {
          final highlighter = _RecordingHighlighter();
          await tester.pumpWidget(
            themed(CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call)),
          );

          final request = highlighter.requests.single;
          // Light app, dark frame: the frame is what the tokens land on.
          expect(request.brightness, Brightness.dark);
          expect(request.theme.backgroundColor, kDefaultCodeBackgroundColor);
          expect(request.baseStyle, request.theme.codeTextStyle);
          expect(request.baseStyle.color, kDefaultCodeForegroundColor);
        });

        testWidgets('the highlighter is told a light frame is light, with every field resolved', (tester) async {
          final highlighter = _RecordingHighlighter();
          await tester.pumpWidget(
            themed(
              CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call),
              aiTheme: lightTheme,
              brightness: Brightness.dark,
            ),
          );

          final request = highlighter.requests.single;
          expect(request.brightness, Brightness.light);
          final theme = request.theme;
          expect(theme.backgroundColor, const Color(0xFFFAFAFA));
          expect(theme.headerBackgroundColor, const Color(0xFFEAEAEA));
          expect(theme.languageLabelStyle, isNotNull);
          expect(theme.copyIconColor, isNotNull);
          expect(theme.copiedIconColor, isNotNull);
          expect(theme.codeTextStyle, isNotNull);
        });

        testWidgets('a theme change re-highlights with the new brightness', (tester) async {
          // The span is cached in state; a palette picked for the old frame
          // would otherwise stay on the new one.
          final highlighter = _RecordingHighlighter();
          Widget app(CodeBlockThemeData data) => wrap(
            CodeBlockTheme(
              data: data,
              child: CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call),
            ),
          );

          await tester.pumpWidget(app(const CodeBlockThemeData()));
          await tester.pumpWidget(app(const CodeBlockThemeData()));
          expect(highlighter.requests, hasLength(1), reason: 'an equal theme must not re-highlight');

          await tester.pumpWidget(app(lightTheme));
          expect(highlighter.requests.map((r) => r.brightness), [Brightness.dark, Brightness.light]);
        });

        testWidgets('an unrelated ambient theme change does not re-highlight', (tester) async {
          final highlighter = _RecordingHighlighter();
          Widget app(Color seed) => MaterialApp(
            theme: ThemeData(colorSchemeSeed: seed),
            home: CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call),
          );

          await tester.pumpWidget(app(Colors.blue));
          await tester.pumpWidget(app(Colors.red));
          await tester.pumpAndSettle();

          expect(highlighter.requests, hasLength(1));
        });
      });

      group('CodeHighlightRequest', () {
        const resolved = CodeBlockThemeData(
          backgroundColor: Color(0xFFFAFAFA),
          codeTextStyle: TextStyle(fontSize: 13, color: Color(0xFF111111)),
        );

        test('compares by value', () {
          CodeHighlightRequest request(String code) =>
              CodeHighlightRequest(code: code, language: 'dart', theme: resolved);

          expect(request('a'), request('a'));
          expect(request('a').hashCode, request('a').hashCode);
          expect(request('a'), isNot(request('b')));
        });

        test('derives baseStyle and brightness from its theme', () {
          final request = CodeHighlightRequest(code: 'x', language: 'dart', theme: resolved);
          expect(request.baseStyle, resolved.codeTextStyle);
          expect(request.brightness, Brightness.light);
        });

        test('rejects an empty language or an unresolved theme', () {
          expect(
            () => CodeHighlightRequest(code: 'x', language: '', theme: resolved),
            throwsAssertionError,
          );
          expect(
            () => CodeHighlightRequest(code: 'x', language: 'dart', theme: const CodeBlockThemeData()),
            throwsAssertionError,
          );
        });
      });

      group('pinned brightness', () {
        BoxDecoration frameOf(WidgetTester tester) {
          final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
          return tester.widget<Container>(container.first).decoration! as BoxDecoration;
        }

        Color? codeColor(WidgetTester tester) =>
            tester.widget<SelectableText>(find.byType(SelectableText)).style?.color;

        testWidgets('light with no colors gives the light defaults and tells the highlighter', (tester) async {
          mockClipboard();
          final highlighter = _RecordingHighlighter();
          await tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: 'var x;',
                language: 'dart',
                highlighter: highlighter.call,
                theme: const CodeBlockThemeData(brightness: Brightness.light),
              ),
            ),
          );

          expect(frameOf(tester).color, const Color(0xFFF6F8FA));
          final text = codeColor(tester)!;
          expect(text, const Color(0xFF1F2328));
          expect(tester.widget<Icon>(find.byIcon(Icons.content_copy)).color, text.withValues(alpha: 0.6));
          expect(highlighter.requests.single.brightness, Brightness.light);
          expect(highlighter.requests.single.theme.brightness, Brightness.light);

          await tester.tap(find.byIcon(Icons.content_copy));
          await tester.pump();
          expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, isNot(Colors.greenAccent));
          await tester.pump(const Duration(seconds: 2));
        });

        testWidgets('dark pinned in a light app keeps the dark defaults', (tester) async {
          final highlighter = _RecordingHighlighter();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                extensions: const [AITheme(codeBlockTheme: CodeBlockThemeData(brightness: Brightness.dark))],
              ),
              home: CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call),
            ),
          );

          expect(frameOf(tester).color, kDefaultCodeBackgroundColor);
          expect(codeColor(tester), kDefaultCodeForegroundColor);
          expect(highlighter.requests.single.brightness, Brightness.dark);
        });

        testWidgets('a pinned brightness wins over a contrasting background', (tester) async {
          // Documented: explicit colors win over the defaults, and keeping them
          // consistent with the pinned brightness is the host's job.
          final highlighter = _RecordingHighlighter();
          await tester.pumpWidget(
            wrap(
              CodeBlockView(
                code: 'var x;',
                language: 'dart',
                highlighter: highlighter.call,
                theme: const CodeBlockThemeData(brightness: Brightness.dark, backgroundColor: Color(0xFFFFFFFF)),
              ),
            ),
          );

          expect(frameOf(tester).color, const Color(0xFFFFFFFF));
          expect(codeColor(tester), kDefaultCodeForegroundColor, reason: 'the defaults follow the pinned brightness');
          expect(highlighter.requests.single.brightness, Brightness.dark);
        });

        testWidgets('flipping a pinned brightness re-highlights at once', (tester) async {
          final highlighter = _RecordingHighlighter();
          Widget app(Brightness brightness) => wrap(
            CodeBlockView(
              code: 'var x;',
              language: 'dart',
              highlighter: highlighter.call,
              theme: CodeBlockThemeData(brightness: brightness, backgroundColor: const Color(0xFF808080)),
            ),
          );

          await tester.pumpWidget(app(Brightness.dark));
          await tester.pumpWidget(app(Brightness.light));

          expect(highlighter.requests.map((r) => r.brightness), [Brightness.dark, Brightness.light]);
        });
      });

      test('a hand-built request reads a pinned brightness from its theme', () {
        final request = CodeHighlightRequest(
          code: 'x',
          language: 'dart',
          theme: const CodeBlockThemeData(
            brightness: Brightness.dark,
            backgroundColor: Color(0xFFFFFFFF),
            codeTextStyle: TextStyle(fontSize: 13),
          ),
        );
        expect(request.brightness, Brightness.dark);
      });

      group('theme changes', () {
        const light = CodeBlockThemeData(backgroundColor: Color(0xFFFAFAFA));
        const dark = CodeBlockThemeData(backgroundColor: Color(0xFF0D1117));

        BoxDecoration frameOf(WidgetTester tester) {
          final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
          return tester.widget<Container>(container.first).decoration! as BoxDecoration;
        }

        testWidgets('a const block under a changing inherited theme re-highlights', (tester) async {
          // The parent hands over the identical widget, so only
          // didChangeDependencies runs — no didUpdateWidget to catch it.
          _globalRequests.clear();
          Widget app(CodeBlockThemeData data) => wrap(CodeBlockTheme(data: data, child: _constBlock));

          await tester.pumpWidget(app(dark));
          await tester.pumpWidget(app(light));

          expect(_globalRequests.map((r) => r.brightness), [Brightness.dark, Brightness.light]);
        });

        testWidgets('a color-only change repaints at once but re-highlights once, debounced', (tester) async {
          final highlighter = _RecordingHighlighter();
          Widget app(Color background) => wrap(
            CodeBlockTheme(
              data: CodeBlockThemeData(backgroundColor: background),
              child: CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call),
            ),
          );

          await tester.pumpWidget(app(const Color(0xFF101010)));
          for (var shade = 0x11; shade < 0x20; shade++) {
            await tester.pumpWidget(app(Color(0xFF000000 | shade << 16 | shade << 8 | shade)));
            await tester.pump(const Duration(milliseconds: 16));
          }

          expect(frameOf(tester).color, const Color(0xFF1F1F1F), reason: 'the frame follows every step');
          expect(highlighter.requests, hasLength(1), reason: 'color-only steps must not re-highlight per frame');

          await tester.pump(const Duration(milliseconds: 200));
          expect(highlighter.requests, hasLength(2));
          expect(highlighter.requests.last.theme.backgroundColor, const Color(0xFF1F1F1F));
        });

        testWidgets('a light/dark theme animation highlights a bounded number of times', (tester) async {
          final highlighter = _RecordingHighlighter();
          Widget app(ThemeMode mode) => MaterialApp(
            themeMode: mode,
            theme: ThemeData(extensions: const [AITheme(codeBlockTheme: light)]),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              extensions: const [AITheme(codeBlockTheme: dark)],
            ),
            home: Scaffold(
              body: CodeBlockView(code: 'var x;', language: 'dart', highlighter: highlighter.call),
            ),
          );

          await tester.pumpWidget(app(ThemeMode.light));
          expect(highlighter.requests, hasLength(1));

          await tester.pumpWidget(app(ThemeMode.dark));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 200));

          // One pass when the lerped background crosses into dark, one settle
          // pass at the end — not one per animation frame.
          expect(highlighter.requests.length, lessThanOrEqualTo(3));
          expect(highlighter.requests.last.brightness, Brightness.dark);
          expect(highlighter.requests.last.theme.backgroundColor, const Color(0xFF0D1117));
        });

        testWidgets('a font change re-highlights at once', (tester) async {
          final highlighter = _RecordingHighlighter();
          Widget app(double size) => wrap(
            CodeBlockView(
              code: 'var x;',
              language: 'dart',
              highlighter: highlighter.call,
              theme: CodeBlockThemeData(codeTextStyle: TextStyle(fontSize: size)),
            ),
          );

          await tester.pumpWidget(app(13));
          await tester.pumpWidget(app(20));

          expect(highlighter.requests.map((r) => r.baseStyle.fontSize), [13, 20]);
        });
      });

      goldenTest(
        'highlighted dart block',
        fileName: 'code_block_view_dart',
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
        builder: () => wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', highlighter: _wordHighlighter)),
      );

      goldenTest(
        'light-themed dart block',
        fileName: 'code_block_view_light',
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
        builder: () => wrap(
          const CodeBlockView(
            code: _dartSnippet,
            language: 'dart',
            highlighter: _brightnessAwareHighlighter,
            theme: CodeBlockThemeData(
              backgroundColor: Color(0xFFFAFAFA),
              headerBackgroundColor: Color(0xFFEAEAEA),
            ),
          ),
        ),
      );

      goldenTest(
        'light block from a pinned brightness',
        fileName: 'code_block_view_pinned_light',
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
        builder: () => wrap(
          const CodeBlockView(
            code: _dartSnippet,
            language: 'dart',
            highlighter: _brightnessAwareHighlighter,
            theme: CodeBlockThemeData(brightness: Brightness.light),
          ),
        ),
      );

      goldenTest(
        'plain block without a highlighter',
        fileName: 'code_block_view_plain',
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
        builder: () => wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')),
      );
    });
  });
}

/// Colors word runs from a palette chosen by the block's brightness, the way a
/// real host highlighter should.
TextSpan _brightnessAwareHighlighter(CodeHighlightRequest request) {
  final tokenColor = request.brightness == Brightness.dark ? _tokenColor : const Color(0xFFA626A4);
  final children = <TextSpan>[
    for (final match in RegExp(r'\w+|\W+').allMatches(request.code))
      TextSpan(
        text: match[0],
        style: RegExp(r'^\w').hasMatch(match[0]!) ? TextStyle(color: tokenColor) : null,
      ),
  ];
  return TextSpan(style: request.baseStyle, children: children);
}

/// Always throws, for the report-once test — a top-level function so the widget
/// can stay `const` across pumps.
TextSpan? _boom(CodeHighlightRequest request) => throw StateError('boom');

/// A second throwing highlighter, of a different type from [_boom] (it never
/// returns null), which the report dedupe keys on.
TextSpan _boom2(CodeHighlightRequest request) => throw StateError('boom 2');

/// Requests seen by [_recordGlobally], for a test that needs a `const` widget.
final _globalRequests = <CodeHighlightRequest>[];

TextSpan? _recordGlobally(CodeHighlightRequest request) {
  _globalRequests.add(request);
  return null;
}

/// One identical widget instance, so its parent's rebuild skips
/// didUpdateWidget.
const _constBlock = CodeBlockView(code: 'var x;', language: 'dart', highlighter: _recordGlobally);

TextStyle? _capturedStyle;

/// Records the base style it is handed, then declines.
TextSpan? _captureStyle(CodeHighlightRequest request) {
  _capturedStyle = request.baseStyle;
  return null;
}

/// Overrides only the two copy-button strings.
class _TestTranslations extends DefaultAITranslations {
  const _TestTranslations();

  @override
  String get copyCode => 'KOPIEER';

  @override
  String get codeCopied => 'GEKOPIEERD';
}
