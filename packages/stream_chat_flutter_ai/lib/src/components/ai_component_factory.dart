import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_assistant_message_view.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_user_message_view.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';
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

/// Provides [AIComponentBuilders] to the widgets below it, to replace the
/// components this package builds inside its own widgets: code blocks and
/// charts in markdown, agent steps, the tool approval card, the messages of an
/// [AIConversationView] and the composer's slots.
///
/// ```dart
/// AIComponentFactory(
///   builders: AIComponentBuilders(
///     codeBlock: (context, props) => MyCodeBlock(code: props.code),
///   ),
///   child: MaterialApp(...),
/// )
/// ```
///
/// The nearest factory wins: a nested one replaces its parent's builders
/// rather than merging with them. Per-widget builders such as
/// [AIMessagePartsView.partBuilder] are asked before the factory.
class AIComponentFactory extends InheritedTheme {
  /// Creates an [AIComponentFactory].
  const AIComponentFactory({super.key, required this.builders, required super.child});

  /// The builders provided to the subtree.
  final AIComponentBuilders builders;

  /// The builders of the nearest [AIComponentFactory] above [context], or
  /// empty ones, which leave every component to its default, when there is
  /// none.
  static AIComponentBuilders of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AIComponentFactory>()?.builders ?? const AIComponentBuilders();
  }

  @override
  Widget wrap(BuildContext context, Widget child) => AIComponentFactory(builders: builders, child: child);

  @override
  bool updateShouldNotify(AIComponentFactory oldWidget) => builders != oldWidget.builders;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AIComponentBuilders>('builders', builders));
  }
}

/// Builds a widget from a [BuildContext] and typed props.
typedef AIComponentBuilder<T> = Widget Function(BuildContext context, T props);

/// The builders an [AIComponentFactory] provides. Each is nullable: when
/// `null`, its component uses its default.
///
/// From [reasoning], [toolCall] and [unsupportedPart], return
/// [AIMessagePartsView.hidden] to leave the part out of the list.
///
/// Builders are compared by identity, so keep the instance stable, ideally
/// `const` with top-level or static functions: a new one rebuilds every widget
/// that reads it.
@immutable
class AIComponentBuilders with Diagnosticable {
  /// Creates [AIComponentBuilders]. A builder left out keeps its default.
  const AIComponentBuilders({
    this.codeBlock,
    this.chart,
    this.reasoning,
    this.toolCall,
    this.toolApproval,
    this.unsupportedPart,
    this.userMessage,
    this.assistantMessage,
    this.replyActions,
    this.messageAttachment,
    this.composer,
  });

  /// A non-chart code fence in markdown. Defaults to [CodeBlockView].
  final AIComponentBuilder<AICodeBlockProps>? codeBlock;

  /// A code fence in markdown that parsed as chart data. Defaults to
  /// [ChartView].
  final AIComponentBuilder<AIChartProps>? chart;

  /// A round of reasoning in [AIMessagePartsView]. Defaults to
  /// [StreamingReasoningView.part].
  final AIComponentBuilder<AIReasoningProps>? reasoning;

  /// A tool call's row in [AIMessagePartsView]. Defaults to [AIToolCallView].
  ///
  /// Only the row: the approval question under it comes from [toolApproval],
  /// and is still asked when this returns [AIMessagePartsView.hidden].
  final AIComponentBuilder<AIToolCallProps>? toolCall;

  /// The question an [AIToolApprovalView] asks. Defaults to
  /// [AIToolApprovalCard]. Return `const SizedBox.shrink()` to ask nothing.
  final AIComponentBuilder<AIToolApprovalProps>? toolApproval;

  /// A part this package can't read, in [AIMessagePartsView]. Defaults to
  /// [AIUnsupportedPartView].
  final AIComponentBuilder<AIUnsupportedPartProps>? unsupportedPart;

