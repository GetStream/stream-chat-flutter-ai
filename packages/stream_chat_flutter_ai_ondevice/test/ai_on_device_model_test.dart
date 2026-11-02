import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_platform.dart';
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

/// A platform that reports [info] and records the replies it is asked for.
class FakePlatform extends AIOnDeviceModelPlatform {
  FakePlatform({this.info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4096)});

  AIOnDeviceModelInfo info;
  Exception? infoError;
  Completer<void>? infoGate;

  final requests = <({String instructions, List<AIConversationTurn> turns, int maximumResponseTokens})>[];

  /// The answer to the latest reply; each reply gets a new one.
  // Closed by the tests that finish a reply.
  // ignore: close_sinks
  StreamController<String> answer = StreamController<String>();
  bool replyCancelled = false;

  /// Makes [reply] throw an [Error], as a broken implementation might.
  bool replyThrows = false;

  // Closed by the download test.
  // ignore: close_sinks
  final downloads = StreamController<AIOnDeviceDownload>();

  @override
  Future<AIOnDeviceModelInfo> modelInfo() async {
    await infoGate?.future;
    if (infoError case final error?) throw error;
    return info;
  }

  @override
  Stream<String> reply({
    required String instructions,
    required List<AIConversationTurn> turns,
    required int maximumResponseTokens,
  }) {
    if (replyThrows) throw UnimplementedError('reply');
    requests.add((instructions: instructions, turns: turns, maximumResponseTokens: maximumResponseTokens));
    answer = StreamController<String>(onCancel: () => replyCancelled = true);
    return answer.stream;
  }

  @override
  Stream<AIOnDeviceDownload> download() => downloads.stream;
}

