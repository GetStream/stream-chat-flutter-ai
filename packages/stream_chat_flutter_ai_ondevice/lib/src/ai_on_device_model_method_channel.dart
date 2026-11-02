import 'dart:async';
import 'dart:math';

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
/// There is one download at a time: every [download] stream shares it, and it
/// stops once none of them is listened to.
///
/// On platforms without the plugin (web, Windows, Linux) the model is
/// unavailable and the channels are never used.
///
/// Internal to the package.
@internal
class MethodChannelAIOnDeviceModel extends AIOnDeviceModelPlatform {
  /// Constructs a [MethodChannelAIOnDeviceModel].
  ///
  /// [hostApi], [replyEvents], [downloadEvents] and [isSupported] are exposed
  /// for tests to substitute the generated channels and the platform check.
  MethodChannelAIOnDeviceModel({
    wire.OnDeviceModelHostApi? hostApi,
    Stream<wire.ReplyEvent> Function()? replyEvents,
    Stream<wire.DownloadEvent> Function()? downloadEvents,
    bool? isSupported,
  }) : _hostApi = hostApi ?? wire.OnDeviceModelHostApi(),
       _replyEvents = replyEvents ?? wire.replyEvents,
       _downloadEvents = downloadEvents ?? wire.downloadEvents,
       _isSupported = isSupported ?? _hasPlugin;

  final wire.OnDeviceModelHostApi _hostApi;
  final Stream<wire.ReplyEvent> Function() _replyEvents;
  final Stream<wire.DownloadEvent> Function() _downloadEvents;
  final bool _isSupported;

  // The platforms with a native side: anywhere else a channel call would fail.
  static bool get _hasPlugin =>
      !kIsWeb &&
      const {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}.contains(defaultTargetPlatform);

  final _replies = <String, StreamController<String>>{};
  StreamSubscription<wire.ReplyEvent>? _replySubscription;
  var _nextReplyId = 0;

  // Native replies outlive a hot restart, which starts this count again: the
  // prefix keeps a new reply's id from matching one still running.
  final _replyIdPrefix = Random().nextInt(1 << 32).toRadixString(36);

  final _downloads = <StreamController<AIOnDeviceDownload>>{};
  StreamSubscription<wire.DownloadEvent>? _downloadSubscription;

  static const _unsupported = AILocalModelException(
    AILocalModelErrorReason.unavailable,
    'There is no on-device model on this platform.',
  );

  @override
  Future<AIOnDeviceModelInfo> modelInfo() async {
    if (!_isSupported) return const AIOnDeviceModelInfo(status: AIOnDeviceStatus.unavailable, contextSize: 0);
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
    if (!_isSupported) return Stream.error(_unsupported);
    final id = '$_replyIdPrefix-${_nextReplyId++}';
    // Closed when the reply ends: by `_end` on done, failure or cancel.
    // ignore: close_sinks
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        _replies[id] = controller;
        // Listened to before the reply starts, so its first event isn't missed:
        // the listen and `startReply` travel on different channels, but the
        // platform handles both in the order they were sent, on its main thread.
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
    if (!_isSupported) return Stream.value(const AIOnDeviceDownloadFailed(_unsupported));
    late final StreamController<AIOnDeviceDownload> controller;
    controller = StreamController<AIOnDeviceDownload>(
      onListen: () {
        _downloads.add(controller);
        if (_downloadSubscription != null) return; // Joins the download in progress.
        _downloadSubscription = _downloadEvents().listen(
          (event) => switch (event) {
            wire.DownloadStarted(:final bytesToDownload) => _broadcastDownload(
              AIOnDeviceDownloadStarted(bytesToDownload: bytesToDownload),
            ),
            wire.DownloadProgress(:final bytesDownloaded, :final fraction) => _broadcastDownload(
              AIOnDeviceDownloadProgress(bytesDownloaded: bytesDownloaded, fraction: fraction),
            ),
            wire.DownloadCompleted() => _finishDownload(const AIOnDeviceDownloadCompleted()),
            wire.DownloadFailed(:final reason, :final code, :final message) => _finishDownload(
              AIOnDeviceDownloadFailed(_failure(reason, code, message)),
            ),
          },
          onError: (Object error) => _finishDownload(AIOnDeviceDownloadFailed(_exception(error))),
        );
        _hostApi.startDownload().catchError(
          (Object error) => _finishDownload(AIOnDeviceDownloadFailed(_exception(error))),
        );
      },
      onCancel: () async {
        // Already gone when the download finished.
        if (!_downloads.remove(controller) || _downloads.isNotEmpty) return;
        final cancelled = _downloadSubscription?.cancel();
        _downloadSubscription = null;
        await cancelled;
        await _hostApi.cancelDownload().catchError((Object _) {});
      },
    );
    return controller.stream;
  }

  void _broadcastDownload(AIOnDeviceDownload event) {
    for (final controller in _downloads) {
      controller.add(event);
    }
  }

  // Ends the download for everyone listening to it.
  void _finishDownload(AIOnDeviceDownload last) {
    if (_downloadSubscription == null) return;
    unawaited(_downloadSubscription?.cancel());
    _downloadSubscription = null;
    final controllers = _downloads.toList();
    _downloads.clear();
    for (final controller in controllers) {
      controller.add(last);
      unawaited(controller.close());
    }
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

  // A channel error. No plugin listening on the channel means no model here:
  // Pigeon reports that as a `channel-error`, an event channel as a
  // MissingPluginException.
  static AILocalModelException _exception(Object error) {
    return switch (error) {
      PlatformException(code: 'channel-error') || MissingPluginException() => AILocalModelException(
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
