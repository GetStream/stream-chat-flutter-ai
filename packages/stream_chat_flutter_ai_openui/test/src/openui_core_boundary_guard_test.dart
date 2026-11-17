import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The OpenUI Lang core is private and replaceable: code outside lib/src/core/
// imports only the files at its top level, its boundary, never the parser or
// values inside it, so the core can be swapped by rewriting lib/src/core/ only.
void main() {
  test('no file outside lib/src/core/ imports past its boundary', () {
    final crossings = [
      for (final file in _dartFiles())
        if (!_isInCore(file.path))
          for (final uri in _coreImportsIn(file.readAsStringSync()))
            if (!_isBoundary(uri)) '${file.path} imports $uri',
    ];

    expect(crossings, isEmpty);
  });

  test('the walk finds files outside lib/src/core/', () {
    final paths = _dartFiles().map((file) => file.path);

    expect(paths, containsAll(['lib/stream_chat_flutter_ai_openui.dart', 'lib/src/openui_error.dart']));
  });

  test('the walk finds files inside lib/src/core/', () {
    final paths = _dartFiles().map((file) => file.path);

    expect(paths, containsAll(['lib/src/core/openui_library_schema.dart', 'lib/src/core/parser/lexer.dart']));
  });

  test('the import reading flags an import past the boundary', () {
    const source = "import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';";

    expect(_coreImportsIn(source).where((uri) => !_isBoundary(uri)), isNotEmpty);
  });

  test('the import reading accepts an import of the boundary', () {
    const source = "import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';";

    expect(_coreImportsIn(source).where((uri) => !_isBoundary(uri)), isEmpty);
  });

  test('the import reading flags an export past the boundary too', () {
    const source = "export 'src/core/values/js.dart' show JS;";

    expect(_coreImportsIn(source).where((uri) => !_isBoundary(uri)), isNotEmpty);
  });
}

const _core = 'lib/src/core/';

List<File> _dartFiles() => [
  for (final entity in Directory('lib').listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

bool _isInCore(String path) => path.startsWith(_core);

// The URIs of the import and export directives of [source] that reach into
// the core.
List<String> _coreImportsIn(String source) => [
  for (final match in RegExp(r'''^(?:import|export)\s+'([^']+)'.*$''', multiLine: true).allMatches(source))
    if (match.group(1)!.contains('src/core/')) match.group(1)!,
];

// Whether [uri] names a file at the top level of the core.
bool _isBoundary(String uri) => !uri.substring(uri.indexOf('src/core/') + 'src/core/'.length).contains('/');
