import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_agent_activity.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// The agent couldn't answer.
///
/// It said so, such as with an [AIAgentActivity] in the
/// [AIAgentActivityState.error] state, or its reply didn't start in time.
@immutable
class AIAgentError implements Exception {
  /// Creates an [AIAgentError].
  const AIAgentError({this.message});

  /// What the agent said about it, if anything.
  final String? message;

  /// What to tell the person: [message], or else
  /// [AITranslations.agentError] from [translations].
  String localizedMessage(AITranslations translations) {
    final message = this.message;
    if (message != null && message.isNotEmpty) return message;
    return translations.agentError;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AIAgentError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'AIAgentError')}(message: $message)';
}
