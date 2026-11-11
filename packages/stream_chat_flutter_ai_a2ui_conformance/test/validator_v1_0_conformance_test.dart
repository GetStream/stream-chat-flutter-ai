@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

void main() {
  runConformanceSuite('validator_v1_0', run: 42, skipped: 0);
}
