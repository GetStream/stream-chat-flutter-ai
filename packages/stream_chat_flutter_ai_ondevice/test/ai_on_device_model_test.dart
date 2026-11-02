import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_platform.dart';
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

import 'fake_host_api.dart';

void main() {
  for (final status in AIOnDeviceStatus.values) {
    test('status reports $status when the platform does', () async {
      _installFakePlatform().info = AIOnDeviceModelInfo(status: status, contextSize: 4096);
      expect(await const AIOnDeviceModel().status(), status);
    });
  }

  test('status reports unavailable when the platform fails', () async {
    _installFakePlatform().infoError = PlatformException(code: 'boom');
    expect(await const AIOnDeviceModel().status(), AIOnDeviceStatus.unavailable);
  });

  test('status reports unavailable when there is no plugin', () async {
    _installFakePlatform().infoError = MissingPluginException();
    expect(await const AIOnDeviceModel().status(), AIOnDeviceStatus.unavailable);
  });

  test('isAvailable is true when the model is available', () async {
    _installFakePlatform();
    expect(await const AIOnDeviceModel().isAvailable, isTrue);
  });

  test('isAvailable is false when the model is downloadable', () async {
    _installFakePlatform().info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.downloadable, contextSize: 4096);
    expect(await const AIOnDeviceModel().isAvailable, isFalse);
  });

  test('isAvailable is false when the platform fails', () async {
    _installFakePlatform().infoError = PlatformException(code: 'boom');
    expect(await const AIOnDeviceModel().isAvailable, isFalse);
  });

  test('reply streams the whole answer so far and closes when the model is done', () async {
    final platform = _installFakePlatform();
    final answers = expectLater(_replyToQuestion(), emitsInOrder(['Hel', 'Hello!', emitsDone]));
    await pumpEventQueue();
    platform.answer
      ..add('Hel')
      ..add('Hello!');
    await platform.answer.close();
    await answers;
  });

  test('reply sends the instructions and turns to the platform', () async {
    final platform = _installFakePlatform();
    const AIOnDeviceModel()
        .reply(instructions: 'Be brief.', turns: [const AIConversationTurn.user('Hi?')])
        .listen(null);
    await pumpEventQueue();

    final request = platform.requests.single;
    expect(request.instructions, 'Be brief.');
    expect(request.turns, [const AIConversationTurn.user('Hi?')]);
  });

  test('reply asks for 1000 tokens by default', () async {
    final platform = _installFakePlatform();
    _replyToQuestion().listen(null);
    await pumpEventQueue();
    expect(platform.requests.single.maximumResponseTokens, 1000);
  });

  test("reply caps the answer at the model's own limit", () async {
    final platform = _installFakePlatform()
      ..info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4000, maxResponseTokens: 256);
    _replyToQuestion().listen(null);
    await pumpEventQueue();
    expect(platform.requests.single.maximumResponseTokens, 256);
  });

  test("reply keeps a cap below the model's own limit", () async {
    final platform = _installFakePlatform()
      ..info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4000, maxResponseTokens: 256);
    _replyToQuestion(const AIOnDeviceModel(maximumResponseTokens: 100)).listen(null);
    await pumpEventQueue();
    expect(platform.requests.single.maximumResponseTokens, 100);
  });

  test('reply sends the newest turns that fit the context', () async {
    final platform = _installFakePlatform();
    // 4096 context - 1000 answer - 50 framing leaves 3046 tokens; this is 3334.
    final long = 'word ' * 2000;
    const AIOnDeviceModel()
        .reply(
          instructions: 'Be brief.',
          turns: [
            AIConversationTurn.assistant(long),
            const AIConversationTurn.user('Hi?'),
            const AIConversationTurn.assistant('Hello!'),
            const AIConversationTurn.user('Anyone?'),
          ],
        )
        .listen(null);
    await pumpEventQueue();

    expect(platform.requests.single.turns, [
      const AIConversationTurn.user('Hi?'),
      const AIConversationTurn.assistant('Hello!'),
      const AIConversationTurn.user('Anyone?'),
    ]);
  });

  test('reply leaves out an answer whose question no longer fits', () async {
    final platform = _installFakePlatform();
    final long = 'word ' * 2000;
    const AIOnDeviceModel()
        .reply(
          instructions: '',
          turns: [
            AIConversationTurn.user(long),
            const AIConversationTurn.assistant('Noted.'),
            const AIConversationTurn.user('Hi?'),
          ],
        )
        .listen(null);
    await pumpEventQueue();

    expect(platform.requests.single.turns, [const AIConversationTurn.user('Hi?')]);
  });

  for (final status in [AIOnDeviceStatus.unavailable, AIOnDeviceStatus.downloadable, AIOnDeviceStatus.downloading]) {
    test('reply fails as unavailable without asking the model when it is $status', () async {
      final platform = _installFakePlatform()..info = AIOnDeviceModelInfo(status: status, contextSize: 4096);
      await expectLater(
        _replyToQuestion(),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
      );
      expect(platform.requests, isEmpty);
    });
  }

  test("reply fails as unavailable when the platform can't tell", () async {
    _installFakePlatform().infoError = MissingPluginException();
    await expectLater(
      _replyToQuestion(),
      emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
    );
  });

  for (final (name, turns) in [
    ('no turns', <AIConversationTurn>[]),
    ('only a blank question', [const AIConversationTurn.user('  ')]),
    ('an answer last', [const AIConversationTurn.user('Hi?'), const AIConversationTurn.assistant('Hello!')]),
  ]) {
    test('reply fails as an invalid conversation for $name, without asking the model', () async {
      final platform = _installFakePlatform();
      await expectLater(
        const AIOnDeviceModel().reply(instructions: '', turns: turns),
        emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.invalidConversation)), emitsDone]),
      );
      expect(platform.requests, isEmpty);
    });
  }

  test('reply fails as context exceeded when the answer alone fills the context', () async {
    final platform = _installFakePlatform()
      ..info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 1000);
    await expectLater(
      _replyToQuestion(),
      emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.contextExceeded)), emitsDone]),
    );
    expect(platform.requests, isEmpty);
  });

  test("reply passes the model's failure on", () async {
    final platform = _installFakePlatform();
    final answers = expectLater(
      _replyToQuestion(),
      emitsInOrder(['Hel', emitsError(failsWith(AILocalModelErrorReason.failed)), emitsDone]),
    );
    await pumpEventQueue();
    platform.answer
      ..add('Hel')
      ..addError(const AILocalModelException(AILocalModelErrorReason.failed, 'refused'));
    await platform.answer.close();
    await answers;
  });

  test('reply fails, and closes, when the platform throws an Error', () async {
    _installFakePlatform().replyThrows = true;
    await expectLater(
      _replyToQuestion(),
      emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.failed)), emitsDone]),
    );
  });

  test('reply stops the model when the subscription is cancelled', () async {
    final platform = _installFakePlatform();
    final subscription = _replyToQuestion().listen(null);
    await pumpEventQueue();

    await subscription.cancel();
    expect(platform.replyCancelled, isTrue);
  });

  test('reply never starts the model when cancelled before the model is checked', () async {
    final platform = _installFakePlatform()..infoGate = Completer<void>();
    final subscription = _replyToQuestion().listen(null);
    await pumpEventQueue();
    await subscription.cancel();

    platform.infoGate!.complete();
    await pumpEventQueue();
    expect(platform.requests, isEmpty);
  });

  test('reply starts nothing until listened to', () async {
    final platform = _installFakePlatform();
    _replyToQuestion();
    await pumpEventQueue();
    expect(platform.requests, isEmpty);
  });

  test("download passes the platform's events on", () async {
    final platform = _installFakePlatform();
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

// Makes a [_FakePlatform] the platform for this test, restoring the previous
// one when it ends.
_FakePlatform _installFakePlatform() {
  final previous = AIOnDeviceModelPlatform.instance;
  final platform = _FakePlatform();
  AIOnDeviceModelPlatform.instance = platform;
  addTearDown(() => AIOnDeviceModelPlatform.instance = previous);
  // Not awaited: closing a stream nobody listened to never completes.
  addTearDown(() => unawaited(platform.downloads.close()));
  return platform;
}

Stream<String> _replyToQuestion([AIOnDeviceModel model = const AIOnDeviceModel()]) =>
    model.reply(instructions: '', turns: [const AIConversationTurn.user('Hi?')]);

// A platform that reports [info] and records the replies it is asked for.
class _FakePlatform extends AIOnDeviceModelPlatform {
  AIOnDeviceModelInfo info = const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4096);
  Exception? infoError;
  Completer<void>? infoGate;

  // Makes [reply] throw an Error, as a broken implementation might.
  bool replyThrows = false;

  final requests = <({String instructions, List<AIConversationTurn> turns, int maximumResponseTokens})>[];

  // The answer to the latest reply; each reply gets a new one. Closed by the
  // tests that finish a reply.
  // ignore: close_sinks
  StreamController<String> answer = StreamController<String>();
  bool replyCancelled = false;

  // Closed when the test ends, by `_installFakePlatform`.
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
