import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_authorization.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/src/parts/resolved_tool_approval_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Not doc-only: [ToolApprovalThemeData] is a parameter type.
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';

/// {@template aiToolAuthorizationView}
/// Asks the person a tool call waits for to sign in at the provider it needs
/// — the sign-in on an `ai_tool_call` step whose status is
/// `awaiting_authorization`.
///
/// It shows only while [AIToolApprover.signInFor] has a sign-in for the call:
/// the [approver] has an [AIToolAuthorizer], the call waits for its person,
/// and the sign-in is [AIToolAuthorizationKind.oauth]. Otherwise it is an
/// empty box, so it can sit under every tool call:
///
/// ```dart
/// Column(
///   children: [
///     AIToolCallView(call: call),
///     AIToolAuthorizationView(call: call, approver: approver),
///   ],
/// )
/// ```
///
/// `AIMessagePartsView(parts: parts, approver: approver)` does this for every
/// tool call.
///
/// Connect calls [AIToolApprover.connect], which hands the sign-in page to
/// the authorizer; Not now calls [AIToolApprover.declineAuthorization]. Once
/// the provider has answered, the agent's backend updates the call's step and
/// the sign-in goes away. Where the person's answer is lives in the
/// [approver], so it survives this view being rebuilt from scratch, as in a
/// lazy list.
///
/// To ask in your own design, pass a [builder]. It gets the sign-in, the
/// [AIToolAuthorizationState], and `connect` and `decline` callbacks:
///
/// ```dart
/// AIToolAuthorizationView(
///   call: call,
///   approver: approver,
///   builder: (context, authorization, state, connect, decline) => MySignInCard(
///     title: authorization.title,
///     busy: state.isBusy,
///     onConnect: connect,
///     onNotNow: decline,
///   ),
/// )
/// ```
///
/// Without one it shows [AIComponentBuilders.toolAuthorization] — by default
/// an [AIToolAuthorizationCard], styled like the approval card: by [theme],
/// then the nearest [ToolApprovalTheme], then [AITheme.toolApprovalTheme].
/// Override that slot to replace the card everywhere.
/// {@endtemplate}
class AIToolAuthorizationView extends StatefulWidget {
  /// {@macro aiToolAuthorizationView}
  const AIToolAuthorizationView({super.key, required this.call, required this.approver, this.builder, this.theme});

  /// The tool call whose sign-in to ask for.
  final AIToolCallPart call;

  /// Who answers on this device, with the [AIToolAuthorizer] the sign-in
  /// needs, and where the answer is.
  final AIToolApprover approver;

  /// Builds your own content in place of [AIComponentBuilders.toolAuthorization].
  final AIToolAuthorizationContentBuilder? builder;

  /// Overrides for the default card, layered over the ambient
  /// [ToolApprovalTheme]. Its text styles merge over the themed ones rather
  /// than replacing them. Unused with a [builder].
  final ToolApprovalThemeData? theme;

  @override
  State<AIToolAuthorizationView> createState() => _AIToolAuthorizationViewState();
}

class _AIToolAuthorizationViewState extends State<AIToolAuthorizationView> {
  @override
  void initState() {
    super.initState();
    widget.approver.addListener(_onApproverChanged);
  }

  @override
  void didUpdateWidget(AIToolAuthorizationView oldWidget) {
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

  // Bound to the call it was built for, so a callback kept by a builder never
  // acts on another call this view shows since. The approver is read when it
  // acts, so one swapped in since gets it.
  AIToolAuthorizationAction _actionFor(
    AIToolCallPart call,
    void Function(AIToolApprover approver, AIToolCallPart call) act,
  ) =>
      () => _act(call, act);

  void _act(AIToolCallPart call, void Function(AIToolApprover approver, AIToolCallPart call) act) {
    if (!mounted) return reportDroppedAnswer(call, 'its AIToolAuthorizationView was disposed');
    if (widget.call.id != call.id) {
      return reportDroppedAnswer(call, 'its AIToolAuthorizationView shows another call now');
    }
    // A builder acting while building would make the approver notify mid
    // build; act right after the frame instead, if it still applies then.
    final inFrame = switch (SchedulerBinding.instance.schedulerPhase) {
      SchedulerPhase.persistentCallbacks || SchedulerPhase.midFrameMicrotasks => true,
      _ => false,
    };
    if (inFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _act(call, act));
      return;
    }
    act(widget.approver, widget.call);
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final approver = widget.approver;
    final state = approver.authorizationStateOf(call);
    final authorization = approver.signInFor(call);
    if (authorization == null) return const SizedBox.shrink();

    final connect = _actionFor(call, (approver, call) => approver.connect(call));
    final decline = _actionFor(call, (approver, call) => approver.declineAuthorization(call));
    if (widget.builder case final builder?) return builder(context, authorization, state, connect, decline);
    final props = AIToolAuthorizationProps(
      call: call,
      authorization: authorization,
      state: state,
      onConnect: connect,
      onDecline: decline,
      theme: widget.theme,
    );
    return AIComponentFactory.of(context).toolAuthorization?.call(context, props) ??
        AIToolAuthorizationCard(
          authorization: props.authorization,
          state: props.state,
          onConnect: props.onConnect,
          onDecline: props.onDecline,
          theme: props.theme,
        );
  }
}

