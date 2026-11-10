import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

import '../catalog/basic/a2ui_media_fakes.dart';
import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets('a streaming reply without a surface yet shows its text', (tester) async {
    await pumpReplies(tester, [TestReply('m1', a2uiDocument(const [], isStreaming: true))]);

    expect(find.text('text of m1'), findsOneWidget);
  });

  testWidgets('a streaming reply whose surface has no component yet shows its surface', (tester) async {
    await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(const [])], isStreaming: true)),
    ]);

    expect(find.text('text of m1'), findsNothing);
  });

  testWidgets('a finished reply without a surface shows its text', (tester) async {
    await pumpReplies(tester, [
      TestReply('m1', a2uiDocument(const ['Not A2UI'])),
    ]);

    expect(find.text('text of m1'), findsOneWidget);
  });

  testWidgets('a streaming reply shows its surface once it arrives', (tester) async {
    final harness = await pumpReplies(tester, [TestReply('m1', a2uiDocument(const [], isStreaming: true))]);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello'))], isStreaming: true)),
    ]);

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('the Ohrid reply streams in line by line, each part as it arrives', (tester) async {
    final lines = File('test/fixtures/ohrid_prompt_example.jsonl').readAsLinesSync();
    final harness = await pumpReplies(tester, [TestReply('m1', a2uiDocument(const [], isStreaming: true))]);

    for (var count = 1; count <= lines.length; count += 1) {
      await showReplies(tester, harness, [
        TestReply('m1', a2uiDocument(lines.sublist(0, count), isStreaming: count < lines.length)),
      ]);
      expect(tester.takeException(), isNull, reason: 'after line $count');
    }

    expect(find.text('Update the plan'), findsOneWidget);
  });

  testWidgets('a reply that grows keeps what the person typed', (tester) async {
    final first = surfaceMessage([
      {
        'id': 'root',
        'component': 'Column',
        'children': ['field', 'more'],
      },
      ..._field('field'),
    ]);
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([first], isStreaming: true)),
    ]);
    await tester.enterText(find.byType(EditableText), 'typed');

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([first, componentsMessage(_text('More', id: 'more'))], isStreaming: true)),
    ]);

    expect(find.text('typed'), findsOneWidget);
  });

  testWidgets('a reply whose earlier message changed starts again with the new one', (tester) async {
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_text('First draft'))], isStreaming: true)),
    ]);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([surfaceMessage(_text('Second draft'))], isStreaming: true)),
    ]);

    expect(find.text('First draft'), findsNothing);
    expect(find.text('Second draft'), findsOneWidget);
  });

  testWidgets('audio that started while the reply streamed keeps playing when it finishes', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    final audio = surfaceMessage([
      {'id': 'root', 'component': 'AudioPlayer', 'url': 'https://example.com/song.mp3'},
    ]);
    final harness = await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([audio], isStreaming: true)),
    ]);
    // The audio player comes in as the reply streams.
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Play'));
    await _until(tester, () => platform.players.isNotEmpty && platform.players.last.loaded.isNotEmpty);
    platform.players.last.finishLoading();
    await _until(tester, () => platform.players.last.plays > 0);

    await showReplies(tester, harness, [
      TestReply('m1', a2uiDocument([audio])),
    ]);
    await _settle(tester);

    expect(platform.disposed, isEmpty);
    expect(platform.players.single.pauses, 0);
  });

  testWidgets("a reply's surfaces show in the order the agent created them, 12 apart", (tester) async {
    await pumpReplies(tester, [
      TestReply(
        'm1',
        a2uiDocument([
          surfaceMessage(_text('First'), surfaceId: 'a'),
          surfaceMessage(_text('Second'), surfaceId: 'b'),
        ]),
      ),
    ]);

    final surfaces = find.byType(A2UISurfaceView);
    final first = tester.getRect(surfaces.at(0));
    final second = tester.getRect(surfaces.at(1));
    expect(find.descendant(of: surfaces.at(0), matching: find.text('First')), findsOneWidget);
    expect(second.top - first.bottom, 12.0);
  });

  testWidgets('a surface the agent deleted leaves the reply', (tester) async {
    await pumpReplies(tester, [
      TestReply(
        'm1',
        a2uiDocument([
          surfaceMessage(_text('Gone'), surfaceId: 'a'),
          surfaceMessage(_text('Kept'), surfaceId: 'b'),
          deleteMessage(surfaceId: 'a'),
        ]),
      ),
    ]);

    expect(find.text('Gone'), findsNothing);
    expect(find.text('Kept'), findsOneWidget);
  });

  testWidgets('a reply from history shows its surface at once', (tester) async {
    await pumpReplies(tester, [
      TestReply('m1', a2uiDocument([surfaceMessage(_text('Hello'))])),
    ]);

    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Hello'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1.0);
  });
}

List<Map<String, Object?>> _text(String text, {String id = 'root'}) => [
  {'id': id, 'component': 'Text', 'text': text},
];

List<Map<String, Object?>> _field(String id) => [
  {
    'id': id,
    'component': 'TextField',
    'label': 'Name',
    'value': {'@path': '/name'},
  },
];

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(pumpEventQueue);
  await tester.pump();
}

// Settles until [condition] holds, and fails if it never does within 50
// turns of the event queue, many more than the audio player needs.
Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var turn = 0; turn < 50 && !condition(); turn += 1) {
    await _settle(tester);
  }
  expect(condition(), isTrue);
}
