import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_option.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_transport.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:uuid/uuid.dart';

/// What the person asks for in an [AIConversationRequest].
///
/// An open set: compare against the kinds this package knows ([values]), and
/// treat the rest as a new message. A kind it doesn't know keeps its raw value
/// and reports `false` from [isKnown].
extension type const AIConversationRequestKind(String _) implements String {
  /// A new message from the person.
  static const message = AIConversationRequestKind('message');

  /// A new reply in place of the request's message, which is a reply, and of
  /// those after it.
  ///
  /// Without a message, it asks for a reply to the latest message, which has
  /// none, such as after the agent couldn't answer it.
  static const regenerate = AIConversationRequestKind('regenerate');

  /// The person changed the request's message, one of theirs, to say its
  /// text: it is answered again, in place of the replies after it.
  static const edit = AIConversationRequestKind('edit');

  /// The kinds this package knows.
  static const values = [message, regenerate, edit];

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);
}

/// What the person asks of the agent, which an [AIConversation] hands to its
/// [AIConversationTransport].
@immutable
class AIConversationRequest<M extends AIMessage> {
  /// Creates an [AIConversationRequest].
  ///
  /// The [messageId] defaults to a new unique id.
  AIConversationRequest({
    required this.kind,
    required this.text,
    this.attachments = const [],
    this.chatOption,
    this.message,
    String? messageId,
  }) : messageId = messageId ?? const Uuid().v4();

  /// What the person asks for.
  final AIConversationRequestKind kind;

  /// What the person wrote. When a reply is written again, the message it
  /// answers says it.
  final String text;

  /// The files the person picked, on this device, to upload with their
  /// message.
  final List<XFile> attachments;

  /// The option the person picked in the composer, such as thinking harder.
  final ChatOption? chatOption;

  /// The message it is about: the reply to write again, or the person's
  /// message they edited.
  final M? message;

  /// An id for the person's message.
  ///
  /// A transport that creates the message with it lets the conversation find
  /// its copy by it. A retry of the request keeps it.
  final String messageId;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'AIConversationRequest')}(kind: $kind, messageId: $messageId, message: ${message?.id})';
}
