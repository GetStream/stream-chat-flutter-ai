import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/reasoning_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/suggestions_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_call_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/typing_indicator_theme.dart';

/// The package's overrides on the ambient Material theme, registered as a
/// [ThemeExtension].
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(
///         chartTheme: ChartThemeData(seriesColors: brandPalette),
///         composerTheme: ComposerThemeData(sendButtonColor: brandBlue),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// Overrides, not a design system: no brightness, color scheme or typography of
/// its own, so one instance covers light and dark. Note [ThemeData.copyWith]
/// replaces the whole extension set, so an app with other extensions has to
/// re-list them.
///
/// Every component theme defaults to an all-null instance, which derives each
/// field from the ambient [ThemeData] (or, for [codeBlockTheme], from the
/// package's fixed dark code frame) — registering no extension at all gets the
/// appearance the package always had.
///
/// See also:
///
///  * [ChartThemeData] and [ChartTheme], for charts.
///  * [CodeBlockThemeData] and [CodeBlockTheme], for code blocks.
///  * [ComposerThemeData] and [ComposerTheme], for the composer and its
///    attachment sheet.
///  * [ReasoningThemeData] and [ReasoningTheme], for the reasoning panel.
///  * [SuggestionsThemeData] and [SuggestionsTheme], for the suggestion chips.
///  * [ToolApprovalThemeData] and [ToolApprovalTheme], for tool-approval
///    cards.
///  * [ToolCallThemeData] and [ToolCallTheme], for tool-call rows.
///  * [TypingIndicatorThemeData] and [TypingIndicatorTheme], for the typing
///    indicator.
@immutable
class AITheme extends ThemeExtension<AITheme> {
  /// Creates an [AITheme].
  const AITheme({
    ChartThemeData? chartTheme,
    CodeBlockThemeData? codeBlockTheme,
    ComposerThemeData? composerTheme,
    ReasoningThemeData? reasoningTheme,
    SuggestionsThemeData? suggestionsTheme,
    ToolApprovalThemeData? toolApprovalTheme,
    ToolCallThemeData? toolCallTheme,
    TypingIndicatorThemeData? typingIndicatorTheme,
  }) : chartTheme = chartTheme ?? const ChartThemeData(),
       codeBlockTheme = codeBlockTheme ?? const CodeBlockThemeData(),
       composerTheme = composerTheme ?? const ComposerThemeData(),
       reasoningTheme = reasoningTheme ?? const ReasoningThemeData(),
       suggestionsTheme = suggestionsTheme ?? const SuggestionsThemeData(),
       toolApprovalTheme = toolApprovalTheme ?? const ToolApprovalThemeData(),
       toolCallTheme = toolCallTheme ?? const ToolCallThemeData(),
       typingIndicatorTheme = typingIndicatorTheme ?? const TypingIndicatorThemeData();

  /// How charts are drawn. Defaults to `const ChartThemeData()`, which derives
  /// every field from the ambient [ThemeData].
  final ChartThemeData chartTheme;

  /// How code blocks are framed. Defaults to `const CodeBlockThemeData()`,
  /// which keeps the package's dark code frame in light and dark mode alike.
  final CodeBlockThemeData codeBlockTheme;

  /// How the composer and its attachment sheet are drawn. Defaults to
  /// `const ComposerThemeData()`, which derives every field from the ambient
  /// [ThemeData].
  final ComposerThemeData composerTheme;

  /// How the reasoning panel is drawn. Defaults to `const ReasoningThemeData()`,
  /// which derives every field from the ambient [ThemeData].
  final ReasoningThemeData reasoningTheme;

  /// How suggestion chips are drawn. Defaults to
  /// `const SuggestionsThemeData()`, which derives every field from the ambient
  /// [ThemeData].
  final SuggestionsThemeData suggestionsTheme;

  /// How tool-approval cards are drawn. Defaults to
  /// `const ToolApprovalThemeData()`, which derives every field from the
  /// ambient [ThemeData].
  final ToolApprovalThemeData toolApprovalTheme;

  /// How tool-call rows are drawn. Defaults to `const ToolCallThemeData()`,
  /// which derives its colors and text styles from the ambient [ThemeData].
  final ToolCallThemeData toolCallTheme;

  /// How the typing indicator is drawn. Defaults to
  /// `const TypingIndicatorThemeData()`, which derives every field from the
  /// ambient [ThemeData].
  final TypingIndicatorThemeData typingIndicatorTheme;

  /// The [AITheme] on the ambient [ThemeData], or a default one.
  ///
  /// Never null and never throws — registering no extension gets the appearance
  /// the package always had, which is what makes theming opt-in.
  static AITheme of(BuildContext context) => Theme.of(context).extension<AITheme>() ?? const AITheme();

  @override
  AITheme copyWith({
    ChartThemeData? chartTheme,
    CodeBlockThemeData? codeBlockTheme,
    ComposerThemeData? composerTheme,
    ReasoningThemeData? reasoningTheme,
    SuggestionsThemeData? suggestionsTheme,
    ToolApprovalThemeData? toolApprovalTheme,
    ToolCallThemeData? toolCallTheme,
    TypingIndicatorThemeData? typingIndicatorTheme,
  }) => AITheme(
    chartTheme: chartTheme ?? this.chartTheme,
    codeBlockTheme: codeBlockTheme ?? this.codeBlockTheme,
    composerTheme: composerTheme ?? this.composerTheme,
    reasoningTheme: reasoningTheme ?? this.reasoningTheme,
    suggestionsTheme: suggestionsTheme ?? this.suggestionsTheme,
    toolApprovalTheme: toolApprovalTheme ?? this.toolApprovalTheme,
    toolCallTheme: toolCallTheme ?? this.toolCallTheme,
    typingIndicatorTheme: typingIndicatorTheme ?? this.typingIndicatorTheme,
  );

  @override
  AITheme lerp(covariant AITheme? other, double t) {
    if (other == null || identical(this, other)) return this;
    return AITheme(
      chartTheme: ChartThemeData.lerp(chartTheme, other.chartTheme, t),
      codeBlockTheme: CodeBlockThemeData.lerp(codeBlockTheme, other.codeBlockTheme, t),
      composerTheme: ComposerThemeData.lerp(composerTheme, other.composerTheme, t),
      reasoningTheme: ReasoningThemeData.lerp(reasoningTheme, other.reasoningTheme, t),
      suggestionsTheme: SuggestionsThemeData.lerp(suggestionsTheme, other.suggestionsTheme, t),
      toolApprovalTheme: ToolApprovalThemeData.lerp(toolApprovalTheme, other.toolApprovalTheme, t),
      toolCallTheme: ToolCallThemeData.lerp(toolCallTheme, other.toolCallTheme, t),
      typingIndicatorTheme: TypingIndicatorThemeData.lerp(typingIndicatorTheme, other.typingIndicatorTheme, t),
    );
  }

  // Load-bearing: ThemeData.== compares extensions with mapEquals, so without
  // this every rebuild of an identical ThemeData compares unequal and restarts
  // the theme interpolation.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AITheme &&
        other.chartTheme == chartTheme &&
        other.codeBlockTheme == codeBlockTheme &&
        other.composerTheme == composerTheme &&
        other.reasoningTheme == reasoningTheme &&
        other.suggestionsTheme == suggestionsTheme &&
        other.toolApprovalTheme == toolApprovalTheme &&
        other.toolCallTheme == toolCallTheme &&
        other.typingIndicatorTheme == typingIndicatorTheme;
  }

  @override
  int get hashCode => Object.hash(
    chartTheme,
    codeBlockTheme,
    composerTheme,
    reasoningTheme,
    suggestionsTheme,
    toolApprovalTheme,
    toolCallTheme,
    typingIndicatorTheme,
  );
}
