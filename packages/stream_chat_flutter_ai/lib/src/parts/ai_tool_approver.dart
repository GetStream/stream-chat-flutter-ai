import 'dart:async';

import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';

/// Sends a person's answer to a tool call's question to the agent's backend.
///
/// Complete once the backend has the answer; throw (or complete with an error)
/// when it couldn't be sent, so the person can answer again.
typedef AIToolApprovalDecider = Future<void> Function(AIToolCallPart call, AIToolApprovalDecision decision);

/// Answers the question an [AIToolApprovalView] is showing, from its content:
/// [AIToolApprovalDecision.allowed] or [AIToolApprovalDecision.declined].
typedef AIToolApprovalAnswer = void Function(AIToolApprovalDecision decision);

/// Builds your own content for an [AIToolApprovalView] in place of
/// [AIComponentBuilders.toolApproval].
///
/// [approval] is the call's question, or `null` when the call awaits approval
/// without one — ask in your own words then. [state] says where the answer
/// is; [answer] sends one, and does nothing while an answer is on its way or
/// has been sent.
typedef AIToolApprovalContentBuilder =
    Widget Function(
      BuildContext context,
      AIToolApproval? approval,
      AIToolApprovalState state,
      AIToolApprovalAnswer answer,
    );

/// The person answering tool calls' questions on this device, how their
/// answers reach the agent's backend, and where each answer is.
///
/// **Create it once and keep it** — in a `State`, a provider or a service, not
/// in `build` — and [dispose] it when done. It remembers each call's
/// [AIToolApprovalState], so a question scrolled out of a lazy list and back
/// still shows its answer as sent, and a failure arriving meanwhile isn't lost.
///
/// ```dart
/// late final approver = AIToolApprover(
///   identity: AIClientIdentity(userId: currentUser.id, clientId: installId),
///   decide: (call, decision) => backend.answerToolCall(call.id, decision.value),
/// );
///
/// AIMessagePartsView(parts: parts, approver: approver)
/// ```
///
/// The backend should accept an answer only from the call's targeted person
/// (and install, when the call names one), only while the call waits, and only
/// once. It then updates the call's step: allowed, the call goes on; declined,
/// it is cancelled. Until that update arrives the answer stays
/// [AIToolApprovalSent], with the buttons disabled — for at most [sentTimeout]
/// when one is set, which bounds sending the answer as well.
class AIToolApprover extends ChangeNotifier {
  /// Creates an [AIToolApprover] for [identity].
  ///
  /// The [identity] is fixed: make a new approver when the signed-in person
  /// changes.
  AIToolApprover({required this.identity, required this.decide, this.sentTimeout})
    : assert(sentTimeout == null || sentTimeout > Duration.zero, 'sentTimeout must be positive');

  /// Who is answering, and on which install.
  final AIClientIdentity identity;

  /// Sends an answer. A thrown error, or a future completing with one, makes
  /// the answer [AIToolApprovalFailed] and lets the person answer again; it is
  /// reported through [FlutterError.reportError] and never rethrown, even after
  /// the approver is disposed. Without a [sentTimeout] it must not hang: the
  /// answer stays [AIToolApprovalSending] until it completes.
  final AIToolApprovalDecider decide;

  /// The longest an answer may take to send, and then stay
  /// [AIToolApprovalSent] while the call's step still waits. Past either, the
  /// answer turns [AIToolApprovalFailed] with a [TimeoutException], so the
  /// person sees something went wrong and can answer again. `null`, the
  /// default, waits for as long as it takes.
  ///
  /// A slow send is reported through [FlutterError.reportError] right away. A
  /// call still waiting past the timeout is reported once [stateOf] next sees
  /// it waiting — the backend may have moved it on while no
  /// [AIToolApprovalView] showed it — and not at all if it no longer does.
  final Duration? sentTimeout;

  final _entries = <String, _Entry>{};
  bool _disposed = false;

  /// Where the answer to [call] is. A call that no longer waits for this
  /// person is forgotten, and reads [AIToolApprovalIdle].
  AIToolApprovalState stateOf(AIToolCallPart call) {
    if (!identity.canApprove(call)) {
      _entries.remove(call.id)?.timer?.cancel();
      return const AIToolApprovalIdle();
    }
    final entry = _entries[call.id];
    // A sent timeout is only a backend bug if the call still waits, which
    // [call] now confirms. Reported after this read, as it runs from build.
    if (entry?.unreportedTimeout case (final error, final stackTrace)) {
      entry!.unreportedTimeout = null;
      scheduleMicrotask(() => _report(error, stackTrace, call));
    }
    return entry?.state ?? const AIToolApprovalIdle();
  }

  /// Sends [decision] as the answer to [call] through [decide], unless an
  /// answer is already on its way or sent. An answer for a call that doesn't
  /// wait for this person is dropped (and said so in debug builds).
  void answer(AIToolCallPart call, AIToolApprovalDecision decision) {
    if (_disposed) return reportDroppedAnswer(call, 'its AIToolApprover was disposed');
    if (!identity.canApprove(call)) return reportDroppedAnswer(call, 'it no longer waits for ${identity.userId}');
    final current = stateOf(call);
    if (current is AIToolApprovalSending || current is AIToolApprovalSent) return;

    final entry = _entries[call.id] = _Entry(AIToolApprovalSending(decision));
    notifyListeners();
    unawaited(_send(call, decision, entry));
  }