  /// A message the person sent, in [AIConversationView]. Defaults to
  /// [AIUserMessageView].
  ///
  /// The conversation caches its rows: it builds one again only when what
  /// [AIMessage] says about it changes, or the builders do. Read anything else
  /// that changes, such as a send status, through a [Listenable] of your own
  /// (a [ListenableBuilder] or [ValueListenableBuilder] in what you return),
  /// and create the builders once, not in `build`.
  final AIComponentBuilder<AIUserMessageProps>? userMessage;

  /// A reply of the agent, in [AIConversationView]. Defaults to
  /// [AIAssistantMessageView]. Like [userMessage], it is built again only when
  /// what [AIMessage] says about the reply changes, or the builders do, so read
  /// state of your own through a [Listenable].
  final AIComponentBuilder<AIAssistantMessageProps>? assistantMessage;

  /// What the person can do with a finished reply, shown under it in
  /// [AIConversationView] once its answer is typed out. Nothing by default; an
  /// [AIReplyActionsView] is what to return.
  ///
  /// Like [userMessage], it is built again only when the reply changes, or the
  /// builders do. So read the rating, which changes without the reply
  /// changing, through a [Listenable], and create the builders once:
  ///
  /// ```dart
  /// // In your State, next to a `ValueNotifier<Map<String, AIMessageRating>> ratings`.
  /// late final builders = AIComponentBuilders(
  ///   replyActions: (context, props) => ValueListenableBuilder(
  ///     valueListenable: ratings,
  ///     builder: (context, rated, _) => AIReplyActionsView(
  ///       text: props.text,
  ///       actions: AIReplyActions(
  ///         rating: rated[props.message.id],
  ///         onRate: (rating) => rate(props.message, rating), // sets `ratings.value` to a new map
  ///         onRegenerate: props.isLatestReply ? chat.regenerate : null,
  ///       ),
  ///     ),
  ///   ),
  /// );
  /// ```
  final AIComponentBuilder<AIReplyActionsProps>? replyActions;

  /// One of a message's attachments. Defaults to [AIMessageAttachmentView].
  ///
  /// Kinds of your own, such as artifacts or files in an agent's sandbox, reach
  /// it with their raw fields in [AIMessageAttachment.extraData]: show those
  /// your own way, and return an [AIMessageAttachmentView] for the rest.
  final AIComponentBuilder<AIMessageAttachmentProps>? messageAttachment;

  /// The composer's slots, used by a `ChatComposer` given no factory of its
  /// own. Defaults to [ChatComposerFactory].
  final ChatComposerFactory? composer;

  /// A copy with the given builders replaced. A `null` argument keeps the
  /// current builder.
  AIComponentBuilders copyWith({
    AIComponentBuilder<AICodeBlockProps>? codeBlock,
    AIComponentBuilder<AIChartProps>? chart,
    AIComponentBuilder<AIReasoningProps>? reasoning,
    AIComponentBuilder<AIToolCallProps>? toolCall,
    AIComponentBuilder<AIToolApprovalProps>? toolApproval,
    AIComponentBuilder<AIUnsupportedPartProps>? unsupportedPart,
    AIComponentBuilder<AIUserMessageProps>? userMessage,
    AIComponentBuilder<AIAssistantMessageProps>? assistantMessage,
    AIComponentBuilder<AIReplyActionsProps>? replyActions,
    AIComponentBuilder<AIMessageAttachmentProps>? messageAttachment,
    ChatComposerFactory? composer,
  }) => AIComponentBuilders(
    codeBlock: codeBlock ?? this.codeBlock,
    chart: chart ?? this.chart,
    reasoning: reasoning ?? this.reasoning,
    toolCall: toolCall ?? this.toolCall,
    toolApproval: toolApproval ?? this.toolApproval,
    unsupportedPart: unsupportedPart ?? this.unsupportedPart,
    userMessage: userMessage ?? this.userMessage,
    assistantMessage: assistantMessage ?? this.assistantMessage,
    replyActions: replyActions ?? this.replyActions,
    messageAttachment: messageAttachment ?? this.messageAttachment,
    composer: composer ?? this.composer,
  );

