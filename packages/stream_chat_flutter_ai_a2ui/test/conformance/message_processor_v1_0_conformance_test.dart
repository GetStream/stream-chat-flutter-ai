@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

void main() {
  runConformanceSuite('message_processor_v1_0', run: 63, skipped: 9);
}
