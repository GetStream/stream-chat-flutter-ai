import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_method_channel.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/messages.g.dart' as wire;
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

import 'fake_host_api.dart';

void main() {
  test('reply sends the instructions, turns and answer length to the platform', () async {
    final channels = methodChannelPlatform();
    _reply(channels.platform).listen(null);
    await pumpEventQueue();

    final request = channels.hostApi.started.values.single;
    expect(request.instructions, 'Be brief.');
    expect(request.maximumResponseTokens, 256);
    expect(
      [for (final turn in request.turns) (turn.role, turn.text)],
      [(wire.TurnRoleMessage.assistant, 'Hello!'), (wire.TurnRoleMessage.user, 'Hi?')],
    );
  });

  test('reply streams the answer sent for its id and closes when it is done', () async {
    final channels = methodChannelPlatform();
    final answers = expectLater(_reply(channels.platform), emitsInOrder(['Hel', 'Hello there', emitsDone]));
    await pumpEventQueue();

    final id = channels.hostApi.started.keys.single;
    channels.replyEvents
      ..add(wire.ReplyText(requestId: id, text: 'Hel'))
      ..add(wire.ReplyText(requestId: id, text: 'Hello there'))
      ..add(wire.ReplyDone(requestId: id));
    await answers;
  });

  test("reply ignores another reply's answer", () async {
    final channels = methodChannelPlatform();
    final answers = <String>[];
    _reply(channels.platform).listen(answers.add);
    await pumpEventQueue();

    channels.replyEvents.add(wire.ReplyText(requestId: 'other', text: 'Not mine'));
    await pumpEventQueue();
    expect(answers, isEmpty);
  });

  test('reply routes two replies by their ids', () async {
    final channels = methodChannelPlatform();
    final first = expectLater(_reply(channels.platform, 'One?'), emitsInOrder(['1', emitsDone]));
    final second = expectLater(_reply(channels.platform, 'Two?'), emitsInOrder(['2', emitsDone]));
    await pumpEventQueue();

    final ids = {for (final MapEntry(:key, :value) in channels.hostApi.started.entries) value.turns.last.text: key};
    channels.replyEvents
      ..add(wire.ReplyText(requestId: ids['Two?']!, text: '2'))
      ..add(wire.ReplyText(requestId: ids['One?']!, text: '1'))
      ..add(wire.ReplyDone(requestId: ids['One?']!))
      ..add(wire.ReplyDone(requestId: ids['Two?']!));
    await Future.wait([first, second]);
  });

  test('reply ids differ between instances, so a reply from before a hot restart never matches', () async {
    final first = methodChannelPlatform();
    final second = MethodChannelAIOnDeviceModel(
      hostApi: first.hostApi,
      replyEvents: () => first.replyEvents.stream,
      downloadEvents: () => first.downloadEvents.stream,
      isSupported: true,
    );
    _reply(first.platform).listen(null);
    _reply(second).listen(null);
    await pumpEventQueue();

    final [a, b] = first.hostApi.started.keys.toList();
    expect(a.split('-').first, isNot(b.split('-').first));
  });

  for (final (reason, expected) in [
    ('unavailable', AILocalModelErrorReason.unavailable),
    ('contextExceeded', AILocalModelErrorReason.contextExceeded),
    ('invalidConversation', AILocalModelErrorReason.invalidConversation),
    ('failed', AILocalModelErrorReason.failed),
    ('somethingNew', AILocalModelErrorReason.failed),
  ]) {
    test("reply maps a '$reason' failure to $expected, with the platform's error as the cause", () async {
      final channels = methodChannelPlatform();
      final answers = expectLater(
        _reply(channels.platform),
        emitsInOrder([
          emitsError(failsWith(expected, cause: const AIOnDeviceError('CODE', 'It broke.'))),
          emitsDone,
        ]),
      );
      await pumpEventQueue();

      final id = channels.hostApi.started.keys.single;
      channels.replyEvents.add(wire.ReplyFailed(requestId: id, reason: reason, code: 'CODE', message: 'It broke.'));
      await answers;
    });
  }

  test('reply is stopped on the platform when the subscription is cancelled', () async {
    final channels = methodChannelPlatform();
    final subscription = _reply(channels.platform).listen(null);
    await pumpEventQueue();
    final id = channels.hostApi.started.keys.single;

    await subscription.cancel();
    expect(channels.hostApi.calls, contains('cancelReply $id'));
  });

  test('reply ignores what the platform sends after it was cancelled', () async {
    final channels = methodChannelPlatform();
    final answers = <String>[];
    final subscription = _reply(channels.platform).listen(answers.add);
    await pumpEventQueue();
    final id = channels.hostApi.started.keys.single;

    await subscription.cancel();
    channels.replyEvents.add(wire.ReplyText(requestId: id, text: 'Late'));
    await pumpEventQueue();
    expect(answers, isEmpty);
  });

  test('reply is not cancelled on the platform once it is done', () async {
    final channels = methodChannelPlatform();
    final subscription = _reply(channels.platform).listen(null);
    await pumpEventQueue();
    final id = channels.hostApi.started.keys.single;
    channels.replyEvents.add(wire.ReplyDone(requestId: id));
    await pumpEventQueue();

    await subscription.cancel();
    expect(channels.hostApi.calls, isNot(contains('cancelReply $id')));
  });

  test('reply listens to the channel only while a reply is in progress', () async {
    final channels = methodChannelPlatform();
    expect(channels.replyEvents.hasListener, isFalse);
    final answers = expectLater(_reply(channels.platform), emitsInOrder(['A', emitsDone]));
    await pumpEventQueue();
    expect(channels.replyEvents.hasListener, isTrue);

    final id = channels.hostApi.started.keys.single;
    channels.replyEvents
      ..add(wire.ReplyText(requestId: id, text: 'A'))
      ..add(wire.ReplyDone(requestId: id));
    await answers;
    expect(channels.replyEvents.hasListener, isFalse);
  });

  test('reply fails as unavailable when nothing handles the channel', () async {
    final channels = methodChannelPlatform();
    // What Pigeon throws when no platform code listens.
    channels.hostApi.startReplyError = PlatformException(code: 'channel-error');
    await expectLater(
      _reply(channels.platform),
      emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
    );
  });

  test('reply fails when the platform refuses to start', () async {
    final channels = methodChannelPlatform();
    channels.hostApi.startReplyError = PlatformException(code: 'busy', message: 'Busy.');
    await expectLater(
      _reply(channels.platform),
      emitsInOrder([
        emitsError(failsWith(AILocalModelErrorReason.failed, cause: const AIOnDeviceError('busy', 'Busy.'))),
        emitsDone,
      ]),
    );
  });

  test('reply fails every reply in progress when the channel fails', () async {
    final channels = methodChannelPlatform();
    final failed = emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.failed)), emitsDone]);
    final first = expectLater(_reply(channels.platform, 'One?'), failed);
    final second = expectLater(_reply(channels.platform, 'Two?'), failed);
    await pumpEventQueue();

    channels.replyEvents.addError(PlatformException(code: 'boom'));
    await Future.wait([first, second]);
  });

  test('reply on a platform without the plugin fails as unavailable without using the channels', () async {
    final channels = methodChannelPlatform(isSupported: false);
    await expectLater(
      _reply(channels.platform),
      emitsInOrder([emitsError(failsWith(AILocalModelErrorReason.unavailable)), emitsDone]),
    );
    expect(channels.hostApi.calls, isEmpty);
    expect(channels.replyEvents.hasListener, isFalse);
  });
}

Stream<String> _reply(MethodChannelAIOnDeviceModel platform, [String question = 'Hi?']) => platform.reply(
  instructions: 'Be brief.',
  turns: [const AIConversationTurn.assistant('Hello!'), AIConversationTurn.user(question)],
  maximumResponseTokens: 256,
);
