import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';

/// The A2UI versions this package reads, and the check every message passes
/// before it is applied.
///
/// It reads A2UI 1.0. Agents write the version in a few spellings, such as
/// `v1.0`, often copied from the label of the block they write the UI in, so
/// those count as 1.0 too.
///
/// Internal to the package.
@internal
abstract final class A2UIVersions {
  /// The version of A2UI this package reads, as A2UI 1.0 messages write it.
  static const current = '1.0';

  static const _spellings = {'1', '1.0.0', 'v1', 'v1.0'};

  static const _messageKeys = {
    'createSurface',
    'updateComponents',
    'updateDataModel',
    'deleteSurface',
    'callRendererFunction',
    'agentFunctionResponse',
  };

  static const _earlierMessageKeys = {'beginRendering', 'surfaceUpdate', 'dataModelUpdate'};

  /// Whether a reply's UI written in A2UI [version], or in no version when
  /// `null`, can be read.
  ///
  /// True for `null`, `1`, `1.0`, `1.0.0`, `v1` and `v1.0`. Anything else is
  /// false, including other capitalizations such as `V1`.
  static bool supports(String? version) {
    if (version == null) return true;
    if (version == current) return true;
    return _spellings.contains(version);
  }

  /// The [message] ready to apply, with its `version` written as [current], or
  /// the problem that keeps it from being applied.
  ///
  /// A `version` of `1`, `1.0.0`, `v1` or `v1.0` is rewritten as `1.0`. A
  /// message with no `version`, or with any other, including a number, isn't
  /// applied: the result is an [A2UIRejectedEnvelope] whose error has the code
  /// [A2UIErrorCode.validationFailed] at the path `/version`, and names the
  /// version read and the one found, if any.
  ///
  /// A message also needs exactly one of the six A2UI 1.0 message keys,
  /// `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`,
  /// `callRendererFunction` and `agentFunctionResponse`, with an object as its
  /// value. A message key of an earlier version, such as `beginRendering`, is
  /// an error that says it isn't part of 1.0.
  static A2UIEnvelope check(Map<String, Object?> message) {
    final surfaceId = _surfaceIdOf(message);
    if (!message.containsKey('version')) {
      return A2UIRejectedEnvelope(
        A2UIError(
          code: A2UIErrorCode.validationFailed,
          message: 'Missing required version field: every A2UI message carries "version": "$current".',
          surfaceId: surfaceId,
          path: '/version',
        ),
      );
    }
    final version = message['version'];
    if (!_readsMessageVersion(version)) {
      return A2UIRejectedEnvelope(
        A2UIError(
          code: A2UIErrorCode.validationFailed,
          message: "Unsupported protocol version '${_text(version)}'. This renderer reads A2UI $current.",
          surfaceId: surfaceId,
          path: '/version',
        ),
      );
    }

    final keys = [
      for (final key in message.keys)
        if (_messageKeys.contains(key)) key,
    ]..sort();
    if (keys.length > 1) {
      return A2UIRejectedEnvelope(
        A2UIError(
          code: A2UIErrorCode.validationFailed,
          message:
              'Message contains multiple conflicting update actions: ${keys.join(', ')}. '
              'A message carries exactly one.',
          surfaceId: surfaceId,
          path: '',
        ),
      );
    }
    if (keys.isEmpty) return A2UIRejectedEnvelope(_unknownType(message, surfaceId));
    final key = keys.single;
    if (message[key] is! Map<String, Object?>) {
      return A2UIRejectedEnvelope(
        A2UIError(
          code: A2UIErrorCode.validationFailed,
          message: "Invalid field '$key' in 'envelope' message. The message payload must be an object.",
          surfaceId: surfaceId,
          path: '/$key',
        ),
      );
    }

    if (version == current) return A2UIAcceptedEnvelope(message);
    return A2UIAcceptedEnvelope({...message, 'version': current});
  }

  static bool _readsMessageVersion(Object? version) {
    if (version == current) return true;
    return version is String && _spellings.contains(version);
  }

  static A2UIError _unknownType(Map<String, Object?> message, String? surfaceId) {
    for (final key in message.keys) {
      if (!_earlierMessageKeys.contains(key)) continue;
      return A2UIError(
        code: A2UIErrorCode.validationFailed,
        message: "The action '$key' is not supported in protocol version $current.",
        surfaceId: surfaceId,
        path: '',
      );
    }
    final keys = [for (final key in message.keys) key]..sort();
    return A2UIError(
      code: A2UIErrorCode.validationFailed,
      message: 'Unknown A2UI message type. Keys: ${keys.join(', ')}',
      surfaceId: surfaceId,
      path: '',
    );
  }

  // The surface a message names, from whichever message key it carries, so a
  // problem with the message can be told apart by surface.
  static String? _surfaceIdOf(Map<String, Object?> message) {
    for (final key in _messageKeys) {
      if (message[key] case {'surfaceId': final String surfaceId} when surfaceId.isNotEmpty) return surfaceId;
    }
    return null;
  }

  // The version as text, as the agent wrote it: a string as it is, nothing as
  // empty, and anything else as its JSON.
  static String _text(Object? version) {
    return switch (version) {
      final String text => text,
      null => '',
      _ => jsonEncode(version),
    };
  }
}

/// The result of [A2UIVersions.check]: a message to apply, or why it can't be.
///
/// Internal to the package.
@internal
sealed class A2UIEnvelope {
  /// Creates an [A2UIEnvelope].
  const A2UIEnvelope();
}

/// A message that passed [A2UIVersions.check], with its version written as
/// [A2UIVersions.current].
///
/// Internal to the package.
@internal
final class A2UIAcceptedEnvelope extends A2UIEnvelope {
  /// Creates an [A2UIAcceptedEnvelope] for [message].
  const A2UIAcceptedEnvelope(this.message);

  /// The message, with its `version` written as [A2UIVersions.current].
  final Map<String, Object?> message;
}

/// A message that didn't pass [A2UIVersions.check].
///
/// Internal to the package.
@internal
final class A2UIRejectedEnvelope extends A2UIEnvelope {
  /// Creates an [A2UIRejectedEnvelope] that failed with [error].
  const A2UIRejectedEnvelope(this.error);

  /// Why the message can't be applied.
  final A2UIError error;
}
