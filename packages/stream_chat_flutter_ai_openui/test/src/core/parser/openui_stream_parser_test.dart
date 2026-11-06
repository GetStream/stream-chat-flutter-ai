import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

void main() {
  test('a statement whose line has not ended renders, closed', () {
    final result = _parser().set('root = Stack([Text("a');

    expect(_texts(result), ['a']);
  });

  test('a statement whose line has not ended marks the result incomplete', () {
    expect(_parser().set('root = Stack([Text("a').meta.incomplete, isTrue);
  });

  test('a line starting with `?` continues the statement before it', () {
    const first =
        'root = Stack([Text(s)])\n'
        r's = $n > 0'
        '\n';
    final parser = _parser()..set(first);
    final result = parser.set('$first  ? "some"\n  : "none"\n');

    expect(_textNode(result), isA<AstTernary>());
  });

  test('a ternary still waiting for its `:` continues across line breaks', () {
    const first =
        'root = Stack([Text(s)])\n'
        r's = $n > 0 ?'
        '\n';
    final parser = _parser()..set(first);
    final result = parser.set('$first"yes" : "no"\nx = 1\n');

    expect(_textNode(result), isA<AstTernary>());
  });

  test('a finished statement stays the same when more text arrives', () {
    final parser = _parser();
    final first = parser.set('t = Text("a")\nroot = Stack([t])\n');
    final second = parser.set('t = Text("a")\nroot = Stack([t])\nu = Te');

    expect(second.root, first.root);
  });

  test('a statement still arriving that needs closing does not replace a finished one of the same name', () {
    final result = _parser().set('t = Text("x")\nroot = Stack([t])\nt = Text("y');

    expect(_texts(result), ['x']);
  });

  test('a statement still arriving that needs no closing replaces a finished one of the same name', () {
    final result = _parser().set('t = Text("x")\nroot = Stack([t])\nt = Text("y")');

    expect(_texts(result), ['y']);
  });

  test('at the end of the stream, a redefinition that needed closing replaces the finished one', () {
    final result = _parser().set('t = Text("x")\nroot = Stack([t])\nt = Text("y', complete: true);

    expect(_texts(result), ['y']);
  });

  test(r'a `$name` ending the text is not declared while the stream runs', () {
    final result = _parser().set(r'root = Stack([Text($d');

    expect(result.stateDeclarations, isEmpty);
  });

  test(r'a `$name` ending the text is declared at the end of the stream', () {
    final result = _parser().set(r'root = Stack([Text($d', complete: true);

    expect(result.stateDeclarations, {r'$d': OpenUINull.instance});
  });

  test(r'a `$name` ending the text is declared when the same name appears in full before it', () {
    final result = _parser().set(r'root = Stack([Text($d), Text($d');

    expect(result.stateDeclarations, {r'$d': OpenUINull.instance});
  });

  test(r'a `$name` ending the text is declared when only a longer name contains it before', () {
    final result = _parser().set(r'root = Stack([Text($dishes), Text($d');

    expect(result.stateDeclarations.keys, [r'$dishes']);
  });

  test(r'a `$name` ending a comment is declared, since it is not the end of the program', () {
    final result = _parser().set(r'root = Stack([Text($d)]) # $d');

    expect(result.stateDeclarations, {r'$d': OpenUINull.instance});
  });

  test(r'a name that is not a `$name` ending the text is declared as usual', () {
    final result = _parser().set(r'root = Stack([Text($d)])');

    expect(result.stateDeclarations, {r'$d': OpenUINull.instance});
  });

  test(r'a `$name` ending the text is held back only in the statements still arriving', () {
    final result = _parser().set('t = Text(\$d)\nroot = Stack([t, Text(\$d');

    expect(result.stateDeclarations, {r'$d': OpenUINull.instance});
  });

  for (final (label, text, expected) in [
    ('a name with digits', r'Text($d1', r'$d1'),
    ('a name with an underscore', r'Text($d_x', r'$d_x'),
    ('a name a later full use of it shows is whole', r'Text($dishes), Text($d), Text($d', null),
    ('a name repeated right before itself', r'X($d$d', null),
    ('text that is only a word', 'd', null),
    (r'text with no `$`', 'Text(d', null),
  ]) {
    test('partialStateName of $label', () {
      expect(OpenUIStreamParser.partialStateName(text, text), expected);
    });
  }

  test('set with text that continues the previous text reads only what was added', () {
    final parser = _parser();
    const program = 'root = Stack([t])\nt = Text("a")\n';
    parser.set(program);
    final before = parser.debugPreparedCodeUnits;
    parser.set('${program}u = Text("b")\n');

    // Taking out fences and taking out comments each read it once.
    expect(parser.debugPreparedCodeUnits - before, lessThanOrEqualTo(2 * 'u = Text("b")\n'.length));
  });

  test('set with text that replaces the previous text starts over', () {
    final parser = _parser()..set('root = Stack([Text("a")])\nx = Text("q")\n');
    final result = parser.set('root = Stack([Text("b")])\n');

    expect(result.meta.orphaned, isEmpty);
  });

  test('set with shorter text starts over', () {
    final parser = _parser()..set('root = Stack([Text("a")])\nx = Text("q")\n');
    final result = parser.set('root = Stack([Text("a")])\n');

    expect(result.meta.statementCount, 1);
  });

  test('pushing chunks gives what setting their concatenation gives', () {
    const chunks = ['root = St', 'ack([t, u])\nt = Te', 'xt("a")\nu = Text("', 'b")'];
    final pushed = _parser();
    for (final chunk in chunks) {
      pushed.push(chunk);
    }

    expect(pushed.result(), _parser().set(chunks.join()));
  });

  test('result reads nothing new', () {
    final parser = _parser()..set('root = Stack([Text("a")])\nt = Text("b")');
    final read = (parser.debugPreparedCodeUnits, parser.debugScannedCodeUnits, parser.debugResolvedNodes);
    parser.result();

    expect((parser.debugPreparedCodeUnits, parser.debugScannedCodeUnits, parser.debugResolvedNodes), read);
  });

  test(r'result at the end of the stream declares a `$name` ending the text', () {
    final parser = _parser()..set(r'root = Stack([Text($d');

    expect(parser.result(complete: true).stateDeclarations, {r'$d': OpenUINull.instance});
  });

  test('empty text gives an empty result marked incomplete', () {
    expect(_parser().set(''), ParseResult.empty());
  });

  test('an opening fence alone gives an empty result marked incomplete', () {
    expect(_parser().set('```openui'), ParseResult.empty());
  });

  test('text with no statement in it is not marked incomplete', () {
    expect(_parser().set('roo').meta.incomplete, isFalse);
  });

  test('a fence arriving after prose starts over, keeping only the fenced program', () {
    final parser = _parser()
      ..set('Here you go:\n')
      ..set('Here you go:\n```openui\nroot = Stack([Text("a")])\n');
    final result = parser.set('Here you go:\n```openui\nroot = Stack([Text("a")])\n```\nEnjoy.');

    expect(result, _batch('Here you go:\n```openui\nroot = Stack([Text("a")])\n```\nEnjoy.'));
  });

  test('statements read before the first fence are dropped when it arrives', () {
    const prose = 'a = Text("prose")\nb = Text("more")\nmore prose\n';
    final fenced = '```openui\nroot = Stack([Text("${'x' * 80}")])\nc = Text("c")\n';
    final parser = _parser()..set(prose);

    expect(parser.set('$prose$fenced').meta.orphaned, ['c']);
  });

  test('a statement finished just before a line turned into a comment stays finished', () {
    final parser = _parser()
      ..set('t = Text("x") /')
      ..set('t = Text("x") // note\nroot = Stack([t])\n');

    expect(_texts(parser.set('t = Text("x") // note\nroot = Stack([t])\nt = Text("y')), ['x']);
  });

  test('a statement whose closing bracket follows a line that turned into a comment finishes', () {
    final parser = _parser()
      ..set('\$a = [\n1      /')
      ..set('\$a = [\n1      // note\n]\nroot = Stack([])\n');
    final result = parser.set('\$a = [\n1      // note\n]\nroot = Stack([])\n\$a = "y');

    // The finished `$a` stays: the redefinition still needs closing.
    expect(result.stateDeclarations[r'$a'], OpenUIArray(const [OpenUINumber(1)]));
  });

  test('a comment marker split across chunks reads as in one piece', () {
    final parser = _parser()..set('root = Stack([Text("a")]) /');

    expect(parser.set('root = Stack([Text("a")]) // note\n'), _batch('root = Stack([Text("a")]) // note\n'));
  });

  test('a line after finished statements that turns into a comment reads as in one piece', () {
    const text = 'root = Stack([Text("a")])\n//';
    final parser = _parser()..set('root = Stack([Text("a")])\n/');

    expect(parser.set(text), _batch(text));
  });

  test('a closing fence split across chunks reads as in one piece', () {
    const text = '```openui\nroot = Stack([Text("a")])\n```\nbye';
    final parser = _parser();
    for (final end in [37, 38, 39, text.length]) {
      parser.set(text.substring(0, end));
    }

    expect(parser.result(), _batch(text));
  });

  for (final (label, fence) in [
    ('```Enjoy!', '```Enjoy!'),
    ('four backticks', '````\n'),
    ('a tab-indented', '\t```\n'),
  ]) {
    test('a fence the reply never closes ($label) reads as in one piece', () {
      final text = 'root = Stack([Text("a")])\n$fence';
      final parser = _parser()..set('root = Stack([Text("a")])\n');

      expect(parser.set(text, complete: true), _batch(text));
    });

    test('a fence the reply never closes ($label) leaves nothing to render', () {
      final parser = _parser()..set('root = Stack([Text("a")])\n');

      expect(parser.set('root = Stack([Text("a")])\n$fence', complete: true).root, isNull);
    });
  }

  test('a statement still arriving shorter than longStatement is read again on every call', () {
    final text = _longRoot(OpenUIStreamParser.longStatement ~/ 2);
    final parser = _parser()..set(text);

    expect(_texts(parser.set('$text, Text("b")')), _texts(_batch('$text, Text("b")')));
  });

  test('a long statement still arriving is read again after the statement before it finishes', () {
    final root = _longRoot(OpenUIStreamParser.longStatement);
    final next = ', Text("b")])\nu = Stack([${_longRoot(root.length + 40).substring('root = Stack(['.length)}';
    final parser = _parser()..set(root);

    expect(_texts(parser.set('$root$next')), _texts(_batch('$root$next')));
  });

  test('a long statement still arriving is read again when its end turns into a comment', () {
    final text = _longRoot(OpenUIStreamParser.longStatement);
    final parser = _parser()..set('$text, Text("b") /');
    final commented = '$text, Text("b") // note';

    expect(jsonEncode(parseResultJson(parser.set(commented))), jsonEncode(parseResultJson(_parser().set(commented))));
  });

  test('a long statement still arriving is read again after set starts over', () {
    final first = _longRoot(OpenUIStreamParser.longStatement);
    final replaced = first.replaceFirst('item 0', 'first item 0');
    final parser = _parser()..set(first);

    expect(_texts(parser.set(replaced)).first, 'first item 0');
  });

  test('set with text of the same length that differs starts over', () {
    final parser = _parser()..set('root = Stack([Text("a")])');

    expect(_texts(parser.set('root = Stack([Text("b")])')), ['b']);
  });

  test('a piece that leaves the program unchanged returns the previous result', () {
    final parser = _parser();
    final before = parser.set('root = Stack([Text("a")])');

    expect(parser.set('root = Stack([Text("a")])   '), same(before));
  });

  test(r'a space after a `$name` ending the text declares it', () {
    final parser = _parser()..set(r'root = Stack([Text($d');

    expect(parser.set(r'root = Stack([Text($d ').stateDeclarations, {r'$d': OpenUINull.instance});
  });

  test('a program of many statements is built again only after its text grows by a sixty-fourth', () {
    final text = _manyStatements(OpenUIStreamParser.manyStatements + 1);
    final parser = _parser();
    final before = parser.set(text);

    expect(parser.set('${text}x = Text("${'y' * (text.length ~/ 128)}")'), same(before));
  });

  test('a program of many statements is built again once its text grows by a sixty-fourth', () {
    final text = _manyStatements(OpenUIStreamParser.manyStatements + 1);
    final grown = '${text}x = Text("${'y' * (text.length ~/ 32)}")\nroot = Stack([x])';
    final parser = _parser()..set(text);

    expect(_texts(parser.set(grown)), _texts(_batch(grown)));
  });

  test('a program of many statements whose end turned into a comment is built again', () {
    final text = '${_manyStatements(OpenUIStreamParser.manyStatements + 1)}root = Stack([Text(x)])\nx = 1 /';
    final parser = _parser()..set(text);

    expect(
      jsonEncode(parseResultJson(parser.set('$text/ note'))),
      jsonEncode(parseResultJson(_parser().set('$text/ note'))),
    );
  });

  test('a piece that changes the end of the program but not its length is read', () {
    final parser = _parser()..set('root = Stack([Text("a")]) /');

    expect(_texts(parser.set('root = Stack([Text("a")]) // c\nt')), ['a']);
  });

  test('a program of up to manyStatements statements is built again on every piece', () {
    final text = _manyStatements(OpenUIStreamParser.manyStatements);
    final grown = '${text}root = Stack([Text("b")])';
    final parser = _parser()..set(text);

    expect(_texts(parser.set(grown)), ['b']);
  });

  for (final (label, text) in [
    ('a `:` with no `?` waiting', 'a = : 1\n'),
    (
      'a `?` inside brackets',
      r's = ($n ? 1 : 2)'
          '\n',
    ),
    ('a closing bracket with nothing open', 'a = 1)\n'),
  ]) {
    test('a statement after $label finishes at its line break', () {
      final program = '${text}root = Stack([t])\nt = Text("x")\nz = 1\nt = Text("y';

      expect(_texts(_parser().set(program)), ['x']);
    });
  }

  for (final (label, blank) in [('a tab', '\t'), ('a carriage return', '\r')]) {
    test('a line starting with $label and `?` continues the statement before it', () {
      final program =
          'root = Stack([Text(s)])\n'
          r's = $n > 0'
          '\n$blank? "some"\n  : "none"\nz = 1\n';

      expect(_textNode(_parser().set(program)), isA<AstTernary>());
    });
  }

  test('a long statement still arriving is not read again before it grows by an eighth', () {
    final text = _longRoot(OpenUIStreamParser.longStatement);
    final parser = _parser();
    final first = parser.set(text);
    final grown = '$text${', Text("b")' * ((text.length ~/ 8 - _belowEighth) ~/ ', Text("b")'.length)}';

    expect(parser.set(grown), same(first));
  });

  test('the growth test for long statements grows by more than a sixteenth', () {
    final text = _longRoot(OpenUIStreamParser.longStatement);
    final added = ', Text("b")' * ((text.length ~/ 8 - _belowEighth) ~/ ', Text("b")'.length);

    expect(added.length, greaterThan(text.length ~/ 16));
  });

  test('a long statement still arriving is read again once it grows by an eighth', () {
    final text = _longRoot(OpenUIStreamParser.longStatement);
    final parser = _parser()..set(text);
    final grown = '$text${', Text("b")' * (text.length ~/ 8 ~/ ', Text("b")'.length + 1)}';

    expect(_texts(parser.set(grown)), hasLength(_texts(_batch(grown)).length));
  });

  test('a long statement still arriving is read at once when its line ends', () {
    final text = _longRoot(OpenUIStreamParser.longStatement);
    final parser = _parser()..set(text);
    final ended = '$text, Text("b")])\nx = 1';

    expect(_texts(parser.set(ended)), _texts(_batch(ended)));
  });

  test('the end of the stream reads a long statement still arriving in full', () {
    final text = _longRoot(OpenUIStreamParser.longStatement);
    final parser = _parser()..set(text);

    expect(_texts(parser.set('$text, Text("b")', complete: true)), _texts(_batch('$text, Text("b")')));
  });

  test('text after the end of the stream continues the same program', () {
    final parser = _parser()..set('root = Stack([Text("a")])', complete: true);

    expect(parser.push('\nx = Text("b")\n').meta.orphaned, ['x']);
  });

  test('statementCount at the end of the stream counts each definition of a name defined twice', () {
    const text = 'root = Stack([t])\nt = Text("first")\nt = Text("second")\n';

    expect(_parser().set(text, complete: true).meta.statementCount, 3);
  });

  test('a name defined twice keeps the place of its first definition', () {
    const text =
        r'$a = 1'
        '\n'
        r'$b = 2'
        '\n'
        r'$a = 3'
        '\nroot = Stack([])\n';

    expect(_parser().set(text, complete: true).stateDeclarations.keys, [r'$a', r'$b']);
  });

  test('a name defined twice takes the later definition', () {
    const text =
        r'$a = 1'
        '\n'
        r'$a = 3'
        '\nroot = Stack([])\n';

    expect(_parser().set(text, complete: true).stateDeclarations[r'$a'], const OpenUINumber(3));
  });
}

// How far below an eighth the growth test stays, in code units.
const _belowEighth = 20;

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

OpenUIStreamParser _parser() => OpenUIStreamParser(_schema);

ParseResult _batch(String text) => OpenUILangParser(_schema).parse(text);

// A root statement still arriving, at least `length` code units long.
String _longRoot(int length) {
  final texts = <String>[];
  var size = 'root = Stack(['.length;
  while (size < length) {
    final text = 'Text("item ${texts.length}")';
    texts.add(text);
    size += text.length + 2;
  }
  return 'root = Stack([${texts.join(', ')}';
}

// At least `count` finished statements, each `tN = Text("…")`, then a line
// break and the start of the next.
String _manyStatements(int count) {
  return '${[for (var index = 0; index < count; index += 1) 't$index = Text("item $index")'].join('\n')}\n';
}

// The texts of the Text components the root holds.
List<Object?> _texts(ParseResult result) {
  final children = result.root?.props['children'];
  if (children is! OpenUIArray) return const [];
  return [
    for (final child in children.items)
      if (child case OpenUIElement(:final node)) (node.props['text'] as OpenUIString?)?.value,
  ];
}

// The expression the first Text of the root shows.
AstNode? _textNode(ParseResult result) {
  final children = result.root?.props['children'];
  if (children is! OpenUIArray) return null;
  final first = children.items.firstOrNull;
  if (first is! OpenUIElement) return null;
  return switch (first.node.props['text']) {
    OpenUIExpression(:final node) => node,
    _ => null,
  };
}
