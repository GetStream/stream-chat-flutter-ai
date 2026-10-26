import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/streaming_reasoning_view.dart';

/// A reply's thinking before any of it arrives: "Thinking…", counting the
/// seconds.
///
/// [AIConversationView] shows it under the latest question while it is
/// thinking, counting from when the question was asked, and the reply's first
/// reasoning step takes over the count. Anywhere else it counts from [since],
/// or from when it appears.
class AIThinkingView extends StatelessWidget {
  /// Creates an [AIThinkingView].
  const AIThinkingView({super.key, this.since});

  /// When the thinking began.
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final scope = ThinkingTurnScope.maybeOf(context);
    final start = since ?? scope?.clock.start(scope.turn);
    return StreamingReasoningView(
      text: '',
      isThinking: true,
      duration: start == null ? null : DateTime.now().difference(start),
    );
  }
}
