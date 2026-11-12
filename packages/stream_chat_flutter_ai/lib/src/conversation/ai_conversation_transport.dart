import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_request.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';

/// How an [AIConversation] reaches the agent and learns what it holds.
///
/// It sends what the person asks, stops the agent, and tells the conversation
/// its messages as they change.
///
/// With Stream Chat, the conversation is a channel: the transport follows its
/// messages and AI indicator events, and sends each request through the
/// channel or the agent's own API.
///
/// ```dart
/// class AgentTransport with AIConversationTransport<AgentMessage> {
///   AgentTransport(this.channel);
///
///   final AgentChannel channel;
///   final _subscriptions = <StreamSubscription<Object?>>[];
///
///   @override
///   void connect(AIConversationFeed<AgentMessage> feed) {
///     _subscriptions
///       ..add(channel.messages.listen(feed.updateMessages))
///       ..add(channel.agentStates.listen(feed.updateActivity));
///   }
///
///   @override
///   void disconnect() {
///     for (final subscription in _subscriptions) {
///       subscription.cancel();
///     }
///   }
///
///   @override
///   Future<void> send(AIConversationRequest<AgentMessage> request) {
///     return channel.sendMessage(
///       request.text,
///       id: request.messageId,
///       files: request.attachments,
///     );
///   }
///
///   @override
///   Future<void> stop() => channel.stopGenerating();
/// }
/// ```
abstract mixin class AIConversationTransport<M extends AIMessage> {
  /// Starts telling [feed] what the conversation holds: its messages each time
  /// they change, whether there are older ones to load, and what the agent
  /// says it is doing.
  ///
  /// The conversation calls it once, as it is created.
  void connect(AIConversationFeed<M> feed);

  /// Stops telling the conversation what it holds, such as by cancelling the
  /// subscriptions [connect] started.
  ///
  /// The conversation calls it once, as it is disposed. Does nothing by
  /// default.
  void disconnect() {}

  /// Sends what the person asks.
  ///
  /// Complete once the agent has the request: its reply arrives through the
  /// feed. An error shows as the conversation's [AIConversation.error], unless
  /// it is an [AIConversationCancelledException], and the person can retry,
  /// which sends the same request again with the same
  /// [AIConversationRequest.messageId]. If the first attempt reached the
  /// backend, or the transport keeps a copy of the failed message, use the id
  /// so the message isn't added twice.
  ///
  /// The conversation leaves out the messages a
  /// [AIConversationRequestKind.regenerate] or an
  /// [AIConversationRequestKind.edit] replaces only until the new reply
  /// starts. From then on it shows the messages as the feed has them, so
  /// update the conversation before the new reply arrives:
  ///
  /// * For a regenerate, remove the request's message and the messages after
  ///   it, or write the new reply in place of the message, under its id.
  /// * For an edit, change the person's message to say the request's text,
  ///   under its id, and remove the messages after it.
  Future<void> send(AIConversationRequest<M> request);

  /// Stops the reply the agent is writing. What it wrote so far stays.
  ///
  /// An error is reported, and the conversation goes back to waiting for the
  /// reply, so the person can stop it again.
  Future<void> stop();

  /// Loads the messages before the first one, which arrive through the feed.
  ///
  /// Does nothing by default.
  Future<void> loadOlderMessages() async {}

  /// Tells the backend how the person rated [reply], or that they took their
  /// rating back with a `null` [rating].
  ///
  /// Does nothing by default: the conversation keeps the ratings on this
  /// device. Ratings the backend has show through each message's
  /// [AIMessage.rating].
  Future<void> rate(M reply, AIMessageRating? rating) async {}
}

/// Thrown by an [AIConversationTransport] that gave up sending a request or
/// stopping the agent on purpose, such as one it cancelled.
///
/// A request that fails with it shows no error, and is forgotten rather than
/// offered to retry. A stop that fails with it is not reported.
class AIConversationCancelledException implements Exception {
  /// Creates an [AIConversationCancelledException].
  const AIConversationCancelledException();

  @override
  String toString() => objectRuntimeType(this, 'AIConversationCancelledException');
}
