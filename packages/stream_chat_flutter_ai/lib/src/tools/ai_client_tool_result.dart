import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// What this device reports to the agent for a client tool call: an
/// [AIClientToolCompleted] or an [AIClientToolFailed].
///
/// Post its [toJson] to your backend, which feeds it to the model.
@immutable
sealed class AIClientToolResult {
  const AIClientToolResult();

  /// A call that ran, with [output] as its result for the model. See
  /// [AIClientToolCompleted].
  factory AIClientToolResult.completed(Object? output, {String? summary}) = AIClientToolCompleted;

  /// A call this device could not run. See [AIClientToolFailed].
  const factory AIClientToolResult.failed(String reason) = AIClientToolFailed;

  /// The result in the backend contract's shape:
  /// `{tool_call_id, client_id, output | failure, summary}`.
  ///
  /// [toolCallId] and [clientId] are left out when not given.
  Map<String, Object?> toJson({String? toolCallId, String? clientId});
}

/// A call that ran, with its [output] for the model.
final class AIClientToolCompleted extends AIClientToolResult {
  /// Creates an [AIClientToolCompleted].
  ///
  /// Throws a [JsonUnsupportedObjectError] when [output] isn't
  /// JSON-encodable. [output] is stored as a deeply unmodifiable copy.
  AIClientToolCompleted(Object? output, {this.summary}) : output = _encodableCopy(output);

  /// The result for the model; may be `null`.
  final Object? output;

  /// A short outcome shown on the step to **every** channel member, such as
  /// "Shared approximate location". Keep the data itself out of it.
  final String? summary;

  static Object? _encodableCopy(Object? output) {
    jsonEncode(output);
    return deepUnmodifiable(output);
  }

  /// Always has an `output` key, `null` included, so it can't be read as a
  /// failure.
  @override
  Map<String, Object?> toJson({String? toolCallId, String? clientId}) => {
    'tool_call_id': ?toolCallId,
    'client_id': ?clientId,
    'output': output,
    'summary': ?summary,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIClientToolCompleted &&
          other.summary == summary &&
          const DeepCollectionEquality().equals(other.output, output);

  @override
  int get hashCode => Object.hash(summary, const DeepCollectionEquality().hash(output));

  /// Leaves [output] out: it is whatever the tool read, which doesn't belong
  /// in a log line.
  @override
  String toString() => 'AIClientToolCompleted(summary: $summary, hasOutput: ${output != null})';
}

/// A call this device could not run, and [reason] why.
final class AIClientToolFailed extends AIClientToolResult {
  /// Creates an [AIClientToolFailed].
  const AIClientToolFailed(this.reason);

  /// Why the call couldn't run, such as "Location not shared". Shown on the
  /// step and told to the model, so keep private details out of it.
  final String reason;

  @override
  Map<String, Object?> toJson({String? toolCallId, String? clientId}) => {
    'tool_call_id': ?toolCallId,
    'client_id': ?clientId,
    'failure': reason,
  };

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIClientToolFailed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'AIClientToolFailed($reason)';
}
