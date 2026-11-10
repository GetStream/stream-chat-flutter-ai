import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import 'a2ui_reply_test_support.dart';

void main() {
  testWidgets("a surface naming the renderer's catalog id shows its components", (tester) async {
    final message = jsonEncode({
      'version': '1.0',
      'createSurface': {
        'surfaceId': 's',
        'catalogId': 'acme:catalog',
        'components': [
          {'id': 'root', 'component': 'Text', 'text': 'Hello'},
        ],
      },
    });

    await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([message])),
      ],
      renderer: (onError) => A2UIRenderer(catalogId: 'acme:catalog', onError: onError),
    );

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets("a reply's components are drawn by the renderer's catalog", (tester) async {
    final catalog = A2UICatalog.basic.replacing('Text', (context, scope) => Text('Drawn: ${scope.string('text')}'));

    await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_text)])),
      ],
      renderer: (onError) => A2UIRenderer(catalog: catalog, onError: onError),
    );

    expect(find.text('Drawn: Hello'), findsOneWidget);
  });

  testWidgets("a reply's media loads through the renderer's media function", (tester) async {
    final audio = surfaceMessage([
      {'id': 'root', 'component': 'AudioPlayer', 'url': 'https://example.com/song.mp3'},
    ]);

    await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([audio])),
      ],
      renderer: (onError) => A2UIRenderer(mediaUrl: (_) => null, onError: onError),
    );

    expect(find.byType(A2UIPlayButton), findsNothing);
  });

  testWidgets("a reply is drawn with the renderer's theme", (tester) async {
    final theme = A2UIThemeData(text: const Color(0xFF00FF00));

    await pumpReplies(
      tester,
      [
        TestReply('m1', a2uiDocument([surfaceMessage(_text)])),
      ],
      renderer: (onError) => A2UIRenderer(theme: theme, onError: onError),
    );

    expect(DefaultTextStyle.of(tester.element(find.text('Hello'))).style.color, const Color(0xFF00FF00));
  });
}

final _text = [
  {'id': 'root', 'component': 'Text', 'text': 'Hello'},
];