  Future<void> _send(AIToolCallPart call, AIToolApprovalDecision decision, _Entry entry) async {
    try {
      final sending = Future.sync(() => decide(call, decision));
      await (sentTimeout == null
          ? sending
          : sending.timeout(
              sentTimeout!,
              onTimeout: () => throw TimeoutException('the answer to tool call "${call.id}" took too long to send'),
            ));
      if (!_isCurrent(call, entry)) return;
      entry.state = AIToolApprovalSent(decision);
      if (sentTimeout case final timeout?) {
        entry.timer = Timer(timeout, () {
          if (!_isCurrent(call, entry)) return;
          final error = TimeoutException(
            'tool call "${call.id}" still awaits approval after the answer was sent',
            timeout,
          );
          // Not reported yet: the call may have moved on while no view showed
          // it. The next [stateOf] that sees it waiting reports it.
          entry
            ..state = AIToolApprovalFailed(decision, error)
            ..timer = null
            ..unreportedTimeout = (error, StackTrace.current);
          notifyListeners();
        });
      }
      notifyListeners();
    } catch (error, stackTrace) {
      // The state first: an app whose error handler rethrows must not leave
      // the card sending for good.
      if (_isCurrent(call, entry)) {
        entry.state = AIToolApprovalFailed(decision, error);
        notifyListeners();
      }
      _report(error, stackTrace, call);
    }
  }

  void _report(Object error, StackTrace stackTrace, AIToolCallPart call) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription('while sending the answer to tool call "${call.id}"'),
      ),
    );
  }

  /// Whether [entry] is still [call]'s: not forgotten, nor replaced by a
  /// later answer, nor disposed.
  bool _isCurrent(AIToolCallPart call, _Entry entry) => !_disposed && identical(_entries[call.id], entry);

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _entries.values) {
      entry.timer?.cancel();
    }
    _entries.clear();
    super.dispose();
  }
}

class _Entry {
  _Entry(this.state);

  AIToolApprovalState state;
  Timer? timer;
  (TimeoutException, StackTrace)? unreportedTimeout;
}

/// Where the person's answer to a tool call's question is: [AIToolApprovalIdle],
/// [AIToolApprovalSending], [AIToolApprovalSent] or [AIToolApprovalFailed].
@immutable
sealed class AIToolApprovalState {
  const AIToolApprovalState();

  /// The answer being sent, sent, or that couldn't be. `null` while idle.
  AIToolApprovalDecision? get decision;

  /// Whether the answer is on its way.
  bool get isSending => this is AIToolApprovalSending;

  /// Whether the answer arrived and the call's step hasn't changed yet.
  bool get isSent => this is AIToolApprovalSent;

  /// Whether the answer couldn't be sent.
  bool get hasFailed => this is AIToolApprovalFailed;

  /// Whether the buttons are disabled: sending or sent.
  bool get isBusy => isSending || isSent;
}

/// Nothing sent yet, so the buttons are enabled.
final class AIToolApprovalIdle extends AIToolApprovalState {
  /// Creates an [AIToolApprovalIdle].
  const AIToolApprovalIdle();

  @override
  AIToolApprovalDecision? get decision => null;

  @override
  bool operator ==(Object other) => other is AIToolApprovalIdle;

  @override
  int get hashCode => (AIToolApprovalIdle).hashCode;

  @override
  String toString() => 'AIToolApprovalIdle()';
}

/// The answer [decision] is on its way.
final class AIToolApprovalSending extends AIToolApprovalState {
  /// Creates an [AIToolApprovalSending].
  const AIToolApprovalSending(this.decision);

  @override
  final AIToolApprovalDecision decision;

  @override
  bool operator ==(Object other) => other is AIToolApprovalSending && other.decision == decision;

  @override
  int get hashCode => Object.hash(AIToolApprovalSending, decision);

  @override
  String toString() => 'AIToolApprovalSending(${decision.value})';
}

/// The answer [decision] arrived; the call's step hasn't changed yet.
final class AIToolApprovalSent extends AIToolApprovalState {
  /// Creates an [AIToolApprovalSent].
  const AIToolApprovalSent(this.decision);

  @override
  final AIToolApprovalDecision decision;

  @override
  bool operator ==(Object other) => other is AIToolApprovalSent && other.decision == decision;

  @override
  int get hashCode => Object.hash(AIToolApprovalSent, decision);

  @override
  String toString() => 'AIToolApprovalSent(${decision.value})';
}

/// The answer [decision] couldn't be sent, because of [error]; the person can
/// answer again.
final class AIToolApprovalFailed extends AIToolApprovalState {
  /// Creates an [AIToolApprovalFailed].
  const AIToolApprovalFailed(this.decision, this.error);

  @override
  final AIToolApprovalDecision decision;

  /// What [AIToolApprover.decide] threw, or a [TimeoutException] past
  /// [AIToolApprover.sentTimeout].
  final Object? error;

  @override
  bool operator ==(Object other) => other is AIToolApprovalFailed && other.decision == decision && other.error == error;

  @override
  int get hashCode => Object.hash(AIToolApprovalFailed, decision, error);

  @override
  String toString() => 'AIToolApprovalFailed(${decision.value}, $error)';
}
