import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';

/// What an AI agent says it is doing in an [AIAgentActivity].
///
/// An open set: compare against the states this package knows ([values]). A
/// state it doesn't know keeps its raw value and reports `false` from
/// [isKnown]. The raw values are those of Stream Chat's AI indicator.
extension type const AIAgentActivityState(String _) implements String {
  /// Thinking about its answer.
  static const thinking = AIAgentActivityState('AI_STATE_THINKING');

  /// Looking something up, such as on the web or with a tool.
  static const checkingExternalSources = AIAgentActivityState('AI_STATE_EXTERNAL_SOURCES');

  /// Writing its answer.
  static const generating = AIAgentActivityState('AI_STATE_GENERATING');

  /// It couldn't answer.
  static const error = AIAgentActivityState('AI_STATE_ERROR');

  /// The states this package knows.
  static const values = [thinking, checkingExternalSources, generating, error];

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);
}

/// What the agent says it is doing while it answers, besides what its reply
/// shows, such as thinking or checking external sources.
///
/// A transport tells an [AIConversation] through its feed, such as from
/// Stream Chat's AI indicator events:
///
/// ```dart
/// feed.updateActivity(
///   AIAgentActivity(
///     state: AIAgentActivityState(event.state),
///     text: event.message,
///   ),
/// );
/// ```
@immutable
class AIAgentActivity {
  /// Creates an [AIAgentActivity].
  const AIAgentActivity({required this.state, this.text});

  /// What the agent is doing.
  final AIAgentActivityState state;

  /// What it says about it, such as "Searching the web", or why it couldn't
  /// answer.
  final String? text;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AIAgentActivity && other.state == state && other.text == text;
  }

  @override
  int get hashCode => Object.hash(state, text);

  @override
  String toString() => '${objectRuntimeType(this, 'AIAgentActivity')}(state: $state, text: $text)';
}