/// {@template aiToolAuthorizationCard}
/// A tool call's sign-in: which provider it needs and what signing in means,
/// with buttons to connect or to say not now — the default content of an
/// [AIToolAuthorizationView].
///
/// Connect ([AITranslations.toolAuthorizationConnect]) reads
/// [AITranslations.toolAuthorizationConnecting] while [state] is connecting,
/// and waits while any answer is under way. Not now
/// ([AITranslations.toolAuthorizationDecline]) waits only while its own answer
/// is on its way, so a sign-in that never comes back leaves the person a way
/// out. A small progress indicator follows the buttons while busy (a static
/// icon with reduced motion on); while declining, screen readers hear it as
/// [AITranslations.toolApprovalSending]. When an answer failed, a line in
/// [ToolApprovalThemeData.failureStyle] says so —
/// [AITranslations.toolAuthorizationNotOpened] or
/// [AITranslations.toolApprovalNotSent] — and is announced to screen readers.
///
/// It fills its width, so give it a bounded one, as a chat list does. It uses
/// the approval card's theme.
///
/// Usable on its own inside an [AIToolAuthorizationView.builder], to wrap the
/// default card rather than replace it.
/// {@endtemplate}
class AIToolAuthorizationCard extends StatelessWidget {
  /// {@macro aiToolAuthorizationCard}
  const AIToolAuthorizationCard({
    super.key,
    required this.authorization,
    this.state = const AIToolAuthorizationState(),
    required this.onConnect,
    required this.onDecline,
    this.theme,
  });

  /// The sign-in, such as "Connect Linear".
  final AIToolAuthorization authorization;

  /// Where the person's answer is.
  final AIToolAuthorizationState state;

  /// Called when the person taps Connect.
  final VoidCallback onConnect;

  /// Called when the person taps Not now.
  final VoidCallback onDecline;

  /// Overrides for this card, layered over the ambient [ToolApprovalTheme].
  /// Its text styles merge over the themed ones rather than replacing them.
  final ToolApprovalThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedToolApprovalTheme.resolve(context, override: this.theme);
    final translations = AITranslations.of(context);
    final message = authorization.message?.trim() ?? '';
    final failure = switch (state) {
      AIToolAuthorizationState(connectFailed: true) => translations.toolAuthorizationNotOpened,
      AIToolAuthorizationState(declineFailed: true) => translations.toolApprovalNotSent,
      _ => null,
    };

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
                Text(authorization.title, style: theme.titleStyle),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(message, style: theme.messageStyle),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: state.isBusy ? null : onConnect,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.onAccentColor,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        state.isConnecting
                            ? translations.toolAuthorizationConnecting
                            : translations.toolAuthorizationConnect,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: state.isDeclining ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accentColor,
                        side: BorderSide(color: theme.borderColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(translations.toolAuthorizationDecline),
                    ),
                    if (state.isBusy)
                      _Busy(
                        color: theme.accentColor,
                        // Connecting says so on its button; declining doesn't.
                        label: state.isDeclining ? translations.toolApprovalSending : null,
                      ),
                  ],
                ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(failure, style: theme.failureStyle),
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

/// A small progress indicator, or a still "in progress" with reduced motion
/// on. Screen readers hear [label]; without one it is left out, as a button
/// label already says what is under way.
class _Busy extends StatelessWidget {
  const _Busy({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const size = 16.0;
    final indicator = ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        // A spinner never stops, so reduced motion gets a still "in progress".
        child: reduceMotion
            ? Icon(Icons.more_horiz_rounded, size: size, color: color)
            : CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
    );
    final label = this.label;
    if (label == null) return indicator;
    return Semantics(label: label, liveRegion: true, child: indicator);
  }
}
