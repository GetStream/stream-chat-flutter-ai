import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';

/// Who wrote an [AIMessage].
///
/// An open set: compare against the roles you know ([user], [assistant]). A
/// message of any role other than [user] shows as the agent's.
@immutable
class AIMessageRole {
  /// Wraps a raw role, such as `'system'`.
  const AIMessageRole(this.value);

  /// The person using the app. Each of their messages starts a turn.
  static const user = AIMessageRole('user');

  /// The agent.
  static const assistant = AIMessageRole('assistant');

  /// The role's name.
  final String value;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIMessageRole && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIMessageRole($value)';
}

/// A message [AIConversationView] can show: the person's in a bubble with its
/// attachments, and the agent's as its steps, its answer and then its
/// attachments.
///
/// Implement it on your own message type, or wrap one:
///
/// ```dart
/// class ChatMessageAdapter with AIMessage {
///   ChatMessageAdapter(this.message);
///
///   final Message message;
///
///   @override
///   String get id => message.id;
///
///   @override
///   AIMessageRole get role => message.extraData['ai_generated'] == true ? AIMessageRole.assistant : AIMessageRole.user;
///
///   @override
///   String get text => message.text ?? '';
/// }
/// ```
abstract mixin class AIMessage {
  /// The message's id, stable across its updates.
  String get id;

  /// Who wrote it.
  AIMessageRole get role;

  /// What it says. A reply's text is markdown.
  String get text;

  /// Whether the agent is still writing it.
  bool get isGenerating => false;

  /// The steps the agent took for it, in order.
  List<AIMessagePart> get parts => const [];

  /// What it carries besides its text, such as images and files.
  List<AIMessageAttachment> get attachments => const [];

  /// The whole of a reasoning step's thinking when the app has it, such as from
  /// live updates. Without it the step shows its own preview.
  ///
  /// It is read every time the conversation rebuilds, so look it up rather than
  /// work it out.
  String? reasoningText(AIReasoningPart step) => null;
}

/// A message the person sent that is not in the conversation yet, such as
/// while its conversation opens or its attachments upload.
///
/// [AIConversationView] shows it as theirs straight away. The first message of
/// theirs that arrives after it takes its place, keeping its attachments, and
/// the list does not move.
@immutable
class AIPendingMessage {
  /// Creates an [AIPendingMessage].
  ///
  /// Pass the [id] the message will have once it arrives when you know it: its
  /// copy is then found by it, rather than by where it lands.
  AIPendingMessage({String? id, required this.text, this.attachments = const []}) : id = id ?? 'pending-${_nextId++}';

  static int _nextId = 0;

  /// The message's id once it arrives, or a made-up one.
  final String id;

  /// What the person wrote.
  final String text;

  /// What they sent with it, such as the photos and files they picked.
  final List<AIMessageAttachment> attachments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIPendingMessage && other.id == id && other.text == text && listEquals(other.attachments, attachments);

  @override
  int get hashCode => Object.hash(id, text, Object.hashAll(attachments));
}
