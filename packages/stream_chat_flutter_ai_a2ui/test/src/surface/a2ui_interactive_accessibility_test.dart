import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../a2ui_test_app.dart';

// A component a person interacts with is one node for assistive
// technologies, labelled with the agent's accessibility attributes.
void main() {
  testWidgets("an interactive component's label is on one node only", (tester) async {
    await pumpSurface(tester, components: _button({'label': 'Book a table'}));

    expect(find.bySemanticsLabel('Book a table'), findsOneWidget);
  });

  testWidgets("an interactive component's label is on the node a person taps", (tester) async {
    await pumpSurface(tester, components: _button({'label': 'Book a table'}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Book a table')).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
  });

  testWidgets('a modal whose trigger is a button is read with its own label around the button', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Modal',
          'trigger': 'open',
          'content': 'details',
          'accessibility': {'label': 'Opening hours', 'description': 'Shows when the shop is open.'},
        },
        {
          'id': 'open',
          'component': 'Button',
          'child': 'open_label',
          'action': {
            'event': {'name': 'open'},
          },
        },
        {'id': 'open_label', 'component': 'Text', 'text': 'Hours'},
        {'id': 'details', 'component': 'Text', 'text': 'Open daily.'},
      ],
    );

    final group = tester.getSemantics(find.bySemanticsLabel('Opening hours')).getSemanticsData();
    final button = tester.getSemantics(find.bySemanticsLabel('Hours')).getSemanticsData();
    expect(group.hint, 'Shows when the shop is open.');
    expect(button.hasAction(SemanticsAction.tap), isTrue);
    expect(button.label, 'Hours');
  });

  testWidgets('a hidden interactive component is left out for assistive technologies', (tester) async {
    await pumpSurface(tester, components: _button({'hidden': true}));

    expect(find.bySemanticsLabel('Book'), findsNothing);
  });

  testWidgets('a live interactive component announces a change of its label', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: _button({
        'label': {'@path': '/label'},
        'live': 'polite',
      }),
      data: {'label': 'Book a table'},
    );

    processor.surface('s')!.write('/label', 'Booked');
    await tester.pump();

    expect(tester.takeAnnouncements().map((it) => it.message), ['Booked']);
  });
}

List<Map<String, Object?>> _button(Map<String, Object?> accessibility) {
  return [
    {
      'id': 'root',
      'component': 'Button',
      'child': 'label',
      'accessibility': accessibility,
      'action': {
        'event': {'name': 'book'},
      },
    },
    {'id': 'label', 'component': 'Text', 'text': 'Book'},
  ];
}
