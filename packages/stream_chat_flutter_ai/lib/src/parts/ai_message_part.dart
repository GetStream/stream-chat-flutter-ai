import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// One attachment of a message, as [AIMessagePart.parseAll] reads it: its
/// `type` and its custom fields.
///
/// With `stream_chat`:
///
/// ```dart
/// final parts = AIMessagePart.parseAll([
///   for (final attachment in message.attachments)
///     if (attachment.rawType case final type?)
///       (type: type, payload: {'id': attachment.id, ...attachment.extraData}),
/// ]);
/// ```
///
/// `rawType` is the type as the agent wrote it; `type` can be rewritten (an
/// attachment with a scrape URL reads as a link preview). The step's `id` lands
/// in a different place depending on where the message came from: a message
/// from the network keeps it in `extraData`, which the spread puts last so it
/// wins, while one read back from the offline database has it promoted to
/// `Attachment.id`. A step that never had an id gets the attachment's local
/// id that way — stable for that attachment, but not across message updates.
typedef AIMessagePartAttachment = ({String type, Map<String, Object?> payload});

/// What kind of step an [AIMessagePart] is: the attachment `type`, such as
/// `ai_reasoning`.
///
/// An open set: compare against the kinds you know ([reasoning], [toolCall])
/// and give the rest a fallback. A kind this package doesn't know — a newer
/// agent's, or one of your own — keeps its raw [value] and reports `false` from
/// [isKnown].
@immutable
class AIMessagePartKind {
  /// Wraps a raw attachment type.
  const AIMessagePartKind(this.value);

  /// A round of the model's reasoning (`ai_reasoning`).
  static const reasoning = AIMessagePartKind('ai_reasoning');

  /// A tool the agent called (`ai_tool_call`).
  static const toolCall = AIMessagePartKind('ai_tool_call');

  /// The kinds this package knows.
  static const values = [reasoning, toolCall];

  /// The attachment type, such as `ai_reasoning`.
  final String value;

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIMessagePartKind && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIMessagePartKind($value)';
}

/// One step an AI agent took while replying, such as a round of reasoning or a
/// tool call.
///
/// The agent writes each step as a custom attachment on its reply
/// (`ai_reasoning`, `ai_tool_call`, …), and the order of the attachments is the
/// order of the steps. The final answer stays in the message text and is shown
/// after them. Turn a message's attachments into parts with [parseAll], and show
/// them with `AIMessagePartsView`.
///
/// The kinds of step are open: a new one can appear without breaking your
/// code. Read the ones you know through their typed views ([reasoning],
/// [toolCall]), read kinds of your own with [decode], and give anything else a
/// neutral fallback. Decoding is lenient — missing or wrong-typed fields get
/// defaults, and nothing throws — and a step in a format newer than
/// [supportedVersion] keeps its [payload] but has no typed view.
///
/// ```dart
/// for (final part in parts) {
///   if (part.reasoning case final reasoning?) {
///     // …
///   } else if (part.toolCall case final call?) {
///     // …
///   } else if (part.kind == const AIMessagePartKind('ai_citation')) {
///     final citation = part.decode(Citation.fromJson);
///   }
/// }
/// ```
///
/// Parts compare by value, so a list of them can be diffed as a reply streams
/// in.
@immutable
class AIMessagePart {
  /// Creates a part from its fields, decoding [reasoning] or [toolCall] from
  /// [payload] when [kind] and [version] are ones this package reads.
  ///
  /// [payload] is copied, deeply unmodifiable, so changing the map you pass
  /// afterwards doesn't change the part.
  factory AIMessagePart({
    required String id,
    required AIMessagePartKind kind,
    int version = supportedVersion,
    Map<String, Object?> payload = const {},
  }) {
    final copy = deepUnmodifiable(payload)! as Map<String, Object?>;
    final readable = version >= 1 && version <= supportedVersion;
    return AIMessagePart._(
      id: id,
      kind: kind,
      version: version,
      payload: copy,
      reasoning: readable && kind == AIMessagePartKind.reasoning ? AIReasoningPart.fromJson(copy, id: id) : null,
      toolCall: readable && kind == AIMessagePartKind.toolCall ? AIToolCallPart.fromJson(copy, id: id) : null,
    );
  }

  /// A reasoning part from its typed view, such as one updated optimistically
  /// with [AIReasoningPart.copyWith].
  factory AIMessagePart.fromReasoning(AIReasoningPart reasoning) =>
      AIMessagePart(id: reasoning.id, kind: AIMessagePartKind.reasoning, payload: reasoning.toJson());

  /// A tool-call part from its typed view, such as one updated optimistically
  /// with [AIToolCallPart.copyWith].
  factory AIMessagePart.fromToolCall(AIToolCallPart toolCall) =>
      AIMessagePart(id: toolCall.id, kind: AIMessagePartKind.toolCall, payload: toolCall.toJson());

  const AIMessagePart._({
    required this.id,
    required this.kind,
    required this.version,
    required this.payload,
    required this.reasoning,
    required this.toolCall,
  });

  /// The attachment type prefix every AI step uses.
  static const typePrefix = 'ai_';

  /// The newest format version (`v`) of the built-in kinds this package reads.
  static const supportedVersion = 1;

