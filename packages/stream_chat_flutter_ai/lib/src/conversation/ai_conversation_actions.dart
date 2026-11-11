import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';

/// What an [AIConversation]'s views offer the person to do with its messages,
/// besides copying and sharing a reply.
///
/// Leave out what the agent or backend doesn't support:
///
/// ```dart
/// AIConversation(transport: transport, actions: AIConversationActions.rate)
/// ```
///
/// Combine actions with `|`:
///
/// ```dart
/// AIConversationActions.edit | AIConversationActions.rate
/// ```
@immutable
class AIConversationActions {
  const AIConversationActions._(this._bits);

  /// No actions.
  static const none = AIConversationActions._(0);

  /// Editing the person's latest message, which is then answered again.
  static const edit = AIConversationActions._(1);

  /// Asking for a new reply in place of the latest.
  static const regenerate = AIConversationActions._(2);

  /// Rating replies.
  static const rate = AIConversationActions._(4);

  /// Every action.
  static const all = AIConversationActions._(7);

  final int _bits;

  /// The actions of this set and of [other].
  AIConversationActions operator |(AIConversationActions other) => AIConversationActions._(_bits | other._bits);

  /// Whether this set has every action of [other].
  bool contains(AIConversationActions other) => _bits & other._bits == other._bits;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AIConversationActions && other._bits == _bits;
  }

  @override
  int get hashCode => _bits.hashCode;

  @override
  String toString() {
    final names = [
      if (contains(edit)) 'edit',
      if (contains(regenerate)) 'regenerate',
      if (contains(rate)) 'rate',
    ];
    return '${objectRuntimeType(this, 'AIConversationActions')}(${names.join(', ')})';
  }
}
