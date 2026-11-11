import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/ai_markdown_body.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_input.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_button.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_assistant_message_view.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_user_message_view.dart';
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_parts_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_authorization.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_authorization_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_view.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/streaming_reasoning_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// The builders that replace the components this package builds inside its
/// own widgets: code blocks and charts in markdown, agent steps, the tool
/// approval and sign-in cards, the messages of an [AIConversationView], the
/// reply actions and the composer's slots.
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
/// Builders are compared by identity, so register them once, ideally from
/// top-level or static functions, rather than in `build`: new ones rebuild
/// every widget that reads them.
///
/// The builders:
///
/// * [codeBlock]: a non-chart code fence in markdown. Defaults to
///   [CodeBlockView].
/// * [chart]: a code fence that parsed as chart data. Defaults to [ChartView].
/// * [math]: a LaTeX expression in markdown, when the [AIMarkdownBody] has no
///   `mathBuilder` of its own. Defaults to the TeX source as text.
/// * [reasoning]: a round of reasoning in [AIMessagePartsView]. Defaults to
///   [StreamingReasoningView.part].
/// * [toolCall]: a tool call's row in [AIMessagePartsView]. Defaults to
///   [AIToolCallView]. Only the row: the approval question under it comes from
///   [toolApproval] and the sign-in from [toolAuthorization], and both are
///   still asked when this returns [AIMessagePartsView.hidden].
/// * [toolApproval]: the question an [AIToolApprovalView] asks. Defaults to
///   [AIToolApprovalCard]. Return `const SizedBox.shrink()` to ask nothing.
/// * [toolAuthorization]: the sign-in an [AIToolAuthorizationView] asks for.
///   Defaults to [AIToolAuthorizationCard]. Content of your own calls the
///   props' `onConnect` and `onDecline`, which hand the sign-in page to the
///   approver's [AIToolAuthorizer] and send the person's "not now".
/// * [unsupportedPart]: a part this package can't read. Defaults to
///   [AIUnsupportedPartView].
/// * [userMessage] and [assistantMessage]: the rows of an
///   [AIConversationView]. Default to [AIUserMessageView] and
///   [AIAssistantMessageView]. The conversation caches its rows: it builds one
///   again only when what its [AIMessage] says changes, or the builders do.
///   Read anything else that changes, such as a send status, through a
///   [Listenable] of your own (a [ListenableBuilder] or
///   [ValueListenableBuilder] in what you return). When a reply's generated UI
///   is shown (see [AIConversationView.ui]), [assistantMessage] gets empty
///   text, and the conversation shows the UI below the builder's widget.
/// * [replyActions]: the actions, such as copy or regenerate, shown under a
///   finished reply in [AIConversationView], once its text, attachments or
///   generated UI (see [AIConversationView.ui]) has finished appearing.
///   Nothing by default, and an [AIReplyActionsView] with
///   [AIReplyActionsProps.actions] in a list made with
///   [AIConversationView.conversation], which builds the row again when the
///   rating or the actions offered change. Otherwise an [AIReplyActionsView]
///   is what to return. Like the rows, it is built again only when the reply
///   changes, so read the rating, which changes without the reply changing,
///   through a [Listenable]:
///
///   ```dart
///   // In your State, next to a `ValueNotifier<Map<String, AIMessageRating>> ratings`.
///   late final builders = streamAIComponentBuilders(
///     replyActions: (context, props) => ValueListenableBuilder(
///       valueListenable: ratings,
///       builder: (context, rated, _) => AIReplyActionsView(
///         text: props.text,
///         actions: AIReplyActions(
///           rating: rated[props.message.id],
///           onRate: (rating) => rate(props.message, rating), // sets `ratings.value` to a new map
///           onRegenerate: props.isLatestReply ? chat.regenerate : null,
///         ),
///       ),
///     ),
///   );
///   ```
/// * [messageAttachment]: one of a message's attachments. Defaults to
///   [AIMessageAttachmentView]. Kinds of your own, such as artifacts or files
///   in an agent's sandbox, reach it with their raw fields in
///   [AIMessageAttachment.extraData]: show those your own way, and return an
///   [AIMessageAttachmentView] for the rest.
/// * [composerLeading], [composerTrailing] and [composerInput]: the slots of a
///   [ChatComposer]. Default to the "+" button, nothing, and
///   [ChatComposerInput].
/// * [composerInputTrailing]: the control at the input's right edge, shown
///   while no response is generating and the field is empty or dictation runs;
///   stop and send take the place otherwise. Built whether or not
///   [ChatComposer.enableSpeechToText] is set, so it can hold any control;
///   [ChatComposerInputTrailingProps.enableSpeechToText] says whether to draw
///   a mic. Without it the place holds a [SpeechToTextButton], and only when
///   [ChatComposer.enableSpeechToText] is set.
/// * [composerAttachmentSheet]: the sheet the "+" button opens. Defaults to
///   [ComposerAttachmentSheet]. A custom [composerLeading] opens it with
///   [ChatComposerSlotProps.openAttachmentSheet].
Iterable<StreamComponentBuilderExtension<Object>> streamAIComponentBuilders({
  StreamComponentBuilder<AICodeBlockProps>? codeBlock,
  StreamComponentBuilder<AIChartProps>? chart,
  StreamComponentBuilder<AIMathProps>? math,
  StreamComponentBuilder<AIReasoningProps>? reasoning,
  StreamComponentBuilder<AIToolCallProps>? toolCall,
  StreamComponentBuilder<AIToolApprovalProps>? toolApproval,
  StreamComponentBuilder<AIToolAuthorizationProps>? toolAuthorization,
  StreamComponentBuilder<AIUnsupportedPartProps>? unsupportedPart,
  StreamComponentBuilder<AIUserMessageProps>? userMessage,
  StreamComponentBuilder<AIAssistantMessageProps>? assistantMessage,
  StreamComponentBuilder<AIReplyActionsProps>? replyActions,
  StreamComponentBuilder<AIMessageAttachmentProps>? messageAttachment,
  StreamComponentBuilder<ChatComposerLeadingProps>? composerLeading,
  StreamComponentBuilder<ChatComposerTrailingProps>? composerTrailing,
  StreamComponentBuilder<ChatComposerInputProps>? composerInput,
  StreamComponentBuilder<ChatComposerInputTrailingProps>? composerInputTrailing,
  StreamComponentBuilder<ChatComposerAttachmentSheetProps>? composerAttachmentSheet,
}) {
  final builders = [
    if (codeBlock != null) StreamComponentBuilderExtension(builder: codeBlock),
    if (chart != null) StreamComponentBuilderExtension(builder: chart),
    if (math != null) StreamComponentBuilderExtension(builder: math),
    if (reasoning != null) StreamComponentBuilderExtension(builder: reasoning),
    if (toolCall != null) StreamComponentBuilderExtension(builder: toolCall),
    if (toolApproval != null) StreamComponentBuilderExtension(builder: toolApproval),
    if (toolAuthorization != null) StreamComponentBuilderExtension(builder: toolAuthorization),
    if (unsupportedPart != null) StreamComponentBuilderExtension(builder: unsupportedPart),
    if (userMessage != null) StreamComponentBuilderExtension(builder: userMessage),
    if (assistantMessage != null) StreamComponentBuilderExtension(builder: assistantMessage),
    if (replyActions != null) StreamComponentBuilderExtension(builder: replyActions),
    if (messageAttachment != null) StreamComponentBuilderExtension(builder: messageAttachment),
    if (composerLeading != null) StreamComponentBuilderExtension(builder: composerLeading),
    if (composerTrailing != null) StreamComponentBuilderExtension(builder: composerTrailing),
    if (composerInput != null) StreamComponentBuilderExtension(builder: composerInput),
    if (composerInputTrailing != null) StreamComponentBuilderExtension(builder: composerInputTrailing),
    if (composerAttachmentSheet != null) StreamComponentBuilderExtension(builder: composerAttachmentSheet),
  ];

  return builders;
}

