import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

FormValidationError? _check(Object? value, Object? rules) =>
    FormValidation.validate(_v(value), FormValidation.parse(_v(rules)));

// A new error each call, which `const FormValidationError(...)` with the same
// arguments is not: those are one object.
FormValidationError _error(FormValidationErrorCode code, [num? limit]) => FormValidationError(code, limit);

void main() {
  test('errors with the same code and limit compare equal', () {
    expect(_error(FormValidationErrorCode.min, 3), _error(FormValidationErrorCode.min, 3));
  });

  test('errors with the same code and limit share a hashCode', () {
    expect(_error(FormValidationErrorCode.min, 3).hashCode, _error(FormValidationErrorCode.min, 3).hashCode);
  });

  test('errors with another code differ', () {
    expect(_error(FormValidationErrorCode.min, 3), isNot(_error(FormValidationErrorCode.max, 3)));
  });

  test('errors with another limit differ', () {
    expect(_error(FormValidationErrorCode.min, 3), isNot(_error(FormValidationErrorCode.min, 4)));
  });

  test('an error without a limit prints as its code', () {
    expect(_error(FormValidationErrorCode.required).toString(), 'required');
  });

  test('an error with a limit prints it after its code', () {
    expect(_error(FormValidationErrorCode.min, 3).toString(), 'min(3)');
  });

  test('rules with the same type and argument share a hashCode', () {
    expect(
      const ValidationRule('min', OpenUINumber(3)).hashCode,
      const ValidationRule('min', OpenUINumber(3)).hashCode,
    );
  });

  test('rules written as an object keep the ones that are on', () {
    expect(FormValidation.parse(_v({'required': true, 'email': false, 'minLength': 3, 'max': null})), [
      const ValidationRule('required'),
      const ValidationRule('minLength', OpenUINumber(3)),
    ]);
  });

  test('rules written as a list of strings keep their arguments', () {
    expect(FormValidation.parse(_v(['required', 'min:8', 'pattern:^a:b'])), [
      const ValidationRule('required'),
      const ValidationRule('min', OpenUINumber(8)),
      const ValidationRule('pattern', OpenUIString('^a:b')),
    ]);
  });

  test('a rule in a list that is not text is skipped', () {
    expect(FormValidation.parse(_v(['required', 5])), [const ValidationRule('required')]);
  });

  for (final (behavior, value, rules, expected) in [
    ('required fails an empty value', '', {'required': true}, FormValidationErrorCode.required),
    (
      'required fails a group of checkboxes with none ticked',
      {'a': false},
      {'required': true},
      FormValidationErrorCode.requiredOption,
    ),
    ('email fails text that is not an address', 'a b@c.d', {'email': true}, FormValidationErrorCode.email),
    ('url fails text with no scheme', 'openui.com', {'url': true}, FormValidationErrorCode.url),
    ('numeric fails text that is not a number', 'abc', {'numeric': true}, FormValidationErrorCode.numeric),
  ]) {
    test(behavior, () {
      expect(_check(value, rules), FormValidationError(expected));
    });
  }

  for (final (behavior, value, rules, expected) in [
    ('min fails a value below its limit', '3', {'min': 5}, _error(FormValidationErrorCode.min, 5)),
    ('max fails a value above its limit', 9, {'max': 5}, _error(FormValidationErrorCode.max, 5)),
    (
      'minLength fails text shorter than its limit',
      'ab',
      {'minLength': 3},
      _error(FormValidationErrorCode.minLength, 3),
    ),
    (
      'maxLength fails text longer than its limit',
      'abcd',
      {'maxLength': 3},
      _error(FormValidationErrorCode.maxLength, 3),
    ),
  ]) {
    test(behavior, () {
      expect(_check(value, rules), expected);
    });
  }

  for (final (behavior, value, rules) in [
    ('email passes an address', 'a@b.co', {'email': true}),
    ('url passes a web address', 'https://openui.com/x', {'url': true}),
    ('numeric passes text that starts with a number', '12abc', {'numeric': true}),
    ('required passes a group of checkboxes with one ticked', {'a': true}, {'required': true}),
    ('min and max pass a value equal to their limits', '5', {'min': 5, 'max': 5}),
  ]) {
    test(behavior, () {
      expect(_check(value, rules), isNull);
    });
  }

  for (final url in ['mailto:a@b.co', 'tel:+15550100', 'urn:isbn:0451450523', 'file:///tmp/a.txt']) {
    test('a URL needs a scheme, not a host ($url)', () {
      expect(_check(url, {'url': true}), isNull);
    });
  }

  test('a relative URL fails', () {
    expect(_check('/relative/path', {'url': true}), const FormValidationError(FormValidationErrorCode.url));
  });

  test('a URL of a scheme without a host may have spaces', () {
    expect(_check('note:hello world', {'url': true}), isNull);
  });

  for (final url in ['https://', 'http://', 'HTTPS://', 'https://a b.com', 'wss://', 'ftp://']) {
    test('a web URL needs a host and no whitespace ($url)', () {
      expect(_check(url, {'url': true}), const FormValidationError(FormValidationErrorCode.url));
    });
  }

  test('a web URL with a host passes', () {
    expect(_check('https://a.com/x', {'url': true}), isNull);
  });

  for (final empty in [null, '', <Object?>[], <String, Object?>{}]) {
    test('every rule but required lets an empty value pass ($empty)', () {
      expect(_check(empty, {'email': true, 'minLength': 3, 'numeric': true}), isNull);
    });
  }

  test('a minLength with a fraction is rounded up, as the check counts it', () {
    expect(_check('ab', {'minLength': 2.5}), const FormValidationError(FormValidationErrorCode.minLength, 3));
  });

  test('a maxLength with a fraction is rounded down, as the check counts it', () {
    expect(_check('abc', {'maxLength': 2.5}), const FormValidationError(FormValidationErrorCode.maxLength, 2));
  });

  test('a length rule whose limit is NaN is skipped', () {
    expect(_check('ab', {'minLength': 'many'}), isNull);
  });

  test('a length rule whose limit is infinite is skipped', () {
    expect(_check('ab', ['maxLength:-Infinity']), isNull);
  });

  test('the first failing rule gives the error', () {
    expect(
      _check('a', {'minLength': 2, 'email': true}),
      const FormValidationError(FormValidationErrorCode.minLength, 2),
    );
  });

  test('an unknown rule is skipped', () {
    expect(_check('a', {'shout': true}), isNull);
  });

  test('a pattern rule passes a value it finds a match in', () {
    expect(_check('AB123', {'pattern': r'^[A-Z]{2}\d{3}$'}), isNull);
  });

  test('a pattern rule fails a value it finds no match in', () {
    expect(
      _check('ab123', {'pattern': r'^[A-Z]{2}\d{3}$'}),
      const FormValidationError(FormValidationErrorCode.pattern),
    );
  });

  test('a pattern rule finds a match anywhere in the value', () {
    expect(_check('xx42yy', {'pattern': r'\d+'}), isNull);
  });

  test('a pattern rule comes as a string rule too', () {
    expect(_check('ab123', [r'pattern:^[a-z]+\d+$']), isNull);
  });

  test('a pattern rule lets an empty value through', () {
    expect(_check('', {'pattern': r'^\d+$'}), isNull);
  });

  for (final (pattern, why) in [
    ('(a', 'invalid'),
    (r'(a)\1', 'unsupported'),
    ('a{0,600}b{0,600}x', 'too large'),
    (5, 'not a string'),
  ]) {
    test('a pattern rule lets any value through when the pattern is $why', () {
      expect(_check('ab', {'pattern': pattern}), isNull);
    });
  }

  test('a pattern rule passes a value at the input cap', () {
    expect(_check('a' * 4096, {'pattern': 'a'}), isNull);
  });

  test('a pattern rule fails a value longer than the input cap', () {
    expect(_check('a' * 4097, {'pattern': 'a'}), const FormValidationError(FormValidationErrorCode.pattern));
  });

  test('a pattern rule decides a pattern that backtracks', () {
    expect(
      _check('${'a' * 4000}b', {'pattern': r'^(a+)+$'}),
      const FormValidationError(FormValidationErrorCode.pattern),
    );
  });

  test('a form field with an empty value is empty', () {
    expect(FormValidation.isEmpty(_v({'value': '', 'componentType': 'input'})), isTrue);
  });

  test('a form field with a value is not empty', () {
    expect(FormValidation.isEmpty(_v({'value': 'x'})), isFalse);
  });
}
