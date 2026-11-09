import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_versions.dart';

void main() {
  for (final version in ['1', '1.0.0', 'v1', 'v1.0']) {
    test('check rewrites the version $version as 1.0', () {
      final envelope = A2UIVersions.check(_message(version: version));

      expect(_accepted(envelope)['version'], '1.0');
    });
  }

  test('check keeps the rest of a message whose version it rewrites', () {
    final envelope = A2UIVersions.check(_message(version: 'v1.0'));

    expect(_accepted(envelope)['deleteSurface'], {'surfaceId': 'plan'});
  });

  test('check accepts a 1.0 message as it is', () {
    final message = _message(version: '1.0');

    final envelope = A2UIVersions.check(message);

    expect(_accepted(envelope), same(message));
  });

  test('check rejects a message with no version at the path /version', () {
    final envelope = A2UIVersions.check({
      'deleteSurface': {'surfaceId': 'plan'},
    });

    expect(_rejected(envelope).path, '/version');
  });

  test('check rejects a message with no version as VALIDATION_FAILED', () {
    final envelope = A2UIVersions.check({
      'deleteSurface': {'surfaceId': 'plan'},
    });

    expect(_rejected(envelope).code, A2UIErrorCode.validationFailed);
  });

  test('check names the version it reads when a message has none', () {
    final envelope = A2UIVersions.check({
      'deleteSurface': {'surfaceId': 'plan'},
    });

    expect(_rejected(envelope).message, contains('"version": "1.0"'));
  });

  test('check rejects a message of version v0.9, naming it', () {
    final envelope = A2UIVersions.check(_message(version: 'v0.9'));

    expect(_rejected(envelope).message, contains("'v0.9'"));
  });

  test('check names the version it reads when a message has another', () {
    final envelope = A2UIVersions.check(_message(version: 'v0.9'));

    expect(_rejected(envelope).message, contains('reads A2UI 1.0'));
  });

  test('check rejects a message with two message keys for the whole message', () {
    final envelope = A2UIVersions.check({
      'version': '1.0',
      'createSurface': {'surfaceId': 'plan'},
      'deleteSurface': {'surfaceId': 'plan'},
    });

    expect(_rejected(envelope).path, '');
  });

  test('check rejects a message of another version at the path /version', () {
    final envelope = A2UIVersions.check(_message(version: '2.0'));

    expect(_rejected(envelope).path, '/version');
  });

  test('check rejects a version written as a number', () {
    final envelope = A2UIVersions.check(_message(version: 1));

    expect(_rejected(envelope).message, contains("version '1'"));
  });

  test('check rejects a version spelled in capitals', () {
    final envelope = A2UIVersions.check(_message(version: 'V1.0'));

    expect(envelope, isA<A2UIRejectedEnvelope>());
  });

  for (final key in ['beginRendering', 'surfaceUpdate', 'dataModelUpdate']) {
    test('check says $key, from an earlier version of A2UI, is not supported in 1.0', () {
      final envelope = A2UIVersions.check({
        'version': '1.0',
        key: {'surfaceId': 'plan'},
      });

      expect(_rejected(envelope).message, "The action '$key' is not supported in protocol version 1.0.");
    });
  }

  test('check rejects a message with two message keys', () {
    final envelope = A2UIVersions.check({
      'version': '1.0',
      'createSurface': {'surfaceId': 'plan'},
      'deleteSurface': {'surfaceId': 'plan'},
    });

    expect(_rejected(envelope).message, contains('createSurface, deleteSurface'));
  });

  test('check rejects a message with no message key, naming its keys', () {
    final envelope = A2UIVersions.check({'version': '1.0', 'other': 1});

    expect(_rejected(envelope).message, 'Unknown A2UI message type. Keys: other, version');
  });

  test("check rejects a message whose message key doesn't hold an object", () {
    final envelope = A2UIVersions.check({'version': '1.0', 'deleteSurface': 'plan'});

    expect(_rejected(envelope).path, '/deleteSurface');
  });

  test('check gives a rejected message the surface it names', () {
    final envelope = A2UIVersions.check(_message(version: 'v0.9'));

    expect(_rejected(envelope).surfaceId, 'plan');
  });

  test('check gives no surface to a rejected message that names none', () {
    final envelope = A2UIVersions.check({'version': 'v0.9', 'other': 1});

    expect(_rejected(envelope).surfaceId, isNull);
  });

  test('check looks at the version before the message keys', () {
    final envelope = A2UIVersions.check({
      'version': 'v0.8',
      'beginRendering': {'surfaceId': 'plan'},
    });

    expect(_rejected(envelope).path, '/version');
  });
}

Map<String, Object?> _message({required Object? version}) => {
  'version': version,
  'deleteSurface': {'surfaceId': 'plan'},
};

Map<String, Object?> _accepted(A2UIEnvelope envelope) => switch (envelope) {
  A2UIAcceptedEnvelope(:final message) => message,
  A2UIRejectedEnvelope(:final error) => fail('Expected the message to be accepted, but: $error'),
};

A2UIError _rejected(A2UIEnvelope envelope) => switch (envelope) {
  A2UIRejectedEnvelope(:final error) => error,
  A2UIAcceptedEnvelope() => fail('Expected the message to be rejected.'),
};
