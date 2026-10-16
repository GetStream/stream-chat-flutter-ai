import 'package:flutter/foundation.dart';
// Here for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';

/// Who is signed in on this device, and which install this is — what a tool
/// call's `target_user_id` and `target_client_id` are matched against.
///
/// The host supplies both: [userId] from its chat client's signed-in user, and
/// [clientId] from an id it keeps per install (generated once and persisted).
/// This package stores neither.
///
/// ```dart
/// final identity = AIClientIdentity(userId: currentUser.id, clientId: installId);
/// final approver = AIToolApprover.forIdentity(identity, decide: sendDecision);
/// ```
///
/// See [AIToolApprover] and [AIToolCallPart.isAwaitingApproval].
@immutable
class AIClientIdentity {
  /// Creates an [AIClientIdentity].
  const AIClientIdentity({required this.userId, this.clientId});

  /// The person signed in, matched against a call's `target_user_id`.
  final String userId;

  /// This install, matched against a call's `target_client_id`. `null` when
  /// the host keeps no install id; calls that name an install then never match.
  final String? clientId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIClientIdentity && other.userId == userId && other.clientId == clientId;

  @override
  int get hashCode => Object.hash(userId, clientId);

  @override
  String toString() => 'AIClientIdentity(userId: $userId, clientId: $clientId)';
}
