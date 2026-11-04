import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The A2UI core library the package is built on stays behind the adapter
// library in lib/src/core/, so it can be replaced without touching the rest of
// the package.
void main() {
  test('no file but the adapter library mentions package:a2ui_core', () {
    final outside = [
      for (final file in _dartFiles())
        if (file.path != _adapter && file.readAsStringSync().contains(_core)) file.path,
    ];

    expect(outside, isEmpty);
  });

  test('the walk finds the files outside lib/src/core/', () {
    final paths = _dartFiles().map((file) => file.path);

    expect(paths, containsAll(['lib/stream_chat_flutter_ai_a2ui.dart', 'lib/src/engine/a2ui_stream.dart']));
  });

  test('the adapter library is where package:a2ui_core is imported', () {
    final adapter = File(_adapter).readAsStringSync();

    expect(adapter, contains("import '$_core"));
  });
}

const _core = 'package:a2ui_core/';

const _adapter = 'lib/src/core/a2ui_adapter.dart';

List<File> _dartFiles() => [
  for (final entity in Directory('lib').listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];
