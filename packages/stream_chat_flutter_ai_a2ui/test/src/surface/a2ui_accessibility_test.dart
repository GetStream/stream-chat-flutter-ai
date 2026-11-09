import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../a2ui_test_app.dart';

// The accessibility attributes the agent gives a component.
void main() {
  testWidgets("a component's label is read in place of its text", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _text(accessibility: {'label': 'Trip title'}),
      ],
    );

    expect(find.semantics.byLabel('Trip title'), findsOne);
  });

  testWidgets("a labeled leaf's own text is not read", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _text(accessibility: {'label': 'Trip title'}),
      ],
    );

    expect(find.semantics.byLabel('Ohrid'), findsNothing);
  });

  testWidgets("a labeled container's children are still read", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Card',
          'child': 'title',
          'accessibility': {'label': 'Trip'},
        },
        {'id': 'title', 'component': 'Text', 'text': 'Ohrid'},
      ],
    );

    expect(find.semantics.byLabel(RegExp('Ohrid')), findsOne);
  });

  testWidgets("a component's description is its hint", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _text(accessibility: {'description': 'The city of the trip'}),
      ],
    );

    expect(find.semantics.byHint('The city of the trip'), findsOne);
  });

  testWidgets('a hidden component is not read', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _text(accessibility: {'hidden': true}),
      ],
    );

    expect(find.semantics.byLabel('Ohrid'), findsNothing);
  });

  testWidgets('a component that is not hidden is read', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _text(accessibility: {'hidden': false}),
      ],
    );

    expect(find.semantics.byLabel('Ohrid'), findsOne);
  });

  testWidgets('a politely live component announces its new text politely', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_boundText(live: 'polite')],
      data: {'status': 'Active'},
    );

    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements().map((it) => (it.message, it.assertiveness)), [('Offline', Assertiveness.polite)]);
  });

  testWidgets('an assertively live component announces its new text assertively', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_boundText(live: 'assertive')],
      data: {'status': 'Active'},
    );

    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements().map((it) => it.assertiveness), [Assertiveness.assertive]);
  });

  testWidgets('a live component with a label announces its label', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [
        _text(
          accessibility: {
            'live': 'assertive',
            'label': {
              '@call': 'formatString',
              'args': {'value': r'Status is ${/status}'},
            },
          },
        ),
      ],
      data: {'status': 'Active'},
    );

    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements().map((it) => it.message), ['Status is Offline']);
  });

  testWidgets('a live component announces nothing when it shows', (tester) async {
    await pumpSurface(
      tester,
      components: [_boundText(live: 'polite')],
      data: {'status': 'Active'},
    );
    await tester.pump();

    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('a component that is not live announces nothing when it changes', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_boundText(live: 'off')],
      data: {'status': 'Active'},
    );

    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('a live component announces nothing when it changes but its text stays the same', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_liveText()],
    );

    processor.apply([
      updateComponents([_liveText(variant: 'caption')]),
    ]);
    await tester.pump();

    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('a hidden live component announces nothing when it changes', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_boundText(live: 'assertive', hidden: true)],
      data: {'status': 'Active'},
    );

    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('a live component restored after its surface was released announces its changes', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_boundText(live: 'polite')],
      data: {'status': 'Active'},
    );

    // Two messages in one frame, as while the agent streams: the first
    // releases the tree and the second restores it, so the component's widget
    // is given a new node for the same component.
    processor.apply([
      updateComponents(_overTheCap()),
      updateComponents([_boundText(live: 'polite')]),
    ]);
    await tester.pump();
    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements().map((it) => it.message), ['Offline']);
  });

  testWidgets('an empty accessibility label is not read in place of the text', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _text(accessibility: {'label': ''}),
      ],
    );

    expect(find.semantics.byLabel('Ohrid'), findsOne);
  });

  testWidgets('a live component with an empty accessibility label announces its new text', (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_boundText(live: 'polite', label: '')],
      data: {'status': 'Active'},
    );

    processor.apply([updateData('/status', 'Offline')]);
    await tester.pump();

    expect(tester.takeAnnouncements().map((it) => it.message), ['Offline']);
  });
}

Map<String, Object?> _text({Map<String, Object?>? accessibility}) => {
  'id': 'root',
  'component': 'Text',
  'text': 'Ohrid',
  'accessibility': ?accessibility,
};

// A Text of the status in the data model.
Map<String, Object?> _boundText({required String live, bool? hidden, String? label}) => {
  'id': 'root',
  'component': 'Text',
  'text': {'@path': '/status'},
  'accessibility': {'live': live, 'hidden': ?hidden, 'label': ?label},
};

// A politely live Text whose text is written in it.
Map<String, Object?> _liveText({String? variant}) => {
  'id': 'root',
  'component': 'Text',
  'text': 'Active',
  'variant': ?variant,
  'accessibility': {'live': 'polite'},
};

// A root that lists a leaf 5,000 times: with the root, one more component
// than a surface may expand to, so the surface's tree is released.
List<Map<String, Object?>> _overTheCap() => [
  {'id': 'root', 'component': 'Column', 'children': List.filled(5000, 'leaf')},
  {'id': 'leaf', 'component': 'Text', 'text': 'x'},
];
