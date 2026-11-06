import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_host.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// Something the person did in an agent's generated UI that the agent needs to
/// know about, such as tapping a place or submitting a form.
///
/// The conversation's [AIUIHost] passes each action to its `send` callback, in
/// the order they happened. The app sends it as the person's next message:
/// [label] becomes the message text that everyone sees, and [toCustomData]
/// adds the details for the agent.
///
/// ```dart
/// await channel.sendMessage(Message(text: action.label, extraData: action.toCustomData()));
/// ```
///
/// Two actions are `==` when all their fields are, with [payload] compared
/// deeply.
@immutable
final class AIUIAction {
  /// Creates an [AIUIAction].
  const AIUIAction({
    required this.messageId,
    required this.format,
    required this.name,
    required this.label,
    this.payload = const {},
  });

  /// The name of the custom field that holds the action in the person's
  /// message.
  static const customDataKey = 'ai_ui_action';

  /// The id of the reply whose UI the person acted in.
  final String messageId;

  /// The format of that reply's UI.
  final AIUIFormat format;

  /// The name of what happened, such as an app component's event
  /// (`ask_about`) or OpenUI's `continue_conversation`.
  final String name;

  /// A short description of what the person did, written as if they said it,
  /// such as "Tell me more about St. Naum". It becomes the message text.
  final String label;

  /// The details, shaped the way the format defines them, such as the option
  /// picked or a form's values.
  ///
  /// The action keeps the map it is given, so it shouldn't be changed
  /// afterwards.
  final Map<String, Object?> payload;

  /// The action as JSON for the agent's backend.
  ///
  /// [label] isn't included, because it is sent as the message text. The
  /// result is a copy, so changing it doesn't change the action.
  Map<String, Object?> toJson() => <String, Object?>{
    'v': _kVersion,
    'message_id': messageId,
    'format': format,
    'name': name,
    'payload': deepCopy(payload),
  };

  /// The custom data to put on the person's message: [toJson] under
  /// [customDataKey].
  Map<String, Object?> toCustomData() => <String, Object?>{customDataKey: toJson()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUIAction &&
          other.messageId == messageId &&
          other.format == format &&
          other.name == name &&
          other.label == label &&
          const DeepCollectionEquality().equals(other.payload, payload);

  @override
  int get hashCode => Object.hash(messageId, format, name, label, const DeepCollectionEquality().hash(payload));

  // The payload's keys only: its values are whatever the person entered.
  @override
  String toString() =>
      'AIUIAction(messageId: $messageId, format: $format, name: $name, payloadKeys: [${payload.keys.join(', ')}])';
}

// The version of the action's shape.
const _kVersion = 1;
