import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_citations.dart';

void main() {
  const sources = {1: 'https://a.dev', 2: 'https://b.dev/x y', 3: 'no-scheme'};

  group('linkCitations', () {
    for (final (name, text, expected) in [
      ('links a [n] that names a source', 'Fact [1].', 'Fact [[1]](https://a.dev).'),
      ('links every [n] in a line', 'A [1] B [1]', 'A [[1]](https://a.dev) B [[1]](https://a.dev)'),
      ('encodes what would break the link', 'See [2]', 'See [[2]](https://b.dev/x%20y)'),
      ('leaves a number with no source', 'Fact [9]', 'Fact [9]'),
      ('leaves a source whose address has no scheme', 'Fact [3]', 'Fact [3]'),
      ('leaves a number of three digits', 'Fact [100]', 'Fact [100]'),
      ('leaves a [n] followed by a bracket pair of a link', 'A [1](https://x.dev)', 'A [1](https://x.dev)'),
      ('leaves a [n] followed by a colon', '[1]: ref', '[1]: ref'),
      ('leaves a [n] after a backslash', r'A \[1]', r'A \[1]'),
      ('leaves a [n] inside another bracket', 'A [[1]]', 'A [[1]]'),
      ('leaves a [n] in a code span', 'A `[1]` B [1]', 'A `[1]` B [[1]](https://a.dev)'),
      ('leaves a [n] in a code span of two backticks', 'A ``x`[1]`` B', 'A ``x`[1]`` B'),
      ('links after an unclosed backtick', 'A ` [1]', 'A ` [[1]](https://a.dev)'),
      ('leaves a [n] in fenced code', 'A\n```\n[1]\n```\nB [1]', 'A\n```\n[1]\n```\nB [[1]](https://a.dev)'),
      ('leaves a [n] in a tilde fence', '~~~\n[1]\n~~~', '~~~\n[1]\n~~~'),
      (
        'closes a fence only on a line of just the fence',
        '```dart\n[1]\n```js\n[1]\n```\n[1]',
        '```dart\n[1]\n```js\n[1]\n```\n[[1]](https://a.dev)',
      ),
      (
        'keeps a longer fence open past a shorter one inside it',
        '````\n```\n[1]\n```\n````\n[1]',
        '````\n```\n[1]\n```\n````\n[[1]](https://a.dev)',
      ),
      (
        'does not take a backtick span on one line for a fence',
        '```x``` t [1]\n[1]',
        '```x``` t [[1]](https://a.dev)\n[[1]](https://a.dev)',
      ),
    ]) {
      test(name, () => expect(linkCitations(text, sources), expected));
    }

    test('returns the text as it is without sources or brackets', () {
      expect(linkCitations('A [1]', const {}), 'A [1]');
      expect(linkCitations('A', sources), 'A');
    });
  });
}
