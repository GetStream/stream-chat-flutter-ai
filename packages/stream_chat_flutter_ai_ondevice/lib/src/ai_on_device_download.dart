import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model.dart';

/// An event in a download of the on-device model, as
/// [AIOnDeviceModel.download] reports it.
///
/// More kinds of event may be added, so a `switch` over them needs a default
/// case.
@immutable
abstract final class AIOnDeviceDownload {
  const AIOnDeviceDownload._();
}

/// An event reporting that the download started.
///
/// iOS and macOS never send it: the system downloads Apple's model by itself.
final class AIOnDeviceDownloadStarted extends AIOnDeviceDownload {
  /// Creates an event for a download of [bytesToDownload] bytes.
  const AIOnDeviceDownloadStarted({required this.bytesToDownload}) : super._();

  /// The size of the download, in bytes.
  final int bytesToDownload;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIOnDeviceDownloadStarted && other.bytesToDownload == bytesToDownload;
  }

  @override
  int get hashCode => bytesToDownload.hashCode;

  @override
  String toString() => 'AIOnDeviceDownloadStarted(bytesToDownload: $bytesToDownload)';
}

/// An event reporting how far the download is.
final class AIOnDeviceDownloadProgress extends AIOnDeviceDownload {
  /// Creates an event for a download with [bytesDownloaded] bytes done.
  const AIOnDeviceDownloadProgress({required this.bytesDownloaded}) : super._();

  /// The bytes downloaded so far.
  final int bytesDownloaded;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIOnDeviceDownloadProgress && other.bytesDownloaded == bytesDownloaded;
  }

  @override
  int get hashCode => bytesDownloaded.hashCode;

  @override
  String toString() => 'AIOnDeviceDownloadProgress(bytesDownloaded: $bytesDownloaded)';
}

/// An event reporting that the model is on the device and can answer.
///
/// The stream closes after it.
final class AIOnDeviceDownloadCompleted extends AIOnDeviceDownload {
  /// Creates an event for a completed download.
  const AIOnDeviceDownloadCompleted() : super._();

  @override
  bool operator ==(Object other) => other is AIOnDeviceDownloadCompleted;

  @override
  int get hashCode => (AIOnDeviceDownloadCompleted).hashCode;

  @override
  String toString() => 'AIOnDeviceDownloadCompleted()';
}

/// An event reporting that the download failed.
///
/// The stream closes after it. The model is still downloadable, so the person
/// can try again.
final class AIOnDeviceDownloadFailed extends AIOnDeviceDownload {
  /// Creates an event for a download that failed with [error].
  const AIOnDeviceDownloadFailed(this.error) : super._();

  /// Why the download failed.
  final AILocalModelException error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIOnDeviceDownloadFailed && other.error.reason == error.reason && other.error.cause == error.cause;
  }

  @override
  int get hashCode => Object.hash(error.reason, error.cause);

  @override
  String toString() => 'AIOnDeviceDownloadFailed($error)';
}
