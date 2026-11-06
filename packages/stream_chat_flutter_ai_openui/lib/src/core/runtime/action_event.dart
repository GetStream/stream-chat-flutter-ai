/// What a program's action sends to the host.
///
/// Internal to the package.
@internal
library;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// An action for the host: a message to the model, a link to open, or one
/// of the library's own actions, in the one shape OpenUI sends them
/// (specification §6.3).
@immutable
final class OpenUIActionEvent {
  /// Creates an event of [type].
  const OpenUIActionEvent({
    required this.type,
    this.params = const {},
    this.message = '',
    this.label = '',
    this.formName,
    this.formState = const {},
  });

  /// The type of a message to the model, from `@ToAssistant`, a control
  /// without an action, or a legacy action object.
  static const continueConversation = 'continue_conversation';

  /// The type of a link to open, from `@OpenUrl`.
  static const openUrl = 'open_url';

  /// [continueConversation], [openUrl], or the name of one of the library's
  /// actions.
  final String type;

  /// The action's values: `context` of a message, `url` of a link, the
  /// arguments of a library action by parameter name.
  final Map<String, OpenUIValue> params;

  /// The message the model wrote for the action (OpenUI's
  /// `humanFriendlyMessage`); empty for a link and a library action.
  final String message;

  /// The label of the control the person used, such as a button's title;
  /// empty for a link.
  final String label;

  /// The form around the control, if any.
  final String? formName;

  /// The form's fields, `{formName: {field: {value, componentType}}}`, or,
  /// outside a form, the page's `$variables` and fields, as they were when
  /// the action ran; secret fields are left out.
  final Map<String, OpenUIValue> formState;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIActionEvent &&
        other.type == type &&
        mapEquals(other.params, params) &&
        other.message == message &&
        other.label == label &&
        other.formName == formName &&
        mapEquals(other.formState, formState);
  }

  @override
  int get hashCode => Object.hash(type, message, label, formName);

  @override
  String toString() => 'OpenUIActionEvent($type, "$message", $params)';
}