  /// These builders with [other]'s set ones layered on top, such as to add to
  /// an enclosing factory's builders.
  AIComponentBuilders merge(AIComponentBuilders? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      codeBlock: other.codeBlock,
      chart: other.chart,
      reasoning: other.reasoning,
      toolCall: other.toolCall,
      toolApproval: other.toolApproval,
      unsupportedPart: other.unsupportedPart,
      userMessage: other.userMessage,
      assistantMessage: other.assistantMessage,
      replyActions: other.replyActions,
      messageAttachment: other.messageAttachment,
      composer: other.composer,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('codeBlock', value: codeBlock != null, ifTrue: 'custom codeBlock'))
      ..add(FlagProperty('chart', value: chart != null, ifTrue: 'custom chart'))
      ..add(FlagProperty('reasoning', value: reasoning != null, ifTrue: 'custom reasoning'))
      ..add(FlagProperty('toolCall', value: toolCall != null, ifTrue: 'custom toolCall'))
      ..add(FlagProperty('toolApproval', value: toolApproval != null, ifTrue: 'custom toolApproval'))
      ..add(FlagProperty('unsupportedPart', value: unsupportedPart != null, ifTrue: 'custom unsupportedPart'))
      ..add(FlagProperty('userMessage', value: userMessage != null, ifTrue: 'custom userMessage'))
      ..add(FlagProperty('assistantMessage', value: assistantMessage != null, ifTrue: 'custom assistantMessage'))
      ..add(FlagProperty('replyActions', value: replyActions != null, ifTrue: 'custom replyActions'))
      ..add(FlagProperty('messageAttachment', value: messageAttachment != null, ifTrue: 'custom messageAttachment'))
      ..add(DiagnosticsProperty<ChatComposerFactory>('composer', composer, defaultValue: null));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIComponentBuilders &&
          other.codeBlock == codeBlock &&
          other.chart == chart &&
          other.reasoning == reasoning &&
          other.toolCall == toolCall &&
          other.toolApproval == toolApproval &&
          other.unsupportedPart == unsupportedPart &&
          other.userMessage == userMessage &&
          other.assistantMessage == assistantMessage &&
          other.replyActions == replyActions &&
          other.messageAttachment == messageAttachment &&
          other.composer == composer;

  @override
  int get hashCode => Object.hash(
    codeBlock,
    chart,
    reasoning,
    toolCall,
    toolApproval,
    unsupportedPart,
    userMessage,
    assistantMessage,
    replyActions,
    messageAttachment,
    composer,
  );
}

/// What [AIComponentBuilders.codeBlock] gets.
@immutable
final class AICodeBlockProps {
  /// Creates an [AICodeBlockProps].
  const AICodeBlockProps({required this.code, this.language, this.highlighter, this.theme});

  /// The fence's source.
  final String code;

  /// The fence's language, or `null` when it has none.
  final String? language;

  /// The markdown body's highlighter as of when this fence was built.
  final CodeHighlighter? highlighter;

  /// The code block theme the markdown body was given.
  final CodeBlockThemeData? theme;
}

/// What [AIComponentBuilders.chart] gets.
@immutable
final class AIChartProps {
  /// Creates an [AIChartProps].
  const AIChartProps({required this.spec});

  /// The parsed chart.
  final USpec spec;
}

/// What [AIComponentBuilders.reasoning] gets.
@immutable
final class AIReasoningProps {
  /// Creates an [AIReasoningProps].
  const AIReasoningProps({required this.reasoning, this.text, this.duration});

  /// The round of reasoning to show.
  final AIReasoningPart reasoning;

  /// The whole of its thinking when the app has it, or `null` for its preview.
  final String? text;

