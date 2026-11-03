import 'package:stream_chat_flutter_ai/src/genui/ai_ui_parameter.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

// The key that keeps the order of an object's fields, which JSON objects
// don't have.
const _kOrderKey = 'x-order';

/// [parameters] as a JSON Schema object, their order kept under `x-order`.
///
/// It shares nothing with the parameters' types, so it can be changed freely.
///
/// Not exported.
Map<String, Object?> objectSchema(List<AIUIParameter> parameters) => <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    for (final parameter in parameters)
      parameter.name: <String, Object?>{
        ...deepCopy(parameter.type.schema)! as Map<String, Object?>,
        if (parameter.description case final description?) 'description': description,
      },
  },
  'required': [
    for (final parameter in parameters)
      if (parameter.isRequired) parameter.name,
  ],
  _kOrderKey: [for (final parameter in parameters) parameter.name],
};

/// The fields of a JSON Schema object, in the order it keeps under `x-order`,
/// then by name.
///
/// Not exported.
List<AIUIParameter> parametersFromObjectSchema(Map<String, Object?> schema) {
  final properties = switch (schema['properties']) {
    final Map<Object?, Object?> properties => {
      for (final MapEntry(:key, :value) in properties.entries)
        if (key is String && value is Map) key: value,
    },
    _ => const <String, Map<Object?, Object?>>{},
  };
  final required = switch (schema['required']) {
    final List<Object?> names => names.whereType<String>().toSet(),
    _ => const <String>{},
  };
  final ordered = switch (schema[_kOrderKey]) {
    final List<Object?> names => names.whereType<String>().where(properties.containsKey).toList(),
    _ => const <String>[],
  };
  final unordered = properties.keys.where((name) => !ordered.contains(name)).toList()..sort();

  return List.unmodifiable([
    for (final name in [...ordered, ...unordered])
      _parameter(name, properties[name]!, isRequired: required.contains(name)),
  ]);
}

// A field of a JSON Schema object, its description moved out of its type, which
// is a deeply unmodifiable copy of the field's schema.
AIUIParameter _parameter(String name, Map<Object?, Object?> schema, {required bool isRequired}) {
  final type = {...deepUnmodifiable(schema)! as Map<String, Object?>};
  final description = type.remove('description');
  return AIUIParameter(
    name: name,
    type: AIUIParameterType(Map.unmodifiable(type)),
    description: description is String ? description : null,
    isRequired: isRequired,
  );
}
