import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';

void main() {
  test('AIUIFormat.openUI is written as openui', () {
    expect(AIUIFormat.openUI, 'openui');
  });

  test('AIUIFormat.a2ui is written as a2ui', () {
    expect(AIUIFormat.a2ui, 'a2ui');
  });

  test('AIUIFormat keeps a format this package does not name', () {
    const cards = AIUIFormat('acme-cards');

    expect(cards, 'acme-cards');
  });
}