  /// How long it has thought, when the conversation timed it rather than the
  /// step, such as its first step taking over the thinking count.
  final Duration? duration;
}

/// What [AIComponentBuilders.toolCall] gets.
@immutable
final class AIToolCallProps {
  /// Creates an [AIToolCallProps].
  const AIToolCallProps({required this.call});

  /// The tool call to show.
  final AIToolCallPart call;
}

/// What [AIComponentBuilders.unsupportedPart] gets.
@immutable
final class AIUnsupportedPartProps {
  /// Creates an [AIUnsupportedPartProps].
  const AIUnsupportedPartProps({required this.part});

  /// The part this package can't read.
  final AIMessagePart part;
}

/// What [AIComponentBuilders.toolApproval] gets.
@immutable
final class AIToolApprovalProps {
  /// Creates an [AIToolApprovalProps].
  const AIToolApprovalProps({
    required this.call,
    this.toolName,
    required this.state,
    required this.onAnswer,
    this.theme,
  });

  /// The tool call being asked about.
  final AIToolCallPart call;

  /// The call's question, or `null` to ask with the translated fallbacks.
  AIToolApproval? get approval => call.approval;

  /// The tool's name for the fallback title, such as "send email".
  final String? toolName;

  /// Whether the answer is unsent, sending, sent or failed.
  final AIToolApprovalState state;

  /// Sends the person's decision.
  final AIToolApprovalAnswer onAnswer;

  /// The theme overrides the [AIToolApprovalView] was given.
  final ToolApprovalThemeData? theme;
}

/// What [AIComponentBuilders.userMessage] gets.
@immutable
final class AIUserMessageProps {
  /// Creates an [AIUserMessageProps].
  const AIUserMessageProps({this.message, required this.text, this.attachments = const [], this.onAttachmentTap});

  /// The message, which is one of the app's own: cast it to read what else it
  /// holds. `null` while the message is on its way.
  final AIMessage? message;

  /// What the person wrote.
  final String text;

  /// What they sent with it.
  final List<AIMessageAttachment> attachments;

  /// Opens one of the attachments.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;
}

/// What [AIComponentBuilders.assistantMessage] gets.
@immutable
final class AIAssistantMessageProps {
  /// Creates an [AIAssistantMessageProps].
  const AIAssistantMessageProps({required this.message, this.approver, this.onAttachmentTap});

  /// The reply, which is one of the app's own messages: cast it to read what
  /// else it holds.
  final AIMessage message;

  /// The answer, in markdown.
  String get text => message.text;

  /// Whether the agent is still writing it.
  bool get isGenerating => message.isGenerating;

  /// The steps the agent took, in order.
  List<AIMessagePart> get parts => message.parts;

  /// What the agent sent with it.
  List<AIMessageAttachment> get attachments => message.attachments;

  /// Who answers tool calls' questions on this device.
  final AIToolApprover? approver;

  /// Opens one of the attachments.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;
}

/// What [AIComponentBuilders.replyActions] gets.
@immutable
final class AIReplyActionsProps {
  /// Creates an [AIReplyActionsProps].
  const AIReplyActionsProps({required this.message, required this.isLatestReply});

  /// The reply, which is one of the app's own messages: cast it to act on it.
  final AIMessage message;

  /// The reply's text, in markdown.
  String get text => message.text;

  /// Whether it is the latest reply in the conversation, such as the only one
  /// an app offers to regenerate.
  final bool isLatestReply;
}

/// What [AIComponentBuilders.messageAttachment] gets.
@immutable
final class AIMessageAttachmentProps {
  /// Creates an [AIMessageAttachmentProps].
  const AIMessageAttachmentProps({required this.attachment, required this.isFromUser, this.onTap});

  /// The attachment.
  final AIMessageAttachment attachment;

  /// Whether the person sent the message that carries it.
  final bool isFromUser;

  /// Opens it.
  final VoidCallback? onTap;
}
