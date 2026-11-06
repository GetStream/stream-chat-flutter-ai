import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parser_errors.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

void main() {
  test('an unknown component is hinted with the components available', () {
    expect(_errors('root = Nope()').single.hint, 'Available components: Card, Text');
  });

  test('an unknown component of a library without components has no hint', () {
    final empty = OpenUILibrarySchema.fromJsonSchema(const {});

    expect(parserErrors(OpenUILangParser(empty).parse('root = Nope()'), empty).first.hint, isNull);
  });

  test("a missing required argument is hinted with the component's signature", () {
    expect(_errors('root = Card()').single.hint, 'Signature: Card(title*, body) — * marks required');
  });

  test("a null required argument is hinted with the component's signature", () {
    expect(_errors('root = Card(null)').single.hint, 'Signature: Card(title*, body) — * marks required');
  });

  test(r"a missing argument of a library action is hinted with its $defs entry's signature", () {
    expect(_errors('root = Card("T", @Copy())').single.hint, 'Signature: Copy(type*, params*) — * marks required');
  });

  test('a missing argument of a library function has no signature hint', () {
    expect(_errors('root = Card("T", @Upper())').single.hint, isNull);
  });

  test('an inline Query is hinted with how to write it as a statement', () {
    expect(
      _errors('root = Card(Query("t", {}, {}))').first.hint,
      'Declare as a top-level statement: myVar = Query(...)',
    );
  });

  test('an inline Mutation is hinted with how to write it as a statement', () {
    expect(
      _errors('root = Card(Mutation("t", {}))').first.hint,
      'Declare as a top-level statement: myVar = Mutation(...)',
    );
  });

  test('other errors have no hint', () {
    expect(_errors('root = Card("T", "B", "X")').single.hint, isNull);
  });

  test('errors come from the parser', () {
    expect(_errors('root = Card()').single.source, OpenUIErrorSource.parser);
  });

  test('an error keeps its code, statement and component', () {
    final error = _errors('root = Card()').single;

    expect((error.code, error.statementId, error.component), (OpenUIErrorCode.missingRequired, 'root', 'Card'));
  });

  test('an error at a prop keeps its path', () {
    expect(_errors('root = Card()').single.path, '/title');
  });

  test('an error with an empty path has no path', () {
    expect(_errors('root = Nope()').single.path, isNull);
  });

  test('an error keeps its message', () {
    expect(
      _errors('root = Card()').single.message,
      'missing required field "/title" — signature: Card(title*: string, body)',
    );
  });

  test('an error is not a warning', () {
    expect(_errors('root = Card()').single.isWarning, isFalse);
  });

  test('a warning stays a warning', () {
    expect(_errors('page = Card("T")', root: 'Card').single.isWarning, isTrue);
  });
}

final _defs = {
  r'$defs': {
    'Card': {
      'properties': {
        'title': {'type': 'string'},
        'body': <String, Object?>{},
      },
      'required': ['title'],
    },
    'Text': {
      'properties': {'text': <String, Object?>{}},
    },
    // The data shape of the `Copy` action, which isn't a component.
    'Copy': {
      'properties': {'type': <String, Object?>{}, 'params': <String, Object?>{}},
      'required': ['type', 'params'],
    },
  },
  'actions': {
    'Copy': {
      'params': {
        'properties': {'text': <String, Object?>{}},
        'required': ['text'],
      },
    },
  },
  'functions': {
    'Upper': {
      'params': {
        'properties': {'text': <String, Object?>{}},
        'required': ['text'],
      },
    },
  },
};

List<OpenUIError> _errors(String text, {String? root}) {
  final schema = OpenUILibrarySchema.fromJsonSchema(_defs, root: root);
  return parserErrors(OpenUILangParser(schema).parse(text), schema);
}
