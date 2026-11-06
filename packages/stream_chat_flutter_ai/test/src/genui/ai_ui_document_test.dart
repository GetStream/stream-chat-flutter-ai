import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_document.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';

void main() {
  test('AIUIDocument.text is the content when it is text', () {
    const document = AIUIDocument(format: AIUIFormat.openUI, content: 'root = Card([title])');

    expect(document.text, 'root = Card([title])');
  });

  test('AIUIDocument.text is null when the content is JSON', () {
    const document = AIUIDocument(format: AIUIFormat.a2ui, content: <Object?>[]);

    expect(document.text, isNull);
  });

  test('AIUIDocument has no version by default', () {
    const document = AIUIDocument(format: AIUIFormat.openUI, content: 'root = Card([])');

    expect(document.version, isNull);
  });

  test('AIUIDocument is finished by default', () {
    const document = AIUIDocument(format: AIUIFormat.openUI, content: 'root = Card([])');

    expect(document.isStreaming, isFalse);
  });

  test('AIUIDocuments with the same fields are equal, their content compared deeply', () {
    final document = _a2uiDocument(surfaceId: 's1');

    expect(document, _a2uiDocument(surfaceId: 's1'));
  });

  test('AIUIDocuments with the same fields have the same hash code', () {
    final document = _a2uiDocument(surfaceId: 's1');

    expect(document.hashCode, _a2uiDocument(surfaceId: 's1').hashCode);
  });

  test('AIUIDocuments with different content are not equal', () {
    final document = _a2uiDocument(surfaceId: 's1');

    expect(document, isNot(_a2uiDocument(surfaceId: 's2')));
  });

  test('AIUIDocuments that differ only in whether they stream are not equal', () {
    const streaming = AIUIDocument(format: AIUIFormat.openUI, isStreaming: true, content: 'root = Card([])');

    expect(streaming, isNot(const AIUIDocument(format: AIUIFormat.openUI, content: 'root = Card([])')));
  });
}

// A document whose content is a new list each time, so equality can't rest on
// identity.
AIUIDocument _a2uiDocument({required String surfaceId}) => AIUIDocument(
  format: AIUIFormat.a2ui,
  version: '1.0',
  content: [
    {
      'createSurface': {'surfaceId': surfaceId},
    },
  ],
);
