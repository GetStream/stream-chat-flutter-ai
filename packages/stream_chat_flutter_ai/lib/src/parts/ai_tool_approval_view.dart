import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/resolved_tool_approval_theme.dart';
// The next two are imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';

/// {@template aiToolApprovalView}
/// Asks the person a tool call waits for whether it may run — the question on
/// an `ai_tool_call` step whose status is `awaiting_approval`.
///
/// It shows only to that person, on the install the call names (or any of
/// their devices when it names none), and only while the call waits and its
/// approval hasn't been answered — [AIToolApprover.isAwaiting]. Otherwise it
/// is an empty box, so it can sit under every tool call:
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
/// Tapping a button calls [AIToolApprover.decide] once; further taps are
/// ignored while the answer is on its way, and the buttons are disabled. If
/// sending fails, the card says so ([AITranslations.toolApprovalNotSent]) and
/// the buttons work again. If it succeeds, the buttons stay disabled until the
/// backend updates the call's step and the call stops waiting, at which point
/// the question goes away.
///
/// To ask in your own design, pass a [builder]. It gets the call's
/// [AIToolCallPart.approval] (which may be `null`), the [AIToolApprovalState]
/// and a `decide` callback:
///
/// ```dart
/// AIToolApprovalView(
///   call: call,
///   approver: approver,
///   builder: (context, approval, state, decide) => MyApprovalCard(
///     title: approval?.title ?? 'Allow this?',
///     busy: state.isSending,
///     onAllow: () => decide(true),
///     onDecline: () => decide(false),
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

  /// Who answers on this device, and how the answer is sent.
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
  AIToolApprovalState _state = const AIToolApprovalState.idle();

  /// Bumped for every answer sent and every reset, so a failure arriving for
  /// an answer that no longer matters changes nothing.
  int _attempt = 0;

  @override
  void didUpdateWidget(AIToolApprovalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another call, or this one no longer waiting: whatever was sent is moot.
    if (widget.call.id != oldWidget.call.id || !widget.approver.isAwaiting(widget.call)) _reset();
  }

  void _reset() {
    if (_state.phase == AIToolApprovalPhase.idle) return;
    _attempt++;
    _state = const AIToolApprovalState.idle();
  }

  void _decide(bool allowed) {
    if (!mounted || _state.isSending || !widget.approver.isAwaiting(widget.call)) return;
    // A builder calling `decide` while building would make `setState` throw;
    // answer right after the frame instead.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _decide(allowed));
      return;
    }
    setState(() => _state = AIToolApprovalState.sending(allowed: allowed));
    unawaited(_send(widget.approver.decide, widget.call, allowed, ++_attempt));
  }

  Future<void> _send(AIToolApprovalDecider decide, AIToolCallPart call, bool allowed, int attempt) async {
    try {
      await decide(call, allowed);
      // Sent: stay disabled until the call's step changes and it stops waiting.
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while sending the answer to tool call "${call.id}"'),
        ),
      );
      if (mounted && attempt == _attempt) setState(() => _state = AIToolApprovalState.failed(allowed: allowed));
    }
  }

  /// What the default card calls the tool: the call's display name, or its
  /// name, or `null` when the agent sent neither.
  static String? _toolName(AIToolCallPart call) {
    for (final candidate in [call.displayName, call.name.replaceAll('_', ' ')]) {
      if (candidate.trim().isNotEmpty) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    if (!widget.approver.isAwaiting(call)) return const SizedBox.shrink();

    if (widget.builder case final builder?) return builder(context, call.approval, _state, _decide);
    return AIToolApprovalCard(
      approval: call.approval,
      toolName: _toolName(call),
      state: _state,
      decide: _decide,
      theme: widget.theme,
    );
  }
}

/// {@template aiToolApprovalCard}
/// A tool call's question: what it asks, the agent's reason and what allowing
/// it shares, and buttons to allow or decline it — the default content of an
/// [AIToolApprovalView].
///
/// Each text falls back to a translation when [approval] (or the field) is
/// missing: the title to [AITranslations.toolApprovalTitle] with [toolName],
/// the buttons to [AITranslations.toolApprovalAllow] and
/// [AITranslations.toolApprovalDecline].
///
/// While [state] is sending, both buttons are disabled and the pressed one
/// shows a small progress indicator (a static icon with reduced motion on).
/// When it has failed, a line in [ToolApprovalThemeData.failureStyle] says the
/// answer couldn't be sent, and is announced to screen readers.
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
    this.state = const AIToolApprovalState.idle(),
    required this.decide,
    this.theme,
  });

  /// The question, or `null` to ask with the translated fallbacks.
  final AIToolApproval? approval;

  /// The tool's name for the fallback title, such as "send email". `null`
  /// falls back to a title without one.
  final String? toolName;

  /// Where the answer is.
  final AIToolApprovalState state;

  /// Called with `true` when the person allows the call, `false` when they
  /// decline it.
  final AIToolApprovalDecide decide;

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
    final sending = state.isSending;

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
                  children: [
                    FilledButton(
                      onPressed: sending ? null : () => decide(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.onAccentColor,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _ButtonLabel(allowLabel, busy: sending && state.allowed == true),
                    ),
                    OutlinedButton(
                      onPressed: sending ? null : () => decide(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accentColor,
                        side: BorderSide(color: theme.borderColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _ButtonLabel(declineLabel, busy: sending && state.allowed == false),
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
