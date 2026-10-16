import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
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
  ///
  /// Pass [arguments] unmodifiable (all the way down) to keep the part
  /// immutable — [AIToolCallPart.fromJson] and [copyWith] make them so.
  /// [hasPayloadId] says whether [id] came from the agent; see there.
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
    this.hasPayloadId = true,
  }) : assert(durationMs == null || durationMs >= 0, 'durationMs must not be negative');

  /// Reads an `ai_tool_call` payload leniently: a missing or wrong-typed field
  /// gets its default, and nothing throws.
  ///
  /// [id] is the step's identity, which [AIMessagePart] resolves (falling back
  /// to the step's position when the payload carries none).
  factory AIToolCallPart.fromJson(Map<String, Object?> json, {required String id}) {
    final context = 'ai_tool_call "$id"';
    final fields = PartFields(json, context);
    final status = switch (fields.string('status')) {
      final status? => AIToolCallStatus(status),
      null => AIToolCallStatus.running,
    };
    final approval = switch (fields.object('approval')) {
      final approval? => AIToolApproval.fromJson(approval, context: context),
      null => null,
    };
    if (status == AIToolCallStatus.awaitingApproval && approval == null) {
      reportPartIssue(() => '$context is awaiting approval but has no `approval` to ask.');
    }
    return AIToolCallPart(
      id: id,
      name: fields.string('name') ?? '',
      displayTitle: fields.string('display_title'),
      status: status,
      executor: switch (fields.string('executor')) {
        final executor? => AIToolExecutor(executor),
        null => AIToolExecutor.server,
      },
      targetUserId: fields.string('target_user_id'),
      targetClientId: fields.string('target_client_id'),
      arguments: fields.object('arguments'),
      summary: fields.string('summary'),
      durationMs: fields.count('duration_ms'),
      approval: approval,
      hasPayloadId: fields.string('id') != null,
    );
  }

  /// The call's identity: usually the model provider's tool-call ID, which a
  /// device's result is matched against. When the agent sent none it is a
  /// fallback, and [hasPayloadId] is `false`.
  final String id;

  /// Whether [id] came from the agent's payload rather than being made up from
  /// the step's position. A call without one can't be answered or run, since
  /// nothing could be matched back to it.
  final bool hasPayloadId;

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

  /// A short, shareable outcome, such as "Found your location". May be blank
  /// when built by hand; [summaryText] reads a blank one as absent.
  final String? summary;

  /// How long the call took, in milliseconds.
  final int? durationMs;

  /// What the call asks the person it waits for before it runs, and how they
  /// answered, when its tool asks first.
  final AIToolApproval? approval;

  /// [durationMs] as a [Duration].
  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);

  /// [displayTitle], or [name] with its underscores turned into spaces
  /// (`get_weather` → `get weather`) when the agent sent no title or a blank
  /// one. Empty when the agent sent neither; a view then shows a generic
  /// fallback, such as `AITranslations.toolCallFallbackTitle`.
  String get displayName {
    final title = displayTitle;
    if (title != null && title.trim().isNotEmpty) return title;
    return name.replaceAll('_', ' ');
  }

  /// [summary], or `null` when it is absent or blank — what a view shows.
  String? get summaryText {
    final summary = this.summary;
    return summary == null || summary.trim().isEmpty ? null : summary;
  }

  /// Whether the person declined the call, so it never ran.
  ///
  /// Takes precedence over [status] when showing the call: a declined call
  /// reads as declined (and shows no duration) even while its status still
  /// says `awaiting_approval` or has moved to `cancelled`.
  bool get isDeclined => approval?.isDeclined ?? false;

  /// Whether this call is waiting for this device: a client tool with an id
  /// from the agent, still awaiting its result, targeted at [userId] and
  /// [clientId].
  bool isAwaiting({required String userId, required String clientId}) =>
      hasPayloadId &&
      executor == AIToolExecutor.client &&
      status == AIToolCallStatus.awaitingClient &&
      targetUserId == userId &&
      targetClientId == clientId;

  /// Whether this call is waiting for [userId] to allow it, on this device:
  /// still awaiting approval and not yet answered, with an id from the agent,
  /// targeted at [userId] — and at [clientId] when it names an install.
  ///
  /// A call that names no install can be answered from any of the person's
  /// devices. That is the normal case for a server tool, and, as on iOS, it
  /// also holds for a client tool whose backend left `target_client_id` out.
  ///
  /// It doesn't need an [approval]: a call awaiting approval without one still
  /// waits, and a view asks with its own translated wording.
  bool isAwaitingApproval({required String userId, String? clientId}) =>
      hasPayloadId &&
      status == AIToolCallStatus.awaitingApproval &&
      !(approval?.isAnswered ?? false) &&
      targetUserId == userId &&
      (targetClientId == null || targetClientId == clientId);

  /// A copy with the given fields replaced. A `null` argument keeps the
  /// current value. New [arguments] are copied, deeply unmodifiable.
  AIToolCallPart copyWith({
    String? id,
    String? name,
    String? displayTitle,
    AIToolCallStatus? status,
    AIToolExecutor? executor,
    String? targetUserId,
    String? targetClientId,
    Map<String, Object?>? arguments,
    String? summary,
    int? durationMs,
    AIToolApproval? approval,
    bool? hasPayloadId,
  }) {
    return AIToolCallPart(
      id: id ?? this.id,
      name: name ?? this.name,
      displayTitle: displayTitle ?? this.displayTitle,
      status: status ?? this.status,
      executor: executor ?? this.executor,
      targetUserId: targetUserId ?? this.targetUserId,
      targetClientId: targetClientId ?? this.targetClientId,
      arguments: arguments == null ? this.arguments : deepUnmodifiable(arguments)! as Map<String, Object?>,
      summary: summary ?? this.summary,
      durationMs: durationMs ?? this.durationMs,
      approval: approval ?? this.approval,
      hasPayloadId: hasPayloadId ?? this.hasPayloadId,
    );
  }

  /// The call as an `ai_tool_call` payload, which [AIToolCallPart.fromJson]
  /// reads back to an equal part. Absent fields are left out, and so is a
  /// fallback [id].
  Map<String, Object?> toJson() => {
    if (hasPayloadId) 'id': id,
    'v': AIMessagePart.supportedVersion,
    'name': name,
    'display_title': ?displayTitle,
    'status': status.value,
    'executor': executor.value,
    'target_user_id': ?targetUserId,
    'target_client_id': ?targetClientId,
    'arguments': ?arguments,
    'summary': ?summary,
    'duration_ms': ?durationMs,
    'approval': ?approval?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIToolCallPart &&
          other.id == id &&
          other.hasPayloadId == hasPayloadId &&
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
    hasPayloadId,
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
