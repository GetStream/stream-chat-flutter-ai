import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';

void main() {
  test('two errors with the same fields are equal', () {
    expect(_error(), _error());
  });

  test('two errors with the same fields have the same hash code', () {
    expect(_error().hashCode, _error().hashCode);
  });

  test('errors with different codes differ', () {
    expect(_error(code: A2UIErrorCode.integrityError), isNot(_error()));
  });

  test('errors with different messages differ', () {
    expect(_error(message: 'Another problem.'), isNot(_error()));
  });

  test('errors on different surfaces differ', () {
    expect(_error(surfaceId: 'other'), isNot(_error()));
  });

  test('errors at different paths differ', () {
    expect(_error(path: '/other'), isNot(_error()));
  });

  test('toString names the code', () {
    expect(_error().toString(), contains('VALIDATION_FAILED'));
  });

  test('an error code equals the string it is made of', () {
    expect(A2UIErrorCode.validationFailed, 'VALIDATION_FAILED');
  });
}

A2UIError _error({
  A2UIErrorCode code = A2UIErrorCode.validationFailed,
  String message = 'A problem.',
  String surfaceId = 'plan',
  String path = '/version',
}) => A2UIError(code: code, message: message, surfaceId: surfaceId, path: path);
