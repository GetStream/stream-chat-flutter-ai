import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/preprocessor.dart';

void main() {
  test('text without fences is kept whole', () {
    expect(Preprocessor.prepare('a = 1\nb = 2'), 'a = 1\nb = 2');
  });

  test('fenced blocks are joined with a line break and the prose around them dropped', () {
    const text = 'Intro\n```openui-lang\na = 1\n```\nmiddle\n```\nb = 2\n```\nend';

    expect(Preprocessor.prepare(text), 'a = 1\n\nb = 2');
  });

  test('a fence inside a double-quoted string neither opens nor closes a block', () {
    const text = '```\na = "use ``` here"\n```';

    expect(Preprocessor.prepare(text), 'a = "use ``` here"');
  });

  test('a fence inside a double-quoted string before any block does not open one', () {
    const text = 'Use "```" to fence.\n```\na = 1\n```';

    expect(Preprocessor.prepare(text), 'a = 1');
  });

  test('a block whose closing fence has not arrived runs to the end', () {
    expect(Preprocessor.prepare('Plan:\n```openui-lang\na = 1\nb = 2'), 'a = 1\nb = 2');
  });

  test('an opening fence with nothing after its line yields nothing', () {
    expect(Preprocessor.prepare('Plan:\n```openui-lang'), '');
  });

  test('a reply that is only an opening fence yields nothing', () {
    expect(Preprocessor.prepare('```'), '');
  });

  test('a // comment is removed with the space before it', () {
    expect(Preprocessor.stripComments('a = 1   // one'), 'a = 1');
  });

  test('a # comment is removed', () {
    expect(Preprocessor.stripComments('# a note\nb = 2'), '\nb = 2');
  });

  test('comment markers inside double-quoted strings are kept', () {
    expect(Preprocessor.stripComments('a = "x // y # z"'), 'a = "x // y # z"');
  });

  test('comment markers inside single-quoted strings are kept', () {
    expect(Preprocessor.stripComments("a = 'x // y # z'"), "a = 'x // y # z'");
  });

  test('a string open at the end of a line keeps protecting the next line', () {
    expect(Preprocessor.stripComments('a = "one\n// still the string"'), 'a = "one\n// still the string"');
  });

  test('an escaped quote does not close a string', () {
    expect(Preprocessor.stripComments(r'a = "say \" // kept"'), r'a = "say \" // kept"');
  });

  test('lines split on line feeds only, so a carriage return stays with its line', () {
    expect(Preprocessor.stripComments('a = 1 // x\r\nb = 2'), 'a = 1\nb = 2');
  });

  test('the prepared text is trimmed', () {
    expect(Preprocessor.prepare('  \n a = 1 \n\t'), 'a = 1');
  });

  test('a fence with no line break after it yields nothing, even when it closes', () {
    expect(Preprocessor.stripFences('```a = 1```'), '');
  });
}
