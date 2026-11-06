import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_versions.dart';

void main() {
  for (final version in [null, '1', '1.0', '1.0.0', 'v1', 'v1.0']) {
    test('supports reads a reply of version $version', () {
      expect(A2UIVersions.supports(version), isTrue);
    });
  }

  for (final version in ['0.9', 'v0.9', '2.0', 'V1', 'V1.0', '1.0 ', '']) {
    test("supports doesn't read a reply of version '$version'", () {
      expect(A2UIVersions.supports(version), isFalse);
    });
  }
}
