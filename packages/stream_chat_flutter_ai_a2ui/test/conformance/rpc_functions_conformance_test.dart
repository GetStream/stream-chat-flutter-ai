@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

void main() {
  runConformanceSuite('rpc_functions', run: 19, skipped: 13);
}
