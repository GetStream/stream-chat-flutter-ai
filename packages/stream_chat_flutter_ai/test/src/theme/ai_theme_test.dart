import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('AITheme', () {
    testWidgets('of falls back to defaults when the host registered none', (tester) async {
      // The whole thing is opt-in: an app that never heard of AITheme has to
      // keep rendering exactly as it did.
      late AITheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = AITheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, const AITheme());
      expect(resolved.chartTheme, const ChartThemeData());
    });

    testWidgets('of returns the registered extension', (tester) async {
      const theme = AITheme(chartTheme: ChartThemeData(height: 300));
      late AITheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [theme]),
          home: Builder(
            builder: (context) {
              resolved = AITheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, theme);
    });

    test('copyWith replaces the chart theme', () {
      const theme = AITheme(chartTheme: ChartThemeData(height: 300));
      expect(theme.copyWith().chartTheme.height, 300);
      expect(theme.copyWith(chartTheme: const ChartThemeData(height: 400)).chartTheme.height, 400);
    });

    test('lerp interpolates the chart theme', () {
      const a = AITheme(chartTheme: ChartThemeData(height: 100));
      const b = AITheme(chartTheme: ChartThemeData(height: 200));

      expect(a.lerp(b, 0).chartTheme.height, 100);
      expect(a.lerp(b, 0.5).chartTheme.height, 150);
      expect(a.lerp(b, 1).chartTheme.height, 200);
    });

    test('lerp with null returns this', () {
      const theme = AITheme(chartTheme: ChartThemeData(height: 100));
      expect(theme.lerp(null, 0.5), same(theme));
    });

    test('equal themes are equal and hash equally', () {
      // Load-bearing: ThemeData.== compares its extensions with mapEquals, so
      // without this every rebuild of an equal ThemeData would compare unequal
      // and start a fresh interpolation.
      const a = AITheme(chartTheme: ChartThemeData(seriesColors: [Color(0xFF112233)]));
      const b = AITheme(chartTheme: ChartThemeData(seriesColors: [Color(0xFF112233)]));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AITheme()));
    });
    group('code block theme', () {
      const codeBlock = CodeBlockThemeData(backgroundColor: Color(0xFF0A0A0A));
      const codeBlock2 = CodeBlockThemeData(backgroundColor: Color(0xFFFAFAFA));

      test('defaults to empty data', () {
        expect(const AITheme().codeBlockTheme, const CodeBlockThemeData());
      });

      test('takes part in equality, hashCode, copyWith and lerp', () {
        const theme = AITheme(codeBlockTheme: codeBlock);

        expect(theme, isNot(const AITheme()));
        expect(theme.hashCode, isNot(const AITheme().hashCode));
        expect(theme, const AITheme(codeBlockTheme: codeBlock));
        expect(theme.copyWith(codeBlockTheme: codeBlock2).codeBlockTheme, codeBlock2);
        expect(theme.copyWith().codeBlockTheme, codeBlock);
        expect(
          theme.lerp(const AITheme(codeBlockTheme: codeBlock2), 0.5).codeBlockTheme,
          CodeBlockThemeData.lerp(codeBlock, codeBlock2, 0.5),
        );
      });
    });

    group('typing indicator theme', () {
      const indicator = TypingIndicatorThemeData(dotColor: Color(0xFF0A0A0A));
      const indicator2 = TypingIndicatorThemeData(dotColor: Color(0xFFFAFAFA));

      test('defaults to empty data', () {
        expect(const AITheme().typingIndicatorTheme, const TypingIndicatorThemeData());
      });

      test('takes part in equality, hashCode, copyWith and lerp', () {
        const theme = AITheme(typingIndicatorTheme: indicator);

        expect(theme, isNot(const AITheme()));
        expect(theme.hashCode, isNot(const AITheme().hashCode));
        expect(theme, const AITheme(typingIndicatorTheme: indicator));
        expect(theme.copyWith(typingIndicatorTheme: indicator2).typingIndicatorTheme, indicator2);
        expect(theme.copyWith().typingIndicatorTheme, indicator);
        expect(
          theme.lerp(const AITheme(typingIndicatorTheme: indicator2), 0.5).typingIndicatorTheme,
          TypingIndicatorThemeData.lerp(indicator, indicator2, 0.5),
        );
      });
    });

    group('reasoning theme', () {
      const reasoning = ReasoningThemeData(ruleColor: Color(0xFF0A0A0A));
      const reasoning2 = ReasoningThemeData(ruleColor: Color(0xFFFAFAFA));

      test('defaults to empty data', () {
        expect(const AITheme().reasoningTheme, const ReasoningThemeData());
      });

      test('takes part in equality, hashCode, copyWith and lerp', () {
        const theme = AITheme(reasoningTheme: reasoning);

        expect(theme, isNot(const AITheme()));
        expect(theme.hashCode, isNot(const AITheme().hashCode));
        expect(theme, const AITheme(reasoningTheme: reasoning));
        expect(theme.copyWith(reasoningTheme: reasoning2).reasoningTheme, reasoning2);
        expect(theme.copyWith().reasoningTheme, reasoning);
        expect(
          theme.lerp(const AITheme(reasoningTheme: reasoning2), 0.5).reasoningTheme,
          ReasoningThemeData.lerp(reasoning, reasoning2, 0.5),
        );
      });
    });

    group('tool approval theme', () {
      const toolApproval = ToolApprovalThemeData(accentColor: Color(0xFF0A0A0A));
      const toolApproval2 = ToolApprovalThemeData(accentColor: Color(0xFFFAFAFA));

      test('defaults to empty data', () {
        expect(const AITheme().toolApprovalTheme, const ToolApprovalThemeData());
      });

      test('takes part in equality, hashCode, copyWith and lerp', () {
        const theme = AITheme(toolApprovalTheme: toolApproval);

        expect(theme, isNot(const AITheme()));
        expect(theme.hashCode, isNot(const AITheme().hashCode));
        expect(theme, const AITheme(toolApprovalTheme: toolApproval));
        expect(theme.copyWith(toolApprovalTheme: toolApproval2).toolApprovalTheme, toolApproval2);
        expect(theme.copyWith().toolApprovalTheme, toolApproval);
        expect(
          theme.lerp(const AITheme(toolApprovalTheme: toolApproval2), 0.5).toolApprovalTheme,
          ToolApprovalThemeData.lerp(toolApproval, toolApproval2, 0.5),
        );
      });
    });

    group('tool call theme', () {
      const toolCall = ToolCallThemeData(accentColor: Color(0xFF0A0A0A));
      const toolCall2 = ToolCallThemeData(accentColor: Color(0xFFFAFAFA));

      test('defaults to empty data', () {
        expect(const AITheme().toolCallTheme, const ToolCallThemeData());
      });

      test('takes part in equality, hashCode, copyWith and lerp', () {
        const theme = AITheme(toolCallTheme: toolCall);

        expect(theme, isNot(const AITheme()));
        expect(theme.hashCode, isNot(const AITheme().hashCode));
        expect(theme, const AITheme(toolCallTheme: toolCall));
        expect(theme.copyWith(toolCallTheme: toolCall2).toolCallTheme, toolCall2);
        expect(theme.copyWith().toolCallTheme, toolCall);
        expect(
          theme.lerp(const AITheme(toolCallTheme: toolCall2), 0.5).toolCallTheme,
          ToolCallThemeData.lerp(toolCall, toolCall2, 0.5),
        );
      });
    });

    group('composer and suggestions themes', () {
      // Each case is one component field on AITheme. A field left out of `==`
      // would let Theme.updateShouldNotify skip the rebuild after a host changed
      // only that component; one left out of `lerp` would drop it for the whole
      // light/dark animation MaterialApp runs.
      const composer = ComposerThemeData(sendButtonColor: Color(0xFF0000AA));
      const composer2 = ComposerThemeData(sendButtonColor: Color(0xFF0000CC));
      const suggestions = SuggestionsThemeData(backgroundColor: Color(0xFF00AA00));
      const suggestions2 = SuggestionsThemeData(backgroundColor: Color(0xFF00CC00));
      const chart = ChartThemeData(height: 300);

      test('default to empty data', () {
        expect(const AITheme().composerTheme, const ComposerThemeData());
        expect(const AITheme().suggestionsTheme, const SuggestionsThemeData());
      });

      test('take part in equality and hashCode', () {
        const withComposer = AITheme(composerTheme: composer);
        const withSuggestions = AITheme(suggestionsTheme: suggestions);

        expect(withComposer, isNot(const AITheme()));
        expect(withComposer.hashCode, isNot(const AITheme().hashCode));
        expect(withSuggestions, isNot(const AITheme()));
        expect(withSuggestions.hashCode, isNot(const AITheme().hashCode));
        expect(withComposer, const AITheme(composerTheme: composer));
        expect(withSuggestions, const AITheme(suggestionsTheme: suggestions));
      });

      test('copyWith replaces one component and keeps the others', () {
        const theme = AITheme(chartTheme: chart, composerTheme: composer, suggestionsTheme: suggestions);

        final composerOnly = theme.copyWith(composerTheme: composer2);
        expect(composerOnly.composerTheme, composer2);
        expect(composerOnly.suggestionsTheme, suggestions);
        expect(composerOnly.chartTheme, chart);

        final suggestionsOnly = theme.copyWith(suggestionsTheme: suggestions2);
        expect(suggestionsOnly.suggestionsTheme, suggestions2);
        expect(suggestionsOnly.composerTheme, composer);
        expect(suggestionsOnly.chartTheme, chart);

        expect(theme.copyWith(), theme);
      });

      test('lerp delegates to each component', () {
        const a = AITheme(composerTheme: composer, suggestionsTheme: suggestions);
        const b = AITheme(composerTheme: composer2, suggestionsTheme: suggestions2);

        final mid = a.lerp(b, 0.5);
        expect(mid.composerTheme, ComposerThemeData.lerp(composer, composer2, 0.5));
        expect(mid.suggestionsTheme, SuggestionsThemeData.lerp(suggestions, suggestions2, 0.5));
        expect(a.lerp(b, 0), a);
        expect(a.lerp(b, 1), b);
      });
    });
  });
}
