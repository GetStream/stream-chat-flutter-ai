import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_schema.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// A parameter of a component: a value the agent fills in when it places the
/// component.
///
/// ```dart
/// AIUIParameter.required('title', AIUIParameterType.string, description: "The place's Wikipedia title.");
/// ```
///
/// Two parameters are `==` when all their fields are.
@immutable
final class AIUIParameter {
  /// Creates an [AIUIParameter].
  const AIUIParameter({
    required this.name,
    required this.type,
    this.description,
    this.isRequired = true,
  });

  /// A parameter the agent must fill in.
  const AIUIParameter.required(this.name, this.type, {this.description}) : isRequired = true;

  /// A parameter the agent may leave out.
  const AIUIParameter.optional(this.name, this.type, {this.description}) : isRequired = false;

  /// The parameter's name, such as `title`.
  final String name;

  /// The type of value it holds.
  final AIUIParameterType type;

  /// Tells the agent what the value is.
  final String? description;

  /// Whether the agent must fill it in.
  final bool isRequired;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUIParameter &&
          other.name == name &&
          other.type == type &&
          other.description == description &&
          other.isRequired == isRequired;

  @override
  int get hashCode => Object.hash(name, type, description, isRequired);

  @override
  String toString() => 'AIUIParameter(name: $name, type: $type, description: $description, isRequired: $isRequired)';
}

/// The type of a component's parameter, written as JSON Schema.
///
/// Use one of the static members, or pass any JSON Schema the app's renderers
/// understand.
///
/// ```dart
/// AIUIParameterType.array(
///   AIUIParameterType.object([
///     AIUIParameter.required('name', AIUIParameterType.string),
///     AIUIParameter.required('latitude', AIUIParameterType.number),
///   ]),
/// );
/// ```
///
/// Two types are `==` when their [schema]s are, compared deeply.
@immutable
final class AIUIParameterType {
  /// Creates an [AIUIParameterType] from its JSON Schema.
  const AIUIParameterType(this.schema);

  // A type whose schema is a deeply unmodifiable copy of [schema], like the
  // constants' and the ones read from JSON.
  AIUIParameterType._frozen(Map<String, Object?> schema) : schema = deepUnmodifiable(schema)! as Map<String, Object?>;

  /// A string.
  static const string = AIUIParameterType({'type': 'string'});

  /// A number.
  static const number = AIUIParameterType({'type': 'number'});

  /// A whole number.
  static const integer = AIUIParameterType({'type': 'integer'});

  /// `true` or `false`.
  static const boolean = AIUIParameterType({'type': 'boolean'});

  /// A day, such as `2026-11-14`.
  static const date = AIUIParameterType({'type': 'string', 'format': 'date'});

  /// A moment, such as `2026-11-14T09:30:00Z`.
  static const dateTime = AIUIParameterType({'type': 'string', 'format': 'date-time'});

  /// A link, such as an image's.
  static const url = AIUIParameterType({'type': 'string', 'format': 'uri'});

  /// One of a fixed set of strings.
  static AIUIParameterType enumeration(List<String> values) =>
      AIUIParameterType._frozen({'type': 'string', 'enum': values});

  /// A list of values of one type.
  static AIUIParameterType array(AIUIParameterType items) =>
      AIUIParameterType._frozen({'type': 'array', 'items': items.schema});

  /// An object with named fields, in order.
  static AIUIParameterType object(List<AIUIParameter> fields) => AIUIParameterType._frozen(objectSchema(fields));

  /// The type as a JSON Schema object.
  ///
  /// The constructor keeps the map it is given, so it shouldn't be changed
  /// afterwards. The static members' schemas can't be changed.
  final Map<String, Object?> schema;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUIParameterType && const DeepCollectionEquality().equals(other.schema, schema);

  @override
  int get hashCode => const DeepCollectionEquality().hash(schema);

  @override
  String toString() => 'AIUIParameterType($schema)';
}