void main() {
  late FakePlatform platform;

  setUp(() => AIOnDeviceModelPlatform.instance = platform = FakePlatform());

  Matcher failsWith(AILocalModelErrorReason reason) =>
      isA<AILocalModelException>().having((error) => error.reason, 'reason', reason);

  group('status', () {
    test('is what the platform reports', () async {
      for (final status in AIOnDeviceStatus.values) {
        platform.info = AIOnDeviceModelInfo(status: status, contextSize: 4096);
        expect(await const AIOnDeviceModel().status(), status);
        expect(await const AIOnDeviceModel().isAvailable, status == AIOnDeviceStatus.available);
      }
    });

    test('is unavailable when the platform fails', () async {
      platform.infoError = PlatformException(code: 'boom');
      expect(await const AIOnDeviceModel().status(), AIOnDeviceStatus.unavailable);
      expect(await const AIOnDeviceModel().isAvailable, isFalse);

      platform.infoError = MissingPluginException();
      expect(await const AIOnDeviceModel().status(), AIOnDeviceStatus.unavailable);
    });
  });

  group('reply', () {
    test('streams the whole answer so far and closes when the model is done', () async {
      final answers = const AIOnDeviceModel().reply(
        instructions: 'Be brief.',
        turns: [const AIConversationTurn.user('Hi?')],
      );
      final events = expectLater(answers, emitsInOrder(['Hel', 'Hello!', emitsDone]));
      await pumpEventQueue();
      platform.answer
        ..add('Hel')
        ..add('Hello!');
      await platform.answer.close();
      await events;

      final request = platform.requests.single;
      expect(request.instructions, 'Be brief.');
      expect(request.turns, [const AIConversationTurn.user('Hi?')]);
      expect(request.maximumResponseTokens, 1000);
    });

    test("caps the answer at the model's own limit", () async {
      platform.info = const AIOnDeviceModelInfo(
        status: AIOnDeviceStatus.available,
        contextSize: 4000,
        maxResponseTokens: 256,
      );
      const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]).listen(null);
      await pumpEventQueue();
      expect(platform.requests.single.maximumResponseTokens, 256);

      platform.requests.clear();
      const AIOnDeviceModel(
        maximumResponseTokens: 100,
      ).reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]).listen(null);
      await pumpEventQueue();
      expect(platform.requests.single.maximumResponseTokens, 100);
    });

    test('sends the newest turns that fit the context', () async {
      // 4096 context - 1000 answer - 50 framing leaves 3046 tokens.
      final long = 'word ' * 2000; // 3334 tokens.
      final turns = [
        AIConversationTurn.user(long),
        const AIConversationTurn.assistant('Noted.'),
        const AIConversationTurn.user('Hi?'),
        const AIConversationTurn.user('Anyone?'),
      ];
      const AIOnDeviceModel().reply(instructions: 'Be brief.', turns: turns).listen(null);
      await pumpEventQueue();

      expect(platform.requests.single.turns, [
        const AIConversationTurn.assistant('Noted.'),
        const AIConversationTurn.user('Hi?\n\nAnyone?'),
      ]);
      expect(
        platform.requests.single.turns,
        AIConversationTurn.fitToBudget(turns, maxTokens: 4096 - 1000 - 50, instructions: 'Be brief.'),
      );
    });

    test('fails as unavailable without asking the model when it is not available', () async {
      for (final status in [
        AIOnDeviceStatus.unavailable,
        AIOnDeviceStatus.downloadable,
        AIOnDeviceStatus.downloading,
      ]) {
        platform.info = AIOnDeviceModelInfo(status: status, contextSize: 4096);
        await expectLater(
          const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]),
          emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
        );
      }
      expect(platform.requests, isEmpty);
    });

    test("fails as unavailable when the platform can't tell", () async {
      platform.infoError = MissingPluginException();
      await expectLater(
        const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
      );
    });

    test('fails as an invalid conversation when it does not end with a question', () async {
      for (final turns in [
        <AIConversationTurn>[],
        [const AIConversationTurn.user('  ')],
        [const AIConversationTurn.user('Hi?'), const AIConversationTurn.assistant('Hello!')],
      ]) {
        await expectLater(
          const AIOnDeviceModel().reply(instructions: '', turns: turns),
          emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.invalidConversation)), emitsDone]),
        );
      }
      expect(platform.requests, isEmpty);
    });

    test('fails as context exceeded when the answer alone fills the context', () async {
      platform.info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 1000);
      await expectLater(
        const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.contextExceeded)), emitsDone]),
      );
      expect(platform.requests, isEmpty);
    });

    test("passes the model's failure on", () async {
      final answers = const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]);
      final events = expectLater(
        answers,
        emitsInOrder(['Hel', emitsError(failsWith(AILocalModelErrorReason.failed)), emitsDone]),
      );
      await pumpEventQueue();
      platform.answer
        ..add('Hel')
        ..addError(const AILocalModelException(AILocalModelErrorReason.failed, 'refused'));
      await platform.answer.close();
      await events;
    });

    test('cancelling the subscription stops the model', () async {
      final subscription = const AIOnDeviceModel()
          .reply(
            instructions: '',
            turns: [const AIConversationTurn.user('Hi?')],
          )
          .listen(null);
      await pumpEventQueue();
      expect(platform.requests, hasLength(1));

      await subscription.cancel();
      expect(platform.replyCancelled, isTrue);
    });

    test('cancelling before the model is checked never starts it', () async {
      platform.infoGate = Completer<void>();
      final subscription = const AIOnDeviceModel()
          .reply(
            instructions: '',
            turns: [const AIConversationTurn.user('Hi?')],
          )
          .listen(null);
      await pumpEventQueue();
      await subscription.cancel();

      platform.infoGate!.complete();
      await pumpEventQueue();
      expect(platform.requests, isEmpty);
    });

    test('fails, and closes, when the platform throws an Error', () async {
      platform.replyThrows = true;
      await expectLater(
        const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.failed)), emitsDone]),
      );
    });

    test('starts nothing until listened to', () async {
      const AIOnDeviceModel().reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]);
      await pumpEventQueue();
      expect(platform.requests, isEmpty);
    });
  });

  test("download passes the platform's events on", () async {
    final events = expectLater(
      const AIOnDeviceModel().download(),
      emitsInOrder([
        const AIOnDeviceDownloadStarted(bytesToDownload: 100),
        const AIOnDeviceDownloadProgress(bytesDownloaded: 50),
        const AIOnDeviceDownloadCompleted(),
        emitsDone,
      ]),
    );
    platform.downloads
      ..add(const AIOnDeviceDownloadStarted(bytesToDownload: 100))
      ..add(const AIOnDeviceDownloadProgress(bytesDownloaded: 50))
      ..add(const AIOnDeviceDownloadCompleted());
    await platform.downloads.close();
    await events;
  });
}
