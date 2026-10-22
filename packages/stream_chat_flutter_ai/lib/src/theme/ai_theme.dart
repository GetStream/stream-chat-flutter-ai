import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/reasoning_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/reply_actions_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/suggestions_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_call_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/typing_indicator_theme.dart';
// Imported for the doc links below only.
import 'package:stream_core_flutter/chat.dart';

/// The package's overrides on top of the Stream theme ([StreamTheme]),
/// registered as a [ThemeExtension] on the app's [ThemeData].
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
/// field from the Stream theme, which falls back to Stream's defaults for the
/// app's brightness when the app sets none (or, for [codeBlockTheme], from the
/// package's fixed dark code frame) — registering no extension at all gets the
/// appearance the package always had.
///
/// See also:
///
///  * [ChartThemeData] and [ChartTheme], for charts.
///  * [CodeBlockThemeData] and [CodeBlockTheme], for code blocks.
///  * [ComposerThemeData] and [ComposerTheme], for the composer and its
///    attachment sheet.
///  * [ConversationThemeData] and [ConversationTheme], for the conversation
///    and its messages.
///  * [ReasoningThemeData] and [ReasoningTheme], for the reasoning panel.
///  * [ReplyActionsThemeData] and [ReplyActionsTheme], for the buttons under a
///    reply.
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
    ConversationThemeData? conversationTheme,
    ReasoningThemeData? reasoningTheme,
    ReplyActionsThemeData? replyActionsTheme,
    SuggestionsThemeData? suggestionsTheme,
    ToolApprovalThemeData? toolApprovalTheme,
    ToolCallThemeData? toolCallTheme,
    TypingIndicatorThemeData? typingIndicatorTheme,
  }) : chartTheme = chartTheme ?? const ChartThemeData(),
       codeBlockTheme = codeBlockTheme ?? const CodeBlockThemeData(),
       composerTheme = composerTheme ?? const ComposerThemeData(),
       conversationTheme = conversationTheme ?? const ConversationThemeData(),
       reasoningTheme = reasoningTheme ?? const ReasoningThemeData(),
       replyActionsTheme = replyActionsTheme ?? const ReplyActionsThemeData(),
       suggestionsTheme = suggestionsTheme ?? const SuggestionsThemeData(),
       toolApprovalTheme = toolApprovalTheme ?? const ToolApprovalThemeData(),
       toolCallTheme = toolCallTheme ?? const ToolCallThemeData(),
       typingIndicatorTheme = typingIndicatorTheme ?? const TypingIndicatorThemeData();

  /// How charts are drawn. Defaults to `const ChartThemeData()`, which derives
  /// every field from the Stream theme.
  final ChartThemeData chartTheme;

  /// How code blocks are framed. Defaults to `const CodeBlockThemeData()`,
  /// which keeps the package's dark code frame in light and dark mode alike.
  final CodeBlockThemeData codeBlockTheme;

  /// How the composer and its attachment sheet are drawn. Defaults to
  /// `const ComposerThemeData()`, which derives every field from the Stream
  /// theme.
  final ComposerThemeData composerTheme;

  /// How the conversation and its messages are drawn. Defaults to
  /// `const ConversationThemeData()`, which derives every field from the
  /// Stream theme.
  final ConversationThemeData conversationTheme;

  /// How the reasoning panel is drawn. Defaults to `const ReasoningThemeData()`,
  /// which derives every field from the Stream theme.
  final ReasoningThemeData reasoningTheme;

  /// How the buttons under a reply are drawn. Defaults to
  /// `const ReplyActionsThemeData()`, which derives every field from the
  /// Stream theme.
  final ReplyActionsThemeData replyActionsTheme;

  /// How suggestion chips are drawn. Defaults to
  /// `const SuggestionsThemeData()`, which derives every field from the Stream
  /// theme.
  final SuggestionsThemeData suggestionsTheme;

  /// How tool-approval cards are drawn. Defaults to
  /// `const ToolApprovalThemeData()`, which derives every field from the
  /// Stream theme.
  final ToolApprovalThemeData toolApprovalTheme;

  /// How tool-call rows are drawn. Defaults to `const ToolCallThemeData()`,
  /// which derives its colors and text styles from the Stream theme.
  final ToolCallThemeData toolCallTheme;

  /// How the typing indicator is drawn. Defaults to
  /// `const TypingIndicatorThemeData()`, which derives every field from the
  /// Stream theme.
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
    ConversationThemeData? conversationTheme,
    ReasoningThemeData? reasoningTheme,
    ReplyActionsThemeData? replyActionsTheme,
    SuggestionsThemeData? suggestionsTheme,
    ToolApprovalThemeData? toolApprovalTheme,
    ToolCallThemeData? toolCallTheme,
    TypingIndicatorThemeData? typingIndicatorTheme,
  }) => AITheme(
    chartTheme: chartTheme ?? this.chartTheme,
    codeBlockTheme: codeBlockTheme ?? this.codeBlockTheme,
    composerTheme: composerTheme ?? this.composerTheme,
    conversationTheme: conversationTheme ?? this.conversationTheme,
    reasoningTheme: reasoningTheme ?? this.reasoningTheme,
    replyActionsTheme: replyActionsTheme ?? this.replyActionsTheme,
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
      conversationTheme: ConversationThemeData.lerp(conversationTheme, other.conversationTheme, t),
      reasoningTheme: ReasoningThemeData.lerp(reasoningTheme, other.reasoningTheme, t),
      replyActionsTheme: ReplyActionsThemeData.lerp(replyActionsTheme, other.replyActionsTheme, t),
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
        other.conversationTheme == conversationTheme &&
        other.reasoningTheme == reasoningTheme &&
        other.replyActionsTheme == replyActionsTheme &&
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
    conversationTheme,
    reasoningTheme,
    replyActionsTheme,
    suggestionsTheme,
    toolApprovalTheme,
    toolCallTheme,
    typingIndicatorTheme,
  );
}
