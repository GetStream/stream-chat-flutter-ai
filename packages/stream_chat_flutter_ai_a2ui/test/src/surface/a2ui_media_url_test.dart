import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

// Only web links load by default.
void main() {
  for (final link in ['https://example.com/a.png', 'http://example.com/a.png', 'HTTP://example.com/a.png']) {
    test('$link loads', () {
      expect(a2uiWebMediaUrl(Uri.parse(link)), Uri.parse(link));
    });
  }

  for (final link in [
    'file:///etc/hosts',
    'data:image/png;base64,AAAA',
    'otherapp://image',
    'ftp://example.com/a.png',
  ]) {
    test('$link does not load', () {
      expect(a2uiWebMediaUrl(Uri.parse(link)), isNull);
    });
  }
}
