import 'package:flutter/material.dart';
// `chat_composer` and `chat_composer_factory` are here for the doc links below
// only; nothing in this file's code uses either.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_action_button.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_controller.dart';

/// A microphone button that feeds speech-to-text results directly into an
/// [ChatComposerController]'s text field.
///
/// Rendered as one of the states of [ChatComposer]'s single trailing
/// control. While listening, it shows an animated recording indicator and the
/// recognised speech appears in the text field in real time. Tapping again
/// stops recognition.
///
/// The button is a *view* over [SpeechToTextController.instance], which owns
/// the recognition session — see that class for why the session can't live in
/// this widget. Disposing the button therefore does not end dictation; the
/// composer keeps showing a stop button for as long as a session is running,
/// even once the recognised words have given the field content.
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
///   Widget buildLeading(BuildContext context, ChatComposerLeadingProps props) {
///     return SpeechToTextButton(controller: props.controller);
///   }
/// }
/// ```
class SpeechToTextButton extends StatefulWidget {
  /// Creates a [SpeechToTextButton].
  const SpeechToTextButton({
    super.key,
    required this.controller,
    this.config = const SpeechToTextConfig(),
  });

  /// The controller whose text field receives recognised words.
  final ChatComposerController controller;

  /// Locale, timeouts and callbacks for the dictation session.
  final SpeechToTextConfig config;

  @override
  State<SpeechToTextButton> createState() => _SpeechToTextButtonState();
}

class _SpeechToTextButtonState extends State<SpeechToTextButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  SpeechToTextController get _speech => SpeechToTextController.instance;

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
    _speech.addListener(_onSpeechChanged);
    WidgetsBinding.instance.addObserver(this);
    _syncPulse();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Settings is how a user who declined the permission
    // prompt changes their mind, so re-ask the platform rather than leaving the
    // mic disabled on the strength of that one refusal.
    if (state == AppLifecycleState.resumed) _speech.invalidateAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.removeListener(_onSpeechChanged);
    _pulseController.dispose();
    // Deliberately does *not* cancel the session. This widget is swapped out
    // the moment dictation puts content in the field, and cancelling here
    // ended dictation roughly as soon as it produced its first word.
    super.dispose();
  }

  void _onSpeechChanged() {
    if (!mounted) return;
    setState(_syncPulse);
  }

  void _syncPulse() {
    if (_speech.isListening) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 1;
    }
  }

  Future<void> _toggle() async {
    if (_speech.isListening) {
      await _speech.stop();
      return;
    }

    // Initialized lazily, on first use. Initializing triggers the microphone /
    // speech-recognition permission prompt, and running it at mount time asked
    // for the microphone the moment a composer with `enableSpeechToText: true`
    // first rendered — before the user had shown any interest in dictating.
    _baseText = widget.controller.text.trimRight();
    await _speech.start(onWords: _onWords, config: widget.config);
  }

  void _onWords(String words) {
    // A session outlives this widget by design, and its *final* transcript
    // lands after listening has stopped — so by the time this runs the field it
    // writes into may already be gone, taking the controller with it. Writing
    // anyway threw "A TextEditingController was used after being disposed".
    if (!mounted) return;
    final text = _baseText.isEmpty ? words : '$_baseText $words';
    widget.controller.textEditingController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listening = _speech.isListening;
    final color = listening ? colorScheme.error : colorScheme.primary;

    // Rendered even before the recognizer has been initialized, and even when it
    // turns out to be unavailable (disabled, in that case). Hiding it outright
    // left the composer's trailing slot completely empty — no mic, and no send
    // button either, since this widget occupies that slot.
    final button = _MicButton(
      color: color,
      onTap: _speech.isAvailable == false ? null : _toggle,
      recording: listening,
    );

    if (!listening) return button;

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
