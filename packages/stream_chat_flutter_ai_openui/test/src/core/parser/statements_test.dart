import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/statements.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';

void main() {
  test('an open string is closed with its own quote', () {
    expect(Statements.autoClose("a = 'one").$1, "a = 'one'");
  });

  test('a string cut in the middle of an escape is closed after a backslash', () {
    expect(Statements.autoClose(r'a = "x\').$1, r'a = "x\\"');
  });

  test('open brackets are closed innermost first', () {
    expect(Statements.autoClose('a = Card([{x: (1').$1, 'a = Card([{x: (1)}])');
  });

  test('a closing bracket that does not match the innermost open one is ignored', () {
    expect(Statements.autoClose('a = [1)').$1, 'a = [1)]');
  });

  test('brackets inside a string are not counted', () {
    expect(Statements.autoClose('a = "(["').wasIncomplete, isFalse);
  });

  test('text with nothing open is not incomplete', () {
    expect(Statements.autoClose('a = [1]').wasIncomplete, isFalse);
  });

  test('text with something open is incomplete', () {
    expect(Statements.autoClose('a = [1').wasIncomplete, isTrue);
  });

  test('a line that does not start with a name is skipped', () {
    expect(_ids('1 = 2\nb = 3'), ['b']);
  });

  test('a name without = after it is skipped', () {
    expect(_ids('a 1\nb = 3'), ['b']);
  });

  test('a line break inside brackets continues the statement', () {
    expect(_ids('a = [1,\n2]\nb = 3'), ['a', 'b']);
  });

  test('a next line starting with ? continues the statement', () {
    expect(_ids('a = x\n  ? 1\n  : 2\nb = 3'), ['a', 'b']);
  });

  test('a next line starting with : continues an open ternary', () {
    expect(_ids('a = x ? 1\n  : 2\nb = 3'), ['a', 'b']);
  });

  test('a next line starting with : does not continue a statement without an open ternary', () {
    expect(_ids('a = 1\n: 2\nb = 3'), ['a', 'b']);
  });

  test('blank lines between the parts of a ternary are allowed', () {
    expect(_ids('a = x\n\n  ? 1\n\n  : 2\nb = 3'), ['a', 'b']);
  });

  test('a long run of blank lines before ? is read in linear time', () {
    final text = 'a = x${'\n' * 200000}? 1 : 2\nb = 3';
    final stopwatch = Stopwatch()..start();
    Statements.split(Lexer.tokenize(text));

    // Linear, this takes milliseconds; quadratic, about half a minute.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test(r'$name and Name start statements', () {
    expect(_ids('\$x = 1\nCard = 2'), [r'$x', 'Card']);
  });

  test('a statement with nothing after = is dropped', () {
    expect(_ids('a =\nb = 3'), ['b']);
  });

  test("a statement's tokens leave out line breaks", () {
    final statement = Statements.split(Lexer.tokenize('a = [1,\n2]')).single;

    expect(statement.tokens.where((token) => token.kind == TokenKind.newline), isEmpty);
  });
}

List<String> _ids(String source) => [for (final statement in Statements.split(Lexer.tokenize(source))) statement.id];
