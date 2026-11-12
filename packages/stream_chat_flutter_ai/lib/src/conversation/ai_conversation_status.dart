// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';

/// Where an [AIConversation]'s latest exchange with the agent is.
///
/// An open set: compare against the statuses this package knows ([values]). A
/// status it doesn't know keeps its raw value and reports `false` from
/// [isKnown].
extension type const AIConversationStatus(String _) implements String {
  /// Nothing is on its way: the agent answered, or the person stopped it.
  static const ready = AIConversationStatus('ready');

  /// The person's request is on its way, or the agent is working on it and
  /// its reply shows nothing yet.
  static const submitted = AIConversationStatus('submitted');

  /// The agent is writing its reply.
  static const streaming = AIConversationStatus('streaming');

  /// The latest request failed, or the agent couldn't answer it.
  ///
  /// [AIConversation.retry] tries again.
  static const error = AIConversationStatus('error');

  /// The statuses this package knows.
  static const values = [ready, submitted, streaming, error];

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  /// Whether the agent is answering: the request is [submitted], or its reply
  /// [streaming].
  bool get isAnswering => this == submitted || this == streaming;
}
