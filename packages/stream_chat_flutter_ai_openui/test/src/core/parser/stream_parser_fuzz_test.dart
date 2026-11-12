import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';

// Reading never throws, and a stream ends as the whole text reads, however
// the text is cut.
void main() {
  test('random programs read in random pieces end as they read in one piece', () {
    final random = Random(_seed);
    final schema = _spec();
    final differing = <String>[];
    for (var run = 0; run < _runs; run += 1) {
      final program = _randomProgram(random);
      final streamed = _stream(schema, _sized(program, random));
      if (!_sameButCount(streamed, OpenUILangParser(schema).parse(program))) differing.add(program);
    }

    expect(differing, isEmpty);
  });

  // The growth gates deliberately return a kept result for a long statement
  // or a program of many statements, so this uses short programs, where every
  // step reads the text afresh.
  test('each step of a stream reads as a fresh parser reads the text so far', () {
    final random = Random(_seed);
    final schema = _spec();
    final differing = <String>[];
    for (var run = 0; run < _stepRuns; run += 1) {
      final program = _randomProgram(random, long: false);
      final streaming = OpenUIStreamParser(schema);
      var text = '';
      for (final piece in _sized(program, random)) {
        text += piece;
        final incremental = parseResultJson(streaming.push(piece));
        final fresh = parseResultJson(OpenUIStreamParser(schema).set(text));
        if (jsonEncode(incremental) != jsonEncode(fresh)) {
          differing.add(text);
          break;
        }
      }
    }

    expect(differing, isEmpty);
  });

  test('every parser fixture read one code unit at a time never throws', () {
    final cases = (jsonDecode(File(_parserFixtures).readAsStringSync()) as List<Object?>).cast<Map<String, Object?>>();
    final schema = _spec();

    expect(() {
      for (final testCase in cases) {
        final input = testCase['input']! as String;
        _stream(schema, [for (final unit in input.codeUnits) String.fromCharCode(unit)]);
      }
    }, returnsNormally);
  });

  test('every parser fixture read one code unit at a time ends as it reads in one piece', () {
    final cases = (jsonDecode(File(_parserFixtures).readAsStringSync()) as List<Object?>).cast<Map<String, Object?>>();
    final schema = _spec();
    final differing = <String>[];
    for (final testCase in cases) {
      final input = testCase['input']! as String;
      final streamed = _stream(schema, [for (final unit in input.codeUnits) String.fromCharCode(unit)]);
      if (!_sameButCount(streamed, OpenUILangParser(schema).parse(input))) differing.add(testCase['name']! as String);
    }

    expect(differing, isEmpty);
  });
}

const _seed = 0x5eed;
const _runs = 500;
const _stepRuns = 60;
const _maxPiece = 12;
const _maxParts = 40;
const _parserFixtures = 'test/conformance/generated/parser-conformance.json';

// The parts random programs are built from: statements of the specification's
// library, references, state, ternaries, comments, fences, strings with
// escapes, and broken pieces.
final _parts = [
  'root = Stack([a, b])\n',
  'a = Text("hello")\n',
  'b = Card([Text(c)])\n',
  'c = "x"\n',
  '\$n = 0\n',
  's = \$n > 0\n',
  '  ? "some"\n',
  '  : "none"\n',
  'a = Text("again")\n',
  '// note\n',
  '# note\n',
  '```openui\n',
  '```\n',
  'Here you go:\n',
  't = Text("a\\"b")\n',
  "u = Text('it''s')\n",
  'v = [1, 2, {k: 3}]\n',
  'w = @Upper("x")\n',
  // Longer than the length past which a statement still arriving is read
  // again only in steps.
  'long = Text("${'x' * 2100}")\n',
  'q = Query("tool", {}, {rows: []})\n',
  'x = Stack([',
  ']\n',
  ')\n',
  '"',
  r'\',
  '\n',
  ' ',
  r'$d',
  'root = Text(',
  'y = Stack([y])\n',
  'z = 1 + 2 * 3\n',
  '\r\n',
];

String _randomProgram(Random random, {bool long = true}) {
  final parts = 1 + random.nextInt(_maxParts);
  final choices = long ? _parts : _parts.where((part) => part.length < OpenUIStreamParser.longStatement ~/ 2).toList();
  return [for (var part = 0; part < parts; part += 1) choices[random.nextInt(choices.length)]].join();
}

List<String> _sized(String text, Random random) {
  final pieces = <String>[];
  var start = 0;
  while (start < text.length) {
    final end = min(text.length, start + 1 + random.nextInt(_maxPiece));
    pieces.add(text.substring(start, end));
    start = end;
  }
  return pieces;
}

ParseResult _stream(OpenUILibrarySchema schema, List<String> pieces) {
  final parser = OpenUIStreamParser(schema);
  for (final piece in pieces) {
    parser.push(piece);
  }
  return parser.result(complete: true);
}

// Whether `streamed` is `whole` apart from how many definitions it counts:
// a stream counts each definition of a name defined twice.
bool _sameButCount(ParseResult streamed, ParseResult whole) {
  final streamedJson = parseResultJson(streamed);
  final wholeJson = parseResultJson(whole);
  (streamedJson['meta']! as Map<String, Object?>).remove('statementCount');
  (wholeJson['meta']! as Map<String, Object?>).remove('statementCount');
  return jsonEncode(streamedJson) == jsonEncode(wholeJson);
}

OpenUILibrarySchema _spec() {
  final spec = jsonDecode(File('test/conformance/generated/spec-library.json').readAsStringSync());
  return OpenUILibrarySchema.fromSpec(spec as Map<String, Object?>);
}
