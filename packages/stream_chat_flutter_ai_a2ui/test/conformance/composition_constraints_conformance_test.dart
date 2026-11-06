@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

void main() {
  runConformanceSuite('composition_constraints', run: 10, skipped: 0);
}
