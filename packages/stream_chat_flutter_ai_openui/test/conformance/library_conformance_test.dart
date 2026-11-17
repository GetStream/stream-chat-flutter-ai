@Tags(['conformance'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';

import '../src/core/library/spec_library.dart';

// The chat and standard libraries are the ones OpenUI's own implementation
// defines: each component's signature and description, the groups, the JSON
// Schema with its `$defs` and property order, the prompt's examples and rules,
// and the props that take a `$variable` are compared with the specs it wrote
// (generated/upstream-*-library.spec.json).
void main() {
  _libraryConformance(
    'chat',
    LibraryDefinition.chat,
    'upstream-chat-library.spec.json',
    components: 84,
    examples: 5,
  );
  _libraryConformance(
    'standard',
    LibraryDefinition.standard,
    'upstream-playground-library.spec.json',
    components: 82,
    examples: 6,
  );
  _specLibraryConformance();
}

void _specLibraryConformance() {
  final spec = _spec('spec-library.json');

  test('the specification library has 12 components', () {
    expect(specLibrary().components, hasLength(12));
  });

  test('the specification library has the components of spec-library.json', () {
    expect(specLibrary().components, hasLength((spec['components']! as Map<String, Object?>).length));
  });

  test('the specification library has the components, signatures and descriptions of spec-library.json', () {
    expect(specLibrary().toSpec()['components'], spec['components']);
  });

  test('the specification library has the functions of spec-library.json', () {
    expect(specLibrary().toSpec()['functions'], spec['functions']);
  });

  test('the specification library has the actions of spec-library.json', () {
    expect(specLibrary().toSpec()['actions'], spec['actions']);
  });

  test(r'the specification library has as many $defs as spec-library.json', () {
    expect(_defs(specLibrary().toJsonSchema()), hasLength(_defs(spec['schema']).length));
  });

  test(r'the specification library has the $defs of spec-library.json', () {
    expect(_defs(specLibrary().toJsonSchema()).keys, unorderedEquals(_defs(spec['schema']).keys));
  });
}

void _libraryConformance(
  String name,
  LibraryDefinition library,
  String file, {
  required int components,
  required int examples,
}) {
  final spec = _spec(file);
  final specComponents = spec['components']! as Map<String, Object?>;
  final specSchema = spec['schema']! as Map<String, Object?>;
  final promptOptions = spec['promptOptions']! as Map<String, Object?>;

  test('the $name library has $components components', () {
    expect(library.components, hasLength(components));
  });

  test('the $name library has the components of the spec', () {
    expect(library.components, hasLength(specComponents.length));
  });

  test('the $name library has the components of the spec, in its order', () {
    expect(library.componentNames, [...specComponents.keys]);
  });

  test("the $name library has the spec's root", () {
    expect(library.root, spec['root']);
  });

  for (final component in specComponents.keys) {
    test('the $name library writes the signature and description of $component as the spec does', () {
      expect((library.toSpec()['components']! as Map<String, Object?>)[component], specComponents[component]);
    });
  }

  test("the $name library groups its components as the spec's componentGroups", () {
    expect(library.toSpec()['componentGroups'], spec['componentGroups']);
  });

  test('the $name library has as many \$defs as the spec', () {
    expect(_defs(library.toJsonSchema()), hasLength(_defs(specSchema).length));
  });

  test("the $name library has the spec's \$defs, in its order", () {
    expect(_defs(library.toJsonSchema()).keys, [..._defs(specSchema).keys]);
  });

  for (final definition in _defs(specSchema).keys) {
    test('the $name library writes the JSON Schema of $definition as the spec does', () {
      expect(_defs(library.toJsonSchema())[definition], _defs(specSchema)[definition]);
    });

    test('the $name library orders the properties of $definition as the spec does', () {
      expect(_properties(_defs(library.toJsonSchema())[definition]), _properties(_defs(specSchema)[definition]));
    });
  }

  for (final key in [r'$schema', 'type', 'properties', 'required', 'additionalProperties']) {
    test("the $name library writes the $key of the JSON Schema as the spec's", () {
      expect(library.toJsonSchema()[key], specSchema[key]);
    });
  }

  test('the $name library has $examples examples', () {
    expect(library.defaultPromptOptions.examples, hasLength(examples));
  });

  test("the $name library has the spec's examples", () {
    expect(library.defaultPromptOptions.examples, promptOptions['examples']);
  });

  // The standard library's spec records no rules; its default prompt
  // golden checks them.
  if (promptOptions.containsKey('additionalRules')) {
    test("the $name library has the spec's additional rules", () {
      expect(library.defaultPromptOptions.additionalRules, promptOptions['additionalRules']);
    });
  }

  test('the $name library takes a \$variable in the props whose spec signature shows \$binding', () {
    final expected = <String>{};
    for (final MapEntry(key: component, :value) in specComponents.entries) {
      final signature = (value! as Map<String, Object?>)['signature']! as String;
      for (final match in RegExp(r'(\w+)\?: \$binding<').allMatches(signature)) {
        expected.add('$component.${match.group(1)}');
      }
    }
    final actual = {
      for (final component in library.components)
        for (final prop in component.props)
          if (library.isBindable(component.name, prop.name)) '${component.name}.${prop.name}',
    };

    expect(actual, allOf(isNotEmpty, expected));
  });

  for (final (index, example) in library.defaultPromptOptions.examples.indexed) {
    final label = 'the $name library example ${index + 1}';

    test('$label has a blank line before its program', () {
      expect(example, contains('\n\n'));
    });

    test('$label reads with no errors', () {
      expect(_parseExample(library, example).meta.errors, isEmpty);
    });

    test('$label reads with nothing unresolved', () {
      expect(_parseExample(library, example).meta.unresolved, isEmpty);
    });

    test('$label reads with nothing orphaned', () {
      expect(_parseExample(library, example).meta.orphaned, isEmpty);
    });

    test('$label reads with a root', () {
      expect(_parseExample(library, example).root, isNotNull);
    });

    test('$label has one statement per line', () {
      final statements = _program(example).split('\n').where((line) => line.trim().isNotEmpty);

      expect(statements.every((line) => RegExp(r'^\$?\w+ = ').hasMatch(line)), isTrue);
    });
  }
}

// The program of an example: what follows its title and a blank line.
String _program(String example) => example.substring(example.indexOf('\n\n') + 2);

ParseResult _parseExample(LibraryDefinition library, String example) {
  return OpenUILangParser(library.schema).parse(_program(example));
}

Map<String, Object?> _spec(String file) {
  return jsonDecode(File('test/conformance/generated/$file').readAsStringSync()) as Map<String, Object?>;
}

Map<String, Object?> _defs(Object? schema) => (schema! as Map<String, Object?>)[r'$defs']! as Map<String, Object?>;

List<String>? _properties(Object? definition) {
  return switch (definition) {
    {'properties': final Map<String, Object?> properties} => [...properties.keys],
    _ => null,
  };
}
