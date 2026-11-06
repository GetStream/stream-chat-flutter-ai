import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

/// The A2UI type an agent places the app's component [name] by: its words,
/// split at `_`, `-` and spaces, each starting with a capital letter and
/// joined, such as `PlaceCard` for `place_card`.
///
/// Internal to the package.
@internal
String a2uiTypeNameOf(String name) {
  return [
    for (final word in name.split(_wordBreak))
      if (word.isNotEmpty) _capitalized(word),
  ].join();
}

String _capitalized(String word) {
  final first = String.fromCharCode(word.runes.first);
  return first.toUpperCase() + word.substring(first.length);
}

final _wordBreak = RegExp('[_ -]');

/// The app's [components] an agent can place in a reply's A2UI, each with the
/// A2UI type it is placed by, in their order.
///
/// A component that can't join the catalogs (see
/// [A2UICatalogs.appComponentProblem]), or whose type an earlier one already
/// has, is left out, and [onLeftOut] gets a message that says which and why.
///
/// Internal to the package.
@internal
List<({String type, AIUIComponent<Object?> component})> a2uiPlaceableComponents(
  List<AIUIComponent<Object?>> components, {
  required void Function(String message) onLeftOut,
}) {
  final placeable = <({String type, AIUIComponent<Object?> component})>[];
  final types = <String>{};
  for (final component in components) {
    final type = a2uiTypeNameOf(component.name);
    final problem = types.contains(type)
        ? "an earlier component of the app is already placed as '$type'"
        : A2UICatalogs.appComponentProblem(type, component.definition.parametersSchema);
    if (problem != null) {
      onLeftOut("The app's component '${component.name}' can't be placed in A2UI replies: $problem.");
      continue;
    }
    types.add(type);
    placeable.add((type: type, component: component));
  }
  return placeable;
}

/// What the agent is told an app component of [definition] is: its
/// description and its events' descriptions, each a sentence, as iOS and
/// Android describe it.
///
/// Internal to the package.
@internal
String a2uiComponentDescription(AIUIComponentDefinition definition) {
  return [
    definition.description,
    for (final event in definition.events) event.description,
  ].map((text) => text.trim()).where((text) => text.isNotEmpty).map(_sentence).join(' ');
}

String _sentence(String text) => const ['.', '!', '?'].any(text.endsWith) ? text : '$text.';
