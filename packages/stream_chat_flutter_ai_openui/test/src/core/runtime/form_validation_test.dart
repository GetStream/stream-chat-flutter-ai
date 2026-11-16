import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

FormValidationError? _check(Object? value, Object? rules) =>
    FormValidation.validate(_v(value), FormValidation.parse(_v(rules)));

void main() {
  test('rules come as an object or a list of strings', () {
    expect(FormValidation.parse(_v({'required': true, 'email': false, 'minLength': 3, 'max': null})), [
      const ValidationRule('required'),
      const ValidationRule('minLength', OpenUINumber(3)),
    ]);
    expect(FormValidation.parse(_v(['required', 'min:8', 'pattern:^a:b', 5])), [
      const ValidationRule('required'),
      const ValidationRule('min', OpenUINumber(8)),
      const ValidationRule('pattern', OpenUIString('^a:b')),
    ]);
  });

  test('each rule gives its message', () {
    expect(_check('', {'required': true}), const FormValidationError(FormValidationErrorCode.required));
    expect(_check({'a': false}, {'required': true}), const FormValidationError(FormValidationErrorCode.requiredOption));
    expect(_check('a b@c.d', {'email': true}), const FormValidationError(FormValidationErrorCode.email));
    expect(_check('openui.com', {'url': true}), const FormValidationError(FormValidationErrorCode.url));
    expect(_check('abc', {'numeric': true}), const FormValidationError(FormValidationErrorCode.numeric));
    expect(_check('3', {'min': 5}), const FormValidationError(FormValidationErrorCode.min, '5'));
    expect(_check(9, {'max': 5}), const FormValidationError(FormValidationErrorCode.max, '5'));
    expect(_check('ab', {'minLength': 3}), const FormValidationError(FormValidationErrorCode.minLength, '3'));
    expect(_check('abcd', {'maxLength': 3}), const FormValidationError(FormValidationErrorCode.maxLength, '3'));
  });

  test('values that pass', () {
    expect(_check('a@b.co', {'email': true}), isNull);
    expect(_check('https://openui.com/x', {'url': true}), isNull);
    expect(_check('12abc', {'numeric': true}), isNull);
    expect(_check({'a': true}, {'required': true}), isNull);
    expect(_check('5', {'min': 5, 'max': 5}), isNull);
  });

  test('a URL needs a scheme, not a host', () {
    for (final url in ['mailto:a@b.co', 'tel:+15550100', 'urn:isbn:0451450523', 'file:///tmp/a.txt']) {
      expect(_check(url, {'url': true}), isNull, reason: url);
    }
    expect(_check('/relative/path', {'url': true}), const FormValidationError(FormValidationErrorCode.url));
  });

  test('every rule but required lets an empty value pass', () {
    for (final empty in [null, '', <Object?>[], <String, Object?>{}]) {
      expect(_check(empty, {'email': true, 'minLength': 3, 'numeric': true}), isNull);
    }
  });

  test('the first failing rule gives the error, and unknown rules are skipped', () {
    expect(
      _check('a', {'shout': true, 'minLength': 2, 'email': true}),
      const FormValidationError(FormValidationErrorCode.minLength, '2'),
    );
  });

  test('a pattern rule is skipped for now', () {
    expect(_check('ab123', {'pattern': r'^[A-Z]{2}\d{3}$'}), isNull);
  });

  test('a form field is checked by its value', () {
    expect(FormValidation.isEmpty(_v({'value': '', 'componentType': 'input'})), isTrue);
    expect(FormValidation.isEmpty(_v({'value': 'x'})), isFalse);
  });
}
