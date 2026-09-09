import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';

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
TextSpan _wordHighlighter(String code, String language, TextStyle baseStyle) {
  final children = <TextSpan>[];
  for (final match in RegExp(r'\w+|\W+').allMatches(code)) {
    final text = match[0]!;
    final isWord = RegExp(r'^\w').hasMatch(text);
    children.add(
      TextSpan(
        text: text,
        style: isWord ? const TextStyle(color: _tokenColor) : null,
      ),
    );
  }
  return TextSpan(style: baseStyle, children: children);
}

/// Records every call, so a test can assert the highlighter was *not* reached.
class _RecordingHighlighter {
  final calls = <({String code, String language})>[];

  TextSpan? call(String code, String language, TextStyle baseStyle) {
    calls.add((code: code, language: language));
    return _wordHighlighter(code, language, baseStyle);
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
          wrap(CodeBlockView(code: _dartSnippet, language: 'pseudocode', highlighter: (_, _, _) => null)),
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
                highlighter: (_, _, _) => throw StateError('highlighter blew up'),
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
                highlighter: (code, _, style) => TextSpan(text: code.substring(0, 4), style: style),
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

      testWidgets('uses its default colors when none are given', (tester) async {
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')));

        final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
        final decoration = tester.widget<Container>(container.first).decoration! as BoxDecoration;
        expect(decoration.color, kDefaultCodeBackgroundColor);
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).style?.color, kDefaultCodeForegroundColor);
      });

      testWidgets('takes its chrome from the given colors', (tester) async {
        const background = Color(0xFF102030);
        const foreground = Color(0xFFAABBCC);

        await tester.pumpWidget(
          wrap(
            const CodeBlockView(
              code: _dartSnippet,
              language: 'dart',
              backgroundColor: background,
              foregroundColor: foreground,
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

      goldenTest(
        'highlighted dart block',
        fileName: 'code_block_view_dart',
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
        builder: () => wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', highlighter: _wordHighlighter)),
      );
    });
  });
}

/// Always throws, for the report-once test — a top-level function so the widget
/// can stay `const` across pumps.
TextSpan? _boom(String code, String language, TextStyle baseStyle) => throw StateError('boom');

TextStyle? _capturedStyle;

/// Records the base style it is handed, then declines.
TextSpan? _captureStyle(String code, String language, TextStyle baseStyle) {
  _capturedStyle = baseStyle;
  return null;
}
