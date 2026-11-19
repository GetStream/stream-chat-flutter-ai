import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_status.dart';

/// What the on-device model is and can take, read before every reply.
@internal
@immutable
final class AIOnDeviceModelInfo {
  /// Info about a model in [status] with a context of [contextSize] tokens,
  /// writing at most [maxResponseTokens] per answer.
  const AIOnDeviceModelInfo({required this.status, required this.contextSize, this.maxResponseTokens});

  /// Where the model is on this device.
  final AIOnDeviceStatus status;

  /// The number of tokens the model reads and writes in one reply.
  final int contextSize;

  /// The longest answer the model writes, or `null` when it has no cap of its
  /// own.
  final int? maxResponseTokens;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIOnDeviceModelInfo &&
          other.status == status &&
          other.contextSize == contextSize &&
          other.maxResponseTokens == maxResponseTokens;

  @override
  int get hashCode => Object.hash(status, contextSize, maxResponseTokens);

  @override
  String toString() =>
      'AIOnDeviceModelInfo(status: $status, contextSize: $contextSize, maxResponseTokens: $maxResponseTokens)';
}
