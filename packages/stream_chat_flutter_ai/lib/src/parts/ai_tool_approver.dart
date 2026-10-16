import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
// Here for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';

/// Sends a person's answer to a tool call's question to the agent's backend.
///
/// [allowed] is `true` to allow the call and `false` to decline it. Complete
/// once the backend has the answer; throw (or complete with an error) when it
/// couldn't be sent, so the person can answer again.
// Positional, like the `(call, allowed)` closure every caller writes; a named
// flag would only add noise at the one place it is called.
// ignore: avoid_positional_boolean_parameters
typedef AIToolApprovalDecider = Future<void> Function(AIToolCallPart call, bool allowed);

/// Answers the question an [AIToolApprovalView] is showing: `true` allows the
/// call, `false` declines it.
typedef AIToolApprovalDecide = ValueChanged<bool>;

/// Builds your own content for an [AIToolApprovalView] in place of the
/// [AIToolApprovalCard].
///
/// [approval] is the call's question, or `null` when the call awaits approval
/// without one — ask in your own words then. [state] says whether an answer is
/// on its way or couldn't be sent; [decide] sends one, and ignores taps while
/// one is on its way.
typedef AIToolApprovalContentBuilder =
    Widget Function(
      BuildContext context,
      AIToolApproval? approval,
      AIToolApprovalState state,
      AIToolApprovalDecide decide,
    );

/// The person answering tool calls' questions on this device, and how their
/// answer reaches the agent's backend, which holds each call until it gets
/// one.
///
/// ```dart
/// final approver = AIToolApprover(
///   userId: currentUser.id,
///   clientId: installId,
///   decide: (call, allowed) => backend.answerToolCall(call.id, allowed: allowed),
/// );
///
/// AIMessagePartsView(parts: parts, approver: approver)
/// ```
///
/// The backend should accept an answer only from the call's targeted person
/// (and install, when the call names one), only while the call waits, and only
/// once. It then updates the call's step: allowed, the call goes on; declined,
/// it is cancelled. Until that update arrives, the question stays up with its
/// buttons disabled.
@immutable
class AIToolApprover {
  /// Creates an [AIToolApprover] for [userId] on the install [clientId].
  AIToolApprover({required String userId, String? clientId, required AIToolApprovalDecider decide})
    : this.forIdentity(
        AIClientIdentity(userId: userId, clientId: clientId),
        decide: decide,
      );

  /// Creates an [AIToolApprover] for [identity], the same identity a client
  /// tool runner on this device would use.
  const AIToolApprover.forIdentity(this.identity, {required this.decide});

  /// Who is answering, and on which install.
  final AIClientIdentity identity;

  /// Sends an answer. A thrown error, or a future completing with one, shows
  /// "couldn't be sent" and lets the person answer again; it is reported
  /// through [FlutterError.reportError] and never rethrown.
  final AIToolApprovalDecider decide;

  /// The person signed in, matched against a call's `target_user_id`.
  String get userId => identity.userId;

  /// This install, matched against a call's `target_client_id`.
  String? get clientId => identity.clientId;

  /// Whether [call] waits for this person's answer on this install. See
  /// [AIToolCallPart.isAwaitingApproval].
  bool isAwaiting(AIToolCallPart call) => call.isAwaitingApproval(userId: userId, clientId: clientId);
}

/// Where an [AIToolApprovalState] is.
enum AIToolApprovalPhase {
  /// Nothing sent yet: the buttons are enabled.
  idle,

  /// An answer is on its way, or arrived and the call's step hasn't changed
  /// yet: the buttons are disabled.
  sending,

  /// The answer couldn't be sent: the buttons are enabled again, so the person
  /// can answer again.
  failed,
}

/// Where the person's answer to a tool call's question is.
@immutable
class AIToolApprovalState {
  /// Nothing sent yet.
  const AIToolApprovalState.idle() : phase = AIToolApprovalPhase.idle, allowed = null;

  /// The answer [allowed] is on its way, or arrived and the call's step hasn't
  /// changed yet.
  const AIToolApprovalState.sending({required bool this.allowed}) : phase = AIToolApprovalPhase.sending;

  /// The answer [allowed] couldn't be sent.
  const AIToolApprovalState.failed({required bool this.allowed}) : phase = AIToolApprovalPhase.failed;

  /// Where the answer is.
  final AIToolApprovalPhase phase;

  /// The answer being sent, or the one that couldn't be: `true` for allow.
  /// `null` while idle.
  final bool? allowed;

  /// Whether an answer is on its way, so the buttons are disabled.
  bool get isSending => phase == AIToolApprovalPhase.sending;

  /// Whether the last answer couldn't be sent.
  bool get hasFailed => phase == AIToolApprovalPhase.failed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIToolApprovalState && other.phase == phase && other.allowed == allowed;

  @override
  int get hashCode => Object.hash(phase, allowed);

  @override
  String toString() => 'AIToolApprovalState(${phase.name}${allowed == null ? '' : ', allowed: $allowed'})';
}
