import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materializer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

// A stream parser reuses what statements resolved to between chunks. Each
// test streams a program and checks that every step reads as a parser that
// has read nothing before reads the same text, and that the end of the stream
// reads as the whole text read at once, by a parser that keeps nothing.
void main() {
  test('reused statements read as fresh ones at every step of every parser fixture', () {
    final cases = (jsonDecode(File(_parserFixtures).readAsStringSync()) as List<Object?>).cast<Map<String, Object?>>();
    final differing = <String>[];
    for (final testCase in cases) {
      final schema = _libraries[testCase['library']]!;
      final chunks = (testCase['chunks']! as List<Object?>).cast<String>();
      if (_firstDifferingStep(schema, chunks) case final step?) differing.add('${testCase['name']} @ $step');
    }

    expect(differing, isEmpty);
  });

  test('a statement edited while it arrives is resolved again', () {
    expect(_firstDifferingStep(_schema, _lines('root = Stack([t])\nt = Text("a', 'b")\n')), isNull);
  });

  test('a statement referenced before it is declared shows up once it arrives', () {
    expect(_firstDifferingStep(_schema, _lines('root = Stack([t, u])\nt = Text("a")\n', 'u = Text("b")\n')), isNull);
  });

  test('a redefinition replaces what the statements reading it resolved to', () {
    final chunks = _lines('root = Stack([s])\ns = Stack([t])\nt = Text("a")\n', 't = Text("b")\n');

    expect(_firstDifferingStep(_schema, chunks), isNull);
  });

  test('state used by a reused statement follows its declaration', () {
    final chunks = _lines('root = Stack([t])\nt = Text(\$name)\n', '\$name = "Ana"\n');

    expect(_firstDifferingStep(_schema, chunks), isNull);
  });

  test('the node budget still applies to reused statements', () {
    final levels = [
      'l0 = Text("x")',
      for (var level = 1; level <= _budgetLevels; level += 1) 'l$level = Stack([l${level - 1}, l${level - 1}])',
      'root = Stack([l$_budgetLevels, l$_budgetLevels])',
    ];
    final program = '${levels.join('\n')}\n';

    expect(_sameResult(_streamed(_schema, _sized(program, _budgetChunk)), _batch(_schema, program)), isTrue);
  });

  test('a program past the node budget is cut, so the budget test reaches it', () {
    final levels = [
      'l0 = Text("x")',
      for (var level = 1; level <= _budgetLevels; level += 1) 'l$level = Stack([l${level - 1}, l${level - 1}])',
      'root = Stack([l$_budgetLevels, l$_budgetLevels])',
    ];
    final result = _batch(_schema, '${levels.join('\n')}\n');

    expect(_countTexts(OpenUIElement(result.root!)), lessThan(1 << (_budgetLevels + 1)));
  });

  test('a chain cut by the depth limit is cut where each use is too deep, also when reused', () {
    final chain = [
      for (var link = 1; link < _chainLength; link += 1) 'd$link = Stack([d${link + 1}])',
      'd$_chainLength = Text("leaf")',
    ];
    final program = 'root = Stack([d1, p])\np = Stack([Stack([Stack([d1])])])\n${chain.join('\n')}\n';

    expect(_sameResult(_streamed(_schema, _sized(program, _budgetChunk)), _batch(_schema, program)), isTrue);
  });

  test('a statement reused where it no longer fits the depth limit is cut as a fresh one', () {
    final differing = [
      for (var links = _firstDeepLinks; links <= _lastDeepLinks; links += 1)
        if (!_sameResult(
          _streamed(_schema, _lines(_deepReuse(links, leafFirst: true), '')),
          _batch(_schema, _deepReuse(links, leafFirst: true)),
        ))
          links,
    ];

    expect(differing, isEmpty);
  });

  test('a statement cut by the depth limit where it is used deep reads in full where it is used shallow', () {
    final differing = [
      for (var links = _firstDeepLinks; links <= _lastDeepLinks; links += 1)
        if (!_sameResult(
          _streamed(_schema, _lines(_deepReuse(links, leafFirst: false), '')),
          _batch(_schema, _deepReuse(links, leafFirst: false)),
        ))
          links,
    ];

    expect(differing, isEmpty);
  });

  for (final wrapping in [_Wrapping.deepBranch, _Wrapping.reusedLeaf]) {
    test('a statement reused near the depth limit is cut as a fresh one (${wrapping.name})', () {
      final differing = [
        for (var links = _firstDeepLinks; links <= _lastDeepLinks; links += 1)
          if (!_sameResult(
            _streamed(_schema, _lines(_deepReuse(links, leafFirst: true, wrapping: wrapping), '')),
            _batch(_schema, _deepReuse(links, leafFirst: true, wrapping: wrapping)),
          ))
            links,
      ];

      expect(differing, isEmpty);
    });
  }

  test('the deep-reuse programs reach the depth limit', () {
    final cut = _batch(_schema, _deepReuse(_lastDeepLinks, leafFirst: true));
    final whole = _batch(_schema, _deepReuse(_firstDeepLinks, leafFirst: true));

    expect(_countTexts(OpenUIElement(cut.root!)), lessThan(_countTexts(OpenUIElement(whole.root!))));
  });

  test('statements that reference each other read as they do in one piece at the end of the stream', () {
    const program = 'root = Stack([a, b])\na = Stack([b])\nb = Stack([a])\n';

    expect(_sameResult(_streamed(_schema, _lines(program, '')), _batch(_schema, program)), isTrue);
  });

  test('the depth-limit test uses a chain that the limit cuts', () {
    expect(_chainLength, greaterThan(Materializer.maxDepth ~/ 2));
  });

  test('statements that reference each other read as in one piece', () {
    final chunks = _lines('root = Stack([a, b])\na = Stack([b])\n', 'b = Stack([a])\n');

    expect(_firstDifferingStep(_schema, chunks), isNull);
  });

  test('a loop variable named like a statement stays the loop variable', () {
    final chunks = _lines('root = Stack([@Each(items, "t", Text(t))])\nitems = ["x"]\n', 't = Text("statement")\n');

    expect(_firstDifferingStep(_schema, chunks), isNull);
  });

  test('a reused statement reports its errors again', () {
    final chunks = _lines('root = Stack([t])\nt = Text(1)\n', 'u = Text("b")\n');

    expect(_firstDifferingStep(_schema, chunks), isNull);
  });
}