/// [child] under a [StreamComponentFactory] with [builders], for a route pushed
/// from where [builders] were read. The factory is a plain inherited widget, so
/// a route on a [Navigator] above it would otherwise not see its builders. Read
/// [builders] before pushing, as the route can outlive the widget it came from.
@internal
Widget withStreamComponents(StreamComponentBuilders builders, Widget child) =>
    StreamComponentFactory(builders: builders, child: child);

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

/// What the `math` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIMathProps {
  /// Creates an [AIMathProps].
  const AIMathProps({required this.tex, this.style, required this.inline});

  /// The LaTeX source, without its delimiters.
  final String tex;

  /// The style of the text around it.
  final TextStyle? style;

  /// Whether it sits in a line of text, from `\(…\)`, rather than in a block
  /// of its own, from `\[…\]`.
  final bool inline;
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

/// What the `toolAuthorization` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIToolAuthorizationProps {
  /// Creates an [AIToolAuthorizationProps].
  const AIToolAuthorizationProps({
    required this.call,
    required this.authorization,
    required this.state,
    required this.onConnect,
    required this.onDecline,
    this.theme,
  });

  /// The tool call that waits for the sign-in.
  final AIToolCallPart call;

  /// The sign-in, such as "Connect Linear".
  final AIToolAuthorization authorization;

  /// Where the person's answer is.
  final AIToolAuthorizationState state;

  /// Hands the sign-in page to the approver's [AIToolAuthorizer], which opens
  /// it. Does nothing while an answer is under way.
  final VoidCallback onConnect;

  /// Sends the person's "not now". Does nothing while it is on its way.
  final VoidCallback onDecline;

  /// The theme overrides the [AIToolAuthorizationView] was given.
  final ToolApprovalThemeData? theme;
}

