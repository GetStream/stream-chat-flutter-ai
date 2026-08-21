import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// A [SpeechToTextPlatform] that records what it was asked to do and lets the
/// test drive results and status changes back into the plugin.
class _FakeSpeechPlatform extends SpeechToTextPlatform {
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  SpeechListenOptions? lastOptions;

  void reset() {
    listenCalls = 0;
    stopCalls = 0;
    cancelCalls = 0;
    lastOptions = null;
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize({Object? debugLogging = false, List<SpeechConfigOption>? options}) async => true;

  @override
  Future<bool> listen({
    String? localeId,
    Object? partialResults = true,
    Object? onDevice = false,
    int listenMode = 0,
    Object? sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    listenCalls++;
    lastOptions = options;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    onStatus?.call(SpeechToText.notListeningStatus);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    onStatus?.call(SpeechToText.notListeningStatus);
  }

  /// Pushes a recognised transcript through the plugin, the way the engine
  /// delivers its results.
  ///
  /// [isFinal] marks it as the session's final transcript — the one the engine
  /// sends after `stop()`, and on engines that report nothing mid-utterance the
  /// only one it sends at all.
  void emitWords(String words, {bool isFinal = false}) {
    onTextRecognition?.call(
      jsonEncode({
        'alternates': [
          {'recognizedWords': words, 'confidence': 1.0},
        ],
        'resultType': isFinal ? ResultType.finalResult.value : ResultType.partial.value,
      }),
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Installed once, not per test: `SpeechToText` is a process singleton whose
  // `initialize()` returns early after the first success, so the platform
  // instance it wired its callbacks to is the only one that will ever be
  // called. Swapping in a fresh fake between tests would leave every one of
  // them deaf.
  final platform = _FakeSpeechPlatform();
  setUpAll(() => SpeechToTextPlatform.instance = platform);

  setUp(() {
    platform.reset();
    SpeechToTextController.instance.debugReset();
  });

  tearDown(SpeechToTextController.instance.debugReset);

  group('SpeechToTextConfig', () {
    test('falls back to a 3s pause on Apple platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(const SpeechToTextConfig().effectivePauseFor, const Duration(seconds: 3));
    });

    test('leaves endpointing to the engine on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // The plugin's pauseFor timer counts recognition results rather than
      // silence, so a fixed value cuts off engines that only report at the end
      // of an utterance.
      expect(const SpeechToTextConfig().effectivePauseFor, isNull);
    });

    test('an explicit pauseFor wins on every platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      const config = SpeechToTextConfig(pauseFor: Duration(seconds: 5));
      expect(config.effectivePauseFor, const Duration(seconds: 5));
    });
  });

  group('SpeechToTextController', () {
    test('start reports recognised words and marks itself listening', () async {
      final words = <String>[];
      final started = await SpeechToTextController.instance.start(onWords: words.add);

      expect(started, isTrue);
      expect(SpeechToTextController.instance.isListening, isTrue);
      expect(platform.listenCalls, 1);

      platform.emitWords('hello there');
      expect(words, ['hello there']);
    });

    test('does not start a second session while one is running', () async {
      await SpeechToTextController.instance.start(onWords: (_) {});
      final second = await SpeechToTextController.instance.start(onWords: (_) {});

      expect(second, isFalse);
      expect(platform.listenCalls, 1);
    });

    test('stop keeps the result callback attached for the final transcript', () async {
      final words = <String>[];
      await SpeechToTextController.instance.start(onWords: words.add);
      await SpeechToTextController.instance.stop();

      expect(SpeechToTextController.instance.isListening, isFalse);
      expect(platform.stopCalls, 1);

      // Stopping is documented to produce a final result, and it necessarily
      // arrives after the fact. Detaching the callback along with the listening
      // flag threw away the entire dictation of anyone who stopped before their
      // engine had reported a partial.
      platform.emitWords('the whole utterance', isFinal: true);
      expect(words, ['the whole utterance']);
    });

    test('cancel discards the pending final transcript', () async {
      final words = <String>[];
      await SpeechToTextController.instance.start(onWords: words.add);
      await SpeechToTextController.instance.cancel();

      platform.emitWords('discarded', isFinal: true);
      expect(words, isEmpty);
    });

    test('cancel discards a transcript still in flight from a stopped session', () async {
      final words = <String>[];
      await SpeechToTextController.instance.start(onWords: words.add);
      await SpeechToTextController.instance.stop();

      // What ChatComposer.dispose does: by then nothing is listening, but the
      // stopped session's transcript is still owed, and the field it would
      // land in is going away.
      await SpeechToTextController.instance.cancel();

      platform.emitWords('discarded', isFinal: true);
      expect(words, isEmpty);
    });

    test('a transcript owed to a finished session never reaches the next one', () async {
      final first = <String>[];
      final second = <String>[];

      await SpeechToTextController.instance.start(onWords: first.add);
      await SpeechToTextController.instance.stop();
      await SpeechToTextController.instance.start(onWords: second.add);

      platform.emitWords('for the second session', isFinal: true);
      expect(first, isEmpty);
      expect(second, ['for the second session']);
    });
  });

  group('ChatComposer voice input', () {
    // The mic pulses while listening, so `pumpAndSettle` never returns once a
    // session is running — these advance by hand, past the trailing control's
    // 150ms AnimatedSwitcher transition.
    Future<void> settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 200));

    /// Ends the session and drains the plugin's post-stop "final result"
    /// timer, which the test binding would otherwise flag as still pending.
    Future<void> endSession(WidgetTester tester) async {
      await SpeechToTextController.instance.stop();
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('keeps the stop control once dictation produces text', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            enableSpeechToText: true,
            onSendPressed: (_, _, _) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await settle(tester);

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      // The first recognised word gives the field content. The trailing control
      // used to morph into send at this point, disposing the mic — which
      // cancelled the session that had just started producing text.
      platform.emitWords('hello');
      await settle(tester);

      expect(controller.text, 'hello');
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(platform.cancelCalls, 0);
      expect(SpeechToTextController.instance.isListening, isTrue);

      // Stopping hands the field back to the send button.
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump(const Duration(seconds: 3));

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('stopping before the engine reports anything still fills the field', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            enableSpeechToText: true,
            onSendPressed: (_, _, _) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await settle(tester);

      // Stopped within the first couple of seconds, before any partial — on a
      // Galaxy A05s the first one takes ~3.3s.
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settle(tester);

      expect(SpeechToTextController.instance.isListening, isFalse);
      expect(controller.text, isEmpty);

      // The engine's final result, which is the whole dictation.
      platform.emitWords('hello there', isFinal: true);
      await settle(tester);

      expect(controller.text, 'hello there');

      // Past the window in which a result is still accepted.
      await tester.pump(const Duration(seconds: 3));
      platform.emitWords('too late', isFinal: true);
      await settle(tester);

      expect(controller.text, 'hello there');
    });

    testWidgets('a rebuilt mic button still drives the session', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      Widget build(Key key) => _wrap(
        ChatComposer(
          key: key,
          controller: controller,
          enableSpeechToText: true,
          onSendPressed: (_, _, _) {},
        ),
      );

      // A new key forces a fresh State for the composer and its mic button.
      await tester.pumpWidget(build(const ValueKey('first')));
      await tester.pumpWidget(build(const ValueKey('second')));
      await settle(tester);

      // The session is owned by the process, not by the button, so a rebuilt
      // mic still reflects and controls it — every instance after the first
      // used to render a mic that no status callback ever reached.
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await settle(tester);

      expect(SpeechToTextController.instance.isListening, isTrue);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      await endSession(tester);
    });

    testWidgets('dictation appends to text already in the field', (tester) async {
      final controller = ChatComposerController(initialText: 'typed');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            enableSpeechToText: true,
            onSendPressed: (_, _, _) {},
          ),
        ),
      );

      // With content in the field the trailing control is the send button, so
      // reach the mic through a custom slot — the same widget the composer
      // builds, just placed where content doesn't displace it.
      await tester.pumpWidget(_wrap(SpeechToTextButton(controller: controller)));
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await settle(tester);

      platform.emitWords('and spoken');
      await settle(tester);

      expect(controller.text, 'typed and spoken');

      await endSession(tester);
    });

    testWidgets('disposing the composer cancels the session', (tester) async {
      await tester.pumpWidget(
        _wrap(ChatComposer(enableSpeechToText: true, onSendPressed: (_, _, _) {})),
      );

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await settle(tester);
      expect(SpeechToTextController.instance.isListening, isTrue);

      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      expect(platform.cancelCalls, 1);
      expect(SpeechToTextController.instance.isListening, isFalse);
    });
  });
}
