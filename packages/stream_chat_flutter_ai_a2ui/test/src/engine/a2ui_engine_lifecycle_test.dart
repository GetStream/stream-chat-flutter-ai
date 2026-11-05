import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets('a reply no view asked for gets no surfaces from what the host receives', (tester) async {
    final city = TestTool('city', output: 'Ohrid');
    final harness = await pumpReplies(tester, const [], tools: [city]);

    harness.host.receive([
      TestReply('m1', a2uiDocument([surfaceMessage(_cityText)])),
    ]);
    await tester.pump();

    expect(city.runs, isEmpty);
  });

  testWidgets("a reply's view shows its surface", (tester) async {
    await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello'))])),
    ]);

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('a reply already shown follows what the host receives for it', (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello'))], isStreaming: true)),
    ]);

    harness.host.receive([
      TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello')), componentsMessage(_text('Bye'))])),
    ]);
    await tester.pump();

    expect(find.text('Bye'), findsOneWidget);
  });

  testWidgets('what the host receives while the screen builds changes the reply after the frame', (tester) async {
    final shown = TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello'))], isStreaming: true));
    final harness = await pumpReplies(tester, [shown]);
    final grown = TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello')), componentsMessage(_text('Bye'))]));

    // The reply's view builds before the widget that hands the host the grown
    // reply, so a change applied then would rebuild a widget already built in
    // this frame, which throws.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [StreamTheme.light()]),
        home: Material(
          child: Column(
            children: [
              AIUIView(host: harness.host, document: shown.uiDocument!, messageId: 'm1'),
              Builder(
                builder: (context) {
                  harness.host.receive([grown]);
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Bye'), findsOneWidget);
  });

  testWidgets('a reply keeps the document its view asked for over one received earlier in the frame', (tester) async {
    final shown = TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello'))], isStreaming: true));
    final harness = await pumpReplies(tester, [shown]);
    final grown = TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello')), componentsMessage(_text('Bye'))]));
    harness.host.receive([grown]);

    // An app hands the host a stale reply while the screen builds, and the
    // view then asks for the reply's latest document.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [StreamTheme.light()]),
        home: Material(
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  harness.host.receive([shown]);
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (context) => AIUIView(host: harness.host, document: grown.uiDocument!, messageId: 'm1'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bye'), findsOneWidget);
  });

  testWidgets('a removed reply starts again from its messages', (tester) async {
    final reply = TestReply('m1', a2uiDocument([surfaceMessage(_field)]));
    final harness = await pumpReplies(tester, [reply]);
    await tester.enterText(find.byType(EditableText), 'typed');

    await showReplies(tester, harness, const []);
    await showReplies(tester, harness, [reply]);

    expect(find.text('typed'), findsNothing);
  });

  testWidgets('a reply that stays keeps what the person typed', (tester) async {
    final reply = TestReply('m1', a2uiDocument([surfaceMessage(_field)]));
    final harness = await pumpReplies(tester, [reply]);
    await tester.enterText(find.byType(EditableText), 'typed');

    await showReplies(tester, harness, [reply]);

    expect(find.text('typed'), findsOneWidget);
  });

  testWidgets('two replies keep their own data', (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_field)])),
      TestReply('m2', a2uiDocument([surfaceMessage(_field)])),
    ]);

    await tester.enterText(find.byType(EditableText).first, 'first');
    await tester.pump();

    expect(find.text('first'), findsOneWidget);
    expect(harness.errors, isEmpty);
  });

  testWidgets("a tool's answer after the host is disposed changes nothing", (tester) async {
    final city = TestTool('city', holds: true);
    final harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_cityText)])),
      ],
      tools: [city],
    );
    expect(city.pending, isNotNull);

    await tester.pumpWidget(const SizedBox());
    harness.host.dispose();
    city.pending!.complete(AIClientToolCompleted('Ohrid'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets("a tool's answer after the reply left changes nothing", (tester) async {
    final city = TestTool('city', holds: true);
    final harness = await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_cityText)])),
      ],
      tools: [city],
    );

    await showReplies(tester, harness, const []);
    city.pending!.complete(AIClientToolCompleted('Ohrid'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(harness.errors, isEmpty);
  });

  testWidgets('a document that holds no A2UI shows the text', (tester) async {
    await pumpReplies(tester, [
      TestReply('m1', const AIUIDocument(format: AIUIFormat.a2ui, content: 42)),
    ]);

    expect(find.text('text of m1'), findsOneWidget);
  });
}

List<Map<String, Object?>> _text(String text) => [
  {'id': 'root', 'component': 'Text', 'text': text},
];

final _field = [
  {
    'id': 'root',
    'component': 'TextField',
    'label': 'Name',
    'value': {'@path': '/name'},
  },
];

final _cityText = [
  {
    'id': 'root',
    'component': 'Text',
    'text': {'@call': 'city', 'args': <String, Object?>{}},
  },
];
