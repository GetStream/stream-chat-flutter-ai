import 'dart:convert';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_stream.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

// The look of the components a person uses, in light and dark.
void main() {
  _goldenInBothThemes(
    'Buttons draw their variants, and a disabled one its failing check',
    'a2ui_buttons',
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['primary', 'default', 'borderless', 'disabled'],
      },
      ..._button('primary', 'Book a table', variant: 'primary'),
      ..._button('default', 'Call the restaurant'),
      ..._button('borderless', 'See the menu', variant: 'borderless'),
      ..._button(
        'disabled',
        'Confirm',
        variant: 'primary',
        checks: [
          {
            'condition': {'@path': '/accepted'},
            'message': 'Accept the terms first.',
          },
        ],
      ),
    ],
    data: {'accepted': false},
  );

  _goldenInBothThemes(
    'TextFields draw a placeholder, a value, a secret, several lines and a failing check',
    'a2ui_text_fields',
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['name', 'email', 'password', 'note'],
      },
      _field('name', 'Name', placeholder: 'Ada Lovelace'),
      _field(
        'email',
        'Email',
        checks: [
          {
            'condition': {
              '@call': 'email',
              'args': {
                'value': {'@path': '/email'},
              },
            },
            'message': 'Enter a valid email address.',
          },
        ],
      ),
      _field('password', 'Password', variant: 'obscured'),
      _field('note', 'Note', variant: 'longText'),
    ],
    data: {'email': 'ada@', 'password': 'hunter2', 'note': 'A table by the window, please.'},
  );

  _goldenInBothThemes(
    'a CheckBox, ChoicePickers as rows and as chips, a Slider and DateTimeInputs',
    'a2ui_choices',
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['subscribe', 'pace', 'interests', 'guests', 'day', 'time'],
      },
      {
        'id': 'subscribe',
        'component': 'CheckBox',
        'label': 'Send me the newsletter',
        'value': {'@path': '/subscribe'},
      },
      {
        'id': 'pace',
        'component': 'ChoicePicker',
        'label': 'Pace',
        'options': [
          {'label': 'Relaxed', 'value': 'relaxed'},
          {'label': 'Packed', 'value': 'packed'},
        ],
        'value': {'@path': '/pace'},
      },
      {
        'id': 'interests',
        'component': 'ChoicePicker',
        'label': 'More of',
        'variant': 'multipleSelection',
        'displayStyle': 'chips',
        'options': [
          {'label': 'History', 'value': 'history'},
          {'label': 'Food', 'value': 'food'},
          {'label': 'Nature', 'value': 'nature'},
          {'label': 'Swimming', 'value': 'swimming'},
        ],
        'value': {'@path': '/interests'},
      },
      {
        'id': 'guests',
        'component': 'Slider',
        'label': 'Guests',
        'min': 1,
        'max': 8,
        'steps': 7,
        'value': {'@path': '/guests'},
      },
      {
        'id': 'day',
        'component': 'DateTimeInput',
        'label': 'Arrival',
        'value': {'@path': '/day'},
      },
      {
        'id': 'time',
        'component': 'DateTimeInput',
        'label': 'Dinner',
        'enableTime': true,
        'value': {'@path': '/time'},
      },
    ],
    data: {
      'subscribe': true,
      'pace': ['relaxed'],
      'interests': ['food', 'nature'],
      'guests': 3,
      'day': '2026-10-02',
      'time': '',
    },
  );

  _goldenInBothThemes(
    'a form at twice the text size keeps its fields within its width',
    'a2ui_form_large',
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['row', 'subscribe', 'book'],
      },
      {
        'id': 'row',
        'component': 'Row',
        'children': ['caption', 'name'],
      },
      {'id': 'caption', 'component': 'Text', 'text': 'Who'},
      _field('name', 'Name', placeholder: 'Ada Lovelace'),
      {
        'id': 'subscribe',
        'component': 'CheckBox',
        'label': 'Send me the newsletter every week',
        'value': {'@path': '/subscribe'},
      },
      ..._button('book', 'Book a table by the window', variant: 'primary'),
    ],
    data: {'subscribe': false},
    textScaler: const TextScaler.linear(2),
  );

  goldenTest(
    'a Modal opens its content in a sheet',
    fileName: 'a2ui_modal_sheet',
    constraints: const BoxConstraints.tightFor(width: 380, height: 520),
    whilePerforming: (tester) async {
      await tester.tap(find.text('Opening hours'));
      await tester.pumpAndSettle();
      return null;
    },
    builder: () => _surface(
      [
        {'id': 'root', 'component': 'Modal', 'trigger': 'open', 'content': 'hours'},
        ..._button('open', 'Opening hours'),
        {'id': 'hours', 'component': 'Text', 'text': 'Open daily, 9 to 5. Closed on public holidays.'},
      ],
      Brightness.light,
    ),
  );

  for (final example in ['09_login-form', '19_software-purchase', '32_advanced-form-validator']) {
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

  goldenTest(
    'the refine form of the Ohrid example shows its choices as chips',
    fileName: 'a2ui_ohrid_form',
    constraints: const BoxConstraints(maxWidth: 380),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final brightness in Brightness.values)
          GoldenTestScenario(name: brightness.name, child: _ohrid(brightness)),
      ],
    ),
  );
}

List<Map<String, Object?>> _button(
  String id,
  String text, {
  String? variant,
  List<Map<String, Object?>>? checks,
}) {
  return [
    {
      'id': id,
      'component': 'Button',
      'child': '${id}_label',
      'variant': ?variant,
      'checks': ?checks,
      'action': {
        'event': {'name': id},
      },
    },
    {'id': '${id}_label', 'component': 'Text', 'text': text},
  ];
}

Map<String, Object?> _field(
  String id,
  String label, {
  String? variant,
  String? placeholder,
  List<Map<String, Object?>>? checks,
}) {
  return {
    'id': id,
    'component': 'TextField',
    'label': label,
    'value': {'@path': '/$id'},
    'variant': ?variant,
    'placeholder': ?placeholder,
    'checks': ?checks,
  };
}

// A golden of a surface of [components] over [data] in a light and a dark
// app, with its text scaled by [textScaler].
void _goldenInBothThemes(
  String description,
  String fileName,
  List<Map<String, Object?>> components, {
  Map<String, Object?> data = const {},
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
                child: _surface(components, brightness, data: data),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _surface(List<Map<String, Object?>> components, Brightness brightness, {Map<String, Object?> data = const {}}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {
        'surfaceId': 's',
        'catalogId': A2UICatalogs.defaultCatalogId,
        'components': components,
        'dataModel': data,
      },
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

Widget _ohrid(Brightness brightness) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply(A2UIStream.messages(File('test/fixtures/ohrid_prompt_example.jsonl').readAsStringSync()));
  return _themed(processor.surface('ohrid-weekend')!, brightness);
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
