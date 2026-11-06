import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The A2UI core library the package is built on, and the schema library its
// catalogs are written in, stay behind the adapter library in lib/src/core/,
// so the core can be replaced without touching the rest of the package.
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

    expect(paths, containsAll(['lib/stream_chat_flutter_ai_a2ui.dart', 'lib/src/engine/a2ui_engine.dart']));
  });

  test('the adapter library is where package:a2ui_core is imported', () {
    final adapter = File(_adapter).readAsStringSync();

    expect(adapter, contains("import '$_core"));
  });

  test('no file but the adapter library mentions package:json_schema_builder', () {
    final outside = [
      for (final file in _dartFiles())
        if (file.path != _adapter && file.readAsStringSync().contains(_schema)) file.path,
    ];

    expect(outside, isEmpty);
  });

  test('the adapter library is where package:json_schema_builder is imported', () {
    final adapter = File(_adapter).readAsStringSync();

    expect(adapter, contains("import '$_schema"));
  });
}

const _core = 'package:a2ui_core/';

// The schema library the core takes its catalogs in, which is part of the
// core's API.
const _schema = 'package:json_schema_builder/';

const _adapter = 'lib/src/core/a2ui_adapter.dart';

List<File> _dartFiles() => [
  for (final entity in Directory('lib').listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];
