/// What an `AIConversation` offers the person to do with each message.
///
/// Internal. None of it is exported.
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_actions.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';

/// What the views of an [AIConversation] offer for its messages.
@internal
extension AIConversationOffers<M extends AIMessage> on AIConversation<M> {
  /// What the person can do with a finished [reply]: rate it, and write it
  /// again while it is the latest and the agent isn't answering.
  AIReplyActions replyActions(M reply, {required bool isLatestReply}) {
    return AIReplyActions(
      rating: ratings[reply.id],
      onRegenerate: offersRegenerate(isLatestReply: isLatestReply) ? () => regenerate(reply) : null,
      onRate: actions.contains(AIConversationActions.rate) ? (rating) => rate(reply, rating) : null,
    );
  }

  /// Whether a reply offers to be written again: regenerating is in
  /// [AIConversation.actions], it is the latest reply, and the agent isn't
  /// answering.
  bool offersRegenerate({required bool isLatestReply}) {
    if (!actions.contains(AIConversationActions.regenerate)) return false;
    if (!isLatestReply) return false;
    return !status.isAnswering;
  }

  /// Edits [message], when [offersEdit] says so.
  VoidCallback? editAction(M message) {
    if (!offersEdit(message)) return null;
    return () => edit(message);
  }

  /// Whether [message] offers to be edited: editing is in
  /// [AIConversation.actions], it is the person's latest message, and the agent
  /// isn't answering.
  bool offersEdit(M message) {
    if (!actions.contains(AIConversationActions.edit)) return false;
    if (message.role != AIMessageRole.user || status.isAnswering) return false;
    return messages.lastWhereOrNull((m) => m.role == AIMessageRole.user)?.id == message.id;
  }
}
