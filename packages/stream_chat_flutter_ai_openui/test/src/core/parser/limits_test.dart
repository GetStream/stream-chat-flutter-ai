import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/expression_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materializer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

// The boundaries are StreamChatOpenUI's, produced by running it
// (test/fixtures/ios_depth_boundaries.txt).
void main() {
  for (final (length, kept) in _boundaries('chain')) {
    test('a chain of $length operators is ${kept ? 'kept' : 'read as null'}', () {
      final root = _parse('root = Title("a"${' + "b"' * length})').root;

      expect(root != null, kept);
    });
  }

  for (final (depth, levels, leafKept) in _nestings()) {
    test('$depth levels of brackets keep $levels levels${leafKept ? ' and the value' : ', the innermost null'}', () {
      final children = _parse('root = Stack(${'[' * depth}1${']' * depth})').root!.props['children'];

      expect(_levels(children), (levels, leafKept ? const OpenUINumber(1) : OpenUINull.instance));
    });
  }

  test('past the depth limit, the rest of the statement is dropped', () {
    final deep = '${'[' * 300}1${']' * 300}';
    final children = _parse('root = Stack([$deep, Title("after")])').root!.props['children']! as OpenUIArray;

    expect(children.items, hasLength(1));
  });

  for (final (length, levels, leafKept) in _referenceChains()) {
    test('a chain of $length references keeps $levels levels${leafKept ? ' and its component' : ''}', () {
      final children = _parse(_referenceChain(length)).root!.props['children'];
      final (kept, leaf) = _levels(children);

      expect((kept, leaf is OpenUIElement), (levels, leafKept));
    });
  }

  test('7,000 uses of a reference, about 21,000 nodes, go past the budget of 20,000', () {
    final uses = List.filled(7000, 'item').join(', ');
    final root = _parse('root = Stack([$uses])\nitem = Title("x")').root!;

    expect((root.props['children']! as OpenUIArray).items.length, lessThan(7000));
  });

  test('a chain of 10,000 operators does not overflow the stack', () {
    expect(() => _parse('root = Title("a"${' + "b"' * 10000})'), returnsNormally);
  });

  test('10,000 levels of brackets do not overflow the stack', () {
    expect(() => _parse('root = Stack(${'[' * 10000}1${']' * 10000})'), returnsNormally);
  });

  test('a chain of 10,000 references does not overflow the stack', () {
    final text = [
      'root = Stack([r0])',
      for (var i = 0; i < 10000; i += 1) 'r$i = [r${i + 1}]',
      'r10000 = Title("end")',
    ].join('\n');

    expect(() => _parse(text), returnsNormally);
  });

  test('a chain of 10,000 member reads does not overflow the stack', () {
    expect(() => _parse('root = Title(a${'.b' * 10000})'), returnsNormally);
  });

  test('references that double at each of 30 levels stop at the node budget', () {
    final text = [
      'root = Stack([a30])',
      'a0 = Title("x")',
      for (var i = 1; i <= 30; i += 1) 'a$i = Stack([a${i - 1}, a${i - 1}])',
    ].join('\n');

    final root = _parse(text).root;

    expect(_elements(root == null ? null : OpenUIElement(root)), lessThanOrEqualTo(Materializer.maxNodes));
  });

  test('every use of a reference counts against the node budget', () {
    final uses = List.filled(Materializer.maxNodes, 'item').join(', ');
    final root = _parse('root = Stack([$uses])\nitem = Title("x")').root!;

    expect((root.props['children']! as OpenUIArray).items.length, lessThan(Materializer.maxNodes));
  });

  test('6,000 uses of a reference, about 18,000 nodes, are resolved whole', () {
    final uses = List.filled(6000, 'item').join(', ');
    final root = _parse('root = Stack([$uses])\nitem = Title("x")').root!;

    expect((root.props['children']! as OpenUIArray).items, hasLength(6000));
  });

  test('references that double at each of 30 levels still render a root', () {
    final text = [
      'root = Stack([a30])',
      'a0 = Title("x")',
      for (var i = 1; i <= 30; i += 1) 'a$i = Stack([a${i - 1}, a${i - 1}])',
    ].join('\n');

    expect(_parse(text).root, isNotNull);
  });

  test('a value printed from 20 levels of nested calls grows linearly', () {
    final nested = '${'@Count(' * 20}x${')' * 20}';
    final root = _parse('root = Stack([Title("" + $nested)])').root!;

    expect(root.props['children'].toString().length, lessThan(20 * 200));
  });

  test('reading never fails, whatever the program', () {
    for (final text in _randomPrograms()) {
      expect(() => _parse(text), returnsNormally, reason: text);
    }
  });

  test('parsing an expression never fails, whatever the tokens', () {
    for (final text in _randomPrograms()) {
      expect(() => ExpressionParser.parse(Lexer.tokenize(text)), returnsNormally, reason: text);
    }
  });

  test('query arguments printed from 20 levels of nested calls grow linearly', () {
    final nested = '${'@Count(' * 20}x${')' * 20}';
    final query = _parse('q = Query("t", {a: $nested})\nroot = Stack([])').queryStatements.single;

    expect(OpenUIExpression(query.args!).toString().length, lessThan(20 * 200));
  });

  test('a root expression printed from 20 levels of nested calls grows linearly', () {
    final nested = '${'@Count(' * 20}x${')' * 20}';
    final result = _parse('root = \$t ? Stack([Title("" + $nested)]) : Title("b")');

    expect(OpenUIExpression(result.rootExpression!).toString().length, lessThan(20 * 200));
  });

  test('two parses of 30 levels of nested calls compare and hash in linear time', () {
    final nested = '${'@Count(' * 30}x${')' * 30}';
    final text = 'q = Query("t", {a: $nested})\nroot = \$t ? Stack([Title("" + $nested)]) : Title("b")';
    final (first, second) = (_parse(text), _parse(text));
    final stopwatch = Stopwatch()..start();
    final same = first == second && first.hashCode == second.hashCode;

    // Linear, this takes microseconds; doubling at each level, over a billion
    // steps.
    expect((same, stopwatch.elapsed < const Duration(seconds: 5)), (true, true));
  });

  test('the fixture has 6 chain cases', () {
    expect(_boundaries('chain'), hasLength(6));
  });

  test('the fixture has 6 nesting cases', () {
    expect(_nestings(), hasLength(6));
  });

  test('the fixture has 6 reference-chain cases', () {
    expect(_referenceChains(), hasLength(6));
  });

  test('calls nested 40 deep in a ternary root are walked once each', () {
    final nested = '${'@Count(' * 40}x${')' * 40}';
    final result = _parse('root = \$t ? Stack([Title("" + $nested)]) : Title("b")');
    var counts = 0;
    result.rootExpression!.walk((node) {
      if (node case AstCall(name: 'Count')) counts += 1;
    });

    expect(counts, 40);
  });
}