const _parserFixtures = 'test/conformance/generated/parser-conformance.json';
const _budgetLevels = 13;
const _budgetChunk = 40;
const _chainLength = 200;
const _firstDeepLinks = 70;
const _lastDeepLinks = 90;

// A root holding `leaf`, a few levels deep, and a chain of `links` statements
// that ends in the same `leaf`, so `leaf` is used once shallow and once near
// the depth limit; `leafFirst` says which use comes first.
String _deepReuse(int links, {required bool leafFirst, _Wrapping wrapping = _Wrapping.none}) {
  final used = wrapping == _Wrapping.none ? 'leaf' : 'mid';
  final chain = [
    for (var link = 1; link < links; link += 1) 'c$link = Stack([c${link + 1}])',
    'c$links = Stack([$used])',
  ];
  final children = [
    if (wrapping == _Wrapping.reusedLeaf) 'leaf',
    if (leafFirst) ...[used, 'c1'] else ...['c1', used],
  ];
  return [
    'root = Stack([${children.join(', ')}])',
    if (wrapping == _Wrapping.deepBranch) 'mid = Stack([$_deepBranch, leaf])',
    if (wrapping == _Wrapping.reusedLeaf) 'mid = Stack([Stack([leaf])])',
    'leaf = Stack([Stack([Stack([Stack([Text("x")])])])])',
    ...chain,
  ].join('\n');
}

// Nested Stacks, deeper than `leaf`.
final _deepBranch = '${'Stack([' * _deepBranchLevels}Text("deep")${'])' * _deepBranchLevels}';
const _deepBranchLevels = 8;

