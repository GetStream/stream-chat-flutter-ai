import 'dart:async';

import 'package:stream_chat_flutter_ai/src/local_model/ai_conversation_turn.dart';
import 'package:stream_chat_flutter_ai/src/local_model/ai_local_model_exception.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/streaming_message_view.dart';

/// A language model on the device, for answering when your AI agent can't:
/// the person is offline, or the agent reached its usage limit.
///
/// This package ships no model and depends on none. Implement this class over
/// the on-device model of your choice, for example:
///
/// - Gemini Nano on Android, through ML Kit's GenAI APIs.
/// - Apple's Foundation Models on iOS 26 and later, with Apple Intelligence
///   turned on, through a plugin or a platform channel of your own.
/// - A small open model run by a local inference library.
///
/// Such models are small, with a context of a few thousand tokens: fit the
/// conversation to it with [AIConversationTurn.fitToBudget], and tell the
/// model in its instructions what it can't do, since it has none of your
/// agent's tools.
///
/// ```dart
/// try {
///   await backend.send(text);
/// } on Exception catch (error) {
///   // Fall back when offline or when the agent hit its usage limit; let
///   // anything else through.
///   if (!isOfflineOrOverQuota(error) || !await localModel.isAvailable) rethrow;
///   _subscription = localModel
///       .reply(
///         instructions: 'Answer briefly. You have no tools.',
///         turns: [...history, AIConversationTurn.user(text)],
///       )
///       .listen(
///         (answer) => setState(() => _localAnswer = answer),
///         onError: (Object error) => setState(() => _localError = error),
///       );
/// }
/// ```
///
/// Each answer is the whole reply so far, which is what
/// [StreamingMessageView.text] takes: pass the latest one and the view types
/// out what it hasn't shown yet. A `StreamBuilder` does the same without a
/// subscription of your own. Create the stream once — in `initState` or when
/// the question is sent, and keep it in your state — never in `build`, where
/// every rebuild would start the model again:
///
/// ```dart
/// StreamBuilder<String>(
///   stream: _answers, // created once, when the question was sent
///   builder: (context, snapshot) {
///     if (snapshot.hasError) return const Text('The on-device model could not answer.');
///     return StreamingMessageView(text: snapshot.data ?? '');
///   },
/// )
/// ```
///
/// The reply exists only on the device. It isn't sent to your backend; keep it
/// local, or send it yourself.
///
/// ## Implementing
///
/// This is an `abstract class` rather than an `interface`, so you can
/// `extends` it: members added to it later will come with default bodies and
/// won't break an implementation that extends it.
///
/// - [isAvailable] should be cheap enough to check before every fallback
///   reply. It completes with `false` rather than throwing when the model is
///   missing, still downloading, or switched off.
/// - [reply] returns a single-subscription stream that starts generating when
///   it is listened to. Each event is the **whole answer so far**, never just
///   the newest piece: convert a model that streams deltas by appending them.
///   The stream closes when the answer is complete.
/// - Cancelling the subscription must stop generation and free the model, as
///   it is how a person's tap on stop reaches it. With a
///   [StreamController], stop the model in [StreamController.onCancel]; with
///   an `async*` generator, cancellation ends the generator at its next
///   `yield`, so release the model in a `finally`.
/// - Fit the turns with [AIConversationTurn.fitToBudget] first, then check
///   that the fitted turns end with a [AIConversationRole.user] turn.
/// - Report failures as an [AILocalModelException] error event, never by
///   throwing synchronously from [reply], and close the stream after it:
///   [AILocalModelErrorReason.unavailable] when the model can't answer now,
///   [AILocalModelErrorReason.invalidConversation] when the fitted turns are
///   empty or don't end with a user turn, and [AILocalModelErrorReason.failed]
///   (with the platform error as `cause`) when generation fails.
abstract class AILocalModel {
  /// Lets subclasses be `const`.
  const AILocalModel();

  /// Whether the model can answer now, on this device.
  Future<bool> get isAvailable;

  /// Streams the answer to the last of [turns], the person's question, with
  /// [instructions] as the model's system prompt.
  ///
  /// [turns] must not be empty and must end with the person's question, an
  /// [AIConversationRole.user] turn. It can be the whole conversation: an
  /// implementation fits it to its context with
  /// [AIConversationTurn.fitToBudget].
  ///
  /// Each event is the whole answer so far. Cancelling the subscription stops
  /// the model. Failures arrive as an [AILocalModelException] error event.
  Stream<String> reply({required String instructions, required List<AIConversationTurn> turns});
}
