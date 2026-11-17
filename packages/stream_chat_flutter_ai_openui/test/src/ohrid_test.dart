import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';
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
  return OpenUILangParser(_library()).parse(File('test/fixtures/ohrid_prompt_example.oui').readAsStringSync());
}

// The chat library with the Ohrid app's components added, as an app adds
// them.
OpenUILibrarySchema _library() {
  final decoded = jsonDecode(File('test/fixtures/ohrid_app_components.json').readAsStringSync()) as List<Object?>;
  final definitions = [for (final definition in decoded) definition! as Map<String, Object?>];
  final components = [for (final (_, schema) in placeableComponents(LibraryDefinition.chat, definitions)) schema];
  return LibraryDefinition.chat.addingContent(components).schema;
}
