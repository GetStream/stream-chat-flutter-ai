@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'openui_conformance.dart';

// The comparison every conformance case goes through.
void main() {
  test('equal values have no difference', () {
    expect(
      firstDifference(
        {
          'a': 1,
          'b': [true, null],
        },
        {
          'a': 1,
          'b': [true, null],
        },
      ),
      isNull,
    );
  });

  test('a missing key is a difference', () {
    expect(firstDifference({'a': 1}, {'a': 1, 'b': 2}), r'$.b: missing, expected 2');
  });

  test('an unexpected key is a difference', () {
    expect(firstDifference({'a': 1, 'b': 2}, {'a': 1}), r'$.b: unexpected 2');
  });

  test('a shorter list is a difference', () {
    expect(firstDifference([1], [1, 2]), r'$: 1 items, expected 2');
  });

  test('a longer list is a difference', () {
    expect(firstDifference([1, 2], [1]), r'$: 2 items, expected 1');
  });

  test('a difference names its path', () {
    expect(
      firstDifference(
        {
          'a': [
            0,
            {'b': 1},
          ],
        },
        {
          'a': [
            0,
            {'b': 2},
          ],
        },
      ),
      r'$.a[1].b: 1, expected 2',
    );
  });

  test('an integer matches the same double', () {
    expect(firstDifference(1, 1.0), isNull);
  });

  test('null does not match 0', () {
    expect(firstDifference(null, 0), r'$: null, expected 0');
  });

  test('true does not match 1', () {
    expect(firstDifference(true, 1), r'$: true, expected 1');
  });

  test('the order of keys does not matter', () {
    expect(firstDifference({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isNull);
  });
}
