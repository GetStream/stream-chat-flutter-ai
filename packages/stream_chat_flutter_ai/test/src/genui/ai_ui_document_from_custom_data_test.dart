import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_document.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';

import 'genui_fixtures.dart';

void main() {
  test('AIUIDocument.fromCustomData reads a streaming OpenUI document', () {
    final customData = genuiFixture('document_openui_streaming.json');

    final document = AIUIDocument.fromCustomData(customData);

    expect(
      document,
      const AIUIDocument(
        format: AIUIFormat.openUI,
        version: '0.4.0',
        isStreaming: true,
        content: 'root = Card([title])',
      ),
    );
  });

  test('AIUIDocument.fromCustomData reads a complete A2UI document with JSON content', () {
    final customData = genuiFixture('document_a2ui_complete.json');

    final document = AIUIDocument.fromCustomData(customData);

    expect(
      document,
      const AIUIDocument(
        format: AIUIFormat.a2ui,
        content: [
          {
            'deleteSurface': {'surfaceId': 's1'},
          },
        ],
      ),
    );
  });

  test("AIUIDocument.fromCustomData reads a document of a format it doesn't name", () {
    final customData = genuiFixture('document_custom_format.json');

    final document = AIUIDocument.fromCustomData(customData);

    expect(document, const AIUIDocument(format: AIUIFormat('acme-cards'), content: <String, Object?>{}));
  });

  test("AIUIDocument.fromCustomData reads the spec's A2UI reply, keeping its messages as they are", () {
    final customData = genuiFixture('document_a2ui_spec.json');

    final document = AIUIDocument.fromCustomData(customData);

    expect(
      document,
      AIUIDocument(format: AIUIFormat.a2ui, version: '1.0', content: _content(customData)),
    );
  });

  test('AIUIDocument.fromCustomData reads an empty version as none', () {
    final customData = _customData({'format': 'openui', 'version': '', 'content': 'root = Card([])'});

    final document = AIUIDocument.fromCustomData(customData);

    expect(document?.version, isNull);
  });

  test('AIUIDocument.fromCustomData reads a document without a status as finished', () {
    final customData = _customData({'format': 'openui', 'content': 'root = Card([])'});

    final document = AIUIDocument.fromCustomData(customData);

    expect(document?.isStreaming, isFalse);
  });

  test('AIUIDocument.fromCustomData reads a version that is not a string as none', () {
    final customData = _customData({'format': 'openui', 'version': 1, 'content': 'root = Card([])'});

    final document = AIUIDocument.fromCustomData(customData);

    expect(document?.version, isNull);
  });

  test('AIUIDocument.fromCustomData reads a status other than streaming as finished', () {
    final customData = _customData({'format': 'openui', 'status': 'failed', 'content': 'root = Card([])'});

    final document = AIUIDocument.fromCustomData(customData);

    expect(document?.isStreaming, isFalse);
  });

  test('AIUIDocument.fromCustomData reads an ai_ui field of the version it supports', () {
    final customData = _customData({'v': 1, 'format': 'openui', 'content': 'root = Card([])'});

    final document = AIUIDocument.fromCustomData(customData);

    expect(document, isNotNull);
  });

  test('AIUIDocument.fromCustomData ignores a field version that is not a number', () {
    final customData = _customData({'v': '2', 'format': 'openui', 'content': 'root = Card([])'});

    final document = AIUIDocument.fromCustomData(customData);

    expect(document, isNotNull);
  });

  for (final (kind, content) in const [('a number', 0), ('a boolean', false)]) {
    test('AIUIDocument.fromCustomData keeps content that is $kind', () {
      final customData = _customData({'format': 'acme-cards', 'content': content});

      final document = AIUIDocument.fromCustomData(customData);

      expect(document?.content, content);
    });
  }

  test('AIUIDocument.fromCustomData reads an ai_ui field that is a map of any type', () {
    final customData = {
      'ai_ui': <Object?, Object?>{'format': 'openui', 'content': 'root = Card([])'},
    };

    final document = AIUIDocument.fromCustomData(customData);

    expect(document, const AIUIDocument(format: AIUIFormat.openUI, content: 'root = Card([])'));
  });

  test('AIUIDocument.fromCustomData keeps its content when the custom data changes afterwards', () {
    final surface = {'surfaceId': 's1'};
    final customData = _customData({
      'format': 'a2ui',
      'content': [
        {'deleteSurface': surface},
      ],
    });
    final document = AIUIDocument.fromCustomData(customData);

    surface['surfaceId'] = 's2';

    expect(document?.content, [
      {
        'deleteSurface': {'surfaceId': 's1'},
      },
    ]);
  });

  test('AIUIDocument.fromCustomData gives content that cannot be changed', () {
    final document = AIUIDocument.fromCustomData(genuiFixture('document_a2ui_complete.json'));

    expect(() => (document!.content as List<Object?>).add('more'), throwsA(isA<UnsupportedError>()));
  });

  group('when the message carries no document this package can read', () {
    final cases = <(String, Map<String, Object?>)>[
      ('it has no ai_ui field', {}),
      ('its ai_ui field is not an object', {'ai_ui': 'root = Card([])'}),
      ('the document has no format', _customData({'content': 'root = Card([])'})),
      ('the format is empty', _customData({'format': '', 'content': 'root = Card([])'})),
      ('the format is not a string', _customData({'format': 1, 'content': 'root = Card([])'})),
      ('the document has no content', _customData({'format': 'openui'})),
      ('the content is null', _customData({'format': 'openui', 'content': null})),
      ('the ai_ui field is newer than this package reads', _customData({'v': 2, 'format': 'openui', 'content': 'x'})),
      ('the ai_ui field is newer by a fraction', _customData({'v': 1.5, 'format': 'openui', 'content': 'x'})),
    ];

    for (final (reason, customData) in cases) {
      test('AIUIDocument.fromCustomData returns null because $reason', () {
        final document = AIUIDocument.fromCustomData(customData);

        expect(document, isNull);
      });
    }
  });
}

Map<String, Object?> _customData(Map<String, Object?> document) => {AIUIDocument.customDataKey: document};

// The content of the document in `customData`, exactly as the fixture holds it.
Object _content(Map<String, Object?> customData) =>
    (customData[AIUIDocument.customDataKey]! as Map<String, Object?>)['content']!;
