import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_action_label.dart';

void main() {
  test('an event name reads as the words iOS reads it as, for every name of the fixture', () {
    final fixture = jsonDecode(File('test/fixtures/ios_action_labels.json').readAsStringSync()) as Map<String, Object?>;
    final cases = (fixture['words']! as List<Object?>).cast<Map<String, Object?>>();

    expect(
      {for (final entry in cases) entry['name']: a2uiWords(entry['name']! as String)},
      {for (final entry in cases) entry['name']: entry['label']},
    );
  });
}
