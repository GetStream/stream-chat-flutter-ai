import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_download.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_error.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_platform.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_status.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/messages.g.dart' as wire;

/// An implementation of [AIOnDeviceModelPlatform] that uses a Pigeon-generated
/// platform channel.
///
/// A reply's answer arrives on one event channel shared by all replies, so
/// each reply has an id and its events are routed by it. The channel is
/// listened to while a reply is in progress.
///
/// Internal to the package.
@internal
class MethodChannelAIOnDeviceModel extends AIOnDeviceModelPlatform {
  /// Constructs a [MethodChannelAIOnDeviceModel].
  ///
  /// [hostApi], [replyEvents] and [downloadEvents] are exposed for tests to
  /// substitute the generated channels.
  MethodChannelAIOnDeviceModel({
    wire.OnDeviceModelHostApi? hostApi,
    Stream<wire.ReplyEvent> Function()? replyEvents,
    Stream<wire.DownloadEvent> Function()? downloadEvents,
  }) : _hostApi = hostApi ?? wire.OnDeviceModelHostApi(),
       _replyEvents = replyEvents ?? wire.replyEvents,
       _downloadEvents = downloadEvents ?? wire.downloadEvents;

  final wire.OnDeviceModelHostApi _hostApi;
  final Stream<wire.ReplyEvent> Function() _replyEvents;
  final Stream<wire.DownloadEvent> Function() _downloadEvents;

  final _replies = <String, StreamController<String>>{};
  StreamSubscription<wire.ReplyEvent>? _replySubscription;
  var _nextReplyId = 0;

  @override
  Future<AIOnDeviceModelInfo> modelInfo() async {
    final info = await _hostApi.modelInfo();
    return AIOnDeviceModelInfo(
      status: _status(info.status),
      contextSize: info.contextSize,
      maxResponseTokens: info.maxResponseTokens,
    );
  }

  @override
  Stream<String> reply({
    required String instructions,
    required List<AIConversationTurn> turns,
    required int maximumResponseTokens,
  }) {
    final id = '${_nextReplyId++}';
    // Closed when the reply ends: by `_end` on done, failure or cancel.
    // ignore: close_sinks
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        _replies[id] = controller;
        // Listened to before the reply starts, so its first event isn't missed:
        // messages on one channel reach the platform in the order they're sent.
        _replySubscription ??= _replyEvents().listen(_onReplyEvent, onError: _onReplyChannelError);
        final request = wire.ReplyRequestMessage(
          instructions: instructions,
          turns: [
            for (final turn in turns) wire.TurnMessage(role: _role(turn.role), text: turn.text),
          ],
          maximumResponseTokens: maximumResponseTokens,
        );
        _hostApi.startReply(id, request).catchError((Object error) => _fail(id, _exception(error)));
      },
      onCancel: () {
        if (_end(id) == null) return null;
        return _hostApi.cancelReply(id).catchError((Object _) {});
      },
    );
    return controller.stream;
  }

  @override
  Stream<AIOnDeviceDownload> download() {
    StreamSubscription<wire.DownloadEvent>? subscription;
    late final StreamController<AIOnDeviceDownload> controller;
    var finished = false;

    void finish(AIOnDeviceDownload last) {
      if (finished) return;
      finished = true;
      controller.add(last);
      unawaited(subscription?.cancel());
      unawaited(controller.close());
    }

    controller = StreamController<AIOnDeviceDownload>(
      onListen: () {
        subscription = _downloadEvents().listen(
          (event) {
            switch (event) {
              case wire.DownloadStarted(:final bytesToDownload):
                controller.add(AIOnDeviceDownloadStarted(bytesToDownload: bytesToDownload));
              case wire.DownloadProgress(:final bytesDownloaded, :final fraction):
                controller.add(AIOnDeviceDownloadProgress(bytesDownloaded: bytesDownloaded, fraction: fraction));
              case wire.DownloadCompleted():
                finish(const AIOnDeviceDownloadCompleted());
              case wire.DownloadFailed(:final reason, :final code, :final message):
                finish(AIOnDeviceDownloadFailed(_failure(reason, code, message)));
            }
          },
          onError: (Object error) => finish(AIOnDeviceDownloadFailed(_exception(error))),
        );
        _hostApi.startDownload().catchError((Object error) => finish(AIOnDeviceDownloadFailed(_exception(error))));
      },
      onCancel: () async {
        await subscription?.cancel();
        if (finished) return;
        finished = true;
        await _hostApi.cancelDownload().catchError((Object _) {});
      },
    );
    return controller.stream;
  }

  void _onReplyEvent(wire.ReplyEvent event) {
    switch (event) {
      case wire.ReplyText(:final requestId, :final text):
        _replies[requestId]?.add(text);
      case wire.ReplyDone(:final requestId):
        unawaited(_end(requestId)?.close());
      case wire.ReplyFailed(:final requestId, :final reason, :final code, :final message):
        _fail(requestId, _failure(reason, code, message));
    }
  }

  // The channel itself failed: no reply in progress can finish.
  void _onReplyChannelError(Object error) {
    for (final id in _replies.keys.toList()) {
      _fail(id, _exception(error));
    }
  }

  void _fail(String id, AILocalModelException error) {
    final controller = _end(id);
    if (controller == null) return;
    controller.addError(error);
    unawaited(controller.close());
  }

  // Forgets reply [id], and stops listening to the channel once no reply is in
  // progress. Returns its controller, or null when it had already ended.
  StreamController<String>? _end(String id) {
    final controller = _replies.remove(id);
    if (_replies.isEmpty) {
      unawaited(_replySubscription?.cancel());
      _replySubscription = null;
    }
    return controller;
  }

  static AIOnDeviceStatus _status(wire.ModelStatusMessage status) => switch (status) {
    wire.ModelStatusMessage.unavailable => AIOnDeviceStatus.unavailable,
    wire.ModelStatusMessage.downloadable => AIOnDeviceStatus.downloadable,
    wire.ModelStatusMessage.downloading => AIOnDeviceStatus.downloading,
    wire.ModelStatusMessage.available => AIOnDeviceStatus.available,
  };

  static wire.TurnRoleMessage _role(AIConversationRole role) => switch (role) {
    AIConversationRole.user => wire.TurnRoleMessage.user,
    AIConversationRole.assistant => wire.TurnRoleMessage.assistant,
  };

  static AILocalModelException _failure(String reason, String code, String message) {
    return AILocalModelException(
      AILocalModelErrorReason.values.asNameMap()[reason] ?? AILocalModelErrorReason.failed,
      message,
      cause: AIOnDeviceError(code, message),
    );
  }

  // A channel error: no plugin on this platform means no model here.
  static AILocalModelException _exception(Object error) {
    return switch (error) {
      MissingPluginException() => AILocalModelException(
        AILocalModelErrorReason.unavailable,
        'There is no on-device model on this platform.',
        cause: error,
      ),
      PlatformException(:final code, :final message) => AILocalModelException(
        AILocalModelErrorReason.failed,
        message ?? code,
        cause: AIOnDeviceError(code, message ?? ''),
      ),
      _ => AILocalModelException(AILocalModelErrorReason.failed, '$error', cause: error),
    };
  }
}
