import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test('act runs an event action, which reaches onAction', () async {
    final events = <A2UIActionEvent>[];
    final update = rootChild(planSurface(events: events), 'update');

    await update.act('action');

    expect(
      events.single,
      const A2UIActionEvent(
        name: 'update_plan',
        surfaceId: 'plan',
        sourceComponentId: 'update',
        context: {
          'pace': ['relaxed'],
        },
        userMessage: 'Update the plan',
      ),
    );
  });

  test('act does nothing for a property that holds no action', () async {
    final events = <A2UIActionEvent>[];
    final title = rootChild(planSurface(events: events), 'title');

    await title.act('text');

    expect(events, isEmpty);
  });

  test('act reports a link it has nothing to open with', () async {
    final reported = Completer<A2UIError>();
    final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: reported.complete);
    addTearDown(processor.dispose);
    processor.apply([createPlanSurface(), updatePlanComponents(components: _openUrlButton)]);

    await processor.surface('plan')!.root!.act('action');

    expect((await reported.future).code, A2UIErrorCode.expressionError);
  });

  test('act completes for a link it has nothing to open with', () async {
    final root = planSurface(components: _openUrlButton).root!;

    await expectLater(root.act('action'), completes);
  });

  test("act reports an event whose context reads a path that can't be read", () async {
    final errors = <A2UIError>[];
    final root = planSurface(components: _badPathButton, errors: errors).root!;

    await root.act('action');

    expect(errors.single.code, A2UIErrorCode.dataError);
  });

  test("act completes for an event whose context reads a path that can't be read", () async {
    final root = planSurface(components: _badPathButton).root!;

    await expectLater(root.act('action'), completes);
  });

  test("a function call doesn't reach onAction", () async {
    final events = <A2UIActionEvent>[];
    final root = planSurface(components: _openUrlButton, events: events).root!;

    await root.act('action');

    expect(events, isEmpty);
  });

  test('no event reaches onAction once the processor is disposed', () async {
    final events = <A2UIActionEvent>[];
    final processor = A2UIProcessor(catalogs: A2UICatalogs(), onAction: events.add)
      ..apply([createPlanSurface(), updatePlanComponents()]);
    final update = rootChild(processor.surface('plan')!, 'update');

    processor.dispose();
    await update.act('action');

    expect(events, isEmpty);
  });

  test('no event reaches onAction from a node whose surface was deleted', () async {
    final events = <A2UIActionEvent>[];
    final processor = testProcessor(events: events)..apply([createPlanSurface(), updatePlanComponents()]);
    final update = rootChild(processor.surface('plan')!, 'update');

    processor.apply([deletePlanSurface()]);
    await update.act('action');

    expect(events, isEmpty);
  });

  test('no event reaches onAction from a node of before a reset, though its surface is back', () async {
    final events = <A2UIActionEvent>[];
    final processor = testProcessor(events: events)..apply([createPlanSurface(), updatePlanComponents()]);
    final update = rootChild(processor.surface('plan')!, 'update');

    processor
      ..reset()
      ..apply([createPlanSurface(), updatePlanComponents()]);
    await update.act('action');

    expect(events, isEmpty);
  });
}

const _openUrlButton = [
  {
    'id': 'root',
    'component': 'Button',
    'child': 'label',
    'action': {
      'functionCall': {
        '@call': 'openUrl',
        'args': {'url': 'https://example.com'},
      },
    },
  },
  {'id': 'label', 'component': 'Text', 'text': 'Open'},
];

const _badPathButton = [
  {
    'id': 'root',
    'component': 'Button',
    'child': 'label',
    'action': {
      'event': {
        'name': 'book',
        'context': {
          'name': {'@path': '/name/~2'},
        },
      },
    },
  },
  {'id': 'label', 'component': 'Text', 'text': 'Book'},
];
