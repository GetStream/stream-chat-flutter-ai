import 'dart:async';

import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_download.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_error.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_platform.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_status.dart';

/// The language model built into the device, for answering when your AI agent
/// can't: the person is offline, or the agent reached its usage limit.
///
/// - On Android it is Gemini Nano in AICore, through ML Kit's GenAI Prompt
///   API, on devices whose AICore offers it (recent Pixel, Samsung and other
///   flagship phones), not on emulators. The app's `minSdk` must be 26 or
///   later.
/// - On iOS and macOS it is Apple's Foundation Models, on iOS 26 and macOS 26
///   and later with Apple Intelligence turned on.
/// - Elsewhere it is never available.
///
/// It answers without a network connection, and the conversation never leaves
/// the device. It is a small model, good for short answers and for working
/// with what is in the conversation. Its context holds a few thousand tokens,
/// so the oldest turns of a long conversation are left out. It has none of
/// your agent's tools, so the instructions should say so.
///
/// ```dart
/// const model = AIOnDeviceModel();
///
/// switch (await model.status()) {
///   case AIOnDeviceStatus.available:
///     _answers = model.reply(
///       instructions: 'Answer briefly. You have no tools.',
///       turns: [...history, AIConversationTurn.user(question)],
///     );
///   case AIOnDeviceStatus.downloadable:
///     // From a tap: the person asked for the model.
///     model.download().listen(showProgress);
///   default:
///     // Downloading or unavailable: this device can't answer yet.
/// }
/// ```
///
/// See [AILocalModel] for how to show the answer and stop it.
class AIOnDeviceModel extends AILocalModel {
  /// The on-device model, writing at most [maximumResponseTokens] per answer.
  const AIOnDeviceModel({this.maximumResponseTokens = 1000})
    : assert(maximumResponseTokens > 0, 'maximumResponseTokens must be positive');

  /// The longest answer, in tokens.
  ///
  /// Gemini Nano writes at most 256 tokens per answer, so on Android larger
  /// values are capped.
  final int maximumResponseTokens;

  // Room for the role markers and separators the platform frames the
  // conversation with, on top of `AIConversationTurn.tokensPerTurn`.
  static const _promptFramingTokens = 50;

  static AIOnDeviceModelPlatform get _platform => AIOnDeviceModelPlatform.instance;

  /// Where the model is on this device.
  ///
  /// Completes with [AIOnDeviceStatus.unavailable], rather than an error, when
  /// the platform can't tell.
  Future<AIOnDeviceStatus> status() async {
    try {
      return (await _platform.modelInfo()).status;
    } catch (_) {
      return AIOnDeviceStatus.unavailable;
    }
  }

  @override
  Future<bool> get isAvailable async => await status() == AIOnDeviceStatus.available;

  /// Downloads the model, when [status] is [AIOnDeviceStatus.downloadable].
  ///
  /// Listening starts the download and cancelling the subscription stops it.
  /// The stream closes after an [AIOnDeviceDownloadCompleted] or an
  /// [AIOnDeviceDownloadFailed]. The download can be large, so consider
  /// starting it from something the person did, such as a tap.
  ///
  /// - On Android, AICore may wait until the device is idle and on Wi-Fi, so
  ///   the download can take hours. Until it starts, [status] may still read
  ///   [AIOnDeviceStatus.downloadable].
  /// - On iOS and macOS the system downloads Apple's model by itself: this
  ///   completes at once when the model is available and fails otherwise,
  ///   with no [AIOnDeviceDownloadStarted] or progress before.
  ///
  /// There is one download at a time: calling this again while one is in
  /// progress joins it, and it stops when no stream is listened to.
  Stream<AIOnDeviceDownload> download() => _platform.download();

  /// Streams the answer to the last of [turns], the person's question, with
  /// [instructions] as the model's system prompt.
  ///
  /// The newest turns that fit the model's context are sent, always with the
  /// question; see [AIConversationTurn.fitToBudget]. Each event is the whole
  /// answer so far. Cancelling the subscription stops the model.
  ///
  /// Failures arrive as an [AILocalModelException] error event, whose
  /// [AILocalModelException.cause] is the platform's [AIOnDeviceError] when it
  /// reported one. A model that
  /// reports itself available can still fail, such as Apple's in the iOS
  /// Simulator.
  @override
  Stream<String> reply({required String instructions, required List<AIConversationTurn> turns}) {
    StreamSubscription<String>? answer;
    var cancelled = false;
    late final StreamController<String> controller;

    void fail(AILocalModelException error) {
      controller.addError(error);
      unawaited(controller.close());
    }

    Future<void> run() async {
      final AIOnDeviceModelInfo info;
      try {
        info = await _platform.modelInfo();
      } on Exception catch (error) {
        if (!cancelled) fail(_unavailable(cause: error));
        return;
      }
      if (cancelled) return;
      if (info.status != AIOnDeviceStatus.available) return fail(_unavailable());

      final maxResponseTokens = info.maxResponseTokens;
      final responseTokens = maxResponseTokens != null && maxResponseTokens < maximumResponseTokens
          ? maxResponseTokens
          : maximumResponseTokens;
      final budget = info.contextSize - responseTokens - _promptFramingTokens;
      if (budget <= 0) {
        return fail(
          AILocalModelException(
            AILocalModelErrorReason.contextExceeded,
            "The model's context of ${info.contextSize} tokens leaves no room after an answer of $responseTokens.",
          ),
        );
      }

      var fitted = AIConversationTurn.fitToBudget(turns, maxTokens: budget, instructions: instructions);
      if (fitted.lastOrNull?.role != AIConversationRole.user) {
        return fail(
          const AILocalModelException(
            AILocalModelErrorReason.invalidConversation,
            "The conversation must end with the person's question.",
          ),
        );
      }

      // A transcript starts with the person speaking: an answer left first by
      // the fitting has lost its question.
      if (fitted.first.role == AIConversationRole.assistant) fitted = fitted.sublist(1);

      answer = _platform
          .reply(instructions: instructions, turns: fitted, maximumResponseTokens: responseTokens)
          .listen(controller.add, onError: controller.addError, onDone: controller.close);
    }

    // Anything else going wrong, even an Error from a platform implementation,
    // still ends the reply, so the app doesn't wait for it forever.
    Future<void> start() async {
      try {
        await run();
      } catch (error) {
        if (cancelled || controller.isClosed) return;
        fail(AILocalModelException(AILocalModelErrorReason.failed, '$error', cause: error));
      }
    }

    controller = StreamController<String>(
      onListen: () => unawaited(start()),
      onPause: () => answer?.pause(),
      onResume: () => answer?.resume(),
      onCancel: () {
        cancelled = true;
        return answer?.cancel();
      },
    );
    return controller.stream;
  }

  static AILocalModelException _unavailable({Object? cause}) {
    return AILocalModelException(
      AILocalModelErrorReason.unavailable,
      'The on-device model is not available on this device now.',
      cause: cause is PlatformException ? AIOnDeviceError(cause.code, cause.message ?? '') : cause,
    );
  }
}
