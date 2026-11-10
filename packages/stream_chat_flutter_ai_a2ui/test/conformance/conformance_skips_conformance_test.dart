@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';
import 'a2ui_conformance_skips.dart';

void main() {
  test('every case the skip list names is a case of the vendored suites', () {
    expect(conformanceSkippedNames.difference(conformanceCaseNames()), isEmpty);
  });
}
