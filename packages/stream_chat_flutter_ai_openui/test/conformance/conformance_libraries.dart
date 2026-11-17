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
