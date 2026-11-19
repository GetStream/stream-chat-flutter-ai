import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_method_channel.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/messages.g.dart' as wire;
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

import 'fake_host_api.dart';

const _prefix = 'dev.flutter.pigeon.stream_chat_flutter_ai_ondevice';
const _replyChannel = EventChannel('$_prefix.OnDeviceModelEventApi.replyEvents', wire.pigeonMethodCodec);
const _codec = wire.OnDeviceModelHostApi.pigeonChannelCodec;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("modelInfo maps the platform's answer", () async {
    final channels = methodChannelPlatform();
    expect(
      await channels.platform.modelInfo(),
      const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4000, maxResponseTokens: 256),
    );
  });

  test('modelInfo maps a model with no answer cap of its own', () async {
    final channels = methodChannelPlatform();
    channels.hostApi.info = wire.ModelInfoMessage(status: wire.ModelStatusMessage.downloadable, contextSize: 4096);
    expect(
      await channels.platform.modelInfo(),
      const AIOnDeviceModelInfo(status: AIOnDeviceStatus.downloadable, contextSize: 4096),
    );
  });

  test('modelInfo on a platform without the plugin is unavailable', () async {
    final channels = methodChannelPlatform(isSupported: false);
    expect((await channels.platform.modelInfo()).status, AIOnDeviceStatus.unavailable);
  });

  test('modelInfo round-trips through the generated channel', () async {
    _mockHostApi(
      'modelInfo',
      (_) => wire.ModelInfoMessage(status: wire.ModelStatusMessage.available, contextSize: 4096),
    );
    expect(
      await MethodChannelAIOnDeviceModel().modelInfo(),
      const AIOnDeviceModelInfo(status: AIOnDeviceStatus.available, contextSize: 4096),
    );
  });

  test('a reply round-trips through the generated channels', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? sink;
    messenger.setMockStreamHandler(_replyChannel, MockStreamHandler.inline(onListen: (_, events) => sink = events));
    addTearDown(() => messenger.setMockStreamHandler(_replyChannel, null));
    wire.ReplyRequestMessage? request;
    _mockHostApi('startReply', (arguments) {
      final [id as String, sent as wire.ReplyRequestMessage] = arguments;
      request = sent;
      sink!
        ..success(wire.ReplyText(requestId: id, text: 'Hello'))
        ..success(wire.ReplyDone(requestId: id));
      return null;
    });

    await expectLater(
      MethodChannelAIOnDeviceModel().reply(
        instructions: '',
        turns: [const AIConversationTurn.user('Hi?')],
        maximumResponseTokens: 100,
      ),
      emitsInOrder(['Hello', emitsDone]),
    );
    expect(request?.turns.single.text, 'Hi?');
  });
}

// Answers the host API's [method] with what [handle] returns, until the test
// ends.
void _mockHostApi(String method, Object? Function(List<Object?> arguments) handle) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = '$_prefix.OnDeviceModelHostApi.$method';
  messenger.setMockMessageHandler(channel, (message) async {
    final arguments = message == null ? const <Object?>[] : _codec.decodeMessage(message)! as List<Object?>;
    return _codec.encodeMessage(<Object?>[handle(arguments)]);
  });
  addTearDown(() => messenger.setMockMessageHandler(channel, null));
}
