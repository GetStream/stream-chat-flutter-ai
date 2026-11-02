import 'package:flutter/foundation.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// The platform's own error behind an [AILocalModelException], set as its
/// [AILocalModelException.cause].
///
/// For logs and bug reports. Consider branching on
/// [AILocalModelException.reason] instead: the codes differ between Android and
/// Apple's platforms, and may change.
@immutable
final class AIOnDeviceError {
  /// An error with the platform's [code], described by [message].
  const AIOnDeviceError(this.code, this.message);

  /// The platform's name for the error, such as ML Kit's `BUSY` or Foundation
  /// Models' `exceededContextWindowSize`.
  final String code;

  /// The platform's description of the error.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIOnDeviceError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'AIOnDeviceError($code): $message';
}
