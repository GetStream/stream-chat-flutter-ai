@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'openui_conformance.dart';
import 'openui_conformance_skips.dart';

// The vendored fixtures this package doesn't run yet, each with the reason.
void main() {
  for (final MapEntry(key: area, value: reason) in specAreasSkipped.entries) {
    skipConformanceSuite('specification $area', reason: reason);
  }
}
