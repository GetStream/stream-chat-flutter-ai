import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_method_channel.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/messages.g.dart' as wire;
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

/// A host API that records what it is asked, without a platform behind it.
class FakeHostApi extends wire.OnDeviceModelHostApi {
  wire.ModelInfoMessage info = wire.ModelInfoMessage(
    status: wire.ModelStatusMessage.available,
    contextSize: 4000,
    maxResponseTokens: 256,
  );
  Exception? startReplyError;
  Exception? startDownloadError;

  final started = <String, wire.ReplyRequestMessage>{};
  final cancelled = <String>[];
  int downloadsStarted = 0;
  int downloadsCancelled = 0;

  @override
  Future<wire.ModelInfoMessage> modelInfo() async => info;

  @override
  Future<void> startReply(String requestId, wire.ReplyRequestMessage request) async {
    if (startReplyError case final error?) throw error;
    started[requestId] = request;
  }

  @override
  Future<void> cancelReply(String requestId) async => cancelled.add(requestId);

  @override
  Future<void> startDownload() async {
    if (startDownloadError case final error?) throw error;
    downloadsStarted++;
  }

  @override
  Future<void> cancelDownload() async => downloadsCancelled++;
}

void main() {
  late FakeHostApi hostApi;
  // Closed in tearDown.
  // ignore: close_sinks
  late StreamController<wire.ReplyEvent> replyEvents;
  // ignore: close_sinks
  late StreamController<wire.DownloadEvent> downloadEvents;
  late MethodChannelAIOnDeviceModel platform;

  setUp(() {
    hostApi = FakeHostApi();
    replyEvents = StreamController<wire.ReplyEvent>.broadcast();
    downloadEvents = StreamController<wire.DownloadEvent>.broadcast();
    platform = MethodChannelAIOnDeviceModel(
      hostApi: hostApi,
      replyEvents: () => replyEvents.stream,
      downloadEvents: () => downloadEvents.stream,
    );
  });

  tearDown(() async {
    await replyEvents.close();
    await downloadEvents.close();
  });

  Matcher failsWith(AILocalModelErrorReason reason, {Object? cause}) => isA<AILocalModelException>()
      .having((error) => error.reason, 'reason', reason)
      .having((error) => error.cause, 'cause', cause ?? anything);

  Stream<String> reply([String question = 'Hi?']) => platform.reply(
    instructions: 'Be brief.',
    turns: [const AIConversationTurn.assistant('Hello!'), AIConversationTurn.user(question)],
    maximumResponseTokens: 256,
  );

  test("modelInfo maps the platform's answer", () async {
    expect(
      await platform.modelInfo(),
      const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4000, maxResponseTokens: 256),
    );
    hostApi.info = wire.ModelInfoMessage(status: wire.ModelStatusMessage.downloadable, contextSize: 4096);
    expect(
      await platform.modelInfo(),
      const AIOnDeviceModelInfo(status: AIOnDeviceStatus.downloadable, contextSize: 4096),
    );
  });

  group('reply', () {
    test('sends the request and streams the answer for its id', () async {
      final events = expectLater(reply(), emitsInOrder(['Hel', 'Hello there', emitsDone]));
      await pumpEventQueue();

      final MapEntry(key: id, value: request) = hostApi.started.entries.single;
      expect(request.instructions, 'Be brief.');
      expect(request.maximumResponseTokens, 256);
      expect(
        [for (final turn in request.turns) (turn.role, turn.text)],
        [
          (wire.TurnRoleMessage.assistant, 'Hello!'),
          (wire.TurnRoleMessage.user, 'Hi?'),
        ],
      );

      replyEvents
        ..add(wire.ReplyText(requestId: id, text: 'Hel'))
        ..add(wire.ReplyText(requestId: 'other', text: 'Not mine'))
        ..add(wire.ReplyText(requestId: id, text: 'Hello there'))
        ..add(wire.ReplyDone(requestId: id));
      await events;
    });

    test('routes two replies by their ids', () async {
      final first = expectLater(reply('One?'), emitsInOrder(['1', emitsDone]));
      final second = expectLater(reply('Two?'), emitsInOrder(['2', emitsDone]));
      await pumpEventQueue();

      final ids = {for (final MapEntry(:key, :value) in hostApi.started.entries) value.turns.last.text: key};
      replyEvents
        ..add(wire.ReplyText(requestId: ids['Two?']!, text: '2'))
        ..add(wire.ReplyText(requestId: ids['One?']!, text: '1'))
        ..add(wire.ReplyDone(requestId: ids['One?']!))
        ..add(wire.ReplyDone(requestId: ids['Two?']!));
      await Future.wait([first, second]);
    });

    test("maps a failure to its reason, with the platform's error as the cause", () async {
      for (final (reason, expected) in [
        ('unavailable', AILocalModelErrorReason.unavailable),
        ('contextExceeded', AILocalModelErrorReason.contextExceeded),
        ('invalidConversation', AILocalModelErrorReason.invalidConversation),
        ('failed', AILocalModelErrorReason.failed),
        ('somethingNew', AILocalModelErrorReason.failed),
      ]) {
        final events = expectLater(
          reply(),
          emitsInOrder([
            emitsError(failsWith(expected, cause: const AIOnDeviceError('CODE', 'It broke.'))),
            emitsDone,
          ]),
        );
        await pumpEventQueue();
        final id = hostApi.started.keys.last;
        replyEvents.add(wire.ReplyFailed(requestId: id, reason: reason, code: 'CODE', message: 'It broke.'));
        await events;
      }
    });

    test('cancelling stops the reply on the platform and ignores what follows', () async {
      final answers = <String>[];
      final subscription = reply().listen(answers.add);
      await pumpEventQueue();
      final id = hostApi.started.keys.single;

      await subscription.cancel();
      expect(hostApi.cancelled, [id]);

      replyEvents.add(wire.ReplyText(requestId: id, text: 'Late'));
      await pumpEventQueue();
      expect(answers, isEmpty);
    });

    test('a finished reply is not cancelled on the platform', () async {
      final subscription = reply().listen(null);
      await pumpEventQueue();
      replyEvents.add(wire.ReplyDone(requestId: hostApi.started.keys.single));
      await pumpEventQueue();

      await subscription.cancel();
      expect(hostApi.cancelled, isEmpty);
    });

    test('listens to the channel only while a reply is in progress', () async {
      expect(replyEvents.hasListener, isFalse);
      final events = expectLater(reply(), emitsInOrder(['A', emitsDone]));
      await pumpEventQueue();
      expect(replyEvents.hasListener, isTrue);

      final id = hostApi.started.keys.single;
      replyEvents
        ..add(wire.ReplyText(requestId: id, text: 'A'))
        ..add(wire.ReplyDone(requestId: id));
      await events;
      expect(replyEvents.hasListener, isFalse);
    });

    test('fails as unavailable when the platform has no plugin', () async {
      hostApi.startReplyError = MissingPluginException();
      await expectLater(
        reply(),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
      );
    });

    test('fails when the platform refuses to start', () async {
      hostApi.startReplyError = PlatformException(code: 'busy', message: 'Busy.');
      await expectLater(
        reply(),
        emitsInOrder([
          emitsError(failsWith(AILocalModelErrorReason.failed, cause: const AIOnDeviceError('busy', 'Busy.'))),
          emitsDone,
        ]),
      );
    });

    test('fails every reply in progress when the channel fails', () async {
      final events = expectLater(
        reply(),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.failed)), emitsDone]),
      );
      await pumpEventQueue();
      replyEvents.addError(PlatformException(code: 'channel-error'));
      await events;
    });
  });

  group('download', () {
    test('starts on listen and maps progress until it completes', () async {
      final events = expectLater(
        platform.download(),
        emitsInOrder([
          const AIOnDeviceDownloadStarted(bytesToDownload: 100),
          const AIOnDeviceDownloadProgress(bytesDownloaded: 40),
          const AIOnDeviceDownloadProgress(fraction: 0.5),
          const AIOnDeviceDownloadCompleted(),
          emitsDone,
        ]),
      );
      await pumpEventQueue();
      expect(hostApi.downloadsStarted, 1);

      downloadEvents
        ..add(wire.DownloadStarted(bytesToDownload: 100))
        ..add(wire.DownloadProgress(bytesDownloaded: 40))
        ..add(wire.DownloadProgress(fraction: 0.5))
        ..add(wire.DownloadCompleted(done: true));
      await events;
      expect(downloadEvents.hasListener, isFalse);
      expect(hostApi.downloadsCancelled, 0);
    });

    test('reports a failure as an event, then closes', () async {
      final events = expectLater(
        platform.download(),
        emitsInOrder([
          isA<AIOnDeviceDownloadFailed>().having(
            (failed) => failed.error,
            'error',
            failsWith(
              AILocalModelErrorReason.unavailable,
              cause: const AIOnDeviceError('NOT_ENOUGH_DISK_SPACE', 'Full.'),
            ),
          ),
          emitsDone,
        ]),
      );
      await pumpEventQueue();
      downloadEvents.add(wire.DownloadFailed(reason: 'unavailable', code: 'NOT_ENOUGH_DISK_SPACE', message: 'Full.'));
      await events;
    });

    test('reports the platform refusing to start as a failure', () async {
      hostApi.startDownloadError = MissingPluginException();
      await expectLater(
        platform.download(),
        emitsInOrder([
          isA<AIOnDeviceDownloadFailed>().having(
            (failed) => failed.error,
            'error',
            failsWith(AILocalModelErrorReason.unavailable),
          ),
          emitsDone,
        ]),
      );
    });

    test('cancelling stops the download on the platform', () async {
      final subscription = platform.download().listen(null);
      await pumpEventQueue();
      await subscription.cancel();
      expect(hostApi.downloadsCancelled, 1);
      expect(downloadEvents.hasListener, isFalse);
    });
  });

  group('over the generated channels', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const prefix = 'dev.flutter.pigeon.stream_chat_flutter_ai_ondevice';
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const replyChannel = EventChannel('$prefix.OnDeviceModelEventApi.replyEvents', wire.pigeonMethodCodec);

    tearDown(() {
      for (final name in ['modelInfo', 'startReply', 'cancelReply']) {
        messenger.setMockMessageHandler('$prefix.OnDeviceModelHostApi.$name', null);
      }
      messenger.setMockStreamHandler(replyChannel, null);
    });

    test('a reply round-trips through the codec', () async {
      const codec = wire.OnDeviceModelHostApi.pigeonChannelCodec;
      final real = MethodChannelAIOnDeviceModel();
      MockStreamHandlerEventSink? sink;
      messenger
        ..setMockStreamHandler(
          replyChannel,
          MockStreamHandler.inline(onListen: (_, events) => sink = events),
        )
        ..setMockMessageHandler('$prefix.OnDeviceModelHostApi.modelInfo', (_) async {
          return codec.encodeMessage(<Object?>[
            wire.ModelInfoMessage(status: wire.ModelStatusMessage.available, contextSize: 4096),
          ]);
        })
        ..setMockMessageHandler('$prefix.OnDeviceModelHostApi.startReply', (message) async {
          final [id as String, request as wire.ReplyRequestMessage] = codec.decodeMessage(message)! as List<Object?>;
          expect(request.turns.single.text, 'Hi?');
          sink!
            ..success(wire.ReplyText(requestId: id, text: 'Hello'))
            ..success(wire.ReplyDone(requestId: id));
          return codec.encodeMessage(<Object?>[]);
        });

      expect(
        await real.modelInfo(),
        const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4096),
      );
      await expectLater(
        real.reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')], maximumResponseTokens: 100),
        emitsInOrder(['Hello', emitsDone]),
      );
    });
  });
}
