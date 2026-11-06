import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  test('AIMessage.uiDocument is null unless the message says otherwise', () {
    expect(_Message().uiDocument, isNull);
  });
}

class _Message with AIMessage {
  @override
  String get id => 'a1';

  @override
  AIMessageRole get role => AIMessageRole.assistant;

  @override
  String get text => 'Ohrid it is';
}
