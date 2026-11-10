import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

/// What a person did in a surface that the agent should hear about, such as
/// tapping a button: the event the agent named, with the values it asked for.
///
/// Reaches the `onAction` callback of [A2UIProcessor.new]. Two events are `==`
/// when their fields are, with [context] compared deeply.
///
/// Internal to the package.
@internal
@immutable
final class A2UIActionEvent {
  /// Creates an [A2UIActionEvent].
  const A2UIActionEvent({
    required this.name,
    required this.surfaceId,
    required this.sourceComponentId,
    this.context = const {},
    this.userMessage,
  });

  /// The event's name, as the agent wrote it in the component's action.
  final String name;

  /// The id of the surface this event happened in.
  final String surfaceId;

  /// The id of the component the person used, such as the button.
  final String sourceComponentId;

  /// The values the action asked for, with bindings read from the surface's
  /// data model when the person acted.
  final Map<String, Object?> context;

  /// The agent's words for what the person did, or `null` when it gave none.
  final String? userMessage;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is A2UIActionEvent &&
        other.name == name &&
        other.surfaceId == surfaceId &&
        other.sourceComponentId == sourceComponentId &&
        const DeepCollectionEquality().equals(other.context, context) &&
        other.userMessage == userMessage;
  }

  @override
  int get hashCode {
    return Object.hash(name, surfaceId, sourceComponentId, const DeepCollectionEquality().hash(context), userMessage);
  }

  // The context's keys only: its values are what the person entered.
  @override
  String toString() {
    return '${objectRuntimeType(this, 'A2UIActionEvent')}(name: $name, surfaceId: $surfaceId, '
        'sourceComponentId: $sourceComponentId, context: ${context.keys.toList()})';
  }
}
