import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_schema.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// Describes an app component to the agent: its name, what it shows, the
/// parameters the agent fills in, and the events it reports.
///
/// The description converts to and from JSON, so one file can be shared by
/// the app on every platform and by the agent's backend, which uses it to
/// teach the model about the component. The parameters are written as a JSON
/// Schema object, like a tool's, with their order kept in `x-order`:
///
/// ```json
/// {
///   "name": "place_card",
///   "description": "A photo and a short summary of a place.",
///   "parameters": {
///     "type": "object",
///     "properties": { "title": { "type": "string", "description": "The place's Wikipedia title." } },
///     "required": ["title"],
///     "x-order": ["title"]
///   },
///   "events": [{ "name": "ask_about", "description": "The person asks about the place." }]
/// }
/// ```
///
/// ```dart
/// const placeCard = AIUIComponentDefinition(
///   name: 'place_card',
///   description: 'A photo and a short summary of a place.',
///   parameters: [AIUIParameter.required('title', AIUIParameterType.string)],
///   events: [AIUIComponentEvent(name: 'ask_about', description: 'The person asks about the place.')],
/// );
/// ```
///
/// Two definitions are `==` when all their fields are.
@immutable
final class AIUIComponentDefinition {
  /// Creates an [AIUIComponentDefinition].
  const AIUIComponentDefinition({
    required this.name,
    required this.description,
    this.parameters = const [],
    this.events = const [],
  });

  /// Reads a definition from [json].
  ///
  /// A missing `description` reads as empty, and missing `parameters` or
  /// `events` read as none. Parameters that aren't listed in `x-order` are
  /// sorted by name.
  ///
  /// Unlike `AIUIDocument.fromCustomData`, which reads what the agent sends at
  /// runtime and never throws, this is strict: a definition ships with the app,
  /// so a mistake in it should fail early. It throws a [FormatException] when
  /// the definition or one of its events has no name, when `description` isn't
  /// a string, when `parameters` isn't an object, or when `events` isn't an
  /// array of objects.
  ///
  /// The definition keeps a copy of [json], so later changes to [json] don't
  /// affect it.
  factory AIUIComponentDefinition.fromJson(Map<String, Object?> json) {
    final fields = deepUnmodifiable(json)! as Map<String, Object?>;
    return AIUIComponentDefinition(
      name: _name(fields),
      description: _description(fields),
      parameters: _parameters(fields),
      events: List.unmodifiable([
        for (final event in _field<List<Object?>>(fields, 'events', 'an array') ?? const <Object?>[])
          switch (event) {
            final Map<String, Object?> event => AIUIComponentEvent._fromJson(event),
            _ => throw FormatException('A component event is not an object', event),
          },
      ]),
    );
  }

  /// The name the agent uses to place the component, such as `place_card`.
  final String name;

  /// Tells the agent what the component shows and when to use it.
  final String description;

  /// The values the agent fills in, in order. The order matters for formats
  /// such as OpenUI, which pass arguments by position.
  final List<AIUIParameter> parameters;

  /// The events the component reports when the person uses it.
  final List<AIUIComponentEvent> events;

  /// [parameters] as a JSON Schema object, the same way a tool's parameters
  /// are written.
  Map<String, Object?> get parametersSchema => objectSchema(parameters);

  /// The definition as JSON, in the shape [AIUIComponentDefinition.fromJson]
  /// reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    'parameters': parametersSchema,
    'events': [for (final event in events) event._toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUIComponentDefinition &&
          other.name == name &&
          other.description == description &&
          listEquals(other.parameters, parameters) &&
          listEquals(other.events, events);

  @override
  int get hashCode => Object.hash(name, description, Object.hashAll(parameters), Object.hashAll(events));

  @override
  String toString() => 'AIUIComponentDefinition(name: $name, parameters: $parameters, events: $events)';
}

/// An event a component reports when the person uses it, such as tapping a
/// place.
///
/// Two events are `==` when all their fields are.
@immutable
final class AIUIComponentEvent {
  /// Creates an [AIUIComponentEvent].
  const AIUIComponentEvent({
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  factory AIUIComponentEvent._fromJson(Map<String, Object?> json) => AIUIComponentEvent(
    name: _name(json),
    description: _description(json),
    parameters: _parameters(json),
  );

  /// The event's name, such as `ask_about`.
  final String name;

  /// Tells the agent when the event happens.
  final String description;

  /// The values the event carries, in order.
  final List<AIUIParameter> parameters;

  Map<String, Object?> _toJson() => <String, Object?>{
    'name': name,
    'description': description,
    if (parameters.isNotEmpty) 'parameters': objectSchema(parameters),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUIComponentEvent &&
          other.name == name &&
          other.description == description &&
          listEquals(other.parameters, parameters);

  @override
  int get hashCode => Object.hash(name, description, Object.hashAll(parameters));

  @override
  String toString() => 'AIUIComponentEvent(name: $name, parameters: $parameters)';
}

// A field that may be missing or null, but has type T when it is there.
T? _field<T extends Object>(Map<String, Object?> json, String key, String expected) => switch (json[key]) {
  null => null,
  final T value => value,
  final value => throw FormatException('"$key" is not $expected', value),
};

String _name(Map<String, Object?> json) =>
    _field<String>(json, 'name', 'a string') ?? (throw FormatException('A component or event has no name', json));

String _description(Map<String, Object?> json) => _field<String>(json, 'description', 'a string') ?? '';

List<AIUIParameter> _parameters(Map<String, Object?> json) {
  final schema = _field<Map<String, Object?>>(json, 'parameters', 'an object');
  return schema == null ? const [] : parametersFromObjectSchema(schema);
}
