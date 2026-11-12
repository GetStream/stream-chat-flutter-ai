import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets('a tap on a button sends an action named after its event', (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it', event: 'book_day'));

    await tester.tap(find.text('Book it'));

    final action = harness.actions.single;
    expect((action.messageId, action.format, action.name), ('m1', AIUIFormat.a2ui, 'book_day'));
  });

  testWidgets("an action's label is the text its button shows", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Update the plan'));

    await tester.tap(find.text('Update the plan'));

    expect(harness.actions.single.label, 'Update the plan');
  });

  testWidgets("an action's label is never the agent's words for it", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it', userMessage: 'Yes, I authorize the transfer'));

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.label, 'Book it');
  });

  testWidgets("an action's label is the text a button shows from the data model", (tester) async {
    final harness = await _pumpButton(
      tester,
      [
        {
          'id': 'root',
          'component': 'Button',
          'child': 'label',
          'action': {
            'event': {'name': 'book'},
          },
        },
        {
          'id': 'label',
          'component': 'Text',
          'text': {'@path': '/cta'},
        },
      ],
      data: {'cta': 'Reserve a table'},
    );

    await tester.tap(find.text('Reserve a table'));

    expect(harness.actions.single.label, 'Reserve a table');
  });

  for (final (name, path) in [('the path', '/password'), ('a path holding', '/')]) {
    testWidgets("a button reading $name an obscured field's value is labeled with its event's name", (tester) async {
      final harness = await _pumpButton(
        tester,
        _signIn(variant: 'obscured', labelText: {'@path': path}),
        data: {'password': 'hunter2'},
      );

      await tester.tap(find.byType(GestureDetector).last);

      expect(harness.actions.single.label, 'Sign in');
    });
  }

  testWidgets("a button reading a field that isn't obscured shows its value as the label", (tester) async {
    final harness = await _pumpButton(tester, _signIn(labelText: {'@path': '/password'}), data: {'password': 'pv'});

    await tester.tap(find.byType(GestureDetector).last);

    expect(harness.actions.single.label, 'pv');
  });

  testWidgets("an action's label is the number a button shows from the data model", (tester) async {
    final harness = await _pumpButton(
      tester,
      [
        {
          'id': 'root',
          'component': 'Button',
          'child': 'label',
          'action': {
            'event': {'name': 'pick_seat'},
          },
        },
        {
          'id': 'label',
          'component': 'Text',
          'text': {'@path': '/seat'},
        },
      ],
      data: {'seat': 42},
    );

    await tester.tap(find.text('42'));

    expect(harness.actions.single.label, '42');
  });

  testWidgets("an icon button's action is labeled with its event's name in words", (tester) async {
    final harness = await _pumpButton(tester, [
      {
        'id': 'root',
        'component': 'Button',
        'child': 'icon',
        'action': {
          'event': {'name': 'submit_form'},
        },
      },
      {'id': 'icon', 'component': 'Icon', 'name': 'send'},
    ]);

    await tester.tap(find.byType(GestureDetector).first);

    expect(harness.actions.single.label, 'Submit form');
  });

  testWidgets("a button whose text reads its list item is labeled with its event's name in words", (tester) async {
    final harness = await _pumpButton(
      tester,
      [
        {
          'id': 'root',
          'component': 'List',
          'children': {'componentId': 'pick', 'path': '/places'},
        },
        {
          'id': 'pick',
          'component': 'Button',
          'child': 'label',
          'action': {
            'event': {'name': 'select_place'},
          },
        },
        {
          'id': 'label',
          'component': 'Text',
          'text': {'@path': 'name'},
        },
      ],
      data: {
        'places': [
          {'name': 'Kaneo'},
        ],
      },
    );

    await tester.tap(find.text('Kaneo'));

    expect(harness.actions.single.label, 'Select place');
  });

  testWidgets("a button with empty text is labeled with its event's name in words", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('', event: 'go_on'));

    await tester.tap(find.byType(GestureDetector).first);

    expect(harness.actions.single.label, 'Go on');
  });

  testWidgets("a button with blank text is labeled with its event's name in words", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('   ', event: 'go_on'));

    await tester.tap(find.byType(GestureDetector).first);

    expect(harness.actions.single.label, 'Go on');
  });

  testWidgets("an action's payload holds its surface, its component and its context", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it', context: {'day': 2}));

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.payload, {
      'surfaceId': 's',
      'sourceComponentId': 'root',
      'context': {'day': 2},
    });
  });

  testWidgets("an action's payload holds the agent's userMessage", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it', userMessage: 'Book the boat'));

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.payload['userMessage'], 'Book the boat');
  });

  testWidgets("an action's payload leaves out an empty userMessage", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it', userMessage: ''));

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.payload.containsKey('userMessage'), isFalse);
  });

  testWidgets("an action holds its surface's data model when the agent asked for it", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it'), data: {'day': 2}, sendDataModel: true);

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.payload['dataModel'], {'day': 2});
  });

  testWidgets("an action leaves out its surface's data model unless the agent asked for it", (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it'), data: {'day': 2});

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.payload.containsKey('dataModel'), isFalse);
  });

  testWidgets("an action's data model holds what the person typed into a field that isn't obscured", (tester) async {
    final harness = await _pumpButton(tester, _signIn(), data: {'user': 'pv'}, sendDataModel: true);
    await tester.enterText(find.byType(EditableText), 'hunter2');

    await tester.tap(find.text('Sign in'));

    expect(harness.actions.single.payload['dataModel'], {'user': 'pv', 'password': 'hunter2'});
  });

  testWidgets('a large action is sent whole', (tester) async {
    // Over 8 KB as JSON, the most the agent's backend takes.
    final note = 'x' * 9000;
    final harness = await _pumpButton(tester, buttonSaying('Book it'), data: {'note': note}, sendDataModel: true);

    await tester.tap(find.text('Book it'));

    expect(harness.actions.single.payload['dataModel'], {'note': note});
  });

  testWidgets('each tap sends its own action', (tester) async {
    final harness = await _pumpButton(tester, buttonSaying('Book it'));

    await tester.tap(find.text('Book it'));
    await tester.tap(find.text('Book it'));

    expect(harness.actions, hasLength(2));
  });

  testWidgets("a link a person's tap opens goes to the host", (tester) async {
    final harness = await _pumpButton(tester, [
      {
        'id': 'root',
        'component': 'Button',
        'child': 'label',
        'action': {
          'functionCall': {
            '@call': 'openUrl',
            'args': {'url': 'https://ohrid.example/boat'},
          },
        },
      },
      {'id': 'label', 'component': 'Text', 'text': 'Boat times'},
    ]);

    await tester.tap(find.text('Boat times'));
    await tester.pump();

    expect(harness.links, [Uri.parse('https://ohrid.example/boat')]);
  });

  testWidgets("an email link a person's tap opens goes to the host", (tester) async {
    final harness = await _pumpButton(tester, [
      {
        'id': 'root',
        'component': 'Button',
        'child': 'label',
        'action': {
          'functionCall': {
            '@call': 'openUrl',
            'args': {'url': 'mailto:boats@ohrid.example'},
          },
        },
      },
      {'id': 'label', 'component': 'Text', 'text': 'Email the harbour'},
    ]);

    await tester.tap(find.text('Email the harbour'));
    await tester.pump();

    expect(harness.links, [Uri.parse('mailto:boats@ohrid.example')]);
    expect(harness.errors, isEmpty);
  });

  testWidgets('a link opens only from a tap, not as a surface shows', (tester) async {
    final harness = await _pumpButton(tester, [
      {
        'id': 'root',
        'component': 'Text',
        'text': {
          '@call': 'openUrl',
          'args': {'url': 'https://ohrid.example/boat'},
        },
      },
    ]);

    expect(harness.links, isEmpty);
  });
}

Future<ReplyHarness> _pumpButton(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  Map<String, Object?> data = const {},
  bool sendDataModel = false,
}) {
  final document = a2uiDocument([surfaceMessage(components, data: data, sendDataModel: sendDataModel)]);
  return pumpReplies(tester, [TestReply('m1', document)]);
}

// A password field and a Sign in button, the field of [variant].
List<Map<String, Object?>> _signIn({String? variant, Object labelText = 'Sign in'}) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['password', 'go'],
  },
  {
    'id': 'password',
    'component': 'TextField',
    'label': 'Password',
    'variant': ?variant,
    'value': {'@path': '/password'},
  },
  {
    'id': 'go',
    'component': 'Button',
    'child': 'label',
    'action': {
      'event': {'name': 'sign_in'},
    },
  },
  {'id': 'label', 'component': 'Text', 'text': labelText},
];
