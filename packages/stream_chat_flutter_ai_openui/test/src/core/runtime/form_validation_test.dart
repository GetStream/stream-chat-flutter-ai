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
    expect(_check('3', {'min': 5}), const FormValidationError(FormValidationErrorCode.min, 5));
    expect(_check(9, {'max': 5}), const FormValidationError(FormValidationErrorCode.max, 5));
    expect(_check('ab', {'minLength': 3}), const FormValidationError(FormValidationErrorCode.minLength, 3));
    expect(_check('abcd', {'maxLength': 3}), const FormValidationError(FormValidationErrorCode.maxLength, 3));
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

  test('a URL of a scheme without a host may have spaces', () {
    expect(_check('note:hello world', {'url': true}), isNull);
  });

  test('a web URL needs a host and no whitespace', () {
    for (final url in ['https://', 'http://', 'HTTPS://', 'https://a b.com', 'wss://', 'ftp://']) {
      expect(_check(url, {'url': true}), const FormValidationError(FormValidationErrorCode.url), reason: url);
    }
    expect(_check('https://a.com/x', {'url': true}), isNull);
  });

  test('every rule but required lets an empty value pass', () {
    for (final empty in [null, '', <Object?>[], <String, Object?>{}]) {
      expect(_check(empty, {'email': true, 'minLength': 3, 'numeric': true}), isNull);
    }
  });

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

  test('the first failing rule gives the error, and unknown rules are skipped', () {
    expect(
      _check('a', {'shout': true, 'minLength': 2, 'email': true}),
      const FormValidationError(FormValidationErrorCode.minLength, 2),
    );
  });

  group('pattern', () {
    test('passes a value it finds a match in', () {
      expect(_check('AB123', {'pattern': r'^[A-Z]{2}\d{3}$'}), isNull);
    });

    test('fails a value it finds no match in', () {
      expect(
        _check('ab123', {'pattern': r'^[A-Z]{2}\d{3}$'}),
        const FormValidationError(FormValidationErrorCode.pattern),
      );
    });

    test('finds a match anywhere in the value', () {
      expect(_check('xx42yy', {'pattern': r'\d+'}), isNull);
    });

    test('comes as a string rule too', () {
      expect(_check('ab123', [r'pattern:^[a-z]+\d+$']), isNull);
    });

    test('lets an empty value through', () {
      expect(_check('', {'pattern': r'^\d+$'}), isNull);
    });

    for (final (pattern, why) in [
      ('(a', 'invalid'),
      (r'(a)\1', 'unsupported'),
      ('a{0,600}b{0,600}x', 'too large'),
      (5, 'not a string'),
    ]) {
      test('lets any value through when the pattern is $why', () {
        expect(_check('ab', {'pattern': pattern}), isNull);
      });
    }

    test('fails a value longer than the input cap', () {
      expect(_check('a' * 4096, {'pattern': 'a'}), isNull);
      expect(_check('a' * 4097, {'pattern': 'a'}), const FormValidationError(FormValidationErrorCode.pattern));
    });

    test('decides a pattern that backtracks', () {
      expect(
        _check('${'a' * 4000}b', {'pattern': r'^(a+)+$'}),
        const FormValidationError(FormValidationErrorCode.pattern),
      );
    });
  });

  test('a form field is checked by its value', () {
    expect(FormValidation.isEmpty(_v({'value': '', 'componentType': 'input'})), isTrue);
    expect(FormValidation.isEmpty(_v({'value': 'x'})), isFalse);
  });
}
