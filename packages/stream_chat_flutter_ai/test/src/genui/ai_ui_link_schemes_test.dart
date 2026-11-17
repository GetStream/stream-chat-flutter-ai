import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  for (final (url, allowed) in [
    ('https://getstream.io', true),
    ('HTTP://getstream.io', true),
    ('mailto:hi@getstream.io', true),
    ('tel:+1555', true),
    ('javascript:alert(1)', false),
    ('intent://scan#Intent;end', false),
    ('file:///etc/hosts', false),
    ('whatsapp://send', false),
  ]) {
    test('${allowed ? 'allows' : 'does not allow'} $url', () {
      expect(AIUILinkSchemes.allows(Uri.parse(url)), allowed);
    });
  }
}
