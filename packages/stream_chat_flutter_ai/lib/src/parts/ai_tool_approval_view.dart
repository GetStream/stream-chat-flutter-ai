import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/src/parts/resolved_tool_approval_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Not doc-only: [ToolApprovalThemeData] is a parameter type.
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';

/// {@template aiToolApprovalView}
/// Asks the person a tool call waits for whether it may run — the question on
/// an `ai_tool_call` step whose status is `awaiting_approval`.
///
/// It shows only while [AIClientIdentity.canApprove] holds for the
/// [approver]'s identity — see [AIToolCallPart.isAwaitingApproval] for the
/// rules. Otherwise it is an empty box, so it can sit under every tool call:
///
/// ```dart
/// Column(
///   children: [
///     AIToolCallView(call: call),
///     AIToolApprovalView(call: call, approver: approver),
///   ],
/// )
/// ```
///
/// `AIMessagePartsView(parts: parts, approver: approver)` does this for every
/// tool call.
///
/// Tapping a button calls [AIToolApprover.answer]; further taps do nothing
/// while the answer is on its way or sent, and the buttons are disabled. If
/// sending fails, the default card says so ([AITranslations.toolApprovalNotSent])
/// and the buttons work again. If it succeeds, the default card says "Sent"
/// and the buttons stay disabled until the backend updates the call's step and
/// the call stops waiting, at which point the question goes away. Where the
/// answer is lives in the [approver], so it survives this view being rebuilt
/// from scratch, as in a lazy list.
///
/// To ask in your own design, pass a [builder]. It gets the call's
/// [AIToolCallPart.approval] (which may be `null`), the [AIToolApprovalState]
/// and an `answer` callback:
///
/// ```dart
/// AIToolApprovalView(
///   call: call,
///   approver: approver,
///   builder: (context, approval, state, answer) => MyApprovalCard(
///     title: approval?.title ?? 'Allow this?',
///     busy: state.isBusy,
///     onAllow: () => answer(AIToolApprovalDecision.allowed),
///     onDecline: () => answer(AIToolApprovalDecision.declined),
///   ),
/// )
/// ```
///
/// Without one it shows an [AIToolApprovalCard], styled by [theme], then the
/// nearest [ToolApprovalTheme], then [AITheme.toolApprovalTheme].
/// {@endtemplate}
class AIToolApprovalView extends StatefulWidget {
  /// {@macro aiToolApprovalView}
  const AIToolApprovalView({super.key, required this.call, required this.approver, this.builder, this.theme});

  /// The tool call whose question to ask.
  final AIToolCallPart call;

  /// Who answers on this device, how the answer is sent, and where it is.
  final AIToolApprover approver;

  /// Builds your own content in place of the [AIToolApprovalCard].
  final AIToolApprovalContentBuilder? builder;

  /// Overrides for the default card, layered over the ambient
  /// [ToolApprovalTheme]. Its text styles merge over the themed ones rather
  /// than replacing them. Unused with a [builder].
  final ToolApprovalThemeData? theme;

  @override
  State<AIToolApprovalView> createState() => _AIToolApprovalViewState();
}

class _AIToolApprovalViewState extends State<AIToolApprovalView> {
  @override
  void initState() {
    super.initState();
    widget.approver.addListener(_onApproverChanged);
  }

  @override
  void didUpdateWidget(AIToolApprovalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.approver != widget.approver) {
      oldWidget.approver.removeListener(_onApproverChanged);
      widget.approver.addListener(_onApproverChanged);
    }
  }

  @override
  void dispose() {
    widget.approver.removeListener(_onApproverChanged);
    super.dispose();
  }

  void _onApproverChanged() {
    if (mounted) setState(() {});
  }

  void _answer(AIToolApprovalDecision decision) {
    if (!mounted) return reportDroppedAnswer(widget.call, 'its AIToolApprovalView was disposed');
    // A builder answering while building would make the approver notify mid
    // build; answer right after the frame instead, if it still applies then.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _answer(decision));
      return;
    }
    widget.approver.answer(widget.call, decision);
  }

  /// The tool's name for the fallback title, with underscores as spaces
  /// (`send_email` → "send email"), or `null` when the agent sent none. Not
  /// the display title, which describes progress ("Sending the email").
  static String? _toolName(AIToolCallPart call) {
    final name = call.name.replaceAll('_', ' ').trim();
    return name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final approver = widget.approver;
    final state = approver.stateOf(call);
    if (!approver.identity.canApprove(call)) return const SizedBox.shrink();

    if (widget.builder case final builder?) return builder(context, call.approval, state, _answer);
    return AIToolApprovalCard(
      approval: call.approval,
      toolName: _toolName(call),
      state: state,
      onAnswer: _answer,
      theme: widget.theme,
    );
  }
}

