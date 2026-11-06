import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';

void main() {
  test('empty text has nothing to render', () {
    expect(_parse('').root, isNull);
  });

  test('empty text is incomplete', () {
    expect(_parse('').meta.incomplete, isTrue);
  });

  test('text of white space and comments only is incomplete', () {
    expect(_parse(' \n// nothing\n# here\n').meta.incomplete, isTrue);
  });

  test('a reply that is only an opening code fence is incomplete', () {
    expect(_parse('Here:\n```\n').meta.incomplete, isTrue);
  });

  test('an empty code block is incomplete', () {
    expect(_parse('```\n```').meta.incomplete, isTrue);
  });

  test('text without any statement is not incomplete', () {
    expect(_parse('just prose').meta.incomplete, isFalse);
  });

  test('text without any statement reports nothing', () {
    expect(_parse('just prose').meta.errors, isEmpty);
  });

  test('text without any statement, cut inside a string, is incomplete', () {
    expect(_parse('just "prose').meta.incomplete, isTrue);
  });

  test('a whole program is not incomplete', () {
    expect(_parse('root = Title("a")').meta.incomplete, isFalse);
  });

  test('a program cut inside a string is incomplete', () {
    expect(_parse('root = Title("a').meta.incomplete, isTrue);
  });

  test('two parses of the same text are equal', () {
    expect(_parse('root = Title("a")'), _parse('root = Title("a")'));
  });

  test("a parse result's lists can't be changed", () {
    expect(() => _parse('root = Title("a")').meta.errors.clear(), throwsUnsupportedError);
  });
}

final _schema = OpenUILibrarySchema.fromJsonSchema(const {
  r'$defs': {
    'Title': {
      'properties': {
        'text': {'type': 'string'},
      },
      'required': ['text'],
    },
  },
});

ParseResult _parse(String text) => OpenUILangParser(_schema).parse(text);
