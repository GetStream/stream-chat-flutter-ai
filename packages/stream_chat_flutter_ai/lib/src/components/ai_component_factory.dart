import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_input.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';
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
import 'package:stream_core_flutter/chat.dart';

/// The builders that replace the components this package builds inside its
/// own widgets: code blocks and charts in markdown, agent steps, the tool
/// approval card, the messages of an [AIConversationView] and the composer's
/// slots.
///
/// Each builder is registered as a [StreamComponentBuilderExtension] keyed by
/// its props type. Pass them to a [StreamComponentFactory] as `extensions`,
/// next to Stream Chat's own when the app uses both:
///
/// ```dart
/// StreamComponentFactory(
///   builders: StreamComponentBuilders(
///     extensions: [
///       ...streamChatComponentBuilders(...),
///       ...streamAIComponentBuilders(
///         codeBlock: (context, props) => MyCodeBlock(code: props.code),
///       ),
///     ],
///   ),
///   child: MaterialApp(...),
/// )
/// ```
///
/// A builder left out keeps its default. The nearest factory wins: a nested
/// one replaces its parent's builders rather than merging with them.
/// Per-widget builders such as [AIMessagePartsView.partBuilder] are asked
/// before the factory.
///
/// From [reasoning], [toolCall] and [unsupportedPart], return
/// [AIMessagePartsView.hidden] to leave the part out of the list.
///
/// The builders:
///
/// * [codeBlock]: a non-chart code fence in markdown. Defaults to
///   [CodeBlockView].
/// * [chart]: a code fence that parsed as chart data. Defaults to [ChartView].
/// * [reasoning]: a round of reasoning in [AIMessagePartsView]. Defaults to
///   [StreamingReasoningView.part].
/// * [toolCall]: a tool call's row in [AIMessagePartsView]. Defaults to
///   [AIToolCallView]. Only the row: its approval question comes from
///   [toolApproval], and is still asked when this returns
///   [AIMessagePartsView.hidden].
/// * [toolApproval]: the question an [AIToolApprovalView] asks. Defaults to
///   [AIToolApprovalCard]. Return `const SizedBox.shrink()` to ask nothing.
/// * [unsupportedPart]: a part this package can't read. Defaults to
///   [AIUnsupportedPartView].
/// * [userMessage] and [assistantMessage]: the rows of an
///   [AIConversationView]. Default to [AIUserMessageView] and
///   [AIAssistantMessageView]. A row is built again only when what its
///   [AIMessage] says changes, so read anything else that changes, such as a
///   send status, from your own listenable.
/// * [replyActions]: what the person can do with a finished reply, under it in
///   [AIConversationView]. Nothing by default; an [AIReplyActionsView] is what
///   to return.
/// * [messageAttachment]: one of a message's attachments. Defaults to
///   [AIMessageAttachmentView].
/// * [composerLeading], [composerTrailing] and [composerInput]: the slots of a
///   [ChatComposer]. Default to the "+" button, nothing, and
///   [ChatComposerInput].
/// * [composerAttachmentSheet]: the sheet the "+" button opens. Defaults to
///   [ComposerAttachmentSheet].
Iterable<StreamComponentBuilderExtension<Object>> streamAIComponentBuilders({
  StreamComponentBuilder<AICodeBlockProps>? codeBlock,
  StreamComponentBuilder<AIChartProps>? chart,
  StreamComponentBuilder<AIReasoningProps>? reasoning,
  StreamComponentBuilder<AIToolCallProps>? toolCall,
  StreamComponentBuilder<AIToolApprovalProps>? toolApproval,
  StreamComponentBuilder<AIUnsupportedPartProps>? unsupportedPart,
  StreamComponentBuilder<AIUserMessageProps>? userMessage,
  StreamComponentBuilder<AIAssistantMessageProps>? assistantMessage,
  StreamComponentBuilder<AIReplyActionsProps>? replyActions,
  StreamComponentBuilder<AIMessageAttachmentProps>? messageAttachment,
  StreamComponentBuilder<ChatComposerLeadingProps>? composerLeading,
  StreamComponentBuilder<ChatComposerTrailingProps>? composerTrailing,
  StreamComponentBuilder<ChatComposerInputProps>? composerInput,
  StreamComponentBuilder<ChatComposerAttachmentSheetProps>? composerAttachmentSheet,
}) {
  final builders = [
    if (codeBlock != null) StreamComponentBuilderExtension(builder: codeBlock),
    if (chart != null) StreamComponentBuilderExtension(builder: chart),
    if (reasoning != null) StreamComponentBuilderExtension(builder: reasoning),
    if (toolCall != null) StreamComponentBuilderExtension(builder: toolCall),
    if (toolApproval != null) StreamComponentBuilderExtension(builder: toolApproval),
    if (unsupportedPart != null) StreamComponentBuilderExtension(builder: unsupportedPart),
    if (userMessage != null) StreamComponentBuilderExtension(builder: userMessage),
    if (assistantMessage != null) StreamComponentBuilderExtension(builder: assistantMessage),
    if (replyActions != null) StreamComponentBuilderExtension(builder: replyActions),
    if (messageAttachment != null) StreamComponentBuilderExtension(builder: messageAttachment),
    if (composerLeading != null) StreamComponentBuilderExtension(builder: composerLeading),
    if (composerTrailing != null) StreamComponentBuilderExtension(builder: composerTrailing),
    if (composerInput != null) StreamComponentBuilderExtension(builder: composerInput),
    if (composerAttachmentSheet != null) StreamComponentBuilderExtension(builder: composerAttachmentSheet),
  ];

  return builders;
}

/// Reads the builders [streamAIComponentBuilders] registered.
extension StreamAIComponentBuildersExtension on BuildContext {
  /// The builder registered for props of type [T] in the nearest
  /// [StreamComponentFactory], or `null` to use the default.
  StreamComponentBuilder<T>? aiComponentBuilder<T>() => StreamComponentFactory.of(this).extension<T>();
}

/// What the `codeBlock` builder of [streamAIComponentBuilders] gets.
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

/// What the `chart` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIChartProps {
  /// Creates an [AIChartProps].
  const AIChartProps({required this.spec});

  /// The parsed chart.
  final USpec spec;
}

/// What the `reasoning` builder of [streamAIComponentBuilders] gets.
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

/// What the `toolCall` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIToolCallProps {
  /// Creates an [AIToolCallProps].
  const AIToolCallProps({required this.call});

  /// The tool call to show.
  final AIToolCallPart call;
}

/// What the `unsupportedPart` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIUnsupportedPartProps {
  /// Creates an [AIUnsupportedPartProps].
  const AIUnsupportedPartProps({required this.part});

  /// The part this package can't read.
  final AIMessagePart part;
}

/// What the `toolApproval` builder of [streamAIComponentBuilders] gets.
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

/// What the `userMessage` builder of [streamAIComponentBuilders] gets.
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

/// What the `assistantMessage` builder of [streamAIComponentBuilders] gets.
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

/// What the `replyActions` builder of [streamAIComponentBuilders] gets.
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

/// What the `messageAttachment` builder of [streamAIComponentBuilders] gets.
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
