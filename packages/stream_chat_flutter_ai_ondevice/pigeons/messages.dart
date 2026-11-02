import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    swiftOut: 'darwin/stream_chat_flutter_ai_ondevice/Sources/stream_chat_flutter_ai_ondevice/Messages.g.swift',
    kotlinOut: 'android/src/main/kotlin/io/getstream/stream_chat_flutter_ai_ondevice/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.getstream.stream_chat_flutter_ai_ondevice'),
    dartPackageName: 'stream_chat_flutter_ai_ondevice',
  ),
)
/// Where the model is on this device.
enum ModelStatusMessage { unavailable, downloadable, downloading, available }

/// Who said a turn.
enum TurnRoleMessage { user, assistant }

/// One turn of the conversation.
class TurnMessage {
  TurnMessage({required this.role, required this.text});

  final TurnRoleMessage role;
  final String text;
}

/// What the model is and can take, read before every reply.
class ModelInfoMessage {
  ModelInfoMessage({required this.status, required this.contextSize, required this.maxResponseTokens});

  final ModelStatusMessage status;

  /// The tokens the model reads and writes in one reply.
  final int contextSize;

  /// The longest answer the model writes, or null when it has no cap of its
  /// own.
  final int? maxResponseTokens;
}

/// A reply to start: the turns are already fitted to the model's context and
/// end with the person's question.
class ReplyRequestMessage {
  ReplyRequestMessage({required this.instructions, required this.turns, required this.maximumResponseTokens});

  final String instructions;
  final List<TurnMessage> turns;
  final int maximumResponseTokens;
}

/// An event of a reply started with [OnDeviceModelHostApi.startReply].
sealed class ReplyEvent {}

/// The whole answer so far.
class ReplyText extends ReplyEvent {
  ReplyText({required this.requestId, required this.text});

  final String requestId;
  final String text;
}

/// The answer is complete.
class ReplyDone extends ReplyEvent {
  ReplyDone({required this.requestId});

  final String requestId;
}

/// The model couldn't answer. [reason] is an `AILocalModelErrorReason` name;
/// [code] is the platform's own error, for logs.
class ReplyFailed extends ReplyEvent {
  ReplyFailed({required this.requestId, required this.reason, required this.code, required this.message});

  final String requestId;
  final String reason;
  final String code;
  final String message;
}

/// An event of a download started with [OnDeviceModelHostApi.startDownload].
sealed class DownloadEvent {}

/// The download started.
class DownloadStarted extends DownloadEvent {
  DownloadStarted({required this.bytesToDownload});

  final int? bytesToDownload;
}

/// The download is under way.
class DownloadProgress extends DownloadEvent {
  DownloadProgress({required this.bytesDownloaded, required this.fraction});

  final int? bytesDownloaded;
  final double? fraction;
}

/// The model is on the device.
class DownloadCompleted extends DownloadEvent {
  DownloadCompleted({required this.done});

  // Pigeon needs at least one field.
  final bool done;
}

/// The download failed. [reason] is an `AILocalModelErrorReason` name.
class DownloadFailed extends DownloadEvent {
  DownloadFailed({required this.reason, required this.code, required this.message});

  final String reason;
  final String code;
  final String message;
}

@HostApi()
abstract class OnDeviceModelHostApi {
  /// Where the model is, and the context and answer length it takes.
  @async
  ModelInfoMessage modelInfo();

  /// Starts answering [request]. Returns at once; the answer arrives on
  /// [OnDeviceModelEventApi.replyEvents] under [requestId].
  void startReply(String requestId, ReplyRequestMessage request);

  /// Stops the reply [requestId]. Nothing more is sent for it.
  void cancelReply(String requestId);

  /// Starts downloading the model. Progress arrives on
  /// [OnDeviceModelEventApi.downloadEvents].
  void startDownload();

  /// Stops the download.
  void cancelDownload();
}

@EventChannelApi()
abstract class OnDeviceModelEventApi {
  ReplyEvent replyEvents();
  DownloadEvent downloadEvents();
}
