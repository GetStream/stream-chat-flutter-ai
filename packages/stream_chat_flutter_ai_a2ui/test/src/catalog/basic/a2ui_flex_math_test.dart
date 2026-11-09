import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';

// The free-space math of a row or a column gives what the reference gave for
// the same lengths (`test/fixtures/ios_a2ui_flex.json`).
void main() {
  final fixture = jsonDecode(File('test/fixtures/ios_a2ui_flex.json').readAsStringSync()) as Map<String, Object?>;

  test('the fixture has the slot and offset cases', () {
    expect([(fixture['slots']! as List).length, (fixture['offsets']! as List).length], [12, 12]);
  });

  for (final raw in fixture['slots']! as List<Object?>) {
    final example = raw! as Map<String, Object?>;
    test("the free space is shared as the reference shares it, in case ${example['name']}", () {
      final slots = a2uiFlexSlots(
        natural: _doubles(example['natural']),
        weights: _doubles(example['weights']),
        available: (example['available'] as num?)?.toDouble(),
        spacing: (example['spacing']! as num).toDouble(),
      );

      expect(slots, _closeTo(_doubles(example['slots'])));
    });
  }

  for (final raw in fixture['offsets']! as List<Object?>) {
    final example = raw! as Map<String, Object?>;
    test("the children are placed where the reference places them, in case ${example['name']}", () {
      final offsets = a2uiFlexOffsets(
        lengths: _doubles(example['lengths']),
        length: (example['length']! as num).toDouble(),
        justify: example['justify']! as String,
        spacing: (example['spacing']! as num).toDouble(),
      );

      expect(offsets, _closeTo(_doubles(example['offsets'])));
    });
  }

  test('equal huge weights share the free space equally', () {
    final slots = a2uiFlexSlots(natural: [0, 0], weights: [1e308, 1e308], available: 300, spacing: 8);

    expect(slots, _closeTo([(300 - 8) / 2, (300 - 8) / 2]));
  });

  test('a child that cannot be shorter keeps its length when the children do not fit', () {
    final slots = a2uiStackSlots(natural: [24, 500], least: [24, 50], available: 300, spacing: 8);

    expect(slots.first, 24);
  });

  test('a child that can be shorter takes what the others leave when the children do not fit', () {
    final slots = a2uiStackSlots(natural: [24, 500], least: [24, 50], available: 300, spacing: 8);

    expect(slots.last, 300 - 24 - 8);
  });

  test('children that can be shorter give in proportion to how much they can give', () {
    // 100 too long: the first can give 100 and the second 300, so they give a
    // quarter and three quarters of it.
    final slots = a2uiStackSlots(natural: [200, 400], least: [100, 100], available: 500, spacing: 0);

    expect(slots, _closeTo([200 - 25, 400 - 75]));
  });

  test('children that cannot be shorter keep their lengths though they do not fit', () {
    final slots = a2uiStackSlots(natural: [200, 200], least: [200, 200], available: 300, spacing: 8);

    expect(slots, _closeTo([200, 200]));
  });
}

List<double> _doubles(Object? list) => [for (final item in list! as List<Object?>) (item! as num).toDouble()];

Matcher _closeTo(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (expected, actual) => (expected - actual).abs() < 1e-9,
  'within 1e-9 of',
);
