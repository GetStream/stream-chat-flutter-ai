@Tags(['conformance'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'openui_conformance.dart';
import 'openui_conformance_skips.dart';

void main() {
  for (final area in specAreasRun) {
    runSpecConformanceArea(area);
  }

  test('every area of the specification is run or skipped', () {
    final areas = [
      for (final entry in Directory('test/conformance/upstream/spec/fixtures/1.0').listSync())
        if (entry is Directory) entry.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
    ];

    expect(areas, unorderedEquals(specAreasRun));
  });

  test('no streaming case of the specification lists error objects, which only a one-piece read checks', () {
    final withErrorObjects = [
      for (final name in specCaseNames('streaming'))
        if (File(
          'test/conformance/upstream/spec/fixtures/1.0/$name/expected.json',
        ).readAsStringSync().contains('"errorObjects"'))
          name,
    ];

    expect(withErrorObjects, isEmpty);
  });

  test('the cases whose tree is evaluated before it is compared include those of the evaluation area', () {
    final needEvaluating = [
      for (final area in specAreasRun)
        for (final name in specCaseNames(area))
          if (specRootNeedsEvaluating(name)) name,
    ];

    expect(needEvaluating, containsAll(['grammar/006-lex-minus-and-skip', 'entry/006-ternary-root-multiline']));
    expect(needEvaluating.where((name) => name.startsWith('evaluation/')), isNotEmpty);
  });
}
