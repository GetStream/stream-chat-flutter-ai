import 'dart:async';

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

  /// The `initialize()` call currently in flight, so concurrent callers await
  /// the same one instead of each starting their own.
  Future<bool>? _initializing;

  /// Set for the whole of [start], including the awaits inside it.
  ///
  /// [isListening] can't do this job: it only becomes true once the recognizer
  /// has been initialized, and on first use that await spans the platform
  /// permission prompt — seconds during which the mic button still renders as
  /// enabled. A second tap in that window used to reach `listen()` a second
  /// time.
  bool _starting = false;

  /// The callbacks belonging to the session currently in flight.
  ///
  /// Deliberately outlive [isListening]: a session's *final* transcript arrives
  /// after it has stopped, so clearing these the moment listening ends threw it
  /// away. See [_detachTimer].
  void Function(String words)? _onWords;
  SpeechToTextConfig? _config;

  /// Detaches [_onWords] and [_config] once nothing more can arrive for their
  /// session.
  ///
  /// `speech_to_text` guarantees that stopping produces a final result, and it
  /// arrives strictly after `stop()` — from the engine, or synthesized from the
  /// last partial by the plugin's own timer. Stopping within the first couple
  /// of seconds on an Android engine that reports nothing until the utterance
  /// is over (see [SpeechToTextConfig.pauseFor]) means that final result is the
  /// *only* one, so detaching eagerly dropped the whole dictation.
  ///
  /// Armed whenever listening ends for any reason. [cancel] clears it early —
  /// it is the one path meant to discard a pending transcript — and so does the
  /// next [start], whose caller must not receive the previous session's words.
  Timer? _detachTimer;

  /// How long past the end of a session a result is still delivered.
  ///
  /// Derives from the plugin's own final-result timeout — the deadline by which
  /// it either has the engine's final result or synthesizes one — plus a little
  /// slack for that synthesized result to come back through [_onResult].
  static final _detachDelay = SpeechToText.defaultFinalTimeout + const Duration(milliseconds: 500);

  /// Whether a recognition session is currently running.
  bool get isListening => _isListening;

  /// Whether the platform has a usable recognizer: `null` until
  /// [ensureInitialized] has run, then `true`/`false`.
  ///
  /// Deliberately not resolved eagerly — initializing prompts for microphone
  /// and speech-recognition access, which shouldn't happen merely because a
  /// composer with a mic button rendered.
  ///
  /// `false` is a report on the last attempt, not a verdict: see
  /// [invalidateAvailability].
  bool? get isAvailable => _isAvailable;

  /// Initializes the recognizer if it hasn't been already, and reports whether
  /// it is usable.
  ///
  /// Triggers the platform permission prompt on first call.
  ///
  /// Only *success* is remembered. A failure is worth retrying: the usual cause
  /// is the user declining the permission prompt, and caching that would leave
  /// the mic disabled for the life of the process even after they grant access
  /// in Settings. `speech_to_text` itself retries on the same grounds — caching
  /// the failure here made this wrapper stricter than the plugin it wraps.
  Future<bool> ensureInitialized() {
    if (_isAvailable ?? false) return Future.value(true);
    // Concurrent callers share one platform call. Without this, two taps during
    // the permission prompt each ran their own `initialize`.
    return _initializing ??= _initialize();
  }

  Future<bool> _initialize() async {
    try {
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
    } finally {
      _initializing = null;
    }
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
    if (_isListening || _starting) return false;
    _starting = true;
    try {
      if (!await ensureInitialized()) return false;

      // Anything still pending from the previous session belongs to a caller
      // that has moved on; its transcript must not land in this one's field.
      _detachSession();
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
      } catch (error) {
        _setListening(false);
        // Reported rather than rethrown. `speech_to_text` throws from `listen`
        // for conditions the user can act on — most often another app holding
        // the microphone — and the only caller is a tap handler, so a throw
        // became an unhandled async error: a console line in debug, nothing at
        // all in release, and [SpeechToTextConfig.onError] — the callback that
        // exists for exactly this — never fired.
        _reportError(config, error);
        return false;
      }
      return true;
    } finally {
      _starting = false;
    }
  }

  /// Ends the current session, keeping what has been recognised so far —
  /// including the final transcript that lands after this returns.
  Future<void> stop() async {
    if (!_isListening) return;
    final config = _config;
    // Flipped before the platform call rather than after it: the trailing
    // control is held in its stop state by this flag, and the round trip is
    // long enough for the button to feel stuck.
    _setListening(false);
    try {
      await _speech.stop();
    } catch (error) {
      // Same reasoning as [start]: surfaced through the config rather than
      // thrown at a tap handler that has nowhere to put it.
      _reportError(config, error);
    } finally {
      // Re-armed from the moment the recognizer actually stopped, which is when
      // the plugin starts its own final-result timer.
      _scheduleDetach();
    }
  }

  /// Ends the current session and discards its pending result.
  ///
  /// Also discards the pending result of a session already stopped but still
  /// inside its [_detachDelay] window — [ChatComposer] cancels on dispose, and
  /// a transcript delivered after that has nowhere left to go.
  Future<void> cancel() async {
    final wasListening = _isListening;
    final config = _config;
    _detachSession();
    if (!wasListening) return;
    _setListening(false);
    try {
      await _speech.cancel();
    } catch (error) {
      _reportError(config, error);
    }
  }

  /// Forgets whether the recognizer is usable, so the next [ensureInitialized]
  /// asks the platform again.
  ///
  /// Worth calling when the app returns to the foreground: the common reason
  /// initialization fails is the user declining the permission prompt, and the
  /// way they change their mind is to grant it in Settings and come back. Until
  /// then [isAvailable] reads `false` and the mic renders disabled, which would
  /// otherwise stay that way for the life of the process. [SpeechToTextButton]
  /// does this for you.
  ///
  /// Ignored while a session is running — there is nothing to re-check.
  void invalidateAvailability() {
    if (_isListening || _isAvailable == null) return;
    _isAvailable = null;
    notifyListeners();
  }

  void _reportError(SpeechToTextConfig? config, Object error) {
    // `permanent: false` — everything routed here is a failure of this attempt,
    // not of the recognizer as such, and a later attempt may well succeed.
    config?.onError?.call(SpeechRecognitionError(error.toString(), false));
  }

  void _onResult(SpeechRecognitionResult result) => _onWords?.call(result.recognizedWords);

  void _setListening(bool listening) {
    if (listening == _isListening) return;
    _isListening = listening;
    if (!listening) _scheduleDetach();
    notifyListeners();
  }

  void _scheduleDetach() {
    // Nothing attached means nothing to wait for — and no timer to leave
    // pending behind a test.
    if (_onWords == null) return;
    _detachTimer?.cancel();
    _detachTimer = Timer(_detachDelay, _detachSession);
  }

  void _detachSession() {
    _detachTimer?.cancel();
    _detachTimer = null;
    _onWords = null;
    _config = null;
  }

  /// Resets the initialization state. Exposed for tests.
  @visibleForTesting
  void debugReset() {
    _isAvailable = null;
    _initializing = null;
    _starting = false;
    _isListening = false;
    _detachSession();
  }

  /// Refuses to be disposed.
  ///
  /// [instance] is owned by the process, not by whichever widget happens to
  /// hold a reference to it. A host that disposes its controllers reflexively
  /// in `State.dispose` would otherwise brick dictation app-wide, and the
  /// symptom — "A SpeechToTextController was used after being disposed", raised
  /// from an unrelated screen later on — points nowhere near the cause.
  // Deliberately does not call `super.dispose()` — refusing is the whole point.
  @override
  // ignore: must_call_super
  void dispose() {
    assert(false, 'SpeechToTextController.instance is owned by the process and must not be disposed.');
  }
}
