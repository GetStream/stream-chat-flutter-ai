import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/stream_ai_component_builders.dart';
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

  /// Opens one of the attachments, in place of the default: a file with a URL
  /// opens it, and an image does nothing.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  @override
  State<AIAssistantMessageView> createState() => _AIAssistantMessageViewState();
}

class _AIAssistantMessageViewState extends State<AIAssistantMessageView> {
  // Whether the answer is all on screen. A reply that is already done when it
  // appears, such as one from history, shows in full at once.
  late bool _typed = !widget.isGenerating;
  ValueNotifier<bool?>? _writing;

  // [AIAssistantMessageView.isGenerating], held for [_writingTail] after it
  // turns false. An answer whose last chunk, or whole text, arrives in the
  // same update as the end of generation still types out instead of appearing
  // at once.
  late bool _generating;
  Timer? _tail;

  static const _writingTail = Duration(milliseconds: 100);

  // In a conversation, the answer waits for the reasoning above it to show and
  // fold first: whether it is held, and until when. Once it is let go it types
  // out, even if the reply has finished generating.
  ThinkingTurnScope? _turn;
  bool _held = false;
  DateTime? _answerStartsAt;
  Timer? _hold;

  // Whether each reasoning step opens to show its reasoning, decided once, as
  // the step first appears.
  final _opensFinished = <String, bool>{};

  bool get _isWriting => _generating || _held || (widget.text.isNotEmpty && !_typed);

  @override
  void initState() {
    super.initState();
    // Not a `late` initializer: that would run on first read, which may come
    // only after `isGenerating` has already turned false.
    _generating = widget.isGenerating;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _writing = AnswerWritingScope.maybeOf(context);
    _turn = ThinkingTurnScope.maybeOf(context);
    _syncHold();
    _report();
  }

  @override
  void didUpdateWidget(AIAssistantMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only text that types out reports [_onFinished]; one shown at once is done.
    final typesOut = _generating && widget.text != oldWidget.text;
    if (typesOut || (widget.isGenerating && !oldWidget.isGenerating)) _typed = false;
    if (widget.isGenerating) {
      _tail?.cancel();
      _generating = true;
    } else if (oldWidget.isGenerating) {
      _tail?.cancel();
      _tail = Timer(_writingTail, () {
        if (!mounted) return;
        setState(() => _generating = false);
        _report();
      });
    }
    _syncHold();
    _report();
  }

  @override
  void dispose() {
    _tail?.cancel();
    _hold?.cancel();
    super.dispose();
  }

  // Decides which reasoning step opens as it arrives, since that sets when the
  // answer starts, and then holds the answer until then. It runs before the
  // steps build, which only read what it decided.
  void _syncHold() {
    final turn = _turn;
    if (turn == null) return;
    // An app's own reasoning view neither opens nor folds, so there is nothing
    // for the answer to wait for.
    if (context.aiComponentBuilder<AIReasoningProps>() == null) {
      for (final part in widget.parts) {
        final step = part.reasoning;
        if (step != null) _opensFinished.putIfAbsent(step.id, () => _opensWhenFinished(step, turn));
      }
    }
    final startsAt = turn.clock.answerStartsAt(turn.turn);
    if (startsAt == _answerStartsAt) return;
    _answerStartsAt = startsAt;
    _hold?.cancel();
    _held = false;
    if (startsAt == null) return;
    final wait = startsAt.difference(turn.clock.now());
    if (wait <= Duration.zero) return;
    _held = true;
    _hold = Timer(wait, _releaseAnswer);
  }

  void _releaseAnswer() {
    setState(() {
      _held = false;
      _typed = false;
    });
    _report();
  }

  // Whether [step] arrived done as its turn's first, with the reply that ended
  // the thinking, which is when it opens to show its reasoning.
  bool _opensWhenFinished(AIReasoningPart step, ThinkingTurnScope turn) {
    if (!turn.clock.isFirstStep(step.id, turn.turn)) return false;
    if (step.isStreaming) return false;
    if (_shownText(step, widget.reasoningText?.call(step)).isEmpty) return false;
    return turn.clock.showsFirstStep(turn.turn);
  }

  // What a step's view shows, as `StreamingReasoningView.part` does.
  String _shownText(AIReasoningPart step, String? text) => text ?? step.preview ?? step.summary ?? '';

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
    if (context.aiComponentBuilder<AIReasoningProps>() case final builder?) return builder(context, props);
    if (duration == null) return StreamingReasoningView.part(step, text: props.text);
    final view = StreamingReasoningView(
      text: _shownText(step, props.text),
      isThinking: step.isStreaming,
      duration: duration,
      summary: step.summary,
    );
    return _opensFinished[step.id] == true ? FinishedReasoningScope(child: view) : view;
  }

  @override
  Widget build(BuildContext context) {
    final onAttachmentTap = widget.onAttachmentTap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (widget.parts.isNotEmpty)
          AIMessagePartsView(parts: widget.parts, approver: widget.approver, partBuilder: _reasoning),
        if (widget.text.isNotEmpty)
          StreamingMessageView(
            text: _held ? '' : widget.text,
            expectMoreText: _generating || _held,
            onFinished: _onFinished,
          ),
        for (final attachment in widget.attachments)
          AIMessageAttachmentView.of(
            context,
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
