import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// Where a round of reasoning is — the `status` of an `ai_reasoning` step.
///
/// An open set: compare against the statuses you know ([streaming],
/// [completed]) and give the rest a sensible fallback. A status this package
/// doesn't know keeps its raw value and reports `false` from [isKnown].
extension type const AIReasoningStatus(String _) implements String {
  /// The model is still thinking.
  static const streaming = AIReasoningStatus('streaming');

  /// The round is over.
  static const completed = AIReasoningStatus('completed');

  /// The statuses this package knows.
  static const values = [streaming, completed];

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);
}

/// A round of the model's reasoning — the typed view of an `ai_reasoning`
/// step.
///
/// The agent writes:
///
/// ```json
/// {"id": "r1", "v": 1, "status": "completed", "summary": "Compared both plans",
///  "preview": "The user wants…", "duration_ms": 2400}
/// ```
@immutable
class AIReasoningPart {
  /// Creates an [AIReasoningPart].
  const AIReasoningPart({
    required this.id,
    this.status = AIReasoningStatus.completed,
    this.summary,
    this.preview,
    this.durationMs,
  });

  /// Reads an `ai_reasoning` payload leniently: a missing or wrong-typed field
  /// gets its default, and nothing throws.
  ///
  /// [id] is the step's identity, which [AIMessagePart] resolves (falling back
  /// to the step's position when the payload carries none).
  factory AIReasoningPart.fromJson(Map<String, Object?> json, {required String id}) {
    final fields = PartFields(json, 'ai_reasoning "$id"');
    return AIReasoningPart(
      id: id,
      status: switch (fields.string('status')) {
        final status? => reportUnknown(AIReasoningStatus(status), (s) => s.isKnown, 'ai_reasoning "$id"', 'status'),
        null => AIReasoningStatus.completed,
      },
      summary: fields.string('summary'),
      preview: fields.string('preview'),
      durationMs: fields.count('duration_ms'),
    );
  }

  /// The step's stable identity.
  final String id;

  /// Where the round is. Defaults to [AIReasoningStatus.completed] when the
  /// agent sends none.
  final AIReasoningStatus status;

  /// A one-line summary of the reasoning, once it is done.
  final String? summary;

  /// A capped excerpt: the latest thoughts while streaming, the opening once
  /// done. It is not the full reasoning, which the agent doesn't put on the
  /// step.
  final String? preview;

  /// How long the round took, in milliseconds.
  final int? durationMs;

  /// [durationMs] as a [Duration].
  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);

  /// Whether the model is still thinking.
  bool get isStreaming => status == AIReasoningStatus.streaming;

  /// A copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  AIReasoningPart copyWith({
    String? id,
    AIReasoningStatus? status,
    String? summary,
    String? preview,
    int? durationMs,
  }) {
    return AIReasoningPart(
      id: id ?? this.id,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      preview: preview ?? this.preview,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  /// The step as an `ai_reasoning` payload, which [AIReasoningPart.fromJson]
  /// reads back to an equal part. Absent fields are left out.
  Map<String, Object?> toJson() => {
    'id': id,
    'v': AIMessagePart.supportedVersion,
    'status': status,
    'summary': ?summary,
    'preview': ?preview,
    'duration_ms': ?durationMs,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIReasoningPart &&
          other.id == id &&
          other.status == status &&
          other.summary == summary &&
          other.preview == preview &&
          other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(id, status, summary, preview, durationMs);

  @override
  String toString() => 'AIReasoningPart(id: $id, status: $status, summary: $summary, durationMs: $durationMs)';
}
