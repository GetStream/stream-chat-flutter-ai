import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

/// What the indicator asks Stream's dots for.
StreamTypingIndicatorDotsProps _dots(WidgetTester tester) =>
    tester.widget<StreamTypingIndicatorDots>(find.byType(StreamTypingIndicatorDots)).props;

/// Turns on the platform's reduced-motion setting for the rest of the test.
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Lets every dot's staggered start fire, so no timer outlives the test.
Future<void> _settleStagger(WidgetTester tester) => tester.pump(const Duration(seconds: 2));

void main() {
  group('AITypingIndicatorView', () {
    testWidgets('displays the provided text', (WidgetTester tester) async {
      const testText = 'AI is thinking';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AITypingIndicatorView(
              text: testText,
            ),
          ),
        ),
      );

      await _settleStagger(tester);

      expect(find.text(testText), findsOneWidget);
    });

    testWidgets('applies the provided textStyle', (WidgetTester tester) async {
      const testText = 'AI is thinking';
      const textStyle = TextStyle(fontSize: 20, color: Colors.blue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AITypingIndicatorView(
              text: testText,
              textStyle: textStyle,
            ),
          ),
        ),
      );

      await _settleStagger(tester);

      final textWidget = tester.widget<Text>(find.text(testText));
      expect(textWidget.style?.fontSize, equals(20));
      expect(textWidget.style?.color, equals(Colors.blue));
    });

    group('theme', () {
      testWidgets("defaults to the Stream theme's bodyDefault in textSecondary, with dots to match", (tester) async {
        final stream = StreamTheme.light();
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));
        await _settleStagger(tester);

        final style = tester.widget<Text>(find.text('Thinking')).style!;
        expect(style.fontSize, stream.textTheme.bodyDefault.fontSize);
        expect(style.color, stream.colorScheme.textSecondary);
        expect(_dots(tester).color, stream.colorScheme.textSecondary);
        expect(_dots(tester).dotSize, isNull, reason: "Stream's own size");
      });

      testWidgets('the default dots are legible in dark mode, not black', (tester) async {
        final theme = ThemeData(brightness: Brightness.dark);
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking'), theme: theme));
        await _settleStagger(tester);

        final color = _dots(tester).color!;
        expect(color, StreamTheme.dark().colorScheme.textSecondary);
        expect(ThemeData.estimateBrightnessForColor(color), Brightness.light);
      });

      testWidgets('resolves widget > TypingIndicatorTheme > AITheme > defaults', (tester) async {
        final theme = ThemeData(
          extensions: const [
            AITheme(
              typingIndicatorTheme: TypingIndicatorThemeData(
                dotColor: Color(0xFF0000A1),
                dotSize: 10,
                textStyle: TextStyle(fontSize: 30, color: Color(0xFF0000B1)),
              ),
            ),
          ],
        );

        Future<void> pump({TypingIndicatorThemeData? scope, Color? dotColor}) async {
          Widget child = AITypingIndicatorView(text: 'Thinking', dotColor: dotColor);
          if (scope != null) child = TypingIndicatorTheme(data: scope, child: child);
          await tester.pumpWidget(_wrap(child, theme: theme));
          await _settleStagger(tester);
        }

        await pump();
        expect(_dots(tester).color, const Color(0xFF0000A1), reason: 'AITheme over the defaults');
        expect(_dots(tester).dotSize, 10);
        expect(tester.widget<Text>(find.text('Thinking')).style!.fontSize, 30);

        await pump(scope: const TypingIndicatorThemeData(dotColor: Color(0xFF0000A2)));
        expect(_dots(tester).color, const Color(0xFF0000A2), reason: 'the scope over AITheme');

        await pump(
          scope: const TypingIndicatorThemeData(dotColor: Color(0xFF0000A2)),
          dotColor: const Color(0xFF0000A3),
        );
        expect(_dots(tester).color, const Color(0xFF0000A3), reason: 'the widget over the scope');
      });

      testWidgets('the dots follow the text color when no dot color is set', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TypingIndicatorTheme(
              data: TypingIndicatorThemeData(textStyle: TextStyle(color: Color(0xFF00AA00))),
              child: AITypingIndicatorView(text: 'Thinking', textStyle: TextStyle(fontSize: 20)),
            ),
          ),
        );
        await _settleStagger(tester);

        final style = tester.widget<Text>(find.text('Thinking')).style!;
        expect(style.fontSize, 20, reason: "the widget's style merges over the themed one");
        expect(style.color, const Color(0xFF00AA00), reason: 'and keeps its color');
        expect(_dots(tester).color, const Color(0xFF00AA00));
      });

      testWidgets('an inherit: false textStyle keeps a color from the defaults', (tester) async {
        final colors = StreamTheme.light().colorScheme;
        await tester.pumpWidget(
          _wrap(const AITypingIndicatorView(text: 'Thinking', textStyle: TextStyle(inherit: false, fontSize: 18))),
        );
        await _settleStagger(tester);

        expect(tester.takeException(), isNull);
        final style = tester.widget<Text>(find.text('Thinking')).style!;
        expect(style.fontSize, 18);
        expect(style.color, colors.textSecondary);
        expect(_dots(tester).color, colors.textSecondary);
      });

      testWidgets('textStyle merges across all three levels', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TypingIndicatorTheme(
              data: TypingIndicatorThemeData(textStyle: TextStyle(fontWeight: FontWeight.w700)),
              child: AITypingIndicatorView(text: 'Thinking', textStyle: TextStyle(fontSize: 22)),
            ),
            theme: ThemeData(
              extensions: const [
                AITheme(
                  typingIndicatorTheme: TypingIndicatorThemeData(textStyle: TextStyle(color: Color(0xFF0000C1))),
                ),
              ],
            ),
          ),
        );
        await _settleStagger(tester);

        final style = tester.widget<Text>(find.text('Thinking')).style!;
        expect(style.fontSize, 22, reason: 'from the widget');
        expect(style.fontWeight, FontWeight.w700, reason: 'from the scope');
        // A scope replaces AITheme's textStyle (a set field replaces), so the
        // color falls back to the default rather than AITheme's.
        expect(style.color, isNot(const Color(0xFF0000C1)));
      });

      testWidgets('AITheme color and widget fontSize combine', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AITypingIndicatorView(text: 'Thinking', textStyle: TextStyle(fontSize: 22)),
            theme: ThemeData(
              extensions: const [
                AITheme(
                  typingIndicatorTheme: TypingIndicatorThemeData(textStyle: TextStyle(color: Color(0xFF0000C1))),
                ),
              ],
            ),
          ),
        );
        await _settleStagger(tester);

        final style = tester.widget<Text>(find.text('Thinking')).style!;
        expect(style.fontSize, 22);
        expect(style.color, const Color(0xFF0000C1));
        expect(_dots(tester).color, const Color(0xFF0000C1));
      });

      testWidgets("resolves dotSpacing widget > TypingIndicatorTheme > AITheme > Stream's", (tester) async {
        Future<double?> spacing({ThemeData? theme, double? scope, double? widget}) async {
          Widget child = AITypingIndicatorView(text: 'Thinking', dotSpacing: widget);
          if (scope != null) {
            child = TypingIndicatorTheme(
              data: TypingIndicatorThemeData(dotSpacing: scope),
              child: child,
            );
          }
          await tester.pumpWidget(_wrap(child, theme: theme));
          await _settleStagger(tester);
          return _dots(tester).spacing;
        }

        final themed = ThemeData(
          extensions: const [AITheme(typingIndicatorTheme: TypingIndicatorThemeData(dotSpacing: 6))],
        );
        expect(await spacing(), isNull);
        expect(await spacing(theme: themed), 6);
        expect(await spacing(theme: themed, scope: 7), 7);
        expect(await spacing(theme: themed, scope: 7, widget: 9), 9);
      });

      test('negative sizes are rejected', () {
        expect(() => AITypingIndicatorView(text: 'x', dotSize: -1), throwsAssertionError);
        expect(() => AITypingIndicatorView(text: 'x', dotSpacing: -1), throwsAssertionError);
        expect(() => TypingIndicatorThemeData(dotSize: -1), throwsAssertionError);
        expect(() => TypingIndicatorThemeData(dotSpacing: -1), throwsAssertionError);
      });
    });

    group('semantics', () {
      testWidgets('is a single live region labelled with the text, without the dots', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));
        await _settleStagger(tester);

        final node = tester.getSemantics(find.byType(AITypingIndicatorView));
        expect(node, isSemantics(label: 'Thinking', isLiveRegion: true));
        expect(node.childrenCount, 0, reason: 'the caption and dots add no nodes of their own');
        expect(find.bySemanticsLabel('Thinking'), findsOneWidget, reason: 'the caption is not read twice');

        handle.dispose();
      });

      testWidgets('a text change relabels the same live-region node, so it is announced', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));
        await _settleStagger(tester);
        final before = tester.getSemantics(find.byType(AITypingIndicatorView));

        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Checking sources')));
        await _settleStagger(tester);
        final after = tester.getSemantics(find.byType(AITypingIndicatorView));

        // A screen reader announces a live region when the label of a node it
        // already knows changes; a fresh node would not be a change.
        expect(after.id, before.id);
        expect(after, isSemantics(label: 'Checking sources', isLiveRegion: true));
        expect(find.bySemanticsLabel('Thinking'), findsNothing);

        handle.dispose();
      });
    });

    group('reduced motion', () {
      testWidgets('animates the dots normally', (tester) async {
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));
        await _settleStagger(tester);

        expect(tester.hasRunningAnimations, isTrue);
      });

      testWidgets('draws static dots with no animation running', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));

        expect(tester.hasRunningAnimations, isFalse);
        // Would time out if any dot were still animating.
        await tester.pumpAndSettle();
        expect(find.byType(StreamTypingIndicatorDots), findsOneWidget);
      });

      testWidgets('animates again when reduced motion is switched back off', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));
        expect(tester.hasRunningAnimations, isFalse);

        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pump();
        await _settleStagger(tester);

        expect(tester.hasRunningAnimations, isTrue);
      });

      testWidgets('stops animating when reduced motion is switched on', (tester) async {
        await tester.pumpWidget(_wrap(const AITypingIndicatorView(text: 'Thinking')));
        await _settleStagger(tester);
        expect(tester.hasRunningAnimations, isTrue);

        _reduceMotion(tester);
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        await tester.pumpAndSettle();
      });
    });
  });
}
