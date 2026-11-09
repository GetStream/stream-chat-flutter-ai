import 'dart:convert';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

// The look of the media components before they play, in light and dark.
void main() {
  _goldenInBothThemes(
    'a Video and an AudioPlayer show their play buttons, or that they cannot play',
    'a2ui_video_audio',
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['video', 'no_video', 'audio', 'no_audio'],
      },
      {'id': 'video', 'component': 'Video', 'url': 'https://example.com/trailer.mp4'},
      {'id': 'no_video', 'component': 'Video', 'url': 'trailer.mp4'},
      {
        'id': 'audio',
        'component': 'AudioPlayer',
        'url': 'https://example.com/episode.mp3',
        'description': 'The Future of AI in Product Design',
      },
      {'id': 'no_audio', 'component': 'AudioPlayer', 'url': 'episode.mp3', 'description': 'Not available'},
    ],
  );

  _goldenInBothThemes(
    'an AudioPlayer keeps its caption to one line at twice the text size',
    'a2ui_audio_large_text',
    [
      {
        'id': 'root',
        'component': 'AudioPlayer',
        'url': 'https://example.com/episode.mp3',
        'description': 'The Future of AI in Product Design',
      },
    ],
    textScaler: const TextScaler.linear(2),
  );
}

// A golden of a surface of [components] in a light and a dark app, with its
// text scaled by [textScaler].
void _goldenInBothThemes(
  String description,
  String fileName,
  List<Map<String, Object?>> components, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  goldenTest(
    description,
    fileName: fileName,
    constraints: const BoxConstraints(maxWidth: 380),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final brightness in Brightness.values)
          GoldenTestScenario(
            name: brightness.name,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: _surface(components, brightness),
              ),
            ),
          ),
      ],
    ),
  );
}

// A surface of [components] on the background of a [brightness] app. Nothing
// plays, so the players show their boxes.
Widget _surface(List<Map<String, Object?>> components, Brightness brightness) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {'surfaceId': 's', 'catalogId': A2UICatalogs.defaultCatalogId, 'components': components},
    }),
  ]);
  final stream = StreamTheme(brightness: brightness);
  return Theme(
    data: ThemeData(brightness: brightness, extensions: [stream]),
    child: ColoredBox(
      color: stream.colorScheme.backgroundApp,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 340,
          child: A2UISurfaceView(surface: processor.surface('s')!),
        ),
      ),
    ),
  );
}
