part of 'a2ui_conformance.dart';

Future<void> _runHandleRpc(Map<String, Object?> testCase) async {
  final args = (testCase['args'] as Map<String, Object?>?) ?? const {};
  if (args['uiBindingScenario'] case final Map<String, Object?> scenario) return _runAgentBinding(testCase, scenario);
  if (args['uiActionFallbackScenario'] case final Map<String, Object?> scenario) {
    return _runAgentActionFallback(testCase, scenario);
  }
  final message = args['message'];
  if (message is! Map<String, Object?>) fail('Unsupported rpc case.');
  final metadata = (args['functionMetadata'] as Map<String, Object?>?) ?? const {};
  final callFunction = (message['callRendererFunction'] as Map<String, Object?>?)?['callFunction'];
  final callCatalogId = callFunction is Map<String, Object?> ? callFunction['catalogId'] as String? : null;
  final functions = [
    for (final MapEntry(key: name, value: raw) in metadata.entries)
      A2UIDebugFunction(
        name,
        definition: {
          'allowedCallers': 'rendererOnly',
          'requiresUserActivation': false,
          ...?(raw as Map<String, Object?>?),
        },
        body: _rpcFunction(name),
      ),
  ];
  final catalogs = {
    A2UICatalogs.basicCatalogId: const A2UIDebugCatalog.basic(A2UICatalogs.basicCatalogId),
    'basic': const A2UIDebugCatalog.basic('basic'),
  };
  // The suite names the catalog a case means to be missing
  // `non_existent_catalog`; it is left out, as the reference harnesses do.
  if (callCatalogId != null && callCatalogId != 'non_existent_catalog') {
    catalogs[callCatalogId] = catalogs.containsKey(callCatalogId)
        ? A2UIDebugCatalog.basic(callCatalogId, functions: functions)
        : A2UIDebugCatalog.document({
            'catalogId': callCatalogId,
            'protocolVersion': '1.0',
            'components': const <String, Object?>{},
          }, functions: functions);
  }
  final harness = _Harness(catalogs.values.toList());
  if (args['surfaceId'] case final String surfaceId) {
    harness.process([
      {
        'version': '1.0',
        'createSurface': {'surfaceId': surfaceId, 'catalogId': 'basic', 'dataModel': args['dataModel'] ?? const {}},
      },
    ]);
  }
  harness.sent.clear();
  harness.process([message]);
  // The core answers and reports in microtasks after the call; this lets them
  // run, as there is no single event to wait for.
  await pumpEventQueue();
  final expectation = testCase['expect'] as Map<String, Object?>?;
  final responses = [
    for (final sent in harness.sent)
      if (sent['rendererFunctionResponse'] case final Map<String, Object?> response) response,
  ];
  if (expectation != null && expectation.containsKey('response')) {
    final expected = expectation['response'];
    if (expected == null) {
      expect(responses, isEmpty);
    } else {
      expect(responses, hasLength(1));
      final expectedResponse = (expected as Map<String, Object?>)['rendererFunctionResponse']! as Map<String, Object?>;
      final actual = responses.single;
      expect(actual['functionCallId'], expectedResponse['functionCallId']);
      if (expectedResponse.containsKey('value')) _assertContains(expectedResponse['value'], actual['value'], 'value');
      if (expectedResponse['error'] case final Map<String, Object?> error) {
        final actualError = actual['error'];
        if (actualError is! Map<String, Object?>) fail('Expected an error, got $actual.');
        expect(actualError['code'], error['code']);
        expect(_messageMatches(error['message']! as String, actualError['message']! as String), isTrue);
      }
    }
  }
  final expectedError = expectation?['error'] ?? testCase['expectError'];
  if (expectation?['error'] case final Map<String, Object?> error) _assertErrorMatches(error, harness.errors);
  if (testCase['expectError'] case final Object expectError) _assertErrorMatches(expectError, harness.errors);
  if (expectedError == null) expect(harness.errors, isEmpty, reason: 'A case that expects no error reported one.');
}

Future<void> _runAgentBinding(Map<String, Object?> testCase, Map<String, Object?> scenario) async {
  final catalogId = scenario['catalogId']! as String;
  final surfaceId = scenario['surfaceId']! as String;
  final harness =
      _Harness([
        const A2UIDebugCatalog.basic(A2UICatalogs.basicCatalogId),
        A2UIDebugCatalog.basic(catalogId),
      ])..process([
        {
          'version': '1.0',
          'createSurface': {'surfaceId': surfaceId, 'catalogId': catalogId},
        },
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': surfaceId,
            'components': [scenario['component']],
          },
        },
      ]);
  final root = harness.processor.surface(surfaceId)!.root!;
  // The core answers and reports in microtasks after the call; this lets them
  // run, as there is no single event to wait for.
  await pumpEventQueue();
  final expected = testCase['expect']! as Map<String, Object?>;
  expect(root.property('text'), expected['initialValue']);
  final call = harness.sent.singleWhere((message) => message.containsKey('callAgentFunction'));
  _assertContains(expected['outboundCall'], call);
  final callId = (call['callAgentFunction']! as Map<String, Object?>)['functionCallId'];
  harness.process([
    {
      'version': '1.0',
      'agentFunctionResponse': {'functionCallId': callId, 'value': scenario['inboundResponseValue']},
    },
  ]);
  // The core answers and reports in microtasks after the call; this lets them
  // run, as there is no single event to wait for.
  await pumpEventQueue();
  expect(root.property('text'), expected['resolvedValue']);
}

Future<void> _runAgentActionFallback(Map<String, Object?> testCase, Map<String, Object?> scenario) async {
  final catalogId = scenario['catalogId']! as String;
  final surfaceId = scenario['surfaceId']! as String;
  final harness =
      _Harness([
        const A2UIDebugCatalog.basic(A2UICatalogs.basicCatalogId),
        A2UIDebugCatalog.basic(catalogId),
      ])..process([
        {
          'version': '1.0',
          'createSurface': {'surfaceId': surfaceId, 'catalogId': catalogId},
        },
      ]);
  final result = debugAct(harness.processor.surface(surfaceId)!, scenario['actionPayload']);
  // The core answers and reports in microtasks after the call; this lets them
  // run, as there is no single event to wait for.
  await pumpEventQueue();
  final expected = testCase['expect']! as Map<String, Object?>;
  final call = harness.sent.singleWhere((message) => message.containsKey('callAgentFunction'));
  _assertContains(expected['outboundCall'], call);
  final callId = (call['callAgentFunction']! as Map<String, Object?>)['functionCallId'];
  harness.process([
    {
      'version': '1.0',
      'agentFunctionResponse': {'functionCallId': callId, 'value': scenario['inboundResponseValue']},
    },
  ]);
  _assertContains(expected['result'], await result);
}

// The functions of the suite's `handle_rpc` cases, as the reference harnesses
// implement them.
A2UIDebugFunctionBody _rpcFunction(String name) => switch (name) {
  'playMedia' => (_, _) => {'playing': true, 'timestamp': 0},
  'openExternalUrl' => (_, _) => {'opened': true},
  'failingFunction' => (_, _) => throw StateError('An error occurred during function execution.'),
  'echoArgs' => (args, _) => args,
  _ => (_, _) => null,
};
