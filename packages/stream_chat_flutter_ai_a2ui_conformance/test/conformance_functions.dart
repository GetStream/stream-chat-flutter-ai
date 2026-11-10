part of 'a2ui_conformance.dart';

Future<void> _runEvaluateFunction(Map<String, Object?> testCase) async {
  final name = testCase['function']! as String;
  final args = (testCase['args'] as Map<String, Object?>?) ?? const {};
  final surface = testCase['surface'] as Map<String, Object?>?;
  final documents = _catalogPaths(testCase);
  final Object? result;
  if (surface == null && documents.isEmpty) {
    result = await debugEvaluateFunction(
      name,
      args,
      dataModel: (testCase['dataModel'] as Map<String, Object?>?) ?? const {},
      locale: (testCase['locale'] as String?) ?? 'en-US',
    );
  } else {
    result = await debugEvaluateFunction(
      name,
      args,
      dataModel: (testCase['dataModel'] as Map<String, Object?>?) ?? const {},
      locale: (testCase['locale'] as String?) ?? 'en-US',
      catalogs: [if (surface == null) const A2UIDebugCatalog.basic(A2UICatalogs.basicCatalogId), ...documents],
      surfaceCatalogId: surface == null ? A2UICatalogs.basicCatalogId : surface['catalogId'] as String?,
      catalogId: testCase['catalogId'] as String?,
      userActivation: surface == null,
    );
  }
  final expectError = testCase['expectError'];
  if (expectError != null) {
    _assertErrorMatches(expectError, [if (result is A2UIError) result]);
    return;
  }
  if (result is A2UIError) fail('Unexpected error: $result');
  final expected = testCase['expect'];
  final actual = expected is bool && result is Map<String, Object?> ? result['valid'] ?? result : result;
  if (expected == null) {
    expect(actual, isNull);
    return;
  }
  _assertContains(expected, actual);
}

Future<void> _runParseExpression(Map<String, Object?> testCase) async {
  final input = testCase['input']! as String;
  final expectError = testCase['expect_error'] ?? testCase['expectError'];
  final result = debugParseExpression(input);
  if (result is A2UIError) {
    if (expectError == null) fail('Unexpected error: $result');
    _assertErrorMatches(expectError, [result]);
    return;
  }
  if (expectError != null) fail('Expected a parse error, got $result.');
  final parts = <Object?>[];
  for (final part in result as List<Object?>) {
    if (part is String && parts.isNotEmpty && parts.last is String) {
      parts.last = '${parts.last}$part';
    } else if (part != '') {
      parts.add(part);
    }
  }
  _assertContains(testCase['expect'], parts);
}

Future<void> _runDataModel(Map<String, Object?> testCase) async {
  final model = A2UIDebugDataModel(testCase['initial']);
  addTearDown(model.dispose);
  final notified = <String>[];
  for (final path in (testCase['watch'] as List<Object?>?) ?? const []) {
    if (path is String) model.watch(path, () => notified.add(path));
  }
  // The value the last `set` was given, which `mutate_input` changes after
  // the model took it.
  Object? lastInput;
  for (final step in (testCase['steps'] as List<Object?>?) ?? const []) {
    if (step is! Map<String, Object?>) continue;
    notified.clear();
    final path = (step['path'] as String?) ?? '';
    final expectError = step['expect_error'] ?? step['expectError'];
    final error = switch (step['op']) {
      'get' => _checkGet(model.get(path), step),
      'set' => model.set(path, lastInput = _json(step['value'])),
      'delete' => model.set(path, null),
      'mutate_input' => _mutate(lastInput, path, step['value']),
      'dispose' => _dispose(model),
      final op => fail('No data model operation $op.'),
    };
    if (expectError != null) {
      _assertErrorMatches(expectError, [?error]);
    } else if (error != null) {
      fail('Unexpected error: $error');
    }
    if (step['expect_notified'] case final List<Object?> expected) {
      expect([...notified]..sort(), [for (final path in expected) '$path']..sort());
    }
    if (step['expect_values'] case final Map<String, Object?> values) {
      for (final MapEntry(key: watched, :value) in values.entries) {
        _assertContains(value, model.get(watched), watched);
      }
    }
  }
}

A2UIError? _checkGet(Object? value, Map<String, Object?> step) {
  if (value is A2UIError) return value;
  if (step['expect_absent'] == true) expect(value, isNull, reason: '${step['path']}');
  if (step.containsKey('expect')) _assertContains(step['expect'], value, '${step['path']}');
  switch (step['expect_type']) {
    case 'list':
      expect(value, isA<List<Object?>>());
    case 'object':
      expect(value, isA<Map<String, Object?>>());
  }
  return null;
}

// Writes [value] at the JSON pointer [path] inside [input], a value given to
// the model before, as a caller holding on to it would.
A2UIError? _mutate(Object? input, String path, Object? value) {
  final keys = [for (final key in path.split('/').skip(1)) key.replaceAll('~1', '/').replaceAll('~0', '~')];
  if (keys.isEmpty) fail('mutate_input needs a path inside the value.');
  var target = input;
  for (final key in keys.take(keys.length - 1)) {
    target = switch (target) {
      final Map<String, Object?> map => map[key],
      final List<Object?> list => list[int.parse(key)],
      _ => fail('mutate_input path $path is not inside the value.'),
    };
  }
  switch (target) {
    case final Map<String, Object?> map:
      map[keys.last] = value;
    case final List<Object?> list:
      list[int.parse(keys.last)] = value;
    default:
      fail('mutate_input path $path is not inside the value.');
  }
  return null;
}

A2UIError? _dispose(A2UIDebugDataModel model) {
  model.dispose();
  return null;
}

Future<void> _runResolvePath(Map<String, Object?> testCase) async {
  final args = (testCase['args'] as Map<String, Object?>?) ?? const {};
  final resolved = debugResolvePath(args['path']! as String, contextPath: (args['contextPath'] as String?) ?? '/');
  expect(resolved, testCase['expect']);
}
