import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_stream.dart';

import 'a2ui_test_app.dart';

// The refine form of the Ohrid weekend example an agent is shown when it
// learns to write A2UI: a pace to pick one of, interests to pick several of,
// and a button that sends both to the agent.
void main() {
  testWidgets("the form's pickers draw their options as chips", (tester) async {
    await _pumpOhrid(tester);

    final chips = [
      for (final option in ['Relaxed', 'Packed', 'History', 'Food', 'Nature', 'Swimming'])
        find.ancestor(of: find.text(option), matching: find.byWidgetPredicate(_isChip)),
    ];
    expect(chips, everyElement(findsOneWidget));
  });

  testWidgets('picking a pace and an interest and updating sends both', (tester) async {
    final events = <A2UIActionEvent>[];
    await _pumpOhrid(tester, events: events);

    for (final option in ['Packed', 'Food', 'Update the plan']) {
      await tester.ensureVisible(find.text(option));
      await tester.tap(find.text(option));
      await tester.pump();
    }

    expect(
      events.single,
      const A2UIActionEvent(
        name: 'update_plan',
        surfaceId: 'ohrid-weekend',
        sourceComponentId: 'update',
        context: {
          'pace': ['packed'],
          'interests': ['food'],
        },
        userMessage: 'Update the plan',
      ),
    );
  });
}

bool _isChip(Widget widget) {
  return widget is DecoratedBox &&
      widget.decoration is ShapeDecoration &&
      (widget.decoration as ShapeDecoration).shape is StadiumBorder;
}

Future<void> _pumpOhrid(WidgetTester tester, {List<A2UIActionEvent>? events}) async {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onAction: events?.add);
  addTearDown(processor.dispose);
  processor.apply(A2UIStream.messages(File('test/fixtures/ohrid_prompt_example.jsonl').readAsStringSync()));
  await tester.pumpWidget(surfaceApp(processor.surface('ohrid-weekend')!));
}
