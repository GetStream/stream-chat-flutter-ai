// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/voice/ai_voice_views.dart';

/// What a voice agent is doing, which [AIVoiceGlowView] and [AIVoiceWaveView]
/// show as motion.
///
/// The states differ only in how a visualization moves, never in its colors,
/// and changing the state eases from one motion into the next.
enum AIVoiceAgentState {
  /// Waiting to be spoken to: a calm, barely-there shimmer.
  idle,

  /// Not ready yet: a loader sweep with a pulsing breath.
  connecting,

  /// Hearing somebody: a gentle expand and contract.
  listening,

  /// Working on an answer: a slow turn or a travelling wave.
  thinking,

  /// Talking: strong motion that ebbs and pauses like speech.
  speaking,
}
