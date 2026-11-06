import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

void main() {
  test('positional arguments become props in the order the schema declares', () {
    expect(_parse('root = Card("T", "S")').root!.props, {
      'title': const OpenUIString('T'),
      'subtitle': const OpenUIString('S'),
    });
  });

  test('extra arguments are reported', () {
    expect(_parse('root = Card("T", "S", "X")').meta.errors.single.code, OpenUIErrorCode.excessArgs);
  });

  test('extra arguments are dropped and the component kept', () {
    expect(_parse('root = Card("T", "S", "X")').root!.props.keys, ['title', 'subtitle']);
  });

  test('a missing required argument drops the component', () {
    expect(_parse('root = Stack([Card()])').root!.props['children'], OpenUIArray(const []));
  });

  test('a missing required argument is reported with the signature', () {
    expect(
      _parse('root = Card()').meta.errors.single.message,
      'missing required field "/title" — signature: Card(title*: string, subtitle: string)',
    );
  });

  test('a null required argument is reported as null-required', () {
    expect(_parse('root = Card(null)').meta.errors.single.code, OpenUIErrorCode.nullRequired);
  });

  test('a default fills a missing required argument', () {
    expect(_parse('root = Badge()').root!.props['tone'], const OpenUIString('neutral'));
  });

  test('an unknown component is dropped', () {
    expect(_parse('root = Stack([Chart(1)])').root!.props['children'], OpenUIArray(const []));
  });

  test('an unknown component is reported with the components available', () {
    expect(
      _parse('root = Stack([Chart(1)])').meta.errors.single.message,
      'Unknown component "Chart" — not found in catalog or builtins. Available components: Stack, Card, Badge',
    );
  });

  test('an unknown @function reads as null', () {
    expect(_parse('root = Card("T", @Nope(1))').root!.props['subtitle'], OpenUINull.instance);
  });

  test('an unknown @function is reported', () {
    expect(_parse('root = Card("T", @Nope(1))').meta.errors.single.code, OpenUIErrorCode.unknownFunction);
  });

  test('a Query written inside a value is reported as inline-reserved', () {
    expect(_parse('root = Stack([Query("t", {}, {})])').meta.errors.single.code, OpenUIErrorCode.inlineReserved);
  });

  test('a prop holding an expression makes the element dynamic', () {
    expect(_parse(r'root = Card($title)').root!.hasDynamicProps, isTrue);
  });

  test('literal props leave the element static', () {
    expect(_parse('root = Card("T")').root!.hasDynamicProps, isFalse);
  });

  test('an object with a steps list makes the element dynamic', () {
    expect(_parse('root = Stack([{steps: []}])').root!.hasDynamicProps, isTrue);
  });

  test('an element of a cut-off program is partial', () {
    expect(_parse('root = Stack([Card("T")').root!.partial, isTrue);
  });

  test('an element of a whole program is not partial', () {
    expect(_parse('root = Stack([Card("T")])').root!.partial, isFalse);
  });

  test('a library function with a literal argument of the wrong type reads as null', () {
    expect(_parse('root = Card(@Upper(3))').root!.props['title'], const OpenUIExpression(AstNull.instance));
  });

  test('a library function with a literal argument of the wrong type is reported', () {
    expect(_parse('root = Card(@Upper(3))').meta.errors.single.code, OpenUIErrorCode.typeMismatch);
  });

  test('an invalid library action does nothing', () {
    final action = _parse('root = Card("T", @Copy())').root!.props['subtitle']! as OpenUIExpression;

    expect(action.node, AstCall('Action', [AstArray(const [])]));
  });

  test('a library action with an argument of the wrong type does nothing', () {
    final action = _parse('root = Card("T", @Copy(3))').root!.props['subtitle']! as OpenUIExpression;

    expect(action.node, AstCall('Action', [AstArray(const [])]));
  });

  test('a library action with an optional argument of the wrong type does nothing', () {
    final action = _parse('root = Card("T", @Share("a", 3))').root!.props['subtitle']! as OpenUIExpression;

    expect(action.node, AstCall('Action', [AstArray(const [])]));
  });

  test('a library function with an optional argument of the wrong type drops that argument', () {
    final call = (_parse('root = Card(@Join("a", 3))').root!.props['title']! as OpenUIExpression).node as AstCall;

    expect(call.mappedProps, {'text': const AstString('a')});
  });

  test('a library action with an extra argument still runs, the extra argument dropped', () {
    final action = _parse('root = Card("T", @Copy("a", "b"))').root!.props['subtitle']! as OpenUIExpression;

    expect((action.node as AstCall).mappedProps, {'text': const AstString('a')});
  });

  test("a built-in's arguments are named but not checked", () {
    final call =
        (_parse('root = Card(@Count("not an array"))').root!.props['title']! as OpenUIExpression).node as AstCall;

    expect(call.mappedProps, {'array': const AstString('not an array')});
  });

  test("a named argument is the argument's own node", () {
    final call =
        (_parse('root = Card(@Count(items))\nitems = [1]').root!.props['title']! as OpenUIExpression).node as AstCall;

    expect(call.mappedProps!['array'], same(call.args.single));
  });

  test("@Each's loop variable stays a reference in its template", () {
    final call =
        (_parse('root = Card(@Each(rows, "row", row.name))').root!.props['title']! as OpenUIExpression).node as AstCall;

    expect(call.args.last, const AstMember(AstRef('row'), 'name'));
  });

  test("@Each's loop variable is not reported unresolved", () {
    expect(_parse('root = Card(@Each([1], "row", row))').meta.unresolved, isEmpty);
  });

  test('an error is attributed to the statement it was found in', () {
    expect(_parse('root = Stack([c])\nc = Card()').meta.errors.single.statementId, 'c');
  });

  test("an element's statement is the one that defines it", () {
    final child = (_parse('root = Stack([c])\nc = Card("T")').root!.props['children']! as OpenUIArray).items.single;

    expect((child as OpenUIElement).node.statementId, 'c');
  });

  test('a component written inline has no statement', () {
    final child = (_parse('root = Stack([Card("T")])').root!.props['children']! as OpenUIArray).items.single;

    expect((child as OpenUIElement).node.statementId, isNull);
  });

  test("a library function's missing required argument with a default is not reported", () {
    expect(_parse('root = Card(@Pad())').meta.errors, isEmpty);
  });

  test("a library function's missing required argument is not filled with its default", () {
    final title = _parse('root = Card(@Pad())').root!.props['title']! as OpenUIExpression;

    expect((title.node as AstCall).mappedProps, isEmpty);
  });

  test('a library call inside query arguments is checked under the query statement', () {
    final error = _parse('q = Query("t", {a: @Upper(3)}, {})\nroot = Card("T")').meta.errors.single;

    expect((error.code, error.statementId), (OpenUIErrorCode.typeMismatch, 'q'));
  });

  test("a library call's own errors come before those of the calls inside it in query arguments", () {
    final errors = _parse('q = Query("t", {a: @Upper(@Upper(5), "x")})\nroot = Card("T")').meta.errors;

    expect(errors.map((error) => error.code), [OpenUIErrorCode.excessArgs, OpenUIErrorCode.typeMismatch]);
  });

  test("a library call's own errors come before those of the calls inside it in mutation arguments", () {
    final errors = _parse('m = Mutation("t", {a: @Upper(@Upper(5), 7)})\nroot = Card("T")').meta.errors;

    expect(errors.map((error) => error.code), [OpenUIErrorCode.excessArgs, OpenUIErrorCode.typeMismatch]);
  });

  test('a library call inside a built-in call in query arguments is reported once', () {
    expect(_parse('q = Query("t", @Count(@Upper(3)))\nroot = Card("T")').meta.errors, hasLength(1));
  });

  test('a reference to a null statement in an array leaves no hole', () {
    final children = _parse('root = Stack([a, Card("T")])\na = null').root!.props['children']! as OpenUIArray;

    expect(children.items, hasLength(1));
  });

  test('the last of two equal keys in an object wins', () {
    final children = _parse('root = Stack([{a: 1, a: 2}])').root!.props['children']! as OpenUIArray;

    expect(children.items.single, OpenUIObject(const {'a': OpenUINumber(2)}));
  });

  test('calls inside query arguments get their arguments named', () {
    final args = _parse('q = Query("t", {n: @Count(rows)}, {})\nroot = Card("T")').queryStatements.single.args!;
    final call = (args as AstObject).entries.single.$2 as AstCall;

    expect(call.mappedProps, {'array': const AstRef('rows')});
  });
}

final _schema = OpenUILibrarySchema.fromJsonSchema(const {
  r'$defs': {
    'Stack': {
      'properties': {
        'children': {'type': 'array'},
      },
      'required': ['children'],
    },
    'Card': {
      'properties': {
        'title': {'type': 'string'},
        'subtitle': {'type': 'string'},
      },
      'required': ['title'],
    },
    'Badge': {
      'properties': {
        'tone': {'type': 'string', 'default': 'neutral'},
      },
      'required': ['tone'],
    },
  },
  'functions': {
    'Join': {
      'params': {
        'properties': {
          'text': {'type': 'string'},
          'separator': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
    'Pad': {
      'params': {
        'properties': {
          'text': {'type': 'string', 'default': 'p'},
        },
        'required': ['text'],
      },
    },
    'Upper': {
      'params': {
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  },
  'actions': {
    'Share': {
      'params': {
        'properties': {
          'text': {'type': 'string'},
          'channel': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
    'Copy': {
      'params': {
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
    },
  },
}, root: 'Stack');

ParseResult _parse(String text) => OpenUILangParser(_schema).parse(text);
