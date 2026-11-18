import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test("a failing check gives the agent's message ahead of its function's", () {
    final field = _field(
      checks: [
        {'condition': _email, 'message': 'Enter your work email.'},
      ],
      data: {'email': 'not an email'},
    );

    expect(field.failingChecks.single.message, 'Enter your work email.');
  });

  test("a failing check without a message of its own gives its function's", () {
    final field = _field(
      checks: [
        {'condition': _email},
      ],
      data: {'email': 'not an email'},
    );

    expect(field.failingChecks.single.message, 'Must be a valid email address.');
  });

  test('a passing check is not among the failing checks', () {
    final field = _field(
      checks: [
        {'condition': _email, 'message': 'Enter your work email.'},
      ],
      data: {'email': 'person@example.com'},
    );

    expect(field.failingChecks, isEmpty);
  });

  test('a failing check whose condition gives no message has none', () {
    final field = _field(
      checks: [
        {
          'condition': {
            '@call': 'and',
            'args': {
              'values': [true, false],
            },
          },
        },
      ],
    );

    expect(field.failingChecks.single, const A2UICheckFailure());
  });

  test("a result read from the data model gives its message ahead of the agent's", () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
          'message': 'Not accepted.',
        },
      ],
      data: {
        'verdict': {'valid': false, 'message': 'The code has expired.'},
      },
    );

    expect(field.failingChecks.single.message, 'The code has expired.');
  });

  test("a result read from the data model without a message gives the agent's", () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
          'message': 'Not accepted.',
        },
      ],
      data: {
        'verdict': {'valid': false},
      },
    );

    expect(field.failingChecks.single.message, 'Not accepted.');
  });

  test('a result keeps its code', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
        },
      ],
      data: {
        'verdict': {'valid': false, 'code': 'EXPIRED'},
      },
    );

    expect(field.failingChecks.single.code, 'EXPIRED');
  });

  test('a result marked as a warning fails as a warning', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
        },
      ],
      data: {
        'verdict': {'valid': false, 'severity': 'warning'},
      },
    );

    expect(field.failingChecks.single.severity, A2UICheckSeverity.warning);
  });

  test('a result marked as information fails as information', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
        },
      ],
      data: {
        'verdict': {'valid': false, 'severity': 'info'},
      },
    );

    expect(field.failingChecks.single.severity, A2UICheckSeverity.info);
  });

  test('a result of a severity A2UI has no name for fails as an error', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
        },
      ],
      data: {
        'verdict': {'valid': false, 'severity': 'fatal'},
      },
    );

    expect(field.failingChecks.single.severity, A2UICheckSeverity.error);
  });

  test('a check whose condition reads nothing yet passes', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/accepted'},
          'message': 'Accept the terms.',
        },
      ],
    );

    expect(field.failingChecks, isEmpty);
  });

  test('a check whose condition reads false fails', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/accepted'},
          'message': 'Accept the terms.',
        },
      ],
      data: {'accepted': false},
    );

    expect(field.failingChecks.single.message, 'Accept the terms.');
  });

  test("a check whose condition can't be evaluated fails with the agent's message", () {
    final field = _field(
      checks: [
        {
          'condition': _invalidPattern,
          'message': 'Check the code.',
        },
      ],
    );

    expect(field.failingChecks.single.message, 'Check the code.');
  });

  test("a check whose condition can't be evaluated says so without a message of its own", () {
    final field = _field(
      checks: [
        {
          'condition': _invalidPattern,
        },
      ],
    );

    expect(field.failingChecks.single.message, 'This value could not be checked.');
  });

  test('a check whose condition reads 0 fails', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/count'},
          'message': 'Add one.',
        },
      ],
      data: {'count': 0},
    );

    expect(field.failingChecks.single.message, 'Add one.');
  });

  test('a check whose condition reads the string false fails', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/flag'},
          'message': 'Not yet.',
        },
      ],
      data: {'flag': 'FALSE'},
    );

    expect(field.failingChecks.single.message, 'Not yet.');
  });

  test("a check whose condition reads text that isn't a boolean fails", () {
    final field = _maybeChecked();

    expect(field.failingChecks.single.message, 'This value could not be checked.');
  });

  test("a check whose condition reads text that isn't a boolean is reported", () async {
    final errors = <A2UIError>[];
    _maybeChecked(errors: errors).failingChecks;
    await pumpEventQueue();

    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  test("the report of a check that reads text that isn't a boolean doesn't repeat the text", () async {
    final errors = <A2UIError>[];
    _maybeChecked(errors: errors).failingChecks;
    await pumpEventQueue();

    expect(errors.single.message, isNot(contains('maybe')));
  });

  test("a result whose valid isn't a boolean fails with the agent's message", () {
    final field = _noResultChecked();

    expect(field.failingChecks.single.message, 'Check the value.');
  });

  test("a result whose valid isn't a boolean is reported", () async {
    final errors = <A2UIError>[];
    _noResultChecked(errors: errors).failingChecks;
    await pumpEventQueue();

    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  test('a result whose valid is not there yet passes', () {
    final field = _field(
      checks: [
        {
          'condition': {'@path': '/verdict'},
        },
      ],
      data: {
        'verdict': {'valid': null},
      },
    );

    expect(field.failingChecks, isEmpty);
  });

  group('a check calling a function only the agent answers', () {
    test('passes while the answer is on its way', () async {
      final (_, field) = _agentChecked([]);
      await pumpEventQueue();

      expect(field.failingChecks, isEmpty);
    });

    test('asks the agent once', () async {
      final sent = <Map<String, Object?>>[];
      final (_, field) = _agentChecked(sent);
      await pumpEventQueue();

      field.failingChecks;

      expect(sent, hasLength(1));
    });

    test('fails once the agent answers that it fails', () async {
      final sent = <Map<String, Object?>>[];
      final (processor, field) = _agentChecked(sent);
      await pumpEventQueue();

      _answer(processor, sent.single, {'value': false});
      await pumpEventQueue();

      expect(field.failingChecks.single.message, 'Too weak.');
    });

    test('passes once the agent answers that it passes', () async {
      final sent = <Map<String, Object?>>[];
      final (processor, field) = _agentChecked(sent);
      await pumpEventQueue();

      _answer(processor, sent.single, {'value': true});
      await pumpEventQueue();

      expect(field.failingChecks, isEmpty);
    });

    test("fails when the agent's answer is an error", () async {
      final sent = <Map<String, Object?>>[];
      final (processor, field) = _agentChecked(sent);
      await pumpEventQueue();

      _answer(processor, sent.single, {
        'error': {'code': 'NOT_FOUND', 'message': 'No such function.'},
      });
      await pumpEventQueue();

      expect(field.failingChecks.single.message, 'Too weak.');
    });
  });

  test('a check whose condition names another catalog of the processor is evaluated there', () {
    final processor = debugProcessor(catalogs: _catalogsAnsweringDifferently());
    addTearDown(processor.dispose);
    final field = planSurface(
      processor: processor,
      components: [
        _fieldComponent(
          checks: [
            {
              'condition': {'@call': 'verdict', 'catalogId': _strictCatalogId},
              'message': 'The strict catalog says no.',
            },
          ],
        ),
      ],
    ).root!;

    expect(field.failingChecks.single.message, 'The strict catalog says no.');
  });

  test('failing checks keep the order the agent wrote them in', () {
    final field = _field(
      checks: [
        {'condition': _email, 'message': 'First.'},
        {
          'condition': {'@path': '/accepted'},
          'message': 'Second.',
        },
      ],
      data: {'email': 'not an email', 'accepted': false},
    );

    expect(field.failingChecks.map((failure) => failure.message), ['First.', 'Second.']);
  });

  test('a check fails once the data it reads changes to fail it', () {
    final surface = planSurface(
      components: [
        _fieldComponent(
          checks: [
            {'condition': _email},
          ],
        ),
      ],
      data: {'email': 'person@example.com'},
    );
    // Reading the failing checks first makes the node keep them until the data changes.
    final field = surface.root!..failingChecks;

    surface.write('/email', 'not an email');

    expect(field.failingChecks, hasLength(1));
  });

  test('a component without checks has no failing checks', () {
    final field = _field(checks: null);

    expect(field.failingChecks, isEmpty);
  });

  test('a disposed node has no failing checks', () {
    final processor = testProcessor()
      ..apply([
        createPlanSurface(data: {'email': 'not an email'}),
        updatePlanComponents(
          components: [
            _fieldComponent(
              checks: [
                {'condition': _email},
              ],
            ),
          ],
        ),
      ]);
    final field = processor.surface('plan')!.root!;

    processor.reset();

    expect(field.failingChecks, isEmpty);
  });
}

// A condition that can't be evaluated: a pattern that doesn't parse.
const _invalidPattern = {
  '@call': 'regex',
  'args': {'value': 'x', 'pattern': '('},
};

const _email = {
  '@call': 'email',
  'args': {
    'value': {'@path': '/email'},
  },
};

Map<String, Object?> _fieldComponent({required List<Map<String, Object?>>? checks}) {
  return {
    'id': 'root',
    'component': 'TextField',
    'label': 'Email',
    'value': {'@path': '/email'},
    'checks': ?checks,
  };
}

// The root of a surface holding one email field with [checks], over [data].
A2UINode _field({
  required List<Map<String, Object?>>? checks,
  Map<String, Object?> data = const {},
  List<A2UIError>? errors,
}) {
  return planSurface(
    components: [_fieldComponent(checks: checks)],
    data: data,
    errors: errors,
  ).root!;
}

// A field whose check reads `/flag`, which holds text that isn't a boolean.
A2UINode _maybeChecked({List<A2UIError>? errors}) {
  return _field(
    checks: [
      {
        'condition': {'@path': '/flag'},
      },
    ],
    data: {'flag': 'maybe'},
    errors: errors,
  );
}

// A field whose check reads a result with a `valid` that isn't a boolean.
A2UINode _noResultChecked({List<A2UIError>? errors}) {
  return _field(
    checks: [
      {
        'condition': {'@path': '/verdict'},
        'message': 'Check the value.',
      },
    ],
    data: {
      'verdict': {'valid': 'no'},
    },
    errors: errors,
  );
}

// A surface whose field's check calls `strength`, which no catalog has, on a
// processor whose calls to the agent go to [sent].
(A2UIProcessor, A2UINode) _agentChecked(List<Map<String, Object?>> sent) {
  final processor = debugProcessor(catalogs: A2UICatalogs(), onOutbound: sent.add);
  addTearDown(processor.dispose);
  final surface = planSurface(
    processor: processor,
    data: {'email': 'ada@example.com'},
    components: [
      _fieldComponent(
        checks: [
          {
            'condition': {
              '@call': 'strength',
              'args': {
                'value': {'@path': '/email'},
              },
            },
            'message': 'Too weak.',
          },
        ],
      ),
    ],
  );
  return (processor, surface.root!);
}

// The agent's [response] to the function call in [sent].
void _answer(A2UIProcessor processor, Map<String, Object?> sent, Map<String, Object?> response) {
  final call = sent['callAgentFunction']! as Map<String, Object?>;
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'agentFunctionResponse': {'functionCallId': call['functionCallId'], ...response},
    }),
  ]);
}

const _strictCatalogId = 'https://example.com/strict.json';

// The basic catalog under its usual id, whose `verdict` function says yes, and
// a second catalog whose `verdict` says no.
A2UICatalogs _catalogsAnsweringDifferently() {
  return debugCatalogs([
    A2UIDebugCatalog.basic(
      A2UICatalogs.defaultCatalogId,
      functions: [A2UIDebugFunction('verdict', body: (args, scope) => true)],
    ),
    A2UIDebugCatalog.basic(_strictCatalogId, functions: [A2UIDebugFunction('verdict', body: (args, scope) => false)]),
  ]);
}
