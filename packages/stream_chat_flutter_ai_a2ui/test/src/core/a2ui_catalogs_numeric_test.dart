import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

// A number field writes the text the person typed, so the functions that read
// a number read a string holding one as that number.
void main() {
  test('numeric passes a string holding a number in range', () {
    final field = _guests('5');

    expect(field.failingChecks, isEmpty);
  });

  test('numeric fails a string holding a number out of range', () {
    final field = _guests('50');

    expect(field.failingChecks.single.message, 'Between 1 and 10 guests.');
  });

  test("numeric fails a string that isn't a number with the check's message", () {
    final field = _guests('many');

    expect(field.failingChecks.single.message, 'Between 1 and 10 guests.');
  });

  test("numeric reports no problem for a string that isn't a number", () async {
    final errors = <A2UIError>[];
    _guests('many', errors: errors);
    await pumpEventQueue();

    expect(errors, isEmpty);
  });

  test('numeric fails an empty string, though 0 is in range', () {
    final field = _guests('', min: 0);

    expect(field.failingChecks.single.message, 'Between 1 and 10 guests.');
  });

  test("numeric fails a string holding a number that isn't finite", () {
    final field = _guests('Infinity', max: null);

    expect(field.failingChecks.single.message, 'Between 1 and 10 guests.');
  });

  test("formatNumber reports a string that isn't a number", () async {
    final errors = <A2UIError>[];
    final text = _text(
      {
        '@call': 'formatNumber',
        'args': {
          'value': {'@path': '/amount'},
        },
      },
      data: {'amount': 'many'},
      errors: errors,
    );
    await pumpEventQueue();

    expect(text.property('text'), isNull);
    expect(errors.single.code, A2UIErrorCode.expressionError);
  });

  test('formatNumber formats a string holding a number', () {
    final text = _text(
      {
        '@call': 'formatNumber',
        'args': {
          'value': {'@path': '/amount'},
          'decimals': 1,
        },
      },
      data: {'amount': '1234.5'},
    );

    expect(text.property('text'), '1,234.5');
  });

  test('formatCurrency formats a string holding a number', () {
    final text = _text(
      {
        '@call': 'formatCurrency',
        'args': {
          'value': {'@path': '/amount'},
          'currency': 'EUR',
        },
      },
      data: {'amount': '12'},
    );

    expect(text.property('text'), '€12.00');
  });
}

A2UINode _guests(String guests, {List<A2UIError>? errors, int min = 1, int? max = 10}) {
  return planSurface(
    errors: errors,
    data: {'guests': guests},
    components: [
      {
        'id': 'root',
        'component': 'TextField',
        'label': 'Guests',
        'variant': 'number',
        'value': {'@path': '/guests'},
        'checks': [
          {
            'condition': {
              '@call': 'numeric',
              'args': {
                'value': {'@path': '/guests'},
                'min': min,
                'max': ?max,
              },
            },
            'message': 'Between 1 and 10 guests.',
          },
        ],
      },
    ],
  ).root!;
}

A2UINode _text(Map<String, Object?> text, {required Map<String, Object?> data, List<A2UIError>? errors}) {
  return planSurface(
    errors: errors,
    data: data,
    components: [
      {'id': 'root', 'component': 'Text', 'text': text},
    ],
  ).root!;
}
