import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_stream.dart';

void main() {
  test('added returns the messages after the applied ones', () {
    final added = A2UIStream.added(['a', 'b', 'c'], applied: ['a']);

    expect(added, ['b', 'c']);
  });

  test('added returns no messages when no message was completed since', () {
    final added = A2UIStream.added(['a', 'b'], applied: ['a', 'b']);

    expect(added, isEmpty);
  });

  test('added returns every message when none was applied', () {
    final added = A2UIStream.added(['a'], applied: []);

    expect(added, ['a']);
  });

  test('added returns null when an applied message changed', () {
    final added = A2UIStream.added(['a', 'x'], applied: ['a', 'b']);

    expect(added, isNull);
  });

  test('added returns null when an applied message changed and another was added', () {
    final added = A2UIStream.added(['x', 'b', 'c'], applied: ['a', 'b']);

    expect(added, isNull);
  });

  test('added returns null when an applied message was removed', () {
    final added = A2UIStream.added(['a'], applied: ['a', 'b']);

    expect(added, isNull);
  });
}
