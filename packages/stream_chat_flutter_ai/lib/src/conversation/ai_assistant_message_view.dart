import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_parts_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/streaming_reasoning_view.dart';
import 'package:stream_chat_flutter_ai/src/streaming_message_view.dart';

/// A reply of the agent: the steps it took, then its answer, typed out as it
/// arrives, and then its attachments.
///
/// Reasoning shows with [StreamingReasoningView], open while the model thinks,
/// and the other steps as [AIMessagePartsView] shows them, asking this person
/// about a tool call that waits for their approval when given an [approver].
///
/// ```dart
/// AIAssistantMessageView(text: reply.text, isGenerating: reply.isGenerating, parts: reply.parts)
/// ```
class AIAssistantMessageView extends StatefulWidget {
  /// Creates an [AIAssistantMessageView].
  const AIAssistantMessageView({
    super.key,
    required this.text,
    this.isGenerating = false,
    this.parts = const [],
    this.attachments = const [],
    this.approver,
    this.reasoningText,
    this.onAttachmentTap,
  });

  /// The answer, in markdown.
  final String text;

  /// Whether the agent is still writing it.
  final bool isGenerating;

  /// The steps the agent took, in order.
  final List<AIMessagePart> parts;

  /// What the agent sent with it, such as images and files.
  final List<AIMessageAttachment> attachments;

  /// Who answers tool calls' questions on this device.
  final AIToolApprover? approver;

  /// The whole of a reasoning step's thinking, when the app has it.
  final String? Function(AIReasoningPart step)? reasoningText;

  /// Opens one of the attachments.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  @override
  State<AIAssistantMessageView> createState() => _AIAssistantMessageViewState();
}

class _AIAssistantMessageViewState extends State<AIAssistantMessageView> {
  // Whether the answer is all on screen. A reply that is already done when it
  // appears, such as one from history, shows in full at once.
  late bool _typed = !widget.isGenerating;
  ValueNotifier<bool?>? _writing;

  bool get _isWriting => widget.isGenerating || (widget.text.isNotEmpty && !_typed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _writing = AnswerWritingScope.maybeOf(context);
    _report();
  }

  @override
  void didUpdateWidget(AIAssistantMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || (widget.isGenerating && !oldWidget.isGenerating)) _typed = false;
    _report();
  }

  // After the frame: the scope's listener sets state in the row above.
  void _report() {
    final writing = _writing;
    if (writing == null) return;
    final value = _isWriting;
    if (writing.value == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) writing.value = _isWriting;
    });
  }

  void _onFinished() {
    if (_typed) return;
    setState(() => _typed = true);
    _report();
  }

  Widget? _reasoning(BuildContext context, AIMessagePart part) {
    final step = part.reasoning;
    if (step == null) return null;
    // The first step of a turn the conversation saw thinking takes over its
    // count, so "Thinking… 8s" carries on rather than starting again.
    final scope = ThinkingTurnScope.maybeOf(context);
    final takesOver = scope != null && scope.clock.isFirstStep(step.id, scope.turn);
    final duration = !takesOver
        ? null
        : step.isStreaming
        ? scope.clock.elapsed(scope.turn)
        : scope.clock.durationOfFirstStep(scope.turn, step.duration);
    final props = AIReasoningProps(reasoning: step, text: widget.reasoningText?.call(step), duration: duration);
    if (AIComponentFactory.of(context).reasoning case final builder?) return builder(context, props);
    if (duration == null) return StreamingReasoningView.part(step, text: props.text);
    return StreamingReasoningView(
      // As `StreamingReasoningView.part` shows it.
      text: props.text ?? step.preview ?? step.summary ?? '',
      isThinking: step.isStreaming,
      duration: duration,
      summary: step.summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final builders = AIComponentFactory.of(context);
    final onAttachmentTap = widget.onAttachmentTap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (widget.parts.isNotEmpty)
          AIMessagePartsView(parts: widget.parts, approver: widget.approver, partBuilder: _reasoning),
        if (widget.text.isNotEmpty)
          StreamingMessageView(text: widget.text, expectMoreText: widget.isGenerating, onFinished: _onFinished),
        for (final attachment in widget.attachments)
          AIMessageAttachmentView.of(
            context,
            builders,
            AIMessageAttachmentProps(
              attachment: attachment,
              isFromUser: false,
              onTap: onAttachmentTap == null ? null : () => onAttachmentTap(attachment),
            ),
          ),
      ],
    );
  }
}
