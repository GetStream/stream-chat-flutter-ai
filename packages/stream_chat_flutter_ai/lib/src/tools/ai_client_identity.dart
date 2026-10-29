import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
// Not doc-only: the matchers below call into it.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_runner.dart';

/// Who is signed in on this device, and which install this is — what a tool
/// call's `target_user_id` and `target_client_id` are matched against.
///
/// The host supplies both: [userId] from its chat client's signed-in user, and
/// [clientId] from an id it keeps per install (generated once and persisted).
/// This package stores neither.
///
/// ```dart
/// final identity = AIClientIdentity(userId: currentUser.id, clientId: installId);
/// ```
///
/// Three matchers say what this device may do with a call, and they treat a
/// missing `target_client_id` differently:
///
///  * [canApprove] — answering a call's question. A call that names no
///    install can be answered from any of the person's devices.
///  * [canAuthorize] — signing in for a call. Any of the person's devices
///    may, so `target_client_id` isn't checked.
///  * [canRun] — running a client tool. The call must name exactly this
///    install, so a call without `target_client_id`, or an identity without a
///    [clientId], never runs here: two devices must never both run it.
///
/// See [AIToolApprover] and [AIClientToolRunner].
@immutable
class AIClientIdentity {
  /// Creates an [AIClientIdentity]. [userId] must not be empty.
  const AIClientIdentity({required this.userId, this.clientId}) : assert(userId != '', 'userId must not be empty');

  /// The person signed in, matched against a call's `target_user_id`.
  final String userId;

  /// This install, matched against a call's `target_client_id`. `null` when
  /// the host keeps no install id: calls naming an install then never match.
  final String? clientId;

  /// Whether [call] waits for this person to answer its question, on this
  /// device. See [AIToolCallPart.isAwaitingApproval].
  bool canApprove(AIToolCallPart call) => call.isAwaitingApproval(userId: userId, clientId: clientId);

  /// Whether [call] waits for this person to sign in at a provider it needs,
  /// from any of their devices. See [AIToolCallPart.isAwaitingAuthorization].
  bool canAuthorize(AIToolCallPart call) => call.isAwaitingAuthorization(userId: userId);

  /// Whether [call] is a client tool waiting for this install to run it:
  /// targeted at [userId] and exactly at [clientId]. Always `false` without a
  /// [clientId]. See [AIToolCallPart.isAwaiting].
  bool canRun(AIToolCallPart call) {
    final clientId = this.clientId;
    return clientId != null && call.isAwaiting(userId: userId, clientId: clientId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIClientIdentity && other.userId == userId && other.clientId == clientId;

  @override
  int get hashCode => Object.hash(userId, clientId);

  @override
  String toString() => 'AIClientIdentity(userId: $userId, clientId: $clientId)';
}