final _schema = OpenUILibrarySchema.fromJsonSchema(const {
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
});

ParseResult _parse(String text) => OpenUILangParser(_schema).parse(text);

// The chain cases of the fixture, as their length and whether the root was
// kept.
List<(int, bool)> _boundaries(String kind) {
  return [
    for (final line in File('test/fixtures/ios_depth_boundaries.txt').readAsLinesSync())
      if (RegExp('^$kind (\\d+): root (kept|null)').firstMatch(line) case final match?)
        (int.parse(match.group(1)!), match.group(2) == 'kept'),
  ];
}

// The nesting cases of the fixture, as their depth, the levels kept, and
// whether the innermost value was kept.
List<(int, int, bool)> _nestings() {
  return [
    for (final line in File('test/fixtures/ios_depth_boundaries.txt').readAsLinesSync())
      if (RegExp(r'^nest (\d+): array levels kept (\d+) leaf (\S+)').firstMatch(line) case final match?)
        (int.parse(match.group(1)!), int.parse(match.group(2)!), match.group(3) == '1'),
  ];
}

// The reference-chain cases of the fixture, as their length, the levels kept,
// and whether the component at the end was kept.
List<(int, int, bool)> _referenceChains() {
  return [
    for (final line in File('test/fixtures/ios_depth_boundaries.txt').readAsLinesSync())
      if (RegExp(r'^refs (\d+): array levels kept (\d+) leaf (\S+)').firstMatch(line) case final match?)
        (int.parse(match.group(1)!), int.parse(match.group(2)!), match.group(3) == 'Title'),
  ];
}

// 2,000 programs of up to 30 tokens drawn from OpenUI Lang's, seeded so a
// failure repeats.
List<String> _randomPrograms() {
  final random = Random(7);
  const vocabulary = [
    'root', 'a', 'b', r'$v', '=', 'Stack', 'Title', 'Query', 'Mutation', 'Action', '@Count', '@Each', '@Set', //
    '@Nope', 'Nope', '(', ')', '[', ']', '{', '}', ',', ':', '?', '.', '+', '-', '*', '/', '%', '!', '==', '&&', //
    '||', '<', '>=', '"x"', "'y'", '"', '1', '-2.5', '1e', 'null', 'true', '\n', '\n\n', '```', '// c', '# c',
  ];
  return [
    for (var i = 0; i < 2000; i += 1)
      [for (var j = random.nextInt(30); j > 0; j -= 1) vocabulary[random.nextInt(vocabulary.length)]].join(
        random.nextBool() ? ' ' : '',
      ),
  ];
}

String _referenceChain(int length) {
  return [
    'root = Stack([r0])',
    for (var i = 0; i < length; i += 1) 'r$i = [r${i + 1}]',
    'r$length = Title("end")',
  ].join('\n');
}

(int, OpenUIValue?) _levels(OpenUIValue? value) {
  var levels = 0;
  var current = value;
  while (current is OpenUIArray && current.items.isNotEmpty) {
    current = current.items.first;
    levels += 1;
  }
  return (levels, current);
}

int _elements(OpenUIValue? value) {
  return switch (value) {
    OpenUIElement(:final node) => 1 + node.props.values.fold(0, (sum, prop) => sum + _elements(prop)),
    OpenUIArray(:final items) => items.fold(0, (sum, item) => sum + _elements(item)),
    _ => 0,
  };
}
