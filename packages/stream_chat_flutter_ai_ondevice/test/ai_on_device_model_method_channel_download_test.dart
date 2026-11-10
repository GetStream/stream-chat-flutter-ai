import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/messages.g.dart' as wire;
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

import 'fake_host_api.dart';

void main() {
  test('download starts on the platform when listened to', () async {
    final channels = methodChannelPlatform();
    channels.platform.download().listen(null);
    await pumpEventQueue();
    expect(channels.hostApi.calls, ['startDownload']);
  });

  test('download maps the progress, then closes after it completes', () async {
    final channels = methodChannelPlatform();
    final events = expectLater(
      channels.platform.download(),
      emitsInOrder([
        const AIOnDeviceDownloadStarted(bytesToDownload: 100),
        const AIOnDeviceDownloadProgress(bytesDownloaded: 40),
        const AIOnDeviceDownloadCompleted(),
        emitsDone,
      ]),
    );
    await pumpEventQueue();

    channels.downloadEvents
      ..add(wire.DownloadStarted(bytesToDownload: 100))
      ..add(wire.DownloadProgress(bytesDownloaded: 40))
      ..add(wire.DownloadCompleted(done: true));
    await events;
  });

  test('download stops listening to the channel, and cancels nothing, once it completes', () async {
    final channels = methodChannelPlatform();
    final events = expectLater(channels.platform.download(), emitsThrough(emitsDone));
    await pumpEventQueue();

    channels.downloadEvents.add(wire.DownloadCompleted(done: true));
    await events;
    expect(channels.downloadEvents.hasListener, isFalse);
    expect(channels.hostApi.calls, isNot(contains('cancelDownload')));
  });

  test('download reports a failure as an event, then closes', () async {
    final channels = methodChannelPlatform();
    final events = expectLater(
      channels.platform.download(),
      emitsInOrder([
        _failedWith(
          AILocalModelErrorReason.unavailable,
          cause: const AIOnDeviceError('NOT_ENOUGH_DISK_SPACE', 'Full.'),
        ),
        emitsDone,
      ]),
    );
    await pumpEventQueue();

    channels.downloadEvents.add(
      wire.DownloadFailed(reason: 'unavailable', code: 'NOT_ENOUGH_DISK_SPACE', message: 'Full.'),
    );
    await events;
  });

  test('download fails as unavailable when nothing handles the channel', () async {
    final channels = methodChannelPlatform();
    channels.hostApi.startDownloadError = PlatformException(code: 'channel-error');
    await expectLater(
      channels.platform.download(),
      emitsInOrder([_failedWith(AILocalModelErrorReason.unavailable), emitsDone]),
    );
  });

  test('download is stopped on the platform when the subscription is cancelled', () async {
    final channels = methodChannelPlatform();
    final subscription = channels.platform.download().listen(null);
    await pumpEventQueue();

    await subscription.cancel();
    expect(channels.hostApi.calls, ['startDownload', 'cancelDownload']);
    expect(channels.downloadEvents.hasListener, isFalse);
  });

  test('a second download joins the first, and both hear how it ends', () async {
    final channels = methodChannelPlatform();
    final ends = emitsInOrder([
      const AIOnDeviceDownloadProgress(bytesDownloaded: 10),
      const AIOnDeviceDownloadCompleted(),
      emitsDone,
    ]);
    final first = expectLater(channels.platform.download(), ends);
    final second = expectLater(channels.platform.download(), ends);
    await pumpEventQueue();
    expect(channels.hostApi.calls, ['startDownload']);

    channels.downloadEvents
      ..add(wire.DownloadProgress(bytesDownloaded: 10))
      ..add(wire.DownloadCompleted(done: true));
    await Future.wait([first, second]);
  });

  test('a download that joins late starts from the latest start and progress', () async {
    final channels = methodChannelPlatform();
    channels.platform.download().listen(null);
    await pumpEventQueue();
    channels.downloadEvents
      ..add(wire.DownloadStarted(bytesToDownload: 100))
      ..add(wire.DownloadProgress(bytesDownloaded: 10))
      ..add(wire.DownloadProgress(bytesDownloaded: 30));
    await pumpEventQueue();

    final events = <AIOnDeviceDownload>[];
    channels.platform.download().listen(events.add);
    await pumpEventQueue();
    expect(events, [
      const AIOnDeviceDownloadStarted(bytesToDownload: 100),
      const AIOnDeviceDownloadProgress(bytesDownloaded: 30),
    ]);
  });

  test('download keeps going while another stream still listens to it', () async {
    final channels = methodChannelPlatform();
    final first = channels.platform.download().listen(null);
    final events = <AIOnDeviceDownload>[];
    channels.platform.download().listen(events.add);
    await pumpEventQueue();

    await first.cancel();
    channels.downloadEvents.add(wire.DownloadProgress(bytesDownloaded: 5));
    await pumpEventQueue();
    expect(channels.hostApi.calls, isNot(contains('cancelDownload')));
    expect(events, [const AIOnDeviceDownloadProgress(bytesDownloaded: 5)]);
  });

  test('download stops once the last stream listening to it is cancelled', () async {
    final channels = methodChannelPlatform();
    final first = channels.platform.download().listen(null);
    final second = channels.platform.download().listen(null);
    await pumpEventQueue();

    await first.cancel();
    await second.cancel();
    expect(channels.hostApi.calls, ['startDownload', 'cancelDownload']);
  });

  test('a download started right after one is cancelled reaches the platform after the cancel', () async {
    final channels = methodChannelPlatform();
    final first = channels.platform.download().listen(null);
    await pumpEventQueue();

    // A retry: the old download is cancelled and a new one started at once.
    final cancelled = first.cancel();
    channels.platform.download().listen(null);
    await cancelled;
    await pumpEventQueue();
    expect(channels.hostApi.calls, ['startDownload', 'cancelDownload', 'startDownload']);
  });

  test('download on a platform without the plugin fails as unavailable without using the channels', () async {
    final channels = methodChannelPlatform(isSupported: false);
    await expectLater(
      channels.platform.download(),
      emitsInOrder([_failedWith(AILocalModelErrorReason.unavailable), emitsDone]),
    );
    expect(channels.hostApi.calls, isEmpty);
    expect(channels.downloadEvents.hasListener, isFalse);
  });
}

Matcher _failedWith(AILocalModelErrorReason reason, {Object? cause}) =>
    isA<AIOnDeviceDownloadFailed>().having((failed) => failed.error, 'error', failsWith(reason, cause: cause));
