import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
// `chat_composer` and `chat_composer_factory` are here for the doc links below
// only; nothing in this file's code uses either.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_action_button.dart';

/// A microphone button that feeds speech-to-text results directly into an
/// [ChatComposerController]'s text field.
///
/// Rendered as one of the states of [ChatComposer]'s single trailing
/// control — the composer only builds this widget while the field is empty
/// and the AI is not generating, so it does not re-check either condition
/// itself. While listening, it shows an animated recording indicator and the
/// recognised speech appears in the text field in real time. Tapping again
/// stops recognition.
///
/// The recognizer is initialized on the first tap, not at mount, so simply
/// showing the button does not prompt the user for microphone access. If the
/// platform has no recognizer available, the button renders disabled rather
/// than disappearing.
///
/// Platform permissions must be configured before the button can work:
///
/// **iOS** — add to `ios/Runner/Info.plist`:
/// ```xml
/// <key>NSMicrophoneUsageDescription</key>
/// <string>Microphone access is needed for voice input.</string>
/// <key>NSSpeechRecognitionUsageDescription</key>
/// <string>Speech recognition is used to convert your voice to text.</string>
/// ```
///
/// **Android** — add to `android/app/src/main/AndroidManifest.xml`:
/// ```xml
/// <uses-permission android:name="android.permission.RECORD_AUDIO"/>
/// ```
///
/// **macOS** — add to `macos/Runner/Info.plist`:
/// ```xml
/// <key>NSMicrophoneUsageDescription</key>
/// <string>Microphone access is needed for voice input.</string>
/// <key>NSSpeechRecognitionUsageDescription</key>
/// <string>Speech recognition is used to convert your voice to text.</string>
/// ```
/// And enable the audio input entitlement in
/// `macos/Runner/DebugProfile.entitlements`:
/// ```xml
/// <key>com.apple.security.device.audio-input</key>
/// <true/>
/// <key>com.apple.security.device.microphone</key>
/// <true/>
/// ```
///
/// For a single control that toggles between voice input and send — matching
/// the reference iOS/Android AI sample apps — pass
/// `ChatComposer(enableSpeechToText: true, ...)` instead of placing this
/// widget manually; that swaps this button in for the send button's own slot
/// while the field is empty, rather than showing two separate buttons side
/// by side.
///
/// To place it elsewhere instead (e.g. always visible in a custom slot), use
/// it directly via [ChatComposerFactory]:
/// ```dart
/// class MyFactory extends ChatComposerFactory {
///   @override
///   Widget buildLeading(BuildContext context, ChatComposerController controller) {
///     return SpeechToTextButton(controller: controller);
///   }
/// }
/// ```
class SpeechToTextButton extends StatefulWidget {
  /// Creates a [SpeechToTextButton].
  const SpeechToTextButton({
    super.key,
    required this.controller,
    this.onError,
    this.onStatus,
    this.localeId,
    this.listenFor = const Duration(seconds: 30),
    this.pauseFor = const Duration(seconds: 3),
  });

  /// The controller whose text field receives recognised words.
  final ChatComposerController controller;

  /// Called when speech recognition encounters an error.
  final void Function(SpeechRecognitionError error)? onError;

  /// Called when the recognition engine status changes.
  ///
  /// Common status strings: `'listening'`, `'notListening'`, `'done'`.
  final void Function(String status)? onStatus;

  /// BCP-47 locale identifier (e.g. `'en-US'`).
  ///
  /// Defaults to the device's current locale when `null`.
  final String? localeId;

  /// Maximum duration of a single recognition session.
  final Duration listenFor;

  /// How long to wait after the user stops speaking before ending the session.
  final Duration pauseFor;

  @override
  State<SpeechToTextButton> createState() => _SpeechToTextButtonState();
}

class _SpeechToTextButtonState extends State<SpeechToTextButton> with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();

  /// Whether the platform recognizer is usable: `null` until the first tap
  /// initializes it, then `true`/`false`.
  bool? _isAvailable;
  bool _isListening = false;

  /// The text already in the field when listening started.
  ///
  /// Recognized words are appended to it rather than replacing it, so dictating
  /// into a field that already has content doesn't discard what was typed.
  String _baseText = '';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Not started here: the pulse only means something while listening, and a
    // repeating controller ticks every frame for as long as it runs.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1,
    );
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<bool> _initialize() async {
    final available = await _speech.initialize(
      onError: (error) {
        widget.onError?.call(error);
        _setListening(false);
      },
      onStatus: (status) {
        widget.onStatus?.call(status);
        _setListening(status == SpeechToText.listeningStatus);
      },
    );
    if (mounted) setState(() => _isAvailable = available);
    return available;
  }

  void _setListening(bool listening) {
    if (!mounted || listening == _isListening) return;
    setState(() => _isListening = listening);

    if (listening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 1;
    }
  }

  Future<void> _toggle() async {
    if (_isListening) {
      await _speech.stop();
      return;
    }

    // Initialized lazily, on first use. `SpeechToText.initialize` triggers the
    // microphone / speech-recognition permission prompt, and running it at mount
    // time asked for the microphone the moment a composer with
    // `enableSpeechToText: true` first rendered — before the user had shown any
    // interest in dictating.
    final available = _isAvailable ?? await _initialize();
    if (!available) return;

    _baseText = widget.controller.text.trimRight();
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: widget.localeId,
        listenFor: widget.listenFor,
        pauseFor: widget.pauseFor,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    final text = _baseText.isEmpty ? words : '$_baseText $words';
    widget.controller.textEditingController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _isListening ? colorScheme.error : colorScheme.primary;

    // Rendered even before the recognizer has been initialized, and even when it
    // turns out to be unavailable (disabled, in that case). Hiding it outright
    // left the composer's trailing slot completely empty — no mic, and no send
    // button either, since this widget occupies that slot.
    final button = _MicButton(
      color: color,
      onTap: _isAvailable == false ? null : _toggle,
      recording: _isListening,
    );

    if (!_isListening) return button;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Opacity(opacity: _pulseAnimation.value, child: child),
      child: button,
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.color, required this.onTap, required this.recording});

  final Color color;

  /// `null` when the platform recognizer is unavailable, which disables the
  /// button.
  final VoidCallback? onTap;

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return ComposerActionButton(
      icon: recording ? Icons.stop_rounded : Icons.mic_none_rounded,
      onPressed: onTap,
      tooltip: recording ? 'Stop recording' : 'Voice input',
      color: color,
    );
  }
}
