import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_method_channel.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/messages.g.dart' as wire;

/// A host API that records what it is asked, without a platform behind it.
class FakeHostApi extends wire.OnDeviceModelHostApi {
  wire.ModelInfoMessage info = wire.ModelInfoMessage(
    status: wire.ModelStatusMessage.available,
    contextSize: 4000,
    maxResponseTokens: 256,
  );
  Exception? startReplyError;
  Exception? startDownloadError;

  /// Every call, in the order the platform would receive it.
  final calls = <String>[];
  final started = <String, wire.ReplyRequestMessage>{};

  @override
  Future<wire.ModelInfoMessage> modelInfo() async => info;

  @override
  Future<void> startReply(String requestId, wire.ReplyRequestMessage request) async {
    calls.add('startReply $requestId');
    if (startReplyError case final error?) throw error;
    started[requestId] = request;
  }

  @override
  Future<void> cancelReply(String requestId) async => calls.add('cancelReply $requestId');

  @override
  Future<void> startDownload() async {
    calls.add('startDownload');
    if (startDownloadError case final error?) throw error;
  }

  @override
  Future<void> cancelDownload() async => calls.add('cancelDownload');
}

/// The fake channels a [MethodChannelAIOnDeviceModel] under test talks to.
typedef FakeChannels = ({
  MethodChannelAIOnDeviceModel platform,
  FakeHostApi hostApi,
  StreamController<wire.ReplyEvent> replyEvents,
  StreamController<wire.DownloadEvent> downloadEvents,
});

/// A [MethodChannelAIOnDeviceModel] over fake channels, closed when the test
/// ends.
FakeChannels methodChannelPlatform({bool isSupported = true}) {
  final hostApi = FakeHostApi();
  final replyEvents = StreamController<wire.ReplyEvent>.broadcast();
  final downloadEvents = StreamController<wire.DownloadEvent>.broadcast();
  addTearDown(replyEvents.close);
  addTearDown(downloadEvents.close);
  return (
    platform: MethodChannelAIOnDeviceModel(
      hostApi: hostApi,
      replyEvents: () => replyEvents.stream,
      downloadEvents: () => downloadEvents.stream,
      isSupported: isSupported,
    ),
    hostApi: hostApi,
    replyEvents: replyEvents,
    downloadEvents: downloadEvents,
  );
}

/// An [AILocalModelException] with [reason], and [cause] when given.
Matcher failsWith(AILocalModelErrorReason reason, {Object? cause}) => isA<AILocalModelException>()
    .having((error) => error.reason, 'reason', reason)
    .having((error) => error.cause, 'cause', cause ?? anything);
