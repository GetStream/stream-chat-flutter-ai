import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model.dart';

/// How a download of the on-device model is going, as
/// [AIOnDeviceModel.download] reports it.
///
/// More kinds of event may be added, so a `switch` over them needs a default
/// case.
@immutable
abstract final class AIOnDeviceDownload {
  const AIOnDeviceDownload._();
}

/// The download started.
final class AIOnDeviceDownloadStarted extends AIOnDeviceDownload {
  /// A download of [bytesToDownload] bytes started.
  const AIOnDeviceDownloadStarted({this.bytesToDownload}) : super._();

  /// The size of the download, or `null` when the platform doesn't say.
  final int? bytesToDownload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIOnDeviceDownloadStarted && other.bytesToDownload == bytesToDownload;

  @override
  int get hashCode => bytesToDownload.hashCode;

  @override
  String toString() => 'AIOnDeviceDownloadStarted(bytesToDownload: $bytesToDownload)';
}

/// The download is under way.
final class AIOnDeviceDownloadProgress extends AIOnDeviceDownload {
  /// [bytesDownloaded] bytes of the download, or [fraction] of it, are done.
  const AIOnDeviceDownloadProgress({this.bytesDownloaded, this.fraction}) : super._();

  /// The bytes downloaded so far, or `null` when the platform reports only a
  /// [fraction].
  final int? bytesDownloaded;

  /// How much of the download is done, from 0 to 1, or `null` when the
  /// platform reports only [bytesDownloaded].
  final double? fraction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIOnDeviceDownloadProgress && other.bytesDownloaded == bytesDownloaded && other.fraction == fraction;

  @override
  int get hashCode => Object.hash(bytesDownloaded, fraction);

  @override
  String toString() => 'AIOnDeviceDownloadProgress(bytesDownloaded: $bytesDownloaded, fraction: $fraction)';
}

/// The model is on the device and can answer. The stream closes after it.
final class AIOnDeviceDownloadCompleted extends AIOnDeviceDownload {
  /// The download completed.
  const AIOnDeviceDownloadCompleted() : super._();

  @override
  bool operator ==(Object other) => other is AIOnDeviceDownloadCompleted;

  @override
  int get hashCode => (AIOnDeviceDownloadCompleted).hashCode;

  @override
  String toString() => 'AIOnDeviceDownloadCompleted()';
}

/// The download failed. The stream closes after it; the model is still
/// downloadable, so the person can try again.
final class AIOnDeviceDownloadFailed extends AIOnDeviceDownload {
  /// The download failed with [error].
  const AIOnDeviceDownloadFailed(this.error) : super._();

  /// Why the download failed.
  final AILocalModelException error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIOnDeviceDownloadFailed && other.error.reason == error.reason && other.error.cause == error.cause;

  @override
  int get hashCode => Object.hash(error.reason, error.cause);

  @override
  String toString() => 'AIOnDeviceDownloadFailed($error)';
}
