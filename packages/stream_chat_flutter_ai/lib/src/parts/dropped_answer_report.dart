import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';

/// Where [reportDroppedAnswer] sends its messages in debug builds. `null`
/// means [debugPrint]. Tests set it to capture the messages.
///
/// Not exported.
@visibleForTesting
void Function(String message)? debugDroppedAnswerReporter;

/// Says, in debug builds only, that an answer to [call] was dropped and why —
/// usually an answer callback kept past the moment its question went away.
///
/// Not exported.
void reportDroppedAnswer(AIToolCallPart call, String reason) {
  assert(() {
    (debugDroppedAnswerReporter ?? debugPrint)(
      'stream_chat_flutter_ai: dropped an answer to tool call "${call.id}", because $reason.',
    );
    return true;
  }(), 'unreachable');
}
