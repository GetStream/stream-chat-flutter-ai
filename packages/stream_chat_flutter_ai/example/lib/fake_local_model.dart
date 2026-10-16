import 'dart:async';

import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Stands in for an on-device model such as Gemini Nano or Apple's Foundation
/// Models: it answers with a canned reply that quotes the question, a few
/// words at a time.
///
/// A real implementation would fit [reply]'s turns to the model's context with
/// [AIConversationTurn.fitToBudget], hand them to the model, and forward its
/// output the same way.
class FakeLocalModel implements AILocalModel {
  const FakeLocalModel();

  /// The context of a small on-device model, in tokens.
  static const _contextTokens = 4000;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Stream<String> reply({required String instructions, required List<AIConversationTurn> turns}) async* {
    final fitted = AIConversationTurn.fitToBudget(turns, maxTokens: _contextTokens, instructions: instructions);
    final question = fitted.lastOrNull;
    if (question == null || question.role != AIConversationRole.user) {
      throw StateError('The conversation must end with a question.');
    }

    final answer =
        "You're offline, so this answer comes from a model on your device. "
        'You asked: *${question.text}*. I can see ${fitted.length - 1} earlier '
        "turn(s) of our conversation, but I have none of the agent's tools.";

    // Each event is the whole answer so far. Cancelling the subscription ends
    // this generator at its next `yield`, which is how stop reaches the model.
    var soFar = '';
    for (final word in answer.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      soFar = soFar.isEmpty ? word : '$soFar $word';
      yield soFar;
    }
  }
}
