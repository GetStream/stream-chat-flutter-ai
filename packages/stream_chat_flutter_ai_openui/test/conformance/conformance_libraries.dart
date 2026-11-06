part of 'openui_conformance.dart';

/// The libraries the parser fixtures were generated with, by the name each
/// case gives: OpenUI's chat and standard ("playground") libraries, the
/// minimal library of OpenUI's own parser tests, and the test library of the
/// OpenUI Lang specification.
Map<String, OpenUILibrarySchema> conformanceLibraries() => _libraries;

final _libraries = <String, OpenUILibrarySchema>{
  'chat': _spec('$_generated/upstream-chat-library.spec.json'),
  'playground': _spec('$_generated/upstream-playground-library.spec.json'),
  // Two components, no root: `Stack(children*)` and `Title(text*: string)`.
  'mini': OpenUILibrarySchema.fromJsonSchema(const {
    r'$defs': {
      'Stack': {
        'properties': {'children': <String, Object?>{}},
        'required': ['children'],
      },
      'Title': {
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  }),
  'spec': _spec('$_generated/spec-library.json'),
};

OpenUILibrarySchema _spec(String path) {
  return OpenUILibrarySchema.fromSpec(jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>);
}

/// The props of the library named `library` that take a `$variable` both
/// ways: those its spec's signatures print as `$binding<…>`, as OpenUI's
/// fixture generator reads them.
BindablePropTest conformanceBindables(String library) {
  final bindables = _bindables.putIfAbsent(library, () {
    final path = switch (library) {
      'chat' => '$_generated/upstream-chat-library.spec.json',
      'playground' => '$_generated/upstream-playground-library.spec.json',
      'spec' => '$_generated/spec-library.json',
      _ => null,
    };
    if (path == null) return const {};
    final spec = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    final components = spec['components']! as Map<String, Object?>;
    return {
      for (final MapEntry(key: name, value: component) in components.entries)
        for (final match in RegExp(r'(\w+)\??: \$binding<').allMatches(
          (component! as Map<String, Object?>)['signature']! as String,
        ))
          '$name.${match[1]}',
    };
  });
  return (component, prop) => bindables.contains('$component.$prop');
}

final _bindables = <String, Set<String>>{};

/// The spec library's functions, as OpenUI's conformance runner supplies
/// them: `@Upper(text)` gives `text` in upper case.
final specFunctions = <String, OpenUIFunction>{
  'Upper': OpenUIFunction(
    (args) => OpenUIString(switch (args['text']) {
      OpenUIString(:final value) => value.toUpperCase(),
      null || OpenUINull() => '',
      final other => '$other'.toUpperCase(),
    }),
    returns: OpenUIValue.fromJson(const {'type': 'string'}),
  ),
};
