import 'dart:convert';

import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/local_model/ai_local_model.dart';
import 'package:stream_chat_flutter_ai/src/local_model/ai_local_model_exception.dart';

/// Who said an [AIConversationTurn].
enum AIConversationRole {
  /// The person using the app.
  user,

  /// The AI.
  assistant,
}

/// One turn of a conversation, for an [AILocalModel].
@immutable
final class AIConversationTurn {
  /// A turn said by [role].
  const AIConversationTurn({required this.role, required this.text});

  /// A turn said by the person using the app.
  const AIConversationTurn.user(this.text) : role = AIConversationRole.user;

  /// A turn said by the AI.
  const AIConversationTurn.assistant(this.text) : role = AIConversationRole.assistant;

  /// Who said this turn.
  final AIConversationRole role;

  /// What was said.
  final String text;

  /// The number of tokens [text] is estimated to take: three bytes of UTF-8
  /// per token, rounded up, so any non-empty text costs at least one.
  ///
  /// This overcounts English, which tokenizers pack at about four characters
  /// per token, so a budget filled by this estimate leaves some room spare.
  static int estimateTokens(String text) => (utf8.encode(text).length + 2) ~/ 3;

  /// The tokens [fitToBudget] adds to each turn's [estimateTokens], for the
  /// role markers and separators a model's prompt format wraps a turn in.
  ///
  /// Without it, many short turns could add up to more than a small context.
  static const tokensPerTurn = 4;

  /// The newest [turns] that fit in [maxTokens], oldest first, for a model
  /// whose context is small.
  ///
  /// Turns that are empty or only whitespace are dropped, and consecutive
  /// turns of one role are merged into one, their text kept as is and
  /// separated by a blank line — most models expect the roles to alternate.
  ///
  /// The last of the merged turns is always kept, even when it alone is over
  /// the budget: it is never truncated, as a cut-off question would get an
  /// answer to something else. A model then fails with
  /// [AILocalModelErrorReason.contextExceeded]. It is whatever the conversation ends with, so
  /// pass one that ends with the question, a [AIConversationRole.user] turn.
  /// Older turns are then added newest first while they fit, and the first
  /// that doesn't ends the history, so the result is always an unbroken run of
  /// the newest turns. It can start with an [AIConversationRole.assistant]
  /// turn, such as a greeting, or a reply whose question didn't fit; drop it
  /// for a model whose prompt format requires the person to speak first.
  /// [instructions], the system prompt the model is given alongside the turns,
  /// counts against the budget too.
  ///
  /// A turn costs its [estimateTokens] plus [tokensPerTurn]. [maxTokens] must
  /// be positive.
  ///
  /// Returns an empty list when no turn has text.
  static List<AIConversationTurn> fitToBudget(
    List<AIConversationTurn> turns, {
    required int maxTokens,
    String instructions = '',
  }) {
    assert(maxTokens > 0, 'maxTokens must be positive, was $maxTokens');
    final merged = <AIConversationTurn>[];
    for (final turn in turns) {
      if (turn.text.trim().isEmpty) continue;
      final last = merged.lastOrNull;
      if (last != null && last.role == turn.role) {
        merged.last = AIConversationTurn(role: turn.role, text: '${last.text}\n\n${turn.text}');
      } else {
        merged.add(turn);
      }
    }
    if (merged.isEmpty) return const [];

    final question = merged.removeLast();
    final kept = [question];
    int cost(AIConversationTurn turn) => estimateTokens(turn.text) + tokensPerTurn;
    var remaining = maxTokens - estimateTokens(instructions) - cost(question);
    for (final turn in merged.reversed) {
      remaining -= cost(turn);
      if (remaining < 0) break;
      kept.add(turn);
    }
    return List.unmodifiable(kept.reversed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIConversationTurn && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);

  @override
  String toString() => 'AIConversationTurn.${role.name}($text)';
}
