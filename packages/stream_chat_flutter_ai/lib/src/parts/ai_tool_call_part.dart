import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
// Here for the [AIMessagePart] doc link only.
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// Where a tool call is — the `status` of an `ai_tool_call` step.
///
/// Calls move `running` → optionally [awaitingApproval] → optionally
/// [awaitingClient] → [completed] / [failed] / [cancelled].
///
/// An open set: compare against the statuses you know and treat the rest as
/// still in progress. A status this package doesn't know keeps its raw [value]
/// and reports `false` from [isKnown].
@immutable
class AIToolCallStatus {
  /// Wraps a raw status string.
  const AIToolCallStatus(this.value);

  /// The call is running.
  static const running = AIToolCallStatus('running');

  /// Waiting for the targeted person to allow or decline the call. Its
  /// [AIToolCallPart.approval] says what to ask them.
  static const awaitingApproval = AIToolCallStatus('awaiting_approval');

  /// Waiting for the targeted device to run the tool and send its result.
  static const awaitingClient = AIToolCallStatus('awaiting_client');

  /// The call finished and produced a result.
  static const completed = AIToolCallStatus('completed');

  /// The call ran and failed.
  static const failed = AIToolCallStatus('failed');

  /// The call was stopped before it finished, or declined before it ran.
  static const cancelled = AIToolCallStatus('cancelled');

  /// The statuses this package knows.
  static const values = [running, awaitingApproval, awaitingClient, completed, failed, cancelled];

  /// The status as the agent wrote it, such as `awaiting_approval`.
  final String value;

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  /// Whether the call has finished, one way or another: [completed], [failed]
  /// or [cancelled]. An unknown status counts as still in progress.
  bool get isFinished => this == completed || this == failed || this == cancelled;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIToolCallStatus && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIToolCallStatus($value)';
}

/// Who runs a tool — the `executor` of an `ai_tool_call` step.
///
/// An open set: compare against the executors you know ([server], [client]).
/// An executor this package doesn't know keeps its raw [value] and reports
/// `false` from [isKnown].
@immutable
class AIToolExecutor {
  /// Wraps a raw executor string.
  const AIToolExecutor(this.value);

  /// The agent's backend.
  static const server = AIToolExecutor('server');

  /// A person's device.
  static const client = AIToolExecutor('client');

  /// The executors this package knows.
  static const values = [server, client];

  /// The executor as the agent wrote it, such as `client`.
  final String value;

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIToolExecutor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIToolExecutor($value)';
}

/// A tool the agent called, run by the agent's backend or by a person's
/// device — the typed view of an `ai_tool_call` step.
///
/// The agent writes:
///
/// ```json
/// {"id": "call_1", "v": 1, "name": "get_weather", "display_title": "Checking the weather",
///  "status": "completed", "executor": "server", "summary": "Sunny, 21°C", "duration_ms": 800}
/// ```
///
/// A call that waits adds `target_user_id` (and `target_client_id` for a client
/// tool), `arguments` (client tools only) and, when it asks first, `approval`.
@immutable
class AIToolCallPart {
  /// Creates an [AIToolCallPart].
  const AIToolCallPart({
    required this.id,
    required this.name,
    this.displayTitle,
    this.status = AIToolCallStatus.running,
    this.executor = AIToolExecutor.server,
    this.targetUserId,
    this.targetClientId,
    this.arguments,
    this.summary,
    this.durationMs,
    this.approval,
  });

