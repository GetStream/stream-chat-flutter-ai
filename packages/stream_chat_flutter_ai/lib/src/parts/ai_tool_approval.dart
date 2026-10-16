import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// How a person answered a tool call's question — an [AIToolApproval]'s
/// `decision`.
///
/// An open set: compare against the decisions you know ([allowed],
/// [declined]). A decision this package doesn't know keeps its raw [value] and
/// reports `false` from [isKnown].
@immutable
class AIToolApprovalDecision {
  /// Wraps a raw decision string.
  const AIToolApprovalDecision(this.value);

  /// The person allowed the call, so it goes on.
  static const allowed = AIToolApprovalDecision('allowed');

  /// The person declined the call, so it is cancelled and never runs.
  static const declined = AIToolApprovalDecision('declined');

  /// The decisions this package knows.
  static const values = [allowed, declined];

  /// The decision as the backend wrote it, such as `allowed`.
  final String value;

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIToolApprovalDecision && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIToolApprovalDecision($value)';
}

/// What a tool call asks the person it waits for before it runs, such as
/// "Share your location?", and how they answered.
///
/// The agent's backend writes it as the `approval` of an `ai_tool_call` step
/// whose status is `awaiting_approval`, and holds the call until the person
/// answers. Allowed, the call goes on (a client tool then awaits the device);
/// declined, it is cancelled and never runs.
///
/// [allowTitle] and [declineTitle] are `null` when the backend sends none; a
/// view falls back to its own translated labels then.
@immutable
class AIToolApproval {
  /// Creates an [AIToolApproval].
  const AIToolApproval({
    required this.title,
    this.message,
    this.reason,
    this.allowTitle,
    this.declineTitle,
    this.decision,
  });

  /// Reads an `approval` object leniently, or returns `null` when it has no
  /// `title` — a question with no title asks nothing.
  static AIToolApproval? fromJson(Map<String, Object?> json) {
    final title = json.stringField('title');
    if (title == null) return null;
    return AIToolApproval(
      title: title,
      message: json.stringField('message'),
      reason: json.stringField('reason'),
      allowTitle: json.stringField('allow_title'),
      declineTitle: json.stringField('decline_title'),
      decision: switch (json.stringField('decision')) {
        final decision? => AIToolApprovalDecision(decision),
        null => null,
      },
    );
  }

  /// The question, such as "Share your location?".
  final String title;

  /// What allowing it shares or does, such as "Only your city is shared."
  final String? message;

  /// The agent's own words for why it wants the call, such as "to check the
  /// local weather".
  final String? reason;

  /// The label of the button that allows the call, when the backend names
  /// one.
  final String? allowTitle;

  /// The label of the button that declines the call, when the backend names
  /// one.
  final String? declineTitle;

  /// How the person answered, once they did.
  final AIToolApprovalDecision? decision;

  /// Whether the person allowed the call.
  bool get isAllowed => decision == AIToolApprovalDecision.allowed;

  /// Whether the person declined the call.
  bool get isDeclined => decision == AIToolApprovalDecision.declined;

  /// Whether the person has answered at all.
  bool get isAnswered => decision != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIToolApproval &&
          other.title == title &&
          other.message == message &&
          other.reason == reason &&
          other.allowTitle == allowTitle &&
          other.declineTitle == declineTitle &&
          other.decision == decision;

  @override
  int get hashCode => Object.hash(title, message, reason, allowTitle, declineTitle, decision);

  @override
  String toString() => 'AIToolApproval(title: $title, decision: ${decision?.value})';
}
