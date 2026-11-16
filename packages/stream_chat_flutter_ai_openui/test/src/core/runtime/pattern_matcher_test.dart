import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/pattern_matcher.dart';

bool _matches(String pattern, String input) => PatternMatcher.compile(pattern)!.hasMatch(input);

void main() {
  group('matches as JavaScript does', () {
    for (final (pattern, input, expected) in [
      // Search, not a whole match.
      ('b', 'abc', true),
      ('d', 'abc', false),
      // Anchors at the input's ends only.
      (r'^abc$', 'abc', true),
      (r'^abc$', 'abcd', false),
      ('^b', 'ab', false),
      (r'a$', 'a\n', false),
      // Classes and their escapes.
      (r'^[a-c]+$', 'abcab', true),
      (r'^[a-c]+$', 'abd', false),
      (r'^[^0-9]+$', 'abc', true),
      (r'^[^0-9]+$', 'a1', false),
      (r'^[\w.-]+$', 'a_b.c-d', true),
      (r'^[]$', '', false),
      (r'^[^]$', 'x', true),
      (r'^\d{3}-\d{4}$', '555-1234', true),
      (r'^\d{3}-\d{4}$', '555-123', false),
      (r'^\D+$', 'abc', true),
      (r'^\s$', ' ', true),
      (r'^\S+$', 'a b', false),
      (r'^\W$', '-', true),
      // Word boundaries.
      (r'\bcat\b', 'a cat sat', true),
      (r'\bcat\b', 'concatenate', false),
      (r'\Bcat\B', 'concatenate', true),
      // `.` matches anything but a line terminator.
      ('^a.c', 'abc', true),
      ('^a.c', 'a\nc', false),
      ('^a.c', 'a\rc', false),
      ('^a.c', 'a\u2028c', false),
      // Alternation and groups.
      (r'^(cat|dog)s?$', 'dogs', true),
      (r'^(cat|dog)s?$', 'cow', false),
      (r'^(?:ab)+$', 'ababab', true),
      (r'^(?:ab)+$', 'aba', false),
      (r'^(?<year>\d{4})$', '2026', true),
      (r'^(?<$_a1>x)$', 'x', true),
      ('^(|a)b', 'b', true),
      // Counts, greedy or lazy.
      (r'^a{2,3}$', 'a', false),
      (r'^a{2,3}$', 'aaa', true),
      (r'^a{2,3}$', 'aaaa', false),
      (r'^a{2,}$', 'aaaaa', true),
      (r'^a{2}$', 'aa', true),
      (r'^a+?b$', 'aaab', true),
      (r'^a*?$', '', true),
      // A brace that starts no count is a brace.
      (r'^a{,2}$', 'a{,2}', true),
      (r'^{}$', '{}', true),
      // Character escapes.
      (r'^\x41B\u{1F600}$', 'AB😀', true),
      (r'^\t\n$', '\t\n', true),
      (r'^\.\*$', '.*', true),
      (r'^\0$', '\u0000', true),
      (r'^[\0]$', '\u0000', true),
      (r'^\cA$', '\u0001', true),
      (r'^[\cA]$', '\u0001', true),
      (r'^\c1$', r'\c1', true),
      // The input is read by code point.
      (r'^.$', '😀', true),
      // Lookaheads right after a leading `^`.
      (r'^(?=.*\d)(?=.*[A-Z]).{8,}$', 'Password1', true),
      (r'^(?=.*\d)(?=.*[A-Z]).{8,}$', 'password1', false),
      (r'^(?=.*\d)(?=.*[A-Z]).{8,}$', 'Pass1', false),
      (r'^(?!admin).+$', 'user', true),
      (r'^(?!admin).+$', 'admin1', false),
      ('^(?=.*a)(?:b|c)', 'ba', true),
      ('^(?=.*a)(?:b|c)', 'ca', true),
      ('^(?=.*a)(?:b|c)', 'c', false),
      // A common email pattern.
      (r'^[^\s@]+@[^\s@]+\.[^\s@]+$', 'a@b.co', true),
      (r'^[^\s@]+@[^\s@]+\.[^\s@]+$', 'a@b', false),
    ]) {
      test(
        '/$pattern/ ${expected ? 'matches' : 'does not match'} ${input.replaceAll('\n', r'\n').replaceAll('\r', r'\r')}',
        () {
          expect(_matches(pattern, input), expected);
        },
      );
    }
  });

  group('rejects', () {
    for (final (pattern, why) in [
      ('(?<=a)b', 'a lookbehind'),
      ('(?<!a)b', 'a negative lookbehind'),
      (r'(a)\1', 'a backreference'),
      (r'(?<x>a)\k<x>', 'a named backreference'),
      ('a(?=b)', 'a lookahead past the start'),
      ('(?=a)b', 'a lookahead without a leading ^'),
      ('(?i)a', 'an inline flag'),
      ('^(?=a)b|c', 'an alternation after a leading lookahead'),
      (r'\01', 'a legacy octal escape'),
      (r'[\1]', 'a legacy octal escape in a class'),
      (r'[\c1]', 'a legacy control escape in a class'),
      ('(?<1a>x)', 'a group name starting with a digit'),
      ('(?<a-b>x)', 'a group name with a hyphen'),
      (r'\p{L}', 'a Unicode property escape'),
      ('(a', 'an unclosed group'),
      ('a)', 'an unopened group'),
      ('[a', 'an unclosed class'),
      ('[z-a]', 'a range out of order'),
      ('a{3,1}', 'counts out of order'),
      ('*a', 'nothing to repeat'),
      ('a**', 'a doubled count'),
      (r'a\', 'a trailing backslash'),
    ]) {
      test('$why: $pattern', () => expect(PatternMatcher.compile(pattern), isNull));
    }

    test('a pattern longer than the cap', () {
      expect(PatternMatcher.compile('a' * PatternMatcher.maxPatternLength), isNotNull);
      expect(PatternMatcher.compile('a' * (PatternMatcher.maxPatternLength + 1)), isNull);
    });

    test('a pattern that expands past the cap once its counts are written out', () {
      expect(PatternMatcher.compile('(?:a{100}){10}'), isNotNull);
      expect(PatternMatcher.compile('(?:a{100}){11}'), isNull);
      expect(PatternMatcher.compile('a{0,600}b{0,600}'), isNull);
      expect(PatternMatcher.compile('a{1000}'), isNotNull);
      expect(PatternMatcher.compile('a{1001}'), isNull);
      expect(PatternMatcher.compile('a{99999999999999999999}'), isNull);
    });

    for (final (pattern, why) in [
      ('[${'b' * 400}a]{0,590}x', 'a long class counted many times'),
      ('(?:(?:|){300}){300}x', 'an empty group counted many times'),
      ('(?:${'(?:' * 190}a${')?' * 190}){999}x', 'nested optional groups counted many times'),
      ('(?:${'(?:' * 190}a${')*' * 190}){999}x', 'nested repeated groups counted many times'),
    ]) {
      test('a pattern that costs too much to compile: $why', () {
        expect(PatternMatcher.compile(pattern), isNull);
      });
    }

    for (final pattern in [r'^[^\s@]+@[^\s@]+\.[^\s@]+$', r'^(?=.*\d)(?=.*[A-Z]).{8,}$']) {
      test('not a common pattern that costs little to compile: $pattern', () {
        expect(PatternMatcher.compile(pattern), isNotNull);
      });
    }
  });

  test('sizes a pattern as its counts written out', () {
    expect(PatternMatcher.sizeOf('a{0,3}b'), 4);
    expect(PatternMatcher.sizeOf('(?:ab){3}'), 6);
    expect(PatternMatcher.sizeOf('a+'), 2);
    expect(PatternMatcher.sizeOf('a*b?'), 2);
    expect(PatternMatcher.sizeOf('a{2,}'), 3);
  });

  group('input', () {
    test('longer than the cap matches nothing', () {
      final matcher = PatternMatcher.compile('a')!;
      expect(matcher.hasMatch('a' * PatternMatcher.maxInputLength), isTrue);
      expect(matcher.hasMatch('a' * (PatternMatcher.maxInputLength + 1)), isFalse);
    });

    for (final (pattern, input) in [
      (r'(a+)+$', '${'a' * 4095}b'),
      (r'^(a|a)*$', '${'a' * 4095}b'),
      ('x.*x.*y', 'x' * 4096),
      (r'(\d*)*\d*\d*x', '1' * 4096),
    ]) {
      test('is matched in linear time against $pattern', () {
        final watch = Stopwatch()..start();
        expect(_matches(pattern, input), isFalse);
        expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
      });
    }
  });
}
