import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
// Here for the doc links below only.
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_runner.dart';

/// What this device reports to the agent for a client tool call it ran: the
/// result for the model, or why it couldn't run the call.
///
/// Build one with [AIClientToolResult.completed] or [AIClientToolResult.failed]
/// and post its [toJson] to your backend, which feeds it to the model. An
/// [AIClientToolRunner] does the posting through its `send` callback.
///
/// A value type: two results with the same fields are `==`, [output] compared
/// deeply.
@immutable
final class AIClientToolResult {
  const AIClientToolResult._({this.output, this.summary, this.failure});

  /// A call that ran, with [output] as its result for the model.
  ///
  /// [output] must be JSON-encodable — `null`, a [num], [bool], [String], or a
  /// [List] / [Map] of those (or an object with a `toJson`). One that isn't
  /// becomes a [AIClientToolResult.failed] result instead, and the encoding error is reported to
  /// [FlutterError.onError], since it is a bug in the tool.
  ///
  /// [summary] is a short outcome shown on the step to **every** channel
  /// member, such as "Shared approximate location". Keep the data itself out of
  /// it.
  factory AIClientToolResult.completed(Object? output, {String? summary}) {
    try {
      jsonEncode(output);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while encoding a client tool result as JSON'),
        ),
      );
      return const AIClientToolResult.failed(unencodableOutputFailure);
    }
    return AIClientToolResult._(output: output, summary: summary);
  }

  /// A call this device could not run, and [reason] why, such as "Location not
  /// shared". Shown on the step and told to the model.
  const AIClientToolResult.failed(String reason) : this._(failure: reason);

  /// The [failure] of a [AIClientToolResult.completed] result whose output
  /// could not be encoded as JSON.
  static const unencodableOutputFailure = "The result couldn't be encoded as JSON";

  /// The result for the model. `null` both for a call that completed without
  /// one and for a [AIClientToolResult.failed] result — tell them apart with [isFailure].
  final Object? output;

  /// A short outcome shown on the step to every channel member, or `null`.
  /// Only a [AIClientToolResult.completed] result carries one.
  final String? summary;

  /// Why the call couldn't run, or `null` when it completed.
  final String? failure;

  /// Whether this is a [AIClientToolResult.failed] result.
  bool get isFailure => failure != null;

  /// The result as the backend contract's device-tool result:
  /// `{tool_call_id, client_id, output | failure, summary}`.
  ///
  /// [toolCallId] (the call's `id`) and [clientId] (this install, the call's
  /// `target_client_id`) are left out when not given, for a backend that reads
  /// them from elsewhere — the URL, say. A completed result always has an
  /// `output` key, `null` included, so it can't be mistaken for a failure; a
  /// failed one has `failure` instead. A `null` [summary] is left out.
  Map<String, Object?> toJson({String? toolCallId, String? clientId}) => {
    'tool_call_id': ?toolCallId,
    'client_id': ?clientId,
    if (failure case final failure?) 'failure': failure else 'output': output,
    'summary': ?summary,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIClientToolResult &&
          other.failure == failure &&
          other.summary == summary &&
          const DeepCollectionEquality().equals(other.output, output);

  @override
  int get hashCode => Object.hash(failure, summary, const DeepCollectionEquality().hash(output));

  /// Leaves [output] out: it is whatever the tool read — a location, a contact
  /// — and doesn't belong in a log line.
  @override
  String toString() => isFailure
      ? 'AIClientToolResult.failed($failure)'
      : 'AIClientToolResult.completed(summary: $summary, hasOutput: ${output != null})';
}
