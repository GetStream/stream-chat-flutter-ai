part of 'a2ui_conformance.dart';

// Runs a `route_agent_function` case: creates surface `main` through the
// processor, binds or acts on each call the case evaluates, answers the
// `callAgentFunction` messages the processor sends, and checks what each step
// sent, reported, dispatched and left in the values bound so far.
Future<void> _runRouteAgentFunction(Map<String, Object?> testCase) async {
  final surfaceBlock = (testCase['surface'] as Map<String, Object?>?) ?? const {};
  final defaultCatalogId = surfaceBlock['catalogId'] as String?;
  final errors = <A2UIError>[];
  final actions = <A2UIActionEvent>[];
  final sent = <Map<String, Object?>>[];
  final catalogIds = [
    for (final catalog in (testCase['catalogs']! as List<Object?>).cast<Map<String, Object?>>())
      catalog['catalogId']! as String,
  ];
  final localById = {
    for (final catalog in (testCase['catalogs']! as List<Object?>).cast<Map<String, Object?>>())
      catalog['catalogId']! as String: ((catalog['localFunctions'] as List<Object?>?) ?? const []).cast<String>(),
  };
  final processor = debugProcessor(
    // Every catalog has the basic functions, which hold the case's
    // `localFunctions` and none of the functions it routes to the agent.
    catalogs: debugCatalogs([for (final id in catalogIds) A2UIDebugCatalog.basic(id, only: localById[id])]),
    onAction: actions.add,
    onError: errors.add,
    onOutbound: surfaceBlock['outboundListener'] == false ? null : sent.add,
  );
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {'surfaceId': 'main', 'catalogId': ?defaultCatalogId},
    }),
  ]);
  final surface = processor.surface('main')!;
  if (testCase['dataModel'] case final Object data) surface.write('/', data);

  final evaluations = <Object? Function()>[];
  final calls = <Map<String, Object?>>[];
  var probes = 0;
  final steps = (testCase['steps']! as List<Object?>).cast<Map<String, Object?>>();
  for (final (index, step) in steps.indexed) {
    final label = 'step $index';
    final errorsSeen = errors.length;
    final actionsSeen = actions.length;
    final sentSeen = sent.length;
    if (step['evaluate'] case final Map<String, Object?> call) {
      final kind = (step['as'] as String?) ?? 'binding';
      switch (kind) {
        case 'binding' || 'check':
          final binding = debugBind(surface, call, componentId: 'probe${probes++}', check: kind == 'check');
          addTearDown(binding.dispose);
          evaluations.add(binding.read);
          // Reading a value evaluates it, which is what makes the call.
          binding.read();
        case 'action' || 'event':
          final action = debugBindAction(
            surface,
            {(kind == 'event' ? 'event' : 'functionCall'): call},
            componentId: 'probe${probes++}',
            // A component of a surface without a default catalog names one.
            catalogId: defaultCatalogId == null ? catalogIds.first : null,
          );
          addTearDown(action.dispose);
          unawaited(action.run());
        default:
          fail('$label: unknown evaluation kind $kind.');
      }
    } else if (step['respond'] case final Map<String, Object?> respond) {
      final callId = calls[respond['call']! as int]['functionCallId'];
      processor.apply([
        jsonEncode({
          'version': '1.0',
          'agentFunctionResponse': {
            'functionCallId': callId,
            for (final MapEntry(:key, :value) in respond.entries)
              if (key != 'call') key: value,
          },
        }),
      ]);
    } else if (step['updateData'] case final Map<String, Object?> update) {
      surface.write(update['path']! as String, update['value']);
      // A drawn component reads its bindings again when the data changes,
      // which is what evaluates them again.
      for (final read in evaluations) {
        read();
      }
    } else if (step['deleteSurface'] == true) {
      processor.apply([
        jsonEncode({
          'version': '1.0',
          'deleteSurface': {'surfaceId': 'main'},
        }),
      ]);
    } else {
      fail('$label: unsupported step $step.');
    }
    // The core sends, answers and reports in microtasks after the step; this
    // lets them run, as there is no single event to wait for.
    await pumpEventQueue();

    final stepCalls = [
      for (final message in sent.sublist(sentSeen))
        if (message['callAgentFunction'] case final Map<String, Object?> call) call,
    ];
    calls.addAll(stepCalls);
    for (final call in stepCalls) {
      expect(call['surfaceId'], 'main', reason: '$label: surfaceId');
    }
    final expectedOutbound = (step['expectOutbound'] as List<Object?>?) ?? const [];
    expect(
      [for (final call in stepCalls) call['callFunction']],
      step['outboundInAnyOrder'] == true ? unorderedEquals(expectedOutbound) : expectedOutbound,
      reason: '$label: outbound calls',
    );

    final reported = errors.sublist(errorsSeen);
    final expectedErrors = ((step['expectErrors'] as List<Object?>?) ?? const []).cast<Map<String, Object?>>();
    expect(reported, hasLength(expectedErrors.length), reason: '$label: reported errors $reported');
    for (final (i, expected) in expectedErrors.indexed) {
      expect(_mismatch(expected, reported[i]), isNull, reason: '$label: ${reported[i]} for $expected');
    }

    expect(
      [
        for (final action in actions.sublist(actionsSeen))
          {'name': action.name, 'context': action.context, 'userMessage': ?action.userMessage},
      ],
      step['expectActions'] ?? const <Object?>[],
      reason: '$label: dispatched actions',
    );

    if (step.containsKey('expectValues')) {
      expect([for (final read in evaluations) read()], step['expectValues'], reason: '$label: values');
    }
  }
}
