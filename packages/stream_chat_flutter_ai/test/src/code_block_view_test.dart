import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/highlight/code_languages.dart';

/// A short Dart snippet with a keyword, a string, a comment and a number, so
/// any reasonable grammar has to emit several distinct scopes for it.
const _dartSnippet = '''
// Greets the world.
void main() {
  const times = 3;
  print('hello' * times);
}''';

/// A language name registered only for the duration of a test, for a grammar
/// built to fail part-way through its input.
const _bombLanguage = 'bomb';

/// A grammar that throws part-way through its input, for the safe-mode path.
///
/// `re_highlight` swallows the throw and hands back a `HighlightResult` holding
/// only the tokens parsed before it, so this is what a real grammar bug looks
/// like to `CodeBlockView`.
Mode _bombGrammar() => Mode(
  name: _bombLanguage,
  contains: [Mode(begin: '"', end: '"', onBegin: (m, resp) => throw StateError('grammar blew up'))],
);

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

      testWidgets('colors a recognised language, keeping every character', (tester) async {
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')));

        final span = spanOf(tester);
        expect(span, isNotNull);
        expect(_colorsOf(span!).length, greaterThanOrEqualTo(3));
        expect(_textOf(span), _dartSnippet);
      });

      testWidgets('resolves language aliases', (tester) async {
        // `js`, `py`, `yml` and `c++` are aliases the grammars declare
        // themselves rather than entries in the curated language map, so this
        // is really asserting that `registerLanguage` picked them up.
        const cases = {
          'js': "const greeting = 'hello'; // comment",
          'py': "greeting = 'hello'  # comment",
          'yml': 'greeting: hello # comment',
          'c++': '// comment\nint main() { return 0; }',
        };

        for (final entry in cases.entries) {
          await tester.pumpWidget(wrap(CodeBlockView(code: entry.value, language: entry.key)));

          final span = spanOf(tester);
          expect(span, isNotNull, reason: 'no span for ${entry.key}');
          expect(_colorsOf(span!).length, greaterThan(1), reason: 'not highlighted: ${entry.key}');
          expect(_textOf(span), entry.value, reason: 'text altered for ${entry.key}');
        }
      });

      testWidgets('falls back to plain text for an unknown language', (tester) async {
        // Not merely unhighlighted: `Highlight.highlight` throws on a language
        // it has no grammar for, and models label fences with anything.
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'pseudocode')));

        expect(tester.takeException(), isNull);
        expect(spanOf(tester), isNull);
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, _dartSnippet);
      });

      testWidgets('falls back to plain text with no language', (tester) async {
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet)));

        expect(spanOf(tester), isNull);
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, _dartSnippet);
      });

      testWidgets('skips highlighting past the length cap', (tester) async {
        // Highlighting re-runs for every frame a streaming fence grows by, so
        // the cost is quadratic in the block's length; past the cap the code is
        // shown plain rather than paying it.
        final huge = '$_dartSnippet\n' * 1000;
        expect(huge.length, greaterThan(20000));

        // Scrollable, as a message list would be: 5000 lines don't fit the
        // test viewport, and an overflow here would be the harness's, not the
        // widget's.
        await tester.pumpWidget(
          wrap(
            SingleChildScrollView(
              child: CodeBlockView(code: huge, language: 'dart'),
            ),
          ),
        );

        expect(spanOf(tester), isNull);
      });

      testWidgets('re-highlights when the code changes', (tester) async {
        await tester.pumpWidget(wrap(const CodeBlockView(code: 'var x = 1;', language: 'dart')));
        expect(_textOf(spanOf(tester)!), 'var x = 1;');

        // The streaming case: the same widget position, more code.
        await tester.pumpWidget(wrap(const CodeBlockView(code: 'var x = 1;\nvar y = 2;', language: 'dart')));
        expect(_textOf(spanOf(tester)!), 'var x = 1;\nvar y = 2;');
      });

      testWidgets('takes its chrome from the theme, not from constants', (tester) async {
        const background = Color(0xFF102030);
        const foreground = Color(0xFFAABBCC);
        const theme = {
          'root': TextStyle(color: foreground, backgroundColor: background),
          'keyword': TextStyle(color: Color(0xFFFF0000)),
        };

        await tester.pumpWidget(
          wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', theme: theme)),
        );

        final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
        final decoration = tester.widget<Container>(container.first).decoration! as BoxDecoration;
        expect(decoration.color, background);

        // The label and copy icon follow the theme's foreground at reduced
        // opacity rather than a hardcoded grey.
        final expectedLabel = foreground.withValues(alpha: 0.6);
        expect(tester.widget<Text>(find.text('dart')).style?.color, expectedLabel);
        expect(tester.widget<Icon>(find.byIcon(Icons.content_copy)).color, expectedLabel);

        expect(_colorsOf(spanOf(tester)!), contains(const Color(0xFFFF0000)));
      });

      testWidgets('re-highlights when the theme changes', (tester) async {
        const red = {'root': TextStyle(color: Color(0xFF000000)), 'keyword': TextStyle(color: Color(0xFFFF0000))};
        const blue = {'root': TextStyle(color: Color(0xFF000000)), 'keyword': TextStyle(color: Color(0xFF0000FF))};

        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', theme: red)));
        expect(_colorsOf(spanOf(tester)!), contains(const Color(0xFFFF0000)));

        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', theme: blue)));
        expect(_colorsOf(spanOf(tester)!), contains(const Color(0xFF0000FF)));
      });

      testWidgets('uses the default theme when none is given', (tester) async {
        // Every other theme assertion injects a custom map, so without this the
        // colors essentially every user actually sees are pinned nowhere.
        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')));

        final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
        final decoration = tester.widget<Container>(container.first).decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFF1E1E1E));
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).style?.color, const Color(0xFFDCDCDC));
      });

      testWidgets('falls back to its own colors for a theme with no root', (tester) async {
        // A hand-written theme is documented as supported, and needn't mention
        // `root` — the only path that reaches `_kBgColor` / `_kFgColor`.
        const rootless = {'keyword': TextStyle(color: Color(0xFFFF0000))};

        await tester.pumpWidget(wrap(const CodeBlockView(code: _dartSnippet, language: 'dart', theme: rootless)));

        final container = find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Container));
        final decoration = tester.widget<Container>(container.first).decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFF1E1E1E));
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).style?.color, const Color(0xFFD4D4D4));
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

      testWidgets('reports and falls back when a grammar fails mid-parse', (tester) async {
        // `Highlight` runs in safe mode: a grammar that throws part-way through
        // does not propagate, it comes back as a `HighlightResult` carrying
        // only the tokens parsed so far. Rendering that silently drops the rest
        // of the user's code — here, all of it.
        kCodeHighlight.registerLanguage(_bombLanguage, _bombGrammar());
        addTearDown(() => kCodeHighlight.unregisterLanguage(_bombLanguage));

        const code = 'alpha "beta" gamma delta epsilon';
        final reported = await _collectingErrors(
          () => tester.pumpWidget(wrap(const CodeBlockView(code: code, language: _bombLanguage))),
        );

        // Plain text, in the same code block, with every character intact —
        // not an empty box where the code was.
        expect(spanOf(tester), isNull);
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, code);
        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.byIcon(Icons.content_copy), findsOneWidget);

        // And the host hears about it, rather than the block looking like a
        // language that was simply never supported.
        expect(reported, hasLength(1));
        expect(reported.single.library, 'stream_chat_flutter_ai');
        expect(reported.single.exception, isStateError);
      });

      testWidgets('reports a failing grammar once, not once per rebuild', (tester) async {
        // A fence that fails while it is still streaming rebuilds on every
        // typewriter tick; a report per tick would flood the host's crash
        // reporter with hundreds of copies.
        kCodeHighlight.registerLanguage(_bombLanguage, _bombGrammar());
        addTearDown(() => kCodeHighlight.unregisterLanguage(_bombLanguage));

        final reported = await _collectingErrors(() async {
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'alpha "b', language: _bombLanguage)));
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'alpha "be', language: _bombLanguage)));
          await tester.pumpWidget(wrap(const CodeBlockView(code: 'alpha "beta" gamma', language: _bombLanguage)));
        });

        expect(reported, hasLength(1));
      });

      goldenTest(
        'highlighted dart block',
        fileName: 'code_block_view_dart',
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
        builder: () => wrap(const CodeBlockView(code: _dartSnippet, language: 'dart')),
      );
    });

    group('language registration', () {
      test('registers every curated grammar', () {
        // Pins the deliberate curation: `builtinAllLanguages` would drag 2.7 MB
        // of grammar source into every host app, so this set is hand-picked and
        // a change to it should be a decision, not a drive-by.
        expect(kCodeBlockLanguages, hasLength(31));

        for (final name in kCodeBlockLanguages.keys) {
          expect(kCodeHighlight.getLanguage(name), isNotNull, reason: 'unregistered: $name');
        }
      });

      test('resolves every alias the docs promise', () {
        // These come from each grammar's own `aliases`, not from the curated
        // map, so a `re_highlight` upgrade could drop one and silently demote
        // that language to plain text.
        const aliases = {
          'js': 'javascript',
          'jsx': 'javascript',
          'mjs': 'javascript',
          'ts': 'typescript',
          'tsx': 'typescript',
          'py': 'python',
          'sh': 'bash',
          'yml': 'yaml',
          'c++': 'cpp',
          'hpp': 'cpp',
          'cxx': 'cpp',
          'cs': 'csharp',
          'c#': 'csharp',
          'rb': 'ruby',
          'kt': 'kotlin',
          'rs': 'rust',
          'md': 'markdown',
          'objc': 'objectivec',
          'gql': 'graphql',
          'docker': 'dockerfile',
          'html': 'xml',
          'svg': 'xml',
          'xhtml': 'xml',
          'text': 'plaintext',
          'txt': 'plaintext',
          'console': 'shell',
        };

        aliases.forEach((alias, language) {
          expect(
            kCodeHighlight.getLanguage(alias),
            same(kCodeBlockLanguages[language]),
            reason: '$alias should resolve to $language',
          );
        });
      });

      test('matches a language name case-insensitively', () {
        // Documented on `CodeBlockView.language`, but delivered by
        // `re_highlight` rather than by anything in this package.
        expect(kCodeHighlight.getLanguage('DART'), same(kCodeBlockLanguages['dart']));
        expect(kCodeHighlight.getLanguage('Python'), same(kCodeBlockLanguages['python']));
      });
    });
  });
}
