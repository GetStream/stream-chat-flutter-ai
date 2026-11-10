import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

void main() {
  test('a reference to a statement defined later resolves', () {
    expect(_children('root = Stack([title])\ntitle = Text("a")'), hasLength(1));
  });

  test('a reference to nothing is unresolved', () {
    expect(_parse('root = Stack([tbl])').meta.unresolved, ['tbl']);
  });

  test('a reference to nothing is listed once per use', () {
    expect(_parse('root = Stack([tbl, tbl])').meta.unresolved, ['tbl', 'tbl']);
  });

  test('a reference to nothing is left out of an array', () {
    expect(_children('root = Stack([tbl, Text("a")])'), hasLength(1));
  });

  test('a reference to nothing reads as null in a prop', () {
    expect(_parse('root = Card(missing)').root!.props['title'], OpenUINull.instance);
  });

  test('a null written in an array stays', () {
    expect(_children('root = Stack([null])'), [OpenUINull.instance]);
  });

  test('a reference back to a statement being resolved is unresolved', () {
    expect(_parse('root = Stack([a])\na = Stack([b])\nb = Stack([a])').meta.unresolved, ['a']);
  });

  test('value statements the entry never reaches are orphaned, in program order', () {
    expect(_parse('root = Stack([])\nz = Text("z")\na = Text("a")').meta.orphaned, ['z', 'a']);
  });

  test('a statement reached through another is not orphaned', () {
    expect(_parse('root = Stack([a])\na = Stack([b])\nb = Text("b")').meta.orphaned, isEmpty);
  });

  test(r'$variables, queries and mutations are never orphaned', () {
    final result = _parse('root = Stack([])\n\$x = 1\nq = Query("t", {}, {})\nm = Mutation("t", {})');

    expect(result.meta.orphaned, isEmpty);
  });

  test('when a name is defined twice, the later definition wins', () {
    expect(
      (_children('root = Stack([t])\nt = Text("one")\nt = Text("two")').single as OpenUIElement).node.props['text'],
      const OpenUIString('two'),
    );
  });

  test('a name defined again keeps the place of its first definition', () {
    expect(_parse('root = Stack([])\na = Text("1")\nb = Text("2")\na = Text("3")').meta.orphaned, ['a', 'b']);
  });

  test('a name defined twice counts as one statement', () {
    expect(_parse('root = Stack([t])\nt = Text("one")\nt = Text("two")').meta.statementCount, 2);
  });

  test(r'a $variable used without a declaration defaults to null', () {
    expect(_parse(r'root = Text($name)').stateDeclarations, {r'$name': OpenUINull.instance});
  });

  test(r'a $variable declaration gives its default', () {
    expect(_parse('\$count = 3\nroot = Text("a")').stateDeclarations, {r'$count': const OpenUINumber(3)});
  });

  test(r'$variables are listed in the order first declared or used', () {
    final result = _parse('root = Text(\$b)\n\$a = 1\nx = \$c');

    expect(result.stateDeclarations.keys, [r'$a', r'$b', r'$c']);
  });

  test(r'$x = Query(…) is a query, not a state declaration', () {
    final result = _parse('\$x = Query("tool", {}, {})\nroot = Text("a")');

    expect(result.queryStatements.single.statementId, r'$x');
  });

  test(r"a query's deps are the $variables its arguments read", () {
    final result = _parse('q = Query("tool", {a: \$a, b: \$b, c: \$a}, {})\nroot = Text("a")');

    expect(result.queryStatements.single.deps, [r'$a', r'$b']);
  });

  test(r'a query whose arguments read no $variables has no deps', () {
    expect(_parse('q = Query("tool", {}, {})\nroot = Text("a")').queryStatements.single.deps, isNull);
  });

  test('a reference to a query is resolved when the program runs', () {
    final props = _parse('q = Query("tool", {}, {})\nroot = Card(q)').root!.props;

    expect(props['title'], const OpenUIExpression(AstRuntimeRef('q', RuntimeRefType.query)));
  });

  test('a reference to a mutation is resolved when the program runs', () {
    final props = _parse('m = Mutation("tool", {})\nroot = Card(m)').root!.props;

    expect(props['title'], const OpenUIExpression(AstRuntimeRef('m', RuntimeRefType.mutation)));
  });

  test("a mutation's tool is kept", () {
    final mutation = _parse('m = Mutation("save", {id: 1})\nroot = Text("a")').mutationStatements.single;

    expect(mutation.tool, const AstString('save'));
  });

  test("a mutation's arguments are kept", () {
    final mutation = _parse('m = Mutation("save", {id: 1})\nroot = Text("a")').mutationStatements.single;

    expect(mutation.args, AstObject(const [('id', AstNumber(1))]));
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
    'Text': {
      'properties': {
        'text': {'type': 'string'},
      },
      'required': ['text'],
    },
    'Card': {
      'properties': {'title': <String, Object?>{}},
    },
  },
});

ParseResult _parse(String text) => OpenUILangParser(_schema).parse(text);

List<OpenUIValue> _children(String text) => (_parse(text).root!.props['children']! as OpenUIArray).items;
