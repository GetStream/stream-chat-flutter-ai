import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

String? _check(Object? value, Object? rules) => FormValidation.validate(_v(value), FormValidation.parse(_v(rules)));

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
    expect(_check('', {'required': true}), 'This field is required');
    expect(_check({'a': false}, {'required': true}), 'At least one option is required');
    expect(_check('a b@c.d', {'email': true}), 'Please enter a valid email');
    expect(_check('openui.com', {'url': true}), 'Please enter a valid URL');
    expect(_check('abc', {'numeric': true}), 'Must be a number');
    expect(_check('3', {'min': 5}), 'Must be at least 5');
    expect(_check(9, {'max': 5}), 'Must be no more than 5');
    expect(_check('ab', {'minLength': 3}), 'Must be at least 3 characters');
    expect(_check('abcd', {'maxLength': 3}), 'Must be no more than 3 characters');
  });

  test('values that pass', () {
    expect(_check('a@b.co', {'email': true}), isNull);
    expect(_check('https://openui.com/x', {'url': true}), isNull);
    expect(_check('12abc', {'numeric': true}), isNull);
    expect(_check({'a': true}, {'required': true}), isNull);
    expect(_check('5', {'min': 5, 'max': 5}), isNull);
  });

  test('every rule but required lets an empty value pass', () {
    for (final empty in [null, '', <Object?>[], <String, Object?>{}]) {
      expect(_check(empty, {'email': true, 'minLength': 3, 'numeric': true}), isNull);
    }
  });

  test('the first failing rule gives the error, and unknown rules are skipped', () {
    expect(_check('a', {'shout': true, 'minLength': 2, 'email': true}), 'Must be at least 2 characters');
  });

  test('a pattern rule is skipped for now', () {
    expect(_check('ab123', {'pattern': r'^[A-Z]{2}\d{3}$'}), isNull);
  });

  test('a form field is checked by its value', () {
    expect(FormValidation.isEmpty(_v({'value': '', 'componentType': 'input'})), isTrue);
    expect(FormValidation.isEmpty(_v({'value': 'x'})), isFalse);
  });
}
