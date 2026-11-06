import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_stream.dart';

void main() {
  test('messages splits two objects on separate lines into two messages', () {
    const text = '{"a":1}\n{"b":2}';

    expect(A2UIStream.messages(text), ['{"a":1}', '{"b":2}']);
  });

  test('messages ignores an object cut off at the end of the text', () {
    const text = '{"a":1}\n{"b":';

    expect(A2UIStream.messages(text), ['{"a":1}']);
  });

  test('messages ignores a sentence before and after the messages', () {
    const text = 'Here is your plan.\n{"a":1}\nEnjoy it.';

    expect(A2UIStream.messages(text), ['{"a":1}']);
  });

  test('messages gives each object of a JSON list written as text', () {
    const text = '[{"a":1}, {"b":{"c":[2]}}]';

    expect(A2UIStream.messages(text), ['{"a":1}', '{"b":{"c":[2]}}']);
  });

  test('messages keeps a pretty-printed object as one message', () {
    const text = '{\n  "a": {\n    "b": 1\n  }\n}\n';

    expect(A2UIStream.messages(text), ['{\n  "a": {\n    "b": 1\n  }\n}']);
  });

  test("messages doesn't end an object at a brace inside a string", () {
    const text = '{"a":"} {"}';

    expect(A2UIStream.messages(text), ['{"a":"} {"}']);
  });

  test("messages doesn't end a string at an escaped quote", () {
    const text = r'{"a":"say \"}\""}{"b":2}';

    expect(A2UIStream.messages(text), [r'{"a":"say \"}\""}', '{"b":2}']);
  });

  test("messages doesn't start a string at a quote before the first object", () {
    const text = 'A 5" screen.\n{"a":1}';

    expect(A2UIStream.messages(text), ['{"a":1}']);
  });

  test('messages takes braces in the text around the messages for an object', () {
    const text = 'Use {curly} braces.\n{"a":1}';

    expect(A2UIStream.messages(text), ['{curly}', '{"a":1}']);
  });

  test('messages keeps characters outside ASCII inside a message intact', () {
    const text = '{"a":"Plaošnik 🌊"}';

    expect(A2UIStream.messages(text), ['{"a":"Plaošnik 🌊"}']);
  });

  test('messages gives no messages for empty text', () {
    expect(A2UIStream.messages(''), isEmpty);
  });

  test('messages gives each object of a list content', () {
    final content = [
      {'a': 1},
      {'b': 2},
    ];

    expect(A2UIStream.messages(content), ['{"a":1}', '{"b":2}']);
  });

  test("messages skips the items of a list content that aren't objects", () {
    final content = [
      'text',
      {'a': 1},
      3,
    ];

    expect(A2UIStream.messages(content), ['{"a":1}']);
  });

  test('messages gives an object content as one message', () {
    final content = {'a': 1};

    expect(A2UIStream.messages(content), ['{"a":1}']);
  });

  test("messages gives no messages for an object content whose keys aren't strings", () {
    final content = {1: 'a'};

    expect(A2UIStream.messages(content), isEmpty);
  });

  test('messages gives no messages for a number content', () {
    expect(A2UIStream.messages(42), isEmpty);
  });

  test('messages gives no messages for a null content', () {
    expect(A2UIStream.messages(null), isEmpty);
  });

  test('messages keeps an object holding a messages list as one message', () {
    const text = '{"messages":[{"a":1},{"b":2}]}';

    expect(A2UIStream.messages(text), ['{"messages":[{"a":1},{"b":2}]}']);
  });

  test('messages finds nothing after a { that is never closed', () {
    const text = 'Hmm :{\n{"a":1}';

    expect(A2UIStream.messages(text), isEmpty);
  });

  test('messages gives an object content whose map is untyped', () {
    final content = <dynamic, dynamic>{'a': 1};

    expect(A2UIStream.messages(content), ['{"a":1}']);
  });

  test('messages splits lines that end with a carriage return', () {
    const text = '{"a":1}\r\n{"b":2}\r\n';

    expect(A2UIStream.messages(text), ['{"a":1}', '{"b":2}']);
  });
}