/// {@template aiToolApprovalCard}
/// A tool call's question: what it asks, the agent's reason and what allowing
/// it shares, and buttons to allow or decline it — the default content of an
/// [AIToolApprovalView].
///
/// The title and the button labels fall back to translations when [approval]
/// (or the field) is missing or blank: the title to
/// [AITranslations.toolApprovalTitle] with [toolName], the buttons to
/// [AITranslations.toolApprovalAllow] and [AITranslations.toolApprovalDecline].
///
/// While [state] is sending, both buttons are disabled and the pressed one
/// shows a small progress indicator (a static icon with reduced motion on).
/// Once sent, they stay disabled and a check with
/// [AITranslations.toolApprovalSent] follows them. When it has failed, a line
/// in [ToolApprovalThemeData.failureStyle] says the answer couldn't be sent,
/// and is announced to screen readers.
///
/// It fills its width, so give it a bounded one, as a chat list does.
///
/// Usable on its own inside an [AIToolApprovalView.builder], to wrap the
/// default card rather than replace it.
/// {@endtemplate}
class AIToolApprovalCard extends StatelessWidget {
  /// {@macro aiToolApprovalCard}
  const AIToolApprovalCard({
    super.key,
    this.approval,
    this.toolName,
    this.state = const AIToolApprovalIdle(),
    required this.onAnswer,
    this.theme,
  });

  /// The question, or `null` to ask with the translated fallbacks.
  final AIToolApproval? approval;

  /// The tool's name for the fallback title, such as "send email" for
  /// `send_email`. `null` falls back to a title without one.
  final String? toolName;

  /// Where the answer is.
  final AIToolApprovalState state;

  /// Called with the person's decision when they tap a button.
  final AIToolApprovalAnswer onAnswer;

  /// Overrides for this card, layered over the ambient [ToolApprovalTheme].
  /// Its text styles merge over the themed ones rather than replacing them.
  final ToolApprovalThemeData? theme;

  /// The agent's reason, as a sentence, then what allowing the call shares.
  static List<String> _lines(AIToolApproval? approval) {
    final reason = approval?.reason?.trim() ?? '';
    final message = approval?.message?.trim() ?? '';
    return [
      if (reason.isNotEmpty) _sentence(reason),
      if (message.isNotEmpty) message,
    ];
  }

  static String _sentence(String text) {
    final capitalised = text[0].toUpperCase() + text.substring(1);
    return '.!?…'.contains(capitalised[capitalised.length - 1]) ? capitalised : '$capitalised.';
  }

  static String? _nonBlank(String? text) => (text?.trim().isEmpty ?? true) ? null : text;

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedToolApprovalTheme.resolve(context, override: this.theme);
    final translations = AITranslations.of(context);
    final busy = state.isBusy;
    final sending = state is AIToolApprovalSending;

    final title = _nonBlank(approval?.title) ?? translations.toolApprovalTitle(toolName);
    final allowLabel = _nonBlank(approval?.allowTitle) ?? translations.toolApprovalAllow;
    final declineLabel = _nonBlank(approval?.declineTitle) ?? translations.toolApprovalDecline;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: Border.all(color: theme.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.titleStyle),
                for (final line in _lines(approval))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(line, style: theme.messageStyle),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: busy ? null : () => onAnswer(AIToolApprovalDecision.allowed),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.onAccentColor,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _ButtonLabel(
                        allowLabel,
                        busy: sending && state.decision == AIToolApprovalDecision.allowed,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => onAnswer(AIToolApprovalDecision.declined),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accentColor,
                        side: BorderSide(color: theme.borderColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _ButtonLabel(
                        declineLabel,
                        busy: sending && state.decision == AIToolApprovalDecision.declined,
                      ),
                    ),
                    if (state.isSent)
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 16, color: theme.messageStyle.color),
                            const SizedBox(width: 4),
                            Text(translations.toolApprovalSent, style: theme.messageStyle),
                          ],
                        ),
                      ),
                  ],
                ),
                if (state.hasFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(translations.toolApprovalNotSent, style: theme.failureStyle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A button's label, led by a small progress indicator while its answer is
/// on its way.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text, {required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(text);

    // The button's own (disabled) foreground, which it puts in the icon theme.
    final color = IconTheme.of(context).color;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const size = 14.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: AITranslations.of(context).toolApprovalSending,
          child: SizedBox.square(
            dimension: size,
            // A spinner never stops, so reduced motion gets a still "in progress".
            child: reduceMotion
                ? Icon(Icons.more_horiz_rounded, size: size, color: color)
                : CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
