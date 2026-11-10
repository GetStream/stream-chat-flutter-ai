import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import '../a2ui_test_app.dart';

void main() {
  testWidgets('write writes a bound property to the data model', (tester) async {
    final (:processor, :scope) = await _pumpScope(tester, {'value': _name}, data: {'name': 'Ada'});

    scope().write('value', 'Grace');

    expect(processor.surface('s')!.read('/name'), 'Grace');
  });

  testWidgets('write shows the new value in every component bound to the same place', (tester) async {
    final (processor: _, :scope) = await _pumpScope(
      tester,
      {'value': _name},
      data: {'name': 'Ada'},
      others: [
        {'id': 'echo', 'component': 'Text', 'text': _name},
      ],
    );

    scope().write('value', 'Grace');
    await tester.pump();

    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets("write doesn't change a property written as a value", (tester) async {
    final (:processor, :scope) = await _pumpScope(tester, {'value': 'Ada'});

    scope().write('value', 'Grace');

    expect(processor.surface('s')!.read('/'), isEmpty);
  });

  testWidgets('hasAction is true for a component whose action names an event', (tester) async {
    final (processor: _, :scope) = await _pumpScope(type: 'Button', tester, {'action': _bookEvent});

    expect(scope().hasAction, isTrue);
  });

  testWidgets('hasAction is true for a component whose action calls a function', (tester) async {
    final (processor: _, :scope) = await _pumpScope(type: 'Button', tester, {'action': _openLink});

    expect(scope().hasAction, isTrue);
  });

  testWidgets('hasAction is false for a component without an action', (tester) async {
    final (processor: _, :scope) = await _pumpScope(tester, {});

    expect(scope().hasAction, isFalse);
  });

  testWidgets("performAction sends the event with the data model's values as they are then", (tester) async {
    final events = <A2UIActionEvent>[];
    final (:processor, :scope) = await _pumpScope(
      type: 'Button',

      tester,
      {'action': _bookEvent},
      data: {'name': 'Ada'},
      events: events,
    );
    processor.surface('s')!.write('/name', 'Grace');

    await scope().performAction();

    expect(events.single.context, {'name': 'Grace'});
  });

  testWidgets('performAction without an action sends nothing', (tester) async {
    final events = <A2UIActionEvent>[];
    final (processor: _, :scope) = await _pumpScope(tester, {}, events: events);

    await scope().performAction();

    expect(events, isEmpty);
  });

  testWidgets('performAction without an action reports nothing', (tester) async {
    final errors = <A2UIError>[];
    final (processor: _, :scope) = await _pumpScope(tester, {}, errors: errors);

    await scope().performAction();
    await tester.pump();

    expect(errors, isEmpty);
  });

  testWidgets('performAction opens the link of an action with the surface view', (tester) async {
    final opened = <Uri>[];
    final (processor: _, :scope) = await _pumpScope(type: 'Button', tester, {
      'action': _openLink,
    }, onOpenLink: opened.add);

    await scope().performAction();

    expect(opened, [Uri.parse('https://example.com/menu')]);
  });

  testWidgets('performAction reports a malformed event rather than throwing it', (tester) async {
    final errors = <A2UIError>[];
    final (processor: _, :scope) = await _pumpScope(
      type: 'Button',

      tester,
      {
        'action': {
          'event': {'name': ''},
        },
      },
      errors: errors,
    );

    await scope().performAction();
    await tester.pump();

    expect(errors.single.code, A2UIErrorCode.invalidAction);
  });

  testWidgets('validationErrors lists the messages of the checks that block', (tester) async {
    final (processor: _, :scope) = await _pumpScope(tester, {
      'checks': [_failing('First.'), _failing('Second.')],
    });

    expect(scope().validationErrors, ['First.', 'Second.']);
  });

  testWidgets('validationErrors leaves out a check that only warns', (tester) async {
    final (processor: _, :scope) = await _pumpScope(
      tester,
      {
        'checks': [
          {
            'condition': {'@path': '/seats'},
          },
        ],
      },
      data: {
        'seats': {'valid': false, 'severity': 'warning', 'message': 'Almost gone.'},
      },
    );

    expect(scope().validationErrors, isEmpty);
  });

  testWidgets('validationErrors gives the code of a failing check without a message', (tester) async {
    final (processor: _, :scope) = await _pumpScope(
      tester,
      {
        'checks': [
          {
            'condition': {'@path': '/verdict'},
          },
        ],
      },
      data: {
        'verdict': {'valid': false, 'code': 'EXPIRED'},
      },
    );

    expect(scope().validationErrors, ['EXPIRED']);
  });

  testWidgets('validationErrors is empty without checks', (tester) async {
    final (processor: _, :scope) = await _pumpScope(tester, {});

    expect(scope().validationErrors, isEmpty);
  });

  testWidgets('isValid is false while a check blocks', (tester) async {
    final (processor: _, :scope) = await _pumpScope(tester, {
      'checks': [_failing('Not yet.')],
    });

    expect(scope().isValid, isFalse);
  });

  testWidgets('isValid is true when a check only warns', (tester) async {
    final (processor: _, :scope) = await _pumpScope(
      tester,
      {
        'checks': [
          {
            'condition': {'@path': '/seats'},
          },
        ],
      },
      data: {
        'seats': {'valid': false, 'severity': 'warning'},
      },
    );

    expect(scope().isValid, isTrue);
  });

  testWidgets("isValid is true while a check's value isn't there yet", (tester) async {
    final (processor: _, :scope) = await _pumpScope(tester, {
      'checks': [
        {
          'condition': {'@path': '/accepted'},
        },
      ],
    });

    expect(scope().isValid, isTrue);
  });
}

const _name = {'@path': '/name'};

const _bookEvent = {
  'event': {
    'name': 'book',
    'context': {'name': _name},
  },
};

const _openLink = {
  'functionCall': {
    '@call': 'openUrl',
    'args': {'url': 'https://example.com/menu'},
  },
};

Map<String, Object?> _failing(String message) {
  return {
    'condition': {
      '@call': 'not',
      'args': {'value': true},
    },
    'message': message,
  };
}

// Shows a surface whose root holds a component of [type], `TextField` or
// `Button`, with [properties], drawn by a builder that keeps its scope, beside
// the components [others], and returns the processor and the latest scope.
Future<({A2UIProcessor processor, A2UIComponentScope Function() scope})> _pumpScope(
  WidgetTester tester,
  Map<String, Object?> properties, {
  String type = 'TextField',
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> others = const [],
  List<A2UIActionEvent>? events,
  List<A2UIError>? errors,
  A2UIOpenLink? onOpenLink,
}) async {
  late A2UIComponentScope latest;
  final catalog = A2UICatalog.basic.replacing(type, (context, scope) {
    latest = scope;
    return const SizedBox();
  });
  final required = switch (type) {
    'Button' => <String, Object?>{'child': 'label', 'action': _bookEvent},
    _ => <String, Object?>{'label': 'Name', 'value': _name},
  };
  final processor = await pumpSurface(
    tester,
    components: [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['subject', for (final other in others) other['id']],
      },
      {'id': 'subject', 'component': type, ...required, ...properties},
      {'id': 'label', 'component': 'Text', 'text': 'Book'},
      ...others,
    ],
    data: data,
    catalog: catalog,
    events: events,
    errors: errors,
    onOpenLink: onOpenLink,
  );
  return (processor: processor, scope: () => latest);
}
