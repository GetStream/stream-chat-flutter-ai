import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/incremental_preprocessor.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/preprocessor.dart';

void main() {
  test('appending random pieces prepares what preparing the whole text gives, after every piece', () {
    final random = Random(_seed);
    final mismatches = <String>[];
    for (var run = 0; run < _runs && mismatches.isEmpty; run += 1) {
      final preprocessor = IncrementalPreprocessor();
      final text = StringBuffer();
      final pieceCount = 1 + random.nextInt(_maxPieces);
      for (var piece = 0; piece < pieceCount; piece += 1) {
        final added = _pieces[random.nextInt(_pieces.length)];
        text.write(added);
        preprocessor.append(added);
        final expected = Preprocessor.prepare(text.toString());
        final actual = _prepared(preprocessor);
        if (actual != expected) mismatches.add('${text.toString()} → $actual, expected $expected');
      }
    }

    expect(mismatches, isEmpty);
  });

  test('appending one code unit at a time prepares what preparing the whole text gives', () {
    const text = 'Here:\n```openui\nroot = Stack([t]) // the page\nt = Text("a ``` # b")\n```\nDone.';
    final preprocessor = IncrementalPreprocessor();
    for (final unit in text.codeUnits) {
      preprocessor.append(String.fromCharCode(unit));
    }

    expect(_prepared(preprocessor), Preprocessor.prepare(text));
  });

  test('appending from an offset reads the text from there on', () {
    final preprocessor = IncrementalPreprocessor()..append('ignored a = 1', 'ignored '.length);

    expect(_prepared(preprocessor), 'a = 1');
  });

  test('the first fence after unfenced text starts over', () {
    final preprocessor = IncrementalPreprocessor()..append('Here you go:\n');

    expect(preprocessor.append('```openui\nroot = Stack([])\n'), isTrue);
  });

  test('a second fence does not start over', () {
    final preprocessor = IncrementalPreprocessor()..append('```openui\na = 1\n```\n');

    expect(preprocessor.append('```openui\nb = 2\n'), isFalse);
  });

  test('the first fence starts over also at the very start of the text', () {
    final preprocessor = IncrementalPreprocessor();

    expect(preprocessor.append('```openui\na = 1\n'), isTrue);
  });

  test('text without fences never starts over', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1\n');

    expect(preprocessor.append('b = "``"\n'), isFalse);
  });

  test('one backtick at the end is kept, and stays once the next code unit shows it is not a fence', () {
    final preprocessor = IncrementalPreprocessor()
      ..append('a = 1 `')
      ..append('x');

    expect(_prepared(preprocessor), 'a = 1 `x');
  });

  test('two backticks at the end become a fence when a third arrives', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1\n``');

    expect(preprocessor.append('`js\nb = 2'), isTrue);
  });

  test('a `#` inside a string left open across a line is kept', () {
    final preprocessor = IncrementalPreprocessor()..append('a = "x\n# y"');

    expect(_prepared(preprocessor), 'a = "x\n# y"');
  });

  test('the text up to the last line break stays the same as more arrives', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1\nb = 2 /');
    final stable = preprocessor.codeUnits.sublist(0, preprocessor.stableLength);
    preprocessor.append('/ c');

    expect(preprocessor.codeUnits.sublist(0, stable.length), stable);
  });

  test('a long run of white space appended one code unit at a time is read a bounded number of times', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1');
    for (var index = 0; index < _lines * 20; index += 1) {
      preprocessor.append(' ');
    }

    // Taking out fences and taking out comments each read a space once.
    expect(preprocessor.debugReadCodeUnits, lessThanOrEqualTo(2 * ('a = 1'.length + _lines * 20)));
  });

  test('an append that leaves the prepared text unchanged keeps its revision', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1');
    final revision = preprocessor.revision;
    preprocessor.append('   ');

    expect(preprocessor.revision, revision);
  });

  test('an append that changes the prepared text changes its revision', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1');
    final revision = preprocessor.revision;
    preprocessor.append('2');

    expect(preprocessor.revision, isNot(revision));
  });

  test('an append that changes the end of the prepared text but not its length changes its revision', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1 /');
    final revision = preprocessor.revision;
    preprocessor.append('/ c\nb');

    expect(preprocessor.revision, isNot(revision));
  });

  test('the same-length revision test keeps the length', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1 /');
    final length = preprocessor.length;
    preprocessor.append('/ c\nb');

    expect(preprocessor.length, length);
  });

  test('a line end turning into a comment changes the revision', () {
    final preprocessor = IncrementalPreprocessor()..append('a = 1 /');
    final revision = preprocessor.revision;
    preprocessor.append('/');

    expect(preprocessor.revision, isNot(revision));
  });

  test('preparing a text one code unit at a time reads each unit a bounded number of times', () {
    final text = List.generate(_lines, (index) => 'line$index = Text("value $index") # note').join('\n');
    final preprocessor = IncrementalPreprocessor();
    for (final unit in text.codeUnits) {
      preprocessor.append(String.fromCharCode(unit));
    }

    // Each unit is read by both stages, and its line again on every append
    // that lands on it: the longest line bounds that.
    final longestLine = text.split('\n').map((line) => line.length).reduce(max);
    expect(preprocessor.debugReadCodeUnits, lessThanOrEqualTo(text.length * (2 + longestLine)));
  });
}

// The pieces random texts are built from: fences and partial fences, quotes,
// escapes, both comment markers, line endings, white space JavaScript trims,
// statements and prose.
const _pieces = [
  '`', '``', '```', '```js\n', '```\n', '"', "'", r'\', '/', '//', '#', '\n', '\r\n', ' ', '\t', //
  ' ', '　', 'é', 'a', 'x = 1', '(', ')', '[', ']', '?', ':', 'root = Stack([a])',
  'a = TextContent("hi")', r'$x', "You're", '"```"',
];

const _seed = 0x9e3779b9;
const _runs = 2000;
const _maxPieces = 31;
const _lines = 200;

String _prepared(IncrementalPreprocessor preprocessor) {
  return String.fromCharCodes(preprocessor.codeUnits, 0, preprocessor.length);
}
