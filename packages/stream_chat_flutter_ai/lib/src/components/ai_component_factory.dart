import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_parts_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_view.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/streaming_reasoning_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';

/// Builds the components this package creates inside its own widgets — code
/// blocks and charts in markdown, agent steps, the tool approval card and the
/// composer's slots.
///
/// Subclass it, override the slots to replace, and provide it with
/// [AIComponents]:
///
/// ```dart
/// class MyComponents extends AIComponentFactory {
///   const MyComponents();
///
///   @override
///   Widget buildCodeBlock(BuildContext context, AICodeBlockProps props) => MyCodeBlock(code: props.code);
/// }
///
/// AIComponents(factory: const MyComponents(), child: MaterialApp(...))
/// ```
///
/// Per-widget builders such as [AIMessagePartsView.partBuilder] are asked
/// before the factory. From [buildReasoning], [buildToolCall] and
/// [buildUnsupportedPart], return [AIMessagePartsView.hidden] to leave the
/// part out of the list.
class AIComponentFactory {
  /// Creates an [AIComponentFactory].
  const AIComponentFactory();

  /// A non-chart code fence in markdown. Defaults to [CodeBlockView].
  Widget buildCodeBlock(BuildContext context, AICodeBlockProps props) {
    return CodeBlockView(
      code: props.code,
      language: props.language,
      highlighter: props.highlighter,
      theme: props.theme,
    );
  }

  /// A code fence in markdown that parsed as chart data. Defaults to
  /// [ChartView].
  Widget buildChart(BuildContext context, AIChartProps props) {
    return ChartView(spec: props.spec);
  }

  /// A round of reasoning in [AIMessagePartsView]. Defaults to
  /// [StreamingReasoningView.part].
  Widget buildReasoning(BuildContext context, AIReasoningPart reasoning) {
    return StreamingReasoningView.part(reasoning);
  }

  /// A tool call's row in [AIMessagePartsView]. Defaults to [AIToolCallView].
  ///
  /// Only the row: the approval question under it comes from
  /// [buildToolApproval].
  Widget buildToolCall(BuildContext context, AIToolCallPart call) {
    return AIToolCallView(call: call);
  }

  /// The question an [AIToolApprovalView] asks. Defaults to
  /// [AIToolApprovalCard].
  Widget buildToolApproval(BuildContext context, AIToolApprovalProps props) {
    return AIToolApprovalCard(
      approval: props.approval,
      toolName: props.toolName,
      state: props.state,
      onAnswer: props.onAnswer,
      theme: props.theme,
    );
  }

  /// A part this package can't read, in [AIMessagePartsView]. Defaults to
  /// [AIUnsupportedPartView].
  Widget buildUnsupportedPart(BuildContext context, AIMessagePart part) {
    return const AIUnsupportedPartView();
  }

  /// The composer's slots, used by a `ChatComposer` given no factory of its
  /// own.
  ChatComposerFactory get composer => const ChatComposerFactory();
}

/// What [AIComponentFactory.buildCodeBlock] gets.
@immutable
final class AICodeBlockProps {
  /// Creates an [AICodeBlockProps].
  const AICodeBlockProps({required this.code, this.language, this.highlighter, this.theme});

  /// The fence's source.
  final String code;

  /// The fence's language, or `null` when it has none.
  final String? language;

  /// The highlighter the markdown body was given.
  final CodeHighlighter? highlighter;

  /// The code block theme the markdown body was given.
  final CodeBlockThemeData? theme;
}

/// What [AIComponentFactory.buildChart] gets.
@immutable
final class AIChartProps {
  /// Creates an [AIChartProps].
  const AIChartProps({required this.spec});

  /// The parsed chart.
  final USpec spec;
}

/// What [AIComponentFactory.buildToolApproval] gets.
@immutable
final class AIToolApprovalProps {
  /// Creates an [AIToolApprovalProps].
  const AIToolApprovalProps({
    required this.call,
    this.approval,
    this.toolName,
    required this.state,
    required this.onAnswer,
    this.theme,
  });

  /// The tool call being asked about.
  final AIToolCallPart call;

  /// The call's question, or `null` to ask with the translated fallbacks.
  final AIToolApproval? approval;

  /// The tool's name for the fallback title, such as "send email".
  final String? toolName;

  /// Where the answer is.
  final AIToolApprovalState state;

  /// Sends the person's decision.
  final AIToolApprovalAnswer onAnswer;

  /// The theme overrides the [AIToolApprovalView] was given.
  final ToolApprovalThemeData? theme;
}

/// Provides an [AIComponentFactory] to the widgets below it.
///
/// Keep the factory instance stable (ideally `const`): a new instance rebuilds
/// every widget that reads it.
class AIComponents extends InheritedTheme {
  /// Creates an [AIComponents].
  const AIComponents({super.key, required this.factory, required super.child});

  /// The factory provided to the subtree.
  final AIComponentFactory factory;

  /// The nearest [factory] above [context], or the default
  /// [AIComponentFactory] when there is none.
  static AIComponentFactory of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AIComponents>()?.factory ?? const AIComponentFactory();
  }

  @override
  Widget wrap(BuildContext context, Widget child) => AIComponents(factory: factory, child: child);

  @override
  bool updateShouldNotify(AIComponents oldWidget) => !identical(factory, oldWidget.factory);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AIComponentFactory>('factory', factory));
  }
}
