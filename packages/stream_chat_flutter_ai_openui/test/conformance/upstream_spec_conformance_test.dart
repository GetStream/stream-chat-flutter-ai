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

    expect(areas, unorderedEquals([...specAreasRun, ...specAreasSkipped.keys]));
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

  test('the cases whose tree is skipped are exactly those whose tree holds an expression', () {
    final needEvaluating = [
      for (final area in specAreasRun)
        for (final name in specCaseNames(area))
          if (specRootNeedsEvaluating(name)) name,
    ];

    expect(needEvaluating, unorderedEquals(specRootSkips));
  });
}
