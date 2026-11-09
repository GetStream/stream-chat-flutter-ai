import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_stream.dart';

// Reference splits of 33 texts, from test/fixtures/README.md.
void main() {
  final cases = _cases();

  test('the fixture holds the cases it was made with', () {
    expect(cases, hasLength(33));
  });

  for (final MapEntry(key: name, value: fixture) in cases.entries) {
    test('messages finds the reference split of $name', () {
      final input = fixture['input']! as String;

      final messages = A2UIStream.messages(input);

      expect(messages, fixture['messages']);
    });
  }
}

Map<String, Map<String, Object?>> _cases() {
  final json = jsonDecode(File('test/fixtures/ios_a2ui_stream_messages.json').readAsStringSync());
  return (json as Map<String, Object?>).cast();
}
