import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _icons = StreamIcons();
const _managerChannel = MethodChannel('com.fluttercandies/photo_manager');
const _pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
const _title = 'Photos not added';
const _message =
    "Some photos couldn't be loaded. If they're stored online, check your internet connection and try again.";

/// Whether `AssetEntity.file` reaches the platform on this host; elsewhere it
/// asserts instead of returning.
final _hostResolvesAssetFiles = Platform.isMacOS || Platform.isIOS || Platform.isAndroid;

/// Mocks a gallery holding one photo, whose file resolves to what [fullFile]
/// returns or throws.
void _mockGallery(WidgetTester tester, {required Future<Object?> Function() fullFile}) {
  final messenger = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(_managerChannel, (call) async {
      switch (call.method) {
        case 'requestPermissionExtend':
          return PermissionState.authorized.index;
        case 'getAssetPathList':
          return {
            'data': [
              {'id': 'all', 'name': 'Recent', 'isAll': true, 'assetCount': 1},
            ],
          };
        case 'getAssetCountFromPath':
          return 1;
        case 'getAssetListRange':
          return {
            'data': [
              {'id': 'photo-1', 'type': 1, 'width': 10, 'height': 10},
            ],
          };
        case 'getFullFile':
          return fullFile();
      }
      return null;
    });
  addTearDown(() => messenger.setMockMethodCallHandler(_managerChannel, null));
}

void _mockPicker(WidgetTester tester, Future<Object?> Function(MethodCall call) handler) {
  final messenger = tester.binding.defaultBinaryMessenger..setMockMethodCallHandler(_pickerChannel, handler);
  addTearDown(() => messenger.setMockMethodCallHandler(_pickerChannel, null));
}

Future<ChatComposerController> _pumpSheet(WidgetTester tester) async {
  debugClearAssetPathCache();
  final controller = ChatComposerController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ComposerAttachmentSheet(controller: controller)),
    ),
  );
  await tester.pump();
  await tester.pump();
  return controller;
}

Finder get _photoTile => find.descendant(of: find.byType(ListView), matching: find.byType(InkWell)).at(1);

/// Runs [act], returning what the sheet reported meanwhile.
///
/// The handler is put back before the caller's `expect`s: a failed expectation
/// is itself reported through it.
Future<List<FlutterErrorDetails>> _collectErrors(Future<void> Function() act) async {
  final reported = <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await act();
  } finally {
    FlutterError.onError = original;
  }
  return reported;
}

Future<void> _tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a recent photo with no file shows the photos-not-added notice', (tester) async {
    // `testWidgets` takes only a flag for `skip:`, so the reason goes here.
    if (!_hostResolvesAssetFiles) {
      markTestSkipped('AssetEntity.file asserts on hosts other than macOS, iOS and Android.');
      return;
    }
    _mockGallery(tester, fullFile: () async => null);
    final controller = await _pumpSheet(tester);

    await tester.tap(_photoTile);
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(controller.attachments, isEmpty);
  });

  testWidgets('a recent photo whose file fails to load shows the notice and reports the error', (tester) async {
    _mockGallery(tester, fullFile: () async => throw PlatformException(code: 'icloud'));
    final controller = await _pumpSheet(tester);

    final reported = await _collectErrors(() => _tapAndSettle(tester, _photoTile));

    expect(find.text(_title), findsOneWidget);
    expect(reported, hasLength(1));
    expect(reported.single.library, 'stream_chat_flutter_ai');
    expect(controller.attachments, isEmpty);
  });

  testWidgets('a library picker that throws shows the notice and reports the error', (tester) async {
    _mockGallery(tester, fullFile: () async => null);
    _mockPicker(tester, (call) async => throw PlatformException(code: 'photo_access_denied'));
    await _pumpSheet(tester);

    final reported = await _collectErrors(() => _tapAndSettle(tester, find.text('All Photos')));

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(reported, hasLength(1));
  });

  testWidgets('a camera that fails reports the error and shows no photos notice', (tester) async {
    _mockGallery(tester, fullFile: () async => null);
    _mockPicker(tester, (call) async => throw PlatformException(code: 'camera_access_denied'));
    await _pumpSheet(tester);

    final reported = await _collectErrors(() => _tapAndSettle(tester, find.byIcon(_icons.camera)));

    expect(find.text(_title), findsNothing);
    expect(reported, hasLength(1));
  });

  testWidgets('a cancelled library picker shows nothing', (tester) async {
    _mockGallery(tester, fullFile: () async => null);
    _mockPicker(tester, (call) async => null);
    await _pumpSheet(tester);

    final reported = await _collectErrors(() => _tapAndSettle(tester, find.text('All Photos')));

    expect(find.text(_title), findsNothing);
    expect(reported, isEmpty);
  });

  testWidgets('the notice is dismissed with its OK button', (tester) async {
    _mockGallery(tester, fullFile: () async => null);
    _mockPicker(tester, (call) async => throw PlatformException(code: 'photo_access_denied'));
    await _pumpSheet(tester);

    await _collectErrors(() => _tapAndSettle(tester, find.text('All Photos')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
  });
}
