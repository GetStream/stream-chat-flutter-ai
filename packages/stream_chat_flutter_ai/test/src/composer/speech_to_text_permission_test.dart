import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_core_flutter/core.dart';

const _icons = StreamIcons();
const _notice = 'Microphone permission is required to record audio';

/// A platform whose recognizer never initializes, the way it doesn't once the
/// permission prompt is declined.
///
/// A file of its own, and every test here declines: `SpeechToText` latches on
/// its first successful `initialize` and stops asking the platform, which would
/// leave later tests here deaf.
class _DecliningSpeechPlatform extends SpeechToTextPlatform {
  int initCalls = 0;

  /// Thrown by `initialize` when set, the way the plugin reports a device with
  /// no speech recognizer on Android 12 and later.
  Exception? initializeError;

  /// What `hasPermission` reports: `false` is a denied permission, `true` is a
  /// device that has permission but no recognizer.
  bool permissionGranted = false;

  /// Thrown by `hasPermission` when set.
  Exception? permissionError;

  @override
  Future<bool> hasPermission() async {
    final error = permissionError;
    if (error != null) throw error;
    return permissionGranted;
  }

  @override
  Future<bool> initialize({Object? debugLogging = false, List<SpeechConfigOption>? options}) async {
    initCalls++;
    final error = initializeError;
    if (error != null) throw error;
    return false;
  }

  @override
  Future<void> stop() async => onStatus?.call(SpeechToText.notListeningStatus);

  @override
  Future<void> cancel() async => onStatus?.call(SpeechToText.notListeningStatus);
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Installs a fresh declining platform for the calling test.
_DecliningSpeechPlatform _installPlatform() {
  final platform = _DecliningSpeechPlatform();
  SpeechToTextPlatform.instance = platform;
  SpeechToTextController.instance.debugReset();
  addTearDown(SpeechToTextController.instance.debugReset);
  return platform;
}

void main() {
  testWidgets('a denied tap calls onPermissionDenied and shows no notice', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    var denied = 0;

    await tester.pumpWidget(
      _wrap(
        SpeechToTextButton(
          controller: controller,
          config: SpeechToTextConfig(onPermissionDenied: () => denied++),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();

    expect(denied, 1);
    expect(find.text(_notice), findsNothing);
  });

  testWidgets('a denied tap without onPermissionDenied shows the notice with a Settings action', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(SpeechToTextButton(controller: controller)));
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();

    expect(find.text(_notice), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the notice action opens the system settings', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    final opened = <String>[];
    const channel = MethodChannel('com.fluttercandies/photo_manager');
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(channel, (call) async {
        opened.add(call.method);
        return null;
      });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(_wrap(SpeechToTextButton(controller: controller)));
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(opened, ['openSetting']);
  });

  testWidgets('the notice shows in a StreamSnackbarMessenger when there is one', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamSnackbarScope(
          child: Scaffold(
            body: Center(child: SpeechToTextButton(controller: controller)),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(StreamSnackbar), findsOneWidget);
    expect(find.text(_notice), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets("a composer's notice floats above it, clear of its buttons", (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              ChatComposer(controller: controller, onSendPressed: (_, _, _) {}, enableSpeechToText: true),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(_notice), findsOneWidget, reason: 'it stays until it is dismissed');
    final notice = tester.getRect(find.byType(StreamSnackbar));
    expect(notice.bottom, lessThanOrEqualTo(tester.getRect(find.byType(ChatComposer)).top));
  });

  testWidgets('the notice without a StreamSnackbarMessenger floats, stays and can be closed', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(SpeechToTextButton(controller: controller)));
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.showCloseIcon, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsNothing);
  });

  testWidgets('the notice stays until it is dismissed', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamSnackbarScope(
          child: Scaffold(
            body: Center(child: SpeechToTextButton(controller: controller)),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    expect(find.text(_notice), findsOneWidget);
  });

  testWidgets('shows no notice when nothing can host it', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Material(child: SpeechToTextButton(controller: controller)),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_notice), findsNothing);
  });

  testWidgets('a mic disabled after a denial still reports the denial on tap', (tester) async {
    final platform = _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    var denied = 0;

    await tester.pumpWidget(
      _wrap(
        SpeechToTextButton(
          controller: controller,
          config: SpeechToTextConfig(onPermissionDenied: () => denied++),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    expect(SpeechToTextController.instance.isAvailable, isFalse);

    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();

    expect(denied, 2);
    expect(platform.initCalls, 2, reason: 'each tap asks the platform again, so a grant in Settings is picked up');
  });

  testWidgets('a device with no recognizer is not a denial', (tester) async {
    final platform = _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    platform.permissionGranted = true;
    var denied = 0;

    await tester.pumpWidget(
      _wrap(
        SpeechToTextButton(
          controller: controller,
          config: SpeechToTextConfig(onPermissionDenied: () => denied++),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();

    expect(denied, 0);
    expect(find.text(_notice), findsNothing);
    expect(platform.initCalls, 1, reason: 'the mic is disabled after the first tap');
  });

  testWidgets('a permission check that fails is not a denial', (tester) async {
    final platform = _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    platform.permissionError = PlatformException(code: 'unavailable');
    var denied = 0;

    await tester.pumpWidget(
      _wrap(
        SpeechToTextButton(
          controller: controller,
          config: SpeechToTextConfig(onPermissionDenied: () => denied++),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();

    expect(denied, 0);
  });

  testWidgets('returning to the app lets a tap ask the platform again', (tester) async {
    _installPlatform();
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(SpeechToTextButton(controller: controller)));
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    expect(SpeechToTextController.instance.isPermissionDenied, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(SpeechToTextController.instance.isAvailable, isNull);
    expect(SpeechToTextController.instance.isPermissionDenied, isFalse);
  });

  testWidgets('a recognizer that is not available throws no error and is not a denial', (tester) async {
    final platform = _installPlatform()..initializeError = PlatformException(code: 'recognizerNotAvailable');
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    var denied = 0;
    final reported = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(
      _wrap(
        SpeechToTextButton(
          controller: controller,
          config: SpeechToTextConfig(onPermissionDenied: () => denied++),
        ),
      ),
    );
    await tester.tap(find.byIcon(_icons.voice));
    await tester.pump();
    FlutterError.onError = original;

    expect(tester.takeException(), isNull);
    expect(reported, hasLength(1));
    expect(reported.single.library, 'stream_chat_flutter_ai');
    expect(SpeechToTextController.instance.isAvailable, isFalse);
    expect(SpeechToTextController.instance.isPermissionDenied, isFalse);
    expect(denied, 0);
    expect(platform.initCalls, 1);
  });
}
