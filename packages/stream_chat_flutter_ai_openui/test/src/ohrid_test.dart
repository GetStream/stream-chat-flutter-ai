import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

// The Ohrid weekend example of the Stream agent backend's prompt, read with the
// chat library plus the app's three components (test/fixtures/README.md).
void main() {
  test('the Ohrid example reads with no errors', () {
    expect(_ohrid().meta.errors, isEmpty);
  });

  test('the Ohrid example leaves nothing unresolved', () {
    expect(_ohrid().meta.unresolved, isEmpty);
  });

  test('the Ohrid example leaves nothing orphaned', () {
    expect(_ohrid().meta.orphaned, isEmpty);
  });

  test('the Ohrid example renders a Card', () {
    expect(_ohrid().root!.typeName, 'Card');
  });

  test("the Ohrid example's Card holds its 8 parts", () {
    expect((_ohrid().root!.props['children']! as OpenUIArray).items, hasLength(8));
  });

  test("the Ohrid example's app components render", () {
    final types = <String>{};
    void collect(OpenUIValue value) {
      switch (value) {
        case OpenUIElement(:final node):
          types.add(node.typeName);
          node.props.values.forEach(collect);
        case OpenUIArray(:final items):
          items.forEach(collect);
        default:
          break;
      }
    }

    collect(OpenUIElement(_ohrid().root!));

    expect(types, containsAll(['PlaceCard', 'TripMap', 'CalendarCheck']));
  });
}

ParseResult _ohrid() {
  final spec = jsonDecode(File('test/conformance/generated/upstream-chat-library.spec.json').readAsStringSync());
  final schema = (spec as Map<String, Object?>)['schema']! as Map<String, Object?>;
  final defs = {...(schema[r'$defs']! as Map<String, Object?>), ..._appComponents()};
  final properties = {
    ...(schema['properties']! as Map<String, Object?>),
    for (final name in _appComponents().keys) name: <String, Object?>{},
  };
  final library = OpenUILibrarySchema.fromJsonSchema({
    ...schema,
    r'$defs': defs,
    'properties': properties,
  }, root: spec['root'] as String?);
  return OpenUILangParser(library).parse(File('test/fixtures/ohrid_prompt_example.oui').readAsStringSync());
}

// The app components as the library adds them: a PascalCase name, and their
// parameters' properties in `x-order`.
Map<String, Object?> _appComponents() {
  final definitions = jsonDecode(File('test/fixtures/ohrid_app_components.json').readAsStringSync()) as List<Object?>;
  return {
    for (final definition in definitions.cast<Map<String, Object?>>())
      _pascalCase(definition['name']! as String): _ordered(definition['parameters']! as Map<String, Object?>),
  };
}

Map<String, Object?> _ordered(Map<String, Object?> parameters) {
  final properties = parameters['properties']! as Map<String, Object?>;
  final order = (parameters['x-order']! as List<Object?>).cast<String>();
  return {
    'properties': {for (final name in order) name: properties[name]},
    'required': parameters['required'] ?? const <Object?>[],
  };
}

String _pascalCase(String name) => [
  for (final part in name.split('_')) '${part[0].toUpperCase()}${part.substring(1)}',
].join();
