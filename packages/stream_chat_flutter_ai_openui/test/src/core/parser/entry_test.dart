import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

void main() {
  test('the statement named root is the entry', () {
    expect(_parse('page = Stack([])\nroot = Text("hi")').root!.typeName, 'Text');
  });

  test('without root, the first statement calling the root component renders', () {
    expect(_parse('title = Text("a")\npage = Stack([title])').root!.statementId, 'page');
  });

  test('a fallback entry is reported as a no-root warning', () {
    final error = _parse('page = Stack([])').meta.errors.single;

    expect((error.code, error.isWarning), (OpenUIErrorCode.noRoot, true));
  });

  test('a fallback entry names the root component', () {
    expect(
      _parse('page = Stack([])').meta.errors.single.message,
      'No root statement. Rendering the first statement that calls the root component Stack',
    );
  });

  test('a fallback entry that fails its checks is reported as an error, not a warning', () {
    final noRoot = _parse('page = Stack()').meta.errors.last;

    expect((noRoot.code, noRoot.isWarning), (OpenUIErrorCode.noRoot, false));
  });

  test('a root that is not a component is reported', () {
    expect(_parse('root = "hello"').meta.errors.single.message, 'root does not evaluate to a component');
  });

  test('a root whose component failed its checks reports only that failure', () {
    expect(_parse('root = Text(null)').meta.errors.map((error) => error.code), [OpenUIErrorCode.nullRequired]);
  });

  test('without an entry, no-root names the root component', () {
    expect(
      _parse('title = Text("a")').meta.errors.single.message,
      'No root statement, and no statement calls the root component Stack',
    );
  });

  test('without an entry or a root component, no-root says only that there is no root', () {
    expect(_parse('title = Text("a")', root: null).meta.errors.single.message, 'No root statement');
  });

  test('without an entry, nothing is orphaned', () {
    expect(_parse('title = Text("a")').meta.orphaned, isEmpty);
  });

  test(r'a root that picks its component when evaluated, such as $dark ? a : b, is kept as an expression', () {
    expect(_parse('\$dark = false\nroot = \$dark ? a : b\na = Text("a")\nb = Text("b")').rootExpression, isNotNull);
  });

  test('a root picked when evaluated reports no no-root', () {
    expect(_parse('\$dark = false\nroot = \$dark ? a : b\na = Text("a")\nb = Text("b")').meta.errors, isEmpty);
  });

  test('a state declaration is never the entry', () {
    expect(_parse('\$tab = Stack([])\npage = Stack([Text("A")])').root!.statementId, 'page');
  });

  test('the no-root error is attributed to the entry', () {
    expect(_parse('page = Stack([])').meta.errors.single.statementId, 'page');
  });
}

final _defs = {
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
};

ParseResult _parse(String text, {String? root = 'Stack'}) {
  return OpenUILangParser(OpenUILibrarySchema.fromJsonSchema(_defs, root: root)).parse(text);
}
