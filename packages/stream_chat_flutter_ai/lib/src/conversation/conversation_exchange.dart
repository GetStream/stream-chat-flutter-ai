/// The bookkeeping behind an `AIConversation`'s latest request.
///
/// Internal. None of it is exported.
library;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_request.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/pending_attachments.dart';

/// Whether [message] is a reply the agent has started with no text, steps or
/// attachments yet. Its generated UI can still show, when the conversation's
/// host reads it.
@internal
bool hasEmptyContent(AIMessage message) {
  if (message.role == AIMessageRole.user) return false;
  if (message.text.isNotEmpty) return false;
  if (message.parts.isNotEmpty) return false;
  return message.attachments.isEmpty;
}

/// Where a [ConversationExchange]'s request is.
@internal
enum ExchangeState {
  /// Waiting for its reply.
  waiting,

  /// Stopped by the person before its reply started.
  stopped,

  /// Not sent, because the transport failed.
  failed,

  /// Not answered by the agent.
  unanswered,
}

/// A request the person made, from when they make it until its reply starts
/// or another request takes its place.
@internal
class ConversationExchange<M extends AIMessage> {
  /// Creates a [ConversationExchange] for [request], made in [conversation].
  ///
  /// The person's files show as `attachmentOf` makes them.
  ConversationExchange({
    required this.id,
    required this.request,
    required List<M> conversation,
    this._attachmentOf = pendingAttachmentOf,
  }) : known = {for (final message in conversation) message.id},
       replaced = _replaced(request, conversation),
       _edited = request.kind == AIConversationRequestKind.edit ? request.message?.attachments ?? const [] : const [];

  /// The number that tells it apart from the requests before and after it.
  final int id;

  /// The request.
  final AIConversationRequest<M> request;

  /// The ids of the messages there were when it was made, none of which is
  /// its reply.
  final Set<String> known;

  /// The messages it replaces, as they were, by id, which the conversation
  /// leaves out while it waits: the reply written again, or the message
  /// edited, and those after it.
  final Map<String, M> replaced;

  // What the edited message carried, which its edit keeps.
  final List<AIMessageAttachment> _edited;
  final AIMessageAttachment Function(XFile file) _attachmentOf;

  /// Where the request is.
  ExchangeState state = ExchangeState.waiting;

  static Map<String, M> _replaced<M extends AIMessage>(AIConversationRequest<M> request, List<M> conversation) {
    final kind = request.kind;
    if (kind != AIConversationRequestKind.regenerate && kind != AIConversationRequestKind.edit) return const {};
    final message = request.message;
    if (message == null) return const {};
    final target = conversation.indexWhere((m) => m.id == message.id);
    if (target < 0) return const {};
    return {for (final m in conversation.skip(target)) m.id: m};
  }

  /// The person's message on its way, or `null` for a regenerate.
  AIPendingMessage? get pending {
    if (request.kind == AIConversationRequestKind.regenerate) return null;
    return AIPendingMessage(
      id: request.messageId,
      text: request.text,
      attachments: [..._edited, for (final file in request.attachments) _attachmentOf(file)],
    );
  }

  /// Whether the request failed or wasn't answered.
  bool get hasFailed => state == ExchangeState.failed || state == ExchangeState.unanswered;

  /// The person's message while the conversation shows it.
  ///
  /// That is until its reply starts, and for a new message also once it is
  /// stopped or failed, since the agent may have it, or a retry sends it
  /// again. The messages an edit replaces come back instead.
  AIPendingMessage? get shownPending {
    if (state == ExchangeState.waiting || request.kind == AIConversationRequestKind.message) return pending;
    return null;
  }

  /// The latest message of [conversation] when it is the request's reply: a
  /// reply that wasn't there, or one the request replaces, once it is written
  /// again.
  M? reply(List<M> conversation) {
    final last = conversation.lastOrNull;
    if (last == null || last.role == AIMessageRole.user) return null;
    final original = replaced[last.id];
    final isRewritten = original != null && _isRewritten(last, original);
    return !known.contains(last.id) || isRewritten ? last : null;
  }

  /// Whether the request's reply has started in [conversation]: it shows
  /// something, or it is already finished.
  bool hasReplyStarted(List<M> conversation) {
    final reply = this.reply(conversation);
    if (reply == null) return false;
    return !hasEmptyContent(reply) || !reply.isGenerating;
  }

  /// Whether the person's message is in [conversation]: one with its id, or
  /// one of theirs after the messages there were.
  bool hasMessageArrived(List<M> conversation) {
    if (conversation.any((m) => m.id == request.messageId)) return true;
    final lastKnown = conversation.lastIndexWhere((m) => known.contains(m.id));
    return conversation.skip(lastKnown + 1).any((m) => m.role == AIMessageRole.user);
  }

  /// What a retry sends in [conversation]: the request again, or, when the
  /// agent had the person's message but couldn't answer it, a request for its
  /// reply, since sending it again would add it twice.
  AIConversationRequest<M> retryRequest(List<M> conversation) {
    if (state != ExchangeState.unanswered) return request;
    if (request.kind != AIConversationRequestKind.message) return request;
    if (!hasMessageArrived(conversation)) return request;
    return AIConversationRequest(kind: AIConversationRequestKind.regenerate, text: request.text);
  }

  // Whether a reply is written again since it was [original]: it started
  // anew, or it shows something else.
  static bool _isRewritten(AIMessage reply, AIMessage original) {
    if (reply.isGenerating && !original.isGenerating) return true;
    if (reply.text != original.text) return true;
    if (!listEquals(reply.parts, original.parts)) return true;
    if (!listEquals(reply.attachments, original.attachments)) return true;
    return reply.uiDocument != original.uiDocument;
  }
}