  /// Decodes one attachment, or returns `null` when it is not an AI step (its
  /// [type] doesn't start with [typePrefix]).
  ///
  /// [position] is the step's index among the message's AI steps, used as the
  /// identity of a step whose payload carries no `id`.
  static AIMessagePart? tryParse(String type, Map<String, Object?> payload, {int position = 0}) {
    if (!type.startsWith(typePrefix)) return null;
    final payloadId = PartFields(payload, type).string('id');
    final id = payloadId ?? '$type-$position';
    if (payloadId == null && type == AIMessagePartKind.toolCall.value) {
      reportPartIssue(() => '$type at step $position has no `id`, so it can never be answered or run.');
    }
    return AIMessagePart(
      id: id,
      kind: AIMessagePartKind(type),
      version: _readVersion(payload, '$type "$id"'),
      payload: payload,
    );
  }

  /// Reads a part back from [toJson]'s output: the payload with its `type`
  /// alongside. Returns `null` when it is not an AI step.
  static AIMessagePart? fromJson(Map<String, Object?> json, {int position = 0}) {
    final type = json['type'];
    if (type is! String) return null;
    return tryParse(type, {...json}..remove('type'), position: position);
  }

  /// `v` as an int: [supportedVersion] when missing, and `0` — which no
  /// typed view reads — when present but not a positive whole number.
  static int _readVersion(Map<String, Object?> payload, String context) {
    final value = payload['v'];
    if (value == null) return supportedVersion;
    final version = switch (value) {
      final int value => value,
      final double value when value.isFinite && value == value.roundToDouble() => value.toInt(),
      _ => 0,
    };
    if (version >= 1) return version;
    reportPartIssue(
      () => '$context: `v` must be a positive integer, got ${value.runtimeType} ($value); no typed view.',
    );
    return 0;
  }

  /// Decodes the AI steps among a message's [attachments], in order.
  /// Attachments that are not AI steps (images, files, link previews) are
  /// skipped, and nothing throws.
  ///
  /// A step with no `id` is named after its type and its index among the AI
  /// steps, so other attachments coming and going don't change it. Duplicate
  /// ids are kept as they are; `AIMessagePartsView` keys the repeats by how
  /// many came before them.
  static List<AIMessagePart> parseAll(Iterable<AIMessagePartAttachment> attachments) {
    final parts = <AIMessagePart>[];
    for (final attachment in attachments) {
      if (tryParse(attachment.type, attachment.payload, position: parts.length) case final part?) parts.add(part);
    }
    assert(() {
      final seen = <String>{};
      for (final part in parts) {
        if (!seen.add(part.id)) reportPartIssue(() => 'more than one step has the id "${part.id}".');
      }
      return true;
    }(), 'unreachable');
    return parts;
  }

  /// The step's stable identity, for diffing and animating while it streams.
  /// Usually the agent's own id — for tool calls, the model provider's
  /// tool-call ID. A step with no `id` gets `<type>-<position>`, and
  /// [hasPayloadId] is `false`.
  final String id;

  /// What kind of step this is.
  final AIMessagePartKind kind;

  /// The step's format version (`v`). It changes only when a kind changes
  /// incompatibly. A missing `v` reads as [supportedVersion]; one that isn't a
  /// positive whole number reads as `0`, and gets no typed view.
  final int version;

  /// The step's attachment payload, deeply unmodifiable, for kinds of your own
  /// or fields this package doesn't read.
  final Map<String, Object?> payload;

  /// The step as a round of reasoning, when it is one this package can read.
  final AIReasoningPart? reasoning;

  /// The step as a tool call, when it is one this package can read.
  final AIToolCallPart? toolCall;

  /// Whether this package has a typed view of the step. One that doesn't —
  /// from a newer agent, or of a kind of your own — still keeps its [payload].
  bool get isSupported => reasoning != null || toolCall != null;

  /// Whether [payload] carries an `id`, so [id] is the agent's rather than a
  /// fallback made up from the step's position.
  bool get hasPayloadId => switch (payload['id']) {
    final String id => id.isNotEmpty,
    _ => false,
  };

  /// Decodes [payload] with [fromJson], for kinds of your own.
  ///
  /// When [fromJson] throws, the error is reported through
  /// [FlutterError.reportError] — it is a bug in the decoder or a malformed
  /// step, and should be seen — and `null` is returned, so the step can fall
  /// back to a placeholder.
  T? decode<T>(T Function(Map<String, Object?> json) fromJson) {
    try {
      return fromJson(payload);
      // A decoder may fail with a TypeError on a field of the wrong type as
      // readily as with an exception, and both are reported the same way.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while decoding the ${kind.value} message part "$id"'),
        ),
      );
      return null;
    }
  }

  /// The part as an attachment's JSON: its [payload] with the `type`
  /// alongside, which [fromJson] reads back to an equal part.
  Map<String, Object?> toJson() => {...payload, 'type': kind.value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIMessagePart &&
          other.id == id &&
          other.kind == kind &&
          other.version == version &&
          const DeepCollectionEquality().equals(other.payload, payload);

  @override
  int get hashCode => Object.hash(id, kind, version, const DeepCollectionEquality().hash(payload));

  @override
  String toString() => 'AIMessagePart(id: $id, kind: ${kind.value}, version: $version)';
}