  /// Reads an `ai_tool_call` payload leniently: a missing or wrong-typed field
  /// gets its default, and nothing throws.
  ///
  /// [id] is the step's identity, which [AIMessagePart] resolves (falling back
  /// to the attachment's position when the payload carries none).
  factory AIToolCallPart.fromJson(Map<String, Object?> json, {required String id}) {
    return AIToolCallPart(
      id: id,
      name: json.stringField('name') ?? '',
      displayTitle: json.stringField('display_title'),
      status: switch (json.stringField('status')) {
        final status? => AIToolCallStatus(status),
        null => AIToolCallStatus.running,
      },
      executor: switch (json.stringField('executor')) {
        final executor? => AIToolExecutor(executor),
        null => AIToolExecutor.server,
      },
      targetUserId: json.stringField('target_user_id'),
      targetClientId: json.stringField('target_client_id'),
      arguments: json.objectField('arguments'),
      summary: json.stringField('summary'),
      durationMs: json.intField('duration_ms'),
      approval: switch (asJsonObject(json['approval'])) {
        final approval? => AIToolApproval.fromJson(approval),
        null => null,
      },
    );
  }

  /// The model provider's tool-call ID. A device's result is matched against
  /// it.
  final String id;

  /// The tool's name, such as `get_weather`. Empty when the agent sent none.
  final String name;

  /// What the call is doing, in words for people, such as "Checking the
  /// weather".
  final String? displayTitle;

  /// Where the call is. Defaults to [AIToolCallStatus.running] when the agent
  /// sends none.
  final AIToolCallStatus status;

  /// Who runs the tool. Defaults to [AIToolExecutor.server] when the agent
  /// sends none.
  final AIToolExecutor executor;

  /// The person the call waits for: whose device must run a client tool, or
  /// who must answer its [approval].
  final String? targetUserId;

  /// The install that must run a client tool (or answer its [approval]), from
  /// the custom data of the person's triggering message.
  final String? targetClientId;

  /// The call's arguments, present for client tools, which need them to run.
  /// Every channel member can see them, and they are model output: validate
  /// before acting on them.
  ///
  /// A backend that sends them JSON-encoded as a string is decoded too.
  final Map<String, Object?>? arguments;

  /// A short, shareable outcome, such as "Found your location".
  final String? summary;

  /// How long the call took, in milliseconds.
  final int? durationMs;

  /// What the call asks the person it waits for before it runs, and how they
  /// answered, when its tool asks first.
  final AIToolApproval? approval;

  /// [durationMs] as a [Duration].
  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);

  /// [displayTitle], or [name] with its underscores turned into spaces
  /// (`get_weather` → `get weather`) when the agent sent no title.
  String get displayName => displayTitle ?? name.replaceAll('_', ' ');

  /// Whether the person declined the call, so it never ran.
  bool get isDeclined => approval?.isDeclined ?? false;

  /// Whether this call is waiting for this device: a client tool, still
  /// awaiting its result, targeted at [userId] and [clientId].
  bool isAwaiting({required String userId, required String clientId}) =>
      executor == AIToolExecutor.client &&
      status == AIToolCallStatus.awaitingClient &&
      targetUserId == userId &&
      targetClientId == clientId;

  /// Whether this call is waiting for [userId] to allow it, on this device:
  /// still awaiting approval, with a question to ask, targeted at [userId], and
  /// at [clientId] when it names an install (a client tool does; a server
  /// tool's question may be answered from any of the person's devices).
  bool isAwaitingApproval({required String userId, String? clientId}) =>
      status == AIToolCallStatus.awaitingApproval &&
      approval != null &&
      targetUserId == userId &&
      (targetClientId == null || targetClientId == clientId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIToolCallPart &&
          other.id == id &&
          other.name == name &&
          other.displayTitle == displayTitle &&
          other.status == status &&
          other.executor == executor &&
          other.targetUserId == targetUserId &&
          other.targetClientId == targetClientId &&
          const DeepCollectionEquality().equals(other.arguments, arguments) &&
          other.summary == summary &&
          other.durationMs == durationMs &&
          other.approval == approval;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    displayTitle,
    status,
    executor,
    targetUserId,
    targetClientId,
    const DeepCollectionEquality().hash(arguments),
    summary,
    durationMs,
    approval,
  );

  @override
  String toString() => 'AIToolCallPart(id: $id, name: $name, status: ${status.value}, executor: ${executor.value})';
}
