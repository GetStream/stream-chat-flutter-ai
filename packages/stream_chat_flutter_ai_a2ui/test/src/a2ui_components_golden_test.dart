import 'dart:convert';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

// The look of the components, in light and dark.
void main() {
  _goldenInBothThemes('Text draws a heading, body text, a caption, a list and a quote', 'a2ui_text', [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['heading', 'body', 'caption', 'markdown'],
    },
    {'id': 'heading', 'component': 'Text', 'text': '# A weekend in Ohrid'},
    {'id': 'body', 'component': 'Text', 'text': 'Two slow days by the lake.'},
    {'id': 'caption', 'component': 'Text', 'text': 'Updated just now', 'variant': 'caption'},
    {
      'id': 'markdown',
      'component': 'Text',
      'text': '### Saturday\n- **Plaošnik** in the morning\n- *Kaneo* at sunset\n\n> Bring a jacket for the boat.',
    },
  ]);

  _goldenInBothThemes('a Row, a Divider, a Card and Tabs lay out their children', 'a2ui_layout', [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['row', 'divider', 'card', 'tabs'],
    },
    {
      'id': 'row',
      'component': 'Row',
      'justify': 'spaceBetween',
      'children': ['left', 'line', 'right'],
    },
    {'id': 'left', 'component': 'Text', 'text': 'Saturday'},
    {'id': 'line', 'component': 'Divider', 'axis': 'vertical'},
    {'id': 'right', 'component': 'Text', 'text': '2 stops'},
    {'id': 'divider', 'component': 'Divider'},
    {'id': 'card', 'component': 'Card', 'child': 'card_text'},
    {'id': 'card_text', 'component': 'Text', 'text': 'Samuel’s Fortress opens at 9.'},
    {
      'id': 'tabs',
      'component': 'Tabs',
      'tabs': [
        {'title': 'Saturday', 'child': 'saturday'},
        {'title': 'Sunday', 'child': 'sunday'},
      ],
    },
    {'id': 'saturday', 'component': 'Text', 'text': 'The old town.'},
    {'id': 'sunday', 'component': 'Text', 'text': 'St. Naum.'},
  ]);

  _goldenInBothThemes(
    'icons show by name, by SVG path and as the help icon, and images show their empty boxes',
    'a2ui_media',
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['icons', 'images'],
      },
      {
        'id': 'icons',
        'component': 'Row',
        'children': ['star', 'home', 'path', 'unknown'],
      },
      {'id': 'star', 'component': 'Icon', 'name': 'star'},
      {'id': 'home', 'component': 'Icon', 'name': 'home'},
      {
        'id': 'path',
        'component': 'Icon',
        'name': {'svgPath': 'M6 6h12v12H6z'},
      },
      {'id': 'unknown', 'component': 'Icon', 'name': 'unicorn'},
      {
        'id': 'images',
        'component': 'Row',
        'align': 'center',
        'children': ['icon_image', 'avatar', 'small'],
      },
      {'id': 'icon_image', 'component': 'Image', 'url': 'https://example.com/a.png', 'variant': 'icon'},
      {'id': 'avatar', 'component': 'Image', 'url': 'https://example.com/b.png', 'variant': 'avatar'},
      {'id': 'small', 'component': 'Image', 'url': 'https://example.com/c.png', 'variant': 'smallFeature'},
    ],
  );

  _goldenInBothThemes(
    'text at twice the size fills a Row beside a value',
    'a2ui_text_large',
    [
      {
        'id': 'root',
        'component': 'Row',
        'children': ['label', 'value'],
      },
      {'id': 'label', 'component': 'Text', 'text': 'Departure', 'weight': 1},
      {'id': 'value', 'component': 'Text', 'text': '10:45'},
    ],
    textScaler: const TextScaler.linear(2),
  );

  for (final example in ['01_flight-status', '20_restaurant-card', '24_recipe-card']) {
    goldenTest(
      'the $example example shows each of its components',
      fileName: 'a2ui_example_${example.replaceAll('-', '_')}',
      constraints: const BoxConstraints(maxWidth: 380),
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          for (final brightness in Brightness.values)
            GoldenTestScenario(name: brightness.name, child: _example(example, brightness)),
        ],
      ),
    );
  }
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

// A surface of [components] on the background of a [brightness] app. Images
// don't load, so their boxes show.
Widget _surface(List<Map<String, Object?>> components, Brightness brightness) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {'surfaceId': 's', 'catalogId': A2UICatalogs.defaultCatalogId, 'components': components},
    }),
  ]);
  return _themed(processor.surface('s')!, brightness);
}

Widget _example(String name, Brightness brightness) {
  final file = File('test/fixtures/upstream_examples/$name.json');
  final messages = (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['messages']! as List<Object?>;
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply([for (final message in messages) jsonEncode(message)]);
  return _themed(processor.surface(processor.surfaceIds.single)!, brightness);
}

Widget _themed(A2UISurface surface, Brightness brightness) {
  final stream = StreamTheme(brightness: brightness);
  return Theme(
    data: ThemeData(brightness: brightness, extensions: [stream]),
    child: ColoredBox(
      color: stream.colorScheme.backgroundApp,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 340,
          child: A2UISurfaceView(surface: surface, mediaUrl: (url) => null),
        ),
      ),
    ),
  );
}
