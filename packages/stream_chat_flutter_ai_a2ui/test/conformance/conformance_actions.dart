part of 'a2ui_conformance.dart';

Future<void> _runDispatchAction(Map<String, Object?> testCase) async {
  final surfaceId = (testCase['surfaceId'] as String?) ?? 'main_surface';
  final harness =
      _Harness([
        A2UIDebugCatalog.basic(
          A2UICatalogs.basicCatalogId,
          functions: [
            const A2UIDebugFunction('incrementCounter', body: _incrementCounter),
            A2UIDebugFunction(
              'failingAction',
              body: (_, _) => throw StateError('The action failed.'),
            ),
          ],
        ),
      ])..process([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': surfaceId,
            'catalogId': A2UICatalogs.basicCatalogId,
            'dataModel': testCase['dataModel'] ?? const {},
          },
        },
      ]);
  final surface = harness.processor.surface(surfaceId)!;
  await debugAct(
    surface,
    testCase['actionPayload'],
    scope: (testCase['scope'] as String?) ?? '/',
    sourceComponentId: (testCase['sourceComponentId'] as String?) ?? 'button',
    userActivation: testCase['userActivation'] != false,
  );
  // The core answers and reports in microtasks after the call; this lets them
  // run, as there is no single event to wait for.
  await pumpEventQueue();
  final expectError = testCase['expectError'];
  if (expectError != null) {
    _assertErrorMatches(expectError, harness.errors);
  } else {
    expect(harness.errors, isEmpty, reason: 'A case that expects no error reported one.');
  }
  if (testCase.containsKey('expectDispatched')) {
    final expected = testCase['expectDispatched'];
    if (expected == null) {
      expect(harness.actions, isEmpty, reason: 'Nothing should be dispatched.');
    } else {
      final action = _actionJson(harness.actions.single);
      for (final MapEntry(:key, :value) in (expected as Map<String, Object?>).entries) {
        // This package's actions carry no timestamp: nothing reads one.
        if (key == 'timestampIso8601') continue;
        if (value == null) {
          expect(action[key], isNull, reason: key);
        } else {
          _assertContains(value, action[key], key);
        }
      }
    }
  }
  if (testCase['expectDataModel'] case final Object expected) _assertContains(expected, surface.read('/'));
}

Object? _incrementCounter(Map<String, Object?> args, A2UIDebugScope scope) {
  final path = args['path']! as String;
  final current = (scope.read(path) as num?) ?? 0;
  scope.write(path, (current + ((args['step'] as num?) ?? 1)).toInt());
  return null;
}

Map<String, Object?> _actionJson(A2UIActionEvent event) => {
  'name': event.name,
  'surfaceId': event.surfaceId,
  'sourceComponentId': event.sourceComponentId,
  'context': event.context,
  'userMessage': ?event.userMessage,
};