/// What the `userMessage` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIUserMessageProps {
  /// Creates an [AIUserMessageProps].
  const AIUserMessageProps({
    this.message,
    required this.text,
    this.attachments = const [],
    this.onAttachmentTap,
    this.onEdit,
  });

  /// The message, which is one of the app's own: cast it to read what else it
  /// holds. `null` while the message is on its way.
  final AIMessage? message;

  /// What the person wrote.
  final String text;

  /// What they sent with it.
  final List<AIMessageAttachment> attachments;

  /// Opens one of the attachments.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  /// Puts the message back in the composer to edit, or `null` when it can't
  /// be edited.
  ///
  /// It is set when the list shows an [AIConversation] that offers editing
  /// and the person can edit the message: it is their latest, and the agent
  /// isn't answering.
  final VoidCallback? onEdit;
}

/// What the `assistantMessage` builder of [streamAIComponentBuilders] gets.
@immutable
final class AIAssistantMessageProps {
  /// Creates an [AIAssistantMessageProps].
  ///
  /// [text] defaults to the message's text.
  const AIAssistantMessageProps({required this.message, this._text, this.approver, this.onAttachmentTap});

  /// The reply, which is one of the app's own messages: cast it to read what
  /// else it holds.
  final AIMessage message;

  final String? _text;

  /// The reply's text, in markdown, or an empty string when its generated UI
  /// (see [AIConversationView.ui]) is shown instead.
  ///
  /// The conversation shows that UI below the builder's widget.
  String get text => _text ?? message.text;

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
  const AIReplyActionsProps({required this.message, required this.isLatestReply, this.actions});

  /// The reply, which is one of the app's own messages: cast it to act on it.
  final AIMessage message;

  /// The reply's text, in markdown. It can be empty for a reply that shows
  /// only generated UI (see [AIConversationView.ui]) or attachments.
  String get text => message.text;

  /// Whether it is the latest reply in the conversation, such as the only one
  /// an app offers to regenerate.
  final bool isLatestReply;

  /// What the list's [AIConversation] offers to do with the reply, as its
  /// [AIConversation.actions] allow: rate it, and regenerate it while it is
  /// the latest and the agent isn't answering.
  ///
  /// `null` when the list doesn't show an [AIConversation].
  final AIReplyActions? actions;
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

  /// Opens it, when the app handles taps itself.
  ///
  /// `null` when it doesn't: [AIMessageAttachmentView] then opens a file's URL
  /// by default, and does nothing for an image.
  final VoidCallback? onTap;
}
