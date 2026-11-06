import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The package's public API is exactly the names its barrel exports. Each export
// lists its names with `show`, so a name can't become public unnoticed.
void main() {
  test('the barrel exports exactly the listed names', () {
    expect(_exportedNames(), _expectedNames);
  });

  test('every export of the barrel lists its names with show', () {
    final unlisted = [
      for (final export in _exports())
        if (!export.contains(' show ')) export,
    ];

    expect(unlisted, isEmpty);
  });

  test('the barrel is read as a library', () {
    expect(_barrel(), contains('library;'));
  });

  test('the export reading finds the names an export shows', () {
    expect(_namesIn("export 'src/a.dart' show A, B;\nexport 'src/c.dart';"), {'A', 'B'});
  });

  test('the export reading finds an export that shows nothing', () {
    expect(_exportsIn("export 'src/c.dart';"), ["export 'src/c.dart';"]);
  });
}

// None yet: the package has no public API.
const _expectedNames = <String>{};

String _barrel() => File('lib/stream_chat_flutter_ai_a2ui.dart').readAsStringSync();

List<String> _exports() => _exportsIn(_barrel());

Set<String> _exportedNames() => _namesIn(_barrel());

// Each export directive of [source], from `export` to its `;`.
List<String> _exportsIn(String source) => [
  for (final match in RegExp(r'^export\s[^;]*;', multiLine: true).allMatches(source))
    match.group(0)!.replaceAll(RegExp(r'\s+'), ' '),
];

Set<String> _namesIn(String source) => {
  for (final export in _exportsIn(source))
    if (RegExp(' show ([^;]*);').firstMatch(export) case final match?)
      for (final name in match.group(1)!.split(',')) name.trim(),
};