// How the deep-reuse programs use `leaf`: directly; through `mid`, which holds
// a branch deeper than `leaf` before it; or through `mid`, after the root
// already used `leaf`, so `mid` reuses it.
enum _Wrapping { none, deepBranch, reusedLeaf }

final _schema = OpenUILibrarySchema.fromJsonSchema(const {
  r'$defs': {
    'Stack': {
      'properties': {
        'children': {'type': 'array'},
      },
      'required': ['children'],
    },
    'Text': {
      'properties': {
        'text': {'type': 'string'},
      },
      'required': ['text'],
    },
  },
}, root: 'Stack');

final _libraries = <String, OpenUILibrarySchema>{
  // Two components, no root, as the parser fixtures' minimal library.
  'mini': OpenUILibrarySchema.fromJsonSchema(const {
    r'$defs': {
      'Stack': {
        'properties': {'children': <String, Object?>{}},
        'required': ['children'],
      },
      'Title': {
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  }),
  'chat': _spec('test/conformance/generated/upstream-chat-library.spec.json'),
  'playground': _spec('test/conformance/generated/upstream-playground-library.spec.json'),
  'spec': _spec('test/conformance/generated/spec-library.json'),
};

OpenUILibrarySchema _spec(String path) {
  return OpenUILibrarySchema.fromSpec(jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>);
}

// The first step at which streaming `chunks` reads differently from a parser
// that has read nothing before, or the end of the stream from the whole text
// read at once; null when none does.
int? _firstDifferingStep(OpenUILibrarySchema schema, List<String> chunks) {
  final parser = OpenUIStreamParser(schema);
  var text = '';
  for (final (step, chunk) in chunks.indexed) {
    text += chunk;
    final streamed = parser.push(chunk);
    final fresh = OpenUIStreamParser(schema).set(text);
    if (!_sameResult(streamed, fresh)) return step;
  }
  if (!_sameButCount(parser.result(complete: true), _batch(schema, text))) return chunks.length;
  return null;
}

// Whether `a` and `b` are the same result, compared as the text of their
// written form, which takes time in proportion to its size however deeply
// the tree nests.
bool _sameResult(ParseResult a, ParseResult b) => jsonEncode(parseResultJson(a)) == jsonEncode(parseResultJson(b));

// Whether `streamed` is `whole` apart from how many definitions it counts: a
// stream counts each definition of a name defined twice.
bool _sameButCount(ParseResult streamed, ParseResult whole) {
  final streamedJson = parseResultJson(streamed);
  final wholeJson = parseResultJson(whole);
  (streamedJson['meta']! as Map<String, Object?>).remove('statementCount');
  (wholeJson['meta']! as Map<String, Object?>).remove('statementCount');
  return jsonEncode(streamedJson) == jsonEncode(wholeJson);
}

ParseResult _streamed(OpenUILibrarySchema schema, List<String> chunks) {
  final parser = OpenUIStreamParser(schema);
  for (final chunk in chunks) {
    parser.push(chunk);
  }
  return parser.result(complete: true);
}

ParseResult _batch(OpenUILibrarySchema schema, String text) => OpenUILangParser(schema).parse(text);

// `first` cut into its lines, each with its line break, then `rest`.
List<String> _lines(String first, String rest) {
  return [...first.split('\n').where((line) => line.isNotEmpty).map((line) => '$line\n'), rest];
}

List<String> _sized(String text, int size) {
  return [
    for (var start = 0; start < text.length; start += size) text.substring(start, (start + size).clamp(0, text.length)),
  ];
}

int _countTexts(OpenUIValue value) {
  return switch (value) {
    OpenUIElement(:final node) when node.typeName == 'Text' => 1,
    OpenUIElement(:final node) => node.props.values.fold(0, (sum, prop) => sum + _countTexts(prop)),
    OpenUIArray(:final items) => items.fold(0, (sum, item) => sum + _countTexts(item)),
    _ => 0,
  };
}
