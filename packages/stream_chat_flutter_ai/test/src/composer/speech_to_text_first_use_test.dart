import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// The first-use paths: the permission prompt, and what happens when it is
/// declined.
///
/// A file of their own because `SpeechToText` is a process-wide singleton that
/// latches on its first *successful* `initialize` and never calls the platform
/// again — so these are only reachable before any other test has initialized.
/// `flutter test` gives each file its own isolate. Within the file the order
/// matters too, and is called out where it does.
class _FakeSpeechPlatform extends SpeechToTextPlatform {
  int initCalls = 0;
  int listenCalls = 0;

  /// What the next `initialize` reports. `false` is what the plugin returns
  /// when the user declines the permission prompt.
  bool initResult = true;

  /// Held open to keep `initialize` in flight, standing in for the seconds the
  /// prompt is on screen.
  Completer<void>? initGate;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize({Object? debugLogging = false, List<SpeechConfigOption>? options}) async {
    initCalls++;
    await initGate?.future;
    return initResult;
  }

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
    return true;
  }

  @override
  Future<void> stop() async => onStatus?.call(SpeechToText.notListeningStatus);

  @override
  Future<void> cancel() async => onStatus?.call(SpeechToText.notListeningStatus);
}

void main() {
  final platform = _FakeSpeechPlatform();
  setUpAll(() => SpeechToTextPlatform.instance = platform);
  tearDown(SpeechToTextController.instance.debugReset);

  final controller = SpeechToTextController.instance;

  // Runs first, and deliberately never succeeds: a success here would latch the
  // plugin and make the two tests below unreachable.
  test('concurrent callers share one initialize', () async {
    final gate = Completer<void>();
    platform
      ..initResult = false
      ..initGate = gate;

    final first = controller.ensureInitialized();
    final second = controller.ensureInitialized();
    gate.complete();

    expect(await first, isFalse);
    expect(await second, isFalse);
    expect(platform.initCalls, 1, reason: 'the second caller awaits the prompt already on screen');

    platform.initGate = null;
  });

  test('a declined permission prompt does not disable the recognizer for good', () async {
    platform.initResult = false;
    final callsBefore = platform.initCalls;

    expect(await controller.ensureInitialized(), isFalse);
    expect(controller.isAvailable, isFalse);
    expect(platform.initCalls, callsBefore + 1);

    // The user grants access in Settings and comes back. Caching the refusal
    // alongside a success left the mic dead for the life of the process, which
    // is stricter than `speech_to_text` itself — it retries after a failure.
    platform.initResult = true;

    expect(await controller.ensureInitialized(), isTrue);
    expect(controller.isAvailable, isTrue);
    expect(platform.initCalls, callsBefore + 2);

    // ...and now that it has worked, it isn't asked again.
    expect(await controller.ensureInitialized(), isTrue);
    expect(platform.initCalls, callsBefore + 2);
  });

  test('tapping twice before the first session starts listens once', () async {
    // Neither `isListening` nor `isAvailable` is set until after the
    // `ensureInitialized` await, so the second call used to sail past both
    // checks and reach the platform — two overlapping `listen()` calls, which a
    // real engine rejects as busy while the UI still shows a live session.
    final callsBefore = platform.listenCalls;

    final first = controller.start(onWords: (_) {});
    final second = controller.start(onWords: (_) {});

    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(platform.listenCalls, callsBefore + 1);

    await controller.cancel();
  });

  testWidgets('the mic re-checks availability when the app comes back to the foreground', (tester) async {
    final composerController = ChatComposerController();
    addTearDown(composerController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SpeechToTextButton(controller: composerController)),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    expect(controller.isAvailable, isNotNull);
    await controller.cancel();
    await tester.pump(const Duration(seconds: 3));

    // Going to Settings and back is how a user who declined the prompt changes
    // their mind. Whatever the last attempt concluded has to be forgotten, or
    // `isAvailable == false` keeps the mic disabled for the life of the process.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.isAvailable, isNull, reason: 'unknown again, so the next tap asks the platform');
  });
}
