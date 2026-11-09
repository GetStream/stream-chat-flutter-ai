@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

void main() {
  runConformanceSuite('functions', run: 74, skipped: 4);
}
