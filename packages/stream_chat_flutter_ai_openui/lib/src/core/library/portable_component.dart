/// Components an app describes as JSON definitions.
///
/// A definition has a snake_case `name`, a `description`, its `parameters`
/// as a JSON Schema object that keeps their order in `x-order`, and the
/// `events` it reports:
///
/// ```json
/// {
///   "name": "place_card",
///   "description": "A photo and a short summary of a place.",
///   "parameters": {
///     "type": "object",
///     "properties": {"title": {"type": "string"}},
///     "required": ["title"],
///     "x-order": ["title"]
///   },
///   "events": [
///     {"name": "ask_about", "description": "The person asks about the place."}
///   ]
/// }
/// ```
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// Reads an app's component `definition`, as `jsonDecode` gives it.
///
/// The name is turned into one a program calls: `place_card`, `place-card`
/// and `place card` are `PlaceCard`. The props are the properties of
/// `parameters`, first those its `x-order` names and then the rest as
/// written; a property is optional when `required` doesn't name it or it has
/// a `default`. Each is read as the closest prop type, and one that can't be
/// described takes any value. The description joins the component's own, each
/// property's as `name: description`, and each event's, each made one
/// sentence on one line.
///
/// A name of separators only reads as an empty name, which a program can't
/// call. A property whose schema isn't an object takes any value, and a
/// description part that isn't a string adds nothing.
///
/// Throws a [FormatException] when `definition` isn't JSON data, has no
/// `name` string or an empty one, or nests too deeply for a library to read
/// programs with: more than [OpenUIValue.maxJsonDepth] levels, counted from
/// the library's JSON Schema.
ComponentSchema portableComponentSchema(Map<String, Object?> definition) {
  OpenUIValue.fromJson(definition);
  final name = definition['name'];
  if (name is! String || name.isEmpty) {
    throw FormatException('A component definition needs a name', definition['name']);
  }
  final parameters = definition['parameters'];
  final events = definition['events'];
  final notes = [
    if (definition['description'] case final String description when description.isNotEmpty) _sentence(description),
    for (final (field, property) in _orderedProperties(parameters))
      if (property is Map<String, Object?>)
        if (property['description'] case final String description when description.isNotEmpty)
          _sentence('$field: $description'),
    if (events is List<Object?>)
      for (final event in events)
        if (event is Map<String, Object?>)
          if (event['description'] case final String description when description.isNotEmpty) _sentence(description),
  ];
  final schema = ComponentSchema(
    portableTypeName(name),
    description: notes.where((note) => note.isNotEmpty).join(' '),
    props: _fields(parameters),
  );
  // A library holds a component two levels deeper, under `$defs`.
  OpenUIValue.fromJson({
    r'$defs': {schema.name: schema.jsonSchema},
  });
  return schema;
}

/// The name a program calls the component `name` by: its words, split at
/// `_`, `-` and spaces, each with its first letter in upper case and joined.
String portableTypeName(String name) {
  return [
    for (final word in name.split(_separators))
      if (word.isNotEmpty)
        '${String.fromCharCode(word.runes.first).toUpperCase()}${String.fromCharCodes(word.runes.skip(1))}',
  ].join();
}

/// The prop type closest to the JSON Schema `schema`.
///
/// An `enum` of strings is an enumeration, a string `const` a literal, and
/// `anyOf` or `oneOf` a union of its options other than `null` (just the
/// option when one is left, any value when none is or one takes any). Then
/// `type`, of which a list with one type besides `"null"` counts as that
/// type: `string`, `number` or `integer`, `boolean`, `array` of its `items`,
/// and `object` with its `properties`, or a record of its
/// `additionalProperties` when it has none. Anything else takes any value.
PropType portablePropType(Object? schema) {
  if (schema is! Map<String, Object?>) return PropType.any;
  final values = schema['enum'];
  if (values is List<Object?> && values.isNotEmpty && values.every((value) => value is String)) {
    return PropType.enumeration(values.cast<String>());
  }
  if (schema['const'] case final String constant) return PropType.literal(constant);
  final options = schema['anyOf'] ?? schema['oneOf'];
  if (options is List<Object?> && options.isNotEmpty) {
    final types = [
      for (final option in options)
        if (!(option is Map<String, Object?> && option['type'] == 'null')) portablePropType(option),
    ];
    if (types.length == 1) return types.single;
    if (types.isEmpty || types.contains(PropType.any)) return PropType.any;
    return PropType.union(types);
  }
  final type = switch (schema['type']) {
    final String name => name,
    final List<Object?> names => names.whereType<String>().where((name) => name != 'null').singleOrNull,
    _ => null,
  };
  switch (type) {
    case 'string':
      return PropType.string;
    case 'number' || 'integer':
      return PropType.number;
    case 'boolean':
      return PropType.boolean;
    case 'array':
      return PropType.array(portablePropType(schema['items']));
    case 'object':
      final properties = schema['properties'];
      if (properties is Map<String, Object?> && properties.isNotEmpty) return PropType.object(_fields(schema));
      final values = schema['additionalProperties'];
      if (values is Map<String, Object?>) return PropType.record(portablePropType(values));
      return PropType.any;
    default:
      return PropType.any;
  }
}

final _separators = RegExp('[-_ ]');

final _whitespace = RegExp(r'\s+');

// The fields of a JSON Schema object in positional order, with their
// defaults.
List<PropSchema> _fields(Object? schema) {
  final required = switch (schema) {
    {'required': final List<Object?> names} => names.whereType<String>().toSet(),
    _ => const <String>{},
  };
  return [
    for (final (name, property) in _orderedProperties(schema))
      switch (property) {
        {'default': final defaultValue} => PropSchema(
          name,
          portablePropType(property),
          required: false,
          defaultValue: defaultValue,
        ),
        _ => PropSchema(name, portablePropType(property), required: required.contains(name)),
      },
  ];
}

// A component's line in the prompt stays on one line, so a description does
// too, and ends a sentence.
String _sentence(String text) {
  final collapsed = text.trim().split(_whitespace).where((word) => word.isNotEmpty).join(' ');
  if (collapsed.isEmpty || '.!?'.contains(collapsed[collapsed.length - 1])) return collapsed;
  return '$collapsed.';
}

// A JSON Schema object's properties, first in the order of its `x-order` and
// then as written.
List<(String, Object?)> _orderedProperties(Object? schema) {
  if (schema is! Map<String, Object?>) return const [];
  final properties = schema['properties'];
  if (properties is! Map<String, Object?>) return const [];
  final order = schema['x-order'];
  final names = <String>{
    if (order is List<Object?>)
      for (final name in order.whereType<String>())
        if (properties.containsKey(name)) name,
    ...properties.keys,
  };
  return [for (final name in names) (name, properties[name])];
}
