import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
// Here for the doc links below only; nothing in this file's code uses either.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_button.dart';

/// Tuning and callbacks for a dictation session.
///
/// Passed to [ChatComposer.speechToTextConfig] or [SpeechToTextButton.config].
@immutable
class SpeechToTextConfig {
  /// Creates a [SpeechToTextConfig].
  const SpeechToTextConfig({
    this.localeId,
    this.listenFor = const Duration(seconds: 30),
    this.pauseFor,
    this.onError,
    this.onStatus,
  });

  /// BCP-47 locale identifier (e.g. `'en-US'`).
  ///
  /// Defaults to the device's current locale when `null`.
  final String? localeId;

  /// Maximum duration of a single recognition session.
  final Duration listenFor;

  /// How long the session may go without producing a *recognition result*
  /// before `speech_to_text` ends it, or `null` for the platform default.
  ///
  /// Worth understanding before setting: despite the name, this timer never
  /// looks at the audio — it counts the gap between recognition results. On
  /// Apple's recognizer that is a decent proxy for silence, because it streams
  /// partial results continuously while the user talks. Plenty of Android
  /// engines instead deliver nothing until the utterance is over (on a Galaxy
  /// A05s the first partial takes ~3.3s), so a fixed pause always fires
  /// mid-sentence and dictation looks like it cuts off after three seconds.
  ///
  /// Hence the default: 3 seconds on iOS and macOS, and *no* Dart-side pause on
  /// Android, where the engine's own audio-based endpointing decides when the
  /// utterance ends and [listenFor] remains the backstop. Set this explicitly
  /// to override that on every platform.
  final Duration? pauseFor;

  /// Called when speech recognition encounters an error.
  final void Function(SpeechRecognitionError error)? onError;

  /// Called when the recognition engine status changes.
  ///
  /// Common status strings: `'listening'`, `'notListening'`, `'done'`.
  final void Function(String status)? onStatus;

  /// [pauseFor] if set, otherwise the per-platform default described on it.
  Duration? get effectivePauseFor {
    if (pauseFor != null) return pauseFor;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => const Duration(seconds: 3),
      _ => null,
    };
  }
}

/// Owns the app's speech recognition session.
///
/// Use [instance] — this is deliberately a single, process-lived owner rather
/// than something a widget creates.
///
/// `SpeechToText()` is itself a process-wide singleton, and its `initialize()`
/// returns early once it has succeeded *without* re-registering the
/// `onStatus`/`onError` handlers it is passed. The handlers that ever fire are
/// therefore the ones supplied by the first caller in the process. That makes
/// any shorter-lived owner unsound: [SpeechToTextButton] used to hold the
/// session itself, and the composer's trailing control rebuilds that button
/// whenever it morphs between mic and send — so every instance after the very
/// first rendered a mic that never reacted to anything, and each one's
/// `dispose` cancelled the session out from under whoever was dictating.
///
/// This class registers those handlers exactly once and fans them out to the
/// current session, so the recognizer outlives the widgets observing it.
class SpeechToTextController extends ChangeNotifier {
  SpeechToTextController._();

  /// The single instance. Never dispose it — it is owned by the process.
  static final SpeechToTextController instance = SpeechToTextController._();

  final SpeechToText _speech = SpeechToText();

  bool? _isAvailable;
  bool _isListening = false;

  /// The callbacks belonging to the session currently in flight.
  ///
  /// Cleared when it ends, so a status change arriving after the fact isn't
  /// reported to a caller that has already stopped listening.
  void Function(String words)? _onWords;
  SpeechToTextConfig? _config;

  /// Whether a recognition session is currently running.
  bool get isListening => _isListening;

  /// Whether the platform has a usable recognizer: `null` until
  /// [ensureInitialized] has run, then `true`/`false`.
  ///
  /// Deliberately not resolved eagerly — initializing prompts for microphone
  /// and speech-recognition access, which shouldn't happen merely because a
  /// composer with a mic button rendered.
  bool? get isAvailable => _isAvailable;

  /// Initializes the recognizer if it hasn't been already, and reports whether
  /// it is usable.
  ///
  /// Triggers the platform permission prompt on first call.
  Future<bool> ensureInitialized() async {
    final known = _isAvailable;
    if (known != null) return known;

    final available = await _speech.initialize(
      onError: (error) {
        _config?.onError?.call(error);
        _setListening(false);
      },
      onStatus: (status) {
        _config?.onStatus?.call(status);
        _setListening(status == SpeechToText.listeningStatus);
      },
    );

    _isAvailable = available;
    notifyListeners();
    return available;
  }

  /// Starts a dictation session, reporting each recognised transcript to
  /// [onWords] as it arrives.
  ///
  /// Does nothing if a session is already running, or if the platform has no
  /// usable recognizer. Returns whether a session started.
  Future<bool> start({
    required void Function(String words) onWords,
    SpeechToTextConfig config = const SpeechToTextConfig(),
  }) async {
    if (_isListening) return false;
    if (!await ensureInitialized()) return false;

    _onWords = onWords;
    _config = config;
    // Set here rather than waiting for the engine's `listening` status: the
    // trailing control is held in its stop state by this flag, and a status
    // that arrives late (or not at all) would leave a running session with no
    // way to end it.
    _setListening(true);

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          localeId: config.localeId,
          listenFor: config.listenFor,
          pauseFor: config.effectivePauseFor,
        ),
      );
    } catch (_) {
      _setListening(false);
      rethrow;
    }
    return true;
  }

  /// Ends the current session, keeping what has been recognised so far.
  Future<void> stop() async {
    if (!_isListening) return;
    await _speech.stop();
    _setListening(false);
  }

  /// Ends the current session and discards its pending result.
  Future<void> cancel() async {
    if (!_isListening) return;
    await _speech.cancel();
    _setListening(false);
  }

  void _onResult(SpeechRecognitionResult result) => _onWords?.call(result.recognizedWords);

  void _setListening(bool listening) {
    if (listening == _isListening) return;
    _isListening = listening;
    if (!listening) {
      _onWords = null;
      _config = null;
    }
    notifyListeners();
  }

  /// Resets the initialization state. Exposed for tests.
  @visibleForTesting
  void debugReset() {
    _isAvailable = null;
    _isListening = false;
    _onWords = null;
    _config = null;
  }
}
