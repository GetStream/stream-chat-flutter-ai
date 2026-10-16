import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// One attachment of a message, as [AIMessagePart.parseAll] reads it: its
/// `type` and its custom fields.
///
/// With `stream_chat`, that is an `Attachment`'s `type` and `extraData`:
///
/// ```dart
/// final parts = AIMessagePart.parseAll([
///   for (final attachment in message.attachments)
///     if (attachment.rawType case final type?) (type: type, payload: attachment.extraData),
/// ]);
/// ```
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
  factory AIMessagePart({
    required String id,
    required AIMessagePartKind kind,
    int version = supportedVersion,
    Map<String, Object?> payload = const {},
  }) {
    final readable = version <= supportedVersion;
    return AIMessagePart._(
      id: id,
      kind: kind,
      version: version,
      payload: Map.unmodifiable(payload),
      reasoning: readable && kind == AIMessagePartKind.reasoning ? AIReasoningPart.fromJson(payload, id: id) : null,
      toolCall: readable && kind == AIMessagePartKind.toolCall ? AIToolCallPart.fromJson(payload, id: id) : null,
    );
  }

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
  /// [position] is the attachment's index among the message's attachments,
  /// used as the identity of a step whose payload carries no `id`.
  static AIMessagePart? tryParse(String type, Map<String, Object?> payload, {int position = 0}) {
    if (!type.startsWith(typePrefix)) return null;
    return AIMessagePart(
      id: payload.stringField('id') ?? '$type-$position',
      kind: AIMessagePartKind(type),
      version: payload.intField('v') ?? supportedVersion,
      payload: payload,
    );
  }

  /// Decodes the AI steps among a message's [attachments], in order.
  /// Attachments that are not AI steps (images, files, link previews) are
  /// skipped, and nothing throws.
  ///
  /// Duplicate ids are kept as they are; `AIMessagePartsView` tells them apart
  /// by position.
  static List<AIMessagePart> parseAll(Iterable<AIMessagePartAttachment> attachments) => [
    for (final (index, attachment) in attachments.indexed)
      if (tryParse(attachment.type, attachment.payload, position: index) case final part?) part,
  ];

  /// The step's stable identity, for diffing and animating while it streams.
  /// Tool calls use the model provider's tool-call ID; a step with no `id`
  /// gets `<type>-<position>`.
  final String id;

  /// What kind of step this is.
  final AIMessagePartKind kind;

  /// The step's format version (`v`). It changes only when a kind changes
  /// incompatibly; a missing `v` reads as [supportedVersion].
  final int version;

  /// The step's attachment payload, unmodifiable, for kinds of your own or
  /// fields this package doesn't read.
  final Map<String, Object?> payload;

  /// The step as a round of reasoning, when it is one this package can read.
  final AIReasoningPart? reasoning;

  /// The step as a tool call, when it is one this package can read.
  final AIToolCallPart? toolCall;

  /// Whether this package has a typed view of the step. One that doesn't —
  /// from a newer agent, or of a kind of your own — still keeps its [payload].
  bool get isSupported => reasoning != null || toolCall != null;

  /// Decodes [payload] with [fromJson], for kinds of your own.
  ///
  /// Returns `null` instead of throwing when [fromJson] throws, so a malformed
  /// step can fall back to a placeholder.
  T? decode<T>(T Function(Map<String, Object?> json) fromJson) {
    try {
      return fromJson(payload);
      // A user-supplied decoder may fail with a TypeError on a field of the
      // wrong type, which is exactly the lenience this method promises.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

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
