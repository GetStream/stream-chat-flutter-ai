import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/expression_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';

void main() {
  test('* binds tighter than +', () {
    expect(_parse('1 + 2 * 3'), AstBinary('+', _n(1), AstBinary('*', _n(2), _n(3))));
  });

  test('+ binds tighter than a comparison', () {
    expect(_parse('1 + 2 > 3'), AstBinary('>', AstBinary('+', _n(1), _n(2)), _n(3)));
  });

  test('a comparison binds tighter than ==', () {
    expect(_parse('1 > 2 == true'), AstBinary('==', AstBinary('>', _n(1), _n(2)), const AstBool(true)));
  });

  test('== binds tighter than &&', () {
    expect(_parse('a == b && c'), AstBinary('&&', AstBinary('==', _r('a'), _r('b')), _r('c')));
  });

  test('&& binds tighter than ||', () {
    expect(_parse('a || b && c'), AstBinary('||', _r('a'), AstBinary('&&', _r('b'), _r('c'))));
  });

  test('|| binds tighter than ?:', () {
    expect(_parse('a || b ? c : d'), AstTernary(AstBinary('||', _r('a'), _r('b')), _r('c'), _r('d')));
  });

  test('a prefix operator binds tighter than *', () {
    expect(_parse('-a * b'), AstBinary('*', AstUnary('-', _r('a')), _r('b')));
  });

  test('a member read binds tighter than a prefix operator', () {
    expect(_parse('!a.b'), AstUnary('!', AstMember(_r('a'), 'b')));
  });

  test('?: groups to the right', () {
    expect(_parse('a ? b : c ? d : e'), AstTernary(_r('a'), _r('b'), AstTernary(_r('c'), _r('d'), _r('e'))));
  });

  test('subtraction groups to the left', () {
    expect(_parse('10 - 2 - 3'), AstBinary('-', AstBinary('-', _n(10), _n(2)), _n(3)));
  });

  test('a digit field reads as its digits', () {
    expect(_parse('a.0'), AstMember(_r('a'), '0'));
  });

  test(r'a $name field reads without its $', () {
    expect(_parse(r'a.$x'), AstMember(_r('a'), 'x'));
  });

  test('indexes chain', () {
    expect(_parse('m[1][0]'), AstIndex(AstIndex(_r('m'), _n(1)), _n(0)));
  });

  test(r'object keys are names, strings, numbers, types and $names', () {
    final object = _parse(r'{name: 1, "quoted key": 2, 2: 3, Card: 4, $s: 5}') as AstObject;

    expect(object.entries.map((entry) => entry.$1), ['name', 'quoted key', '2', 'Card', 's']);
  });

  test('a built-in name without its @ is a reference', () {
    expect(_parse('Count(x)'), _r('Count'));
  });

  test('Action is a call without its @', () {
    expect(_parse('Action([])'), AstCall('Action', [AstArray(const [])]));
  });

  test('an @call of a name that is not a built-in is a function call', () {
    expect((_parse('@Upper("a")') as AstCall).isFunction, isTrue);
  });

  test('an @call of a built-in is not a function call', () {
    expect((_parse('@Count(x)') as AstCall).isFunction, isFalse);
  });

  test(r'$name = value is an assignment', () {
    expect(_parse(r'$x = 1'), AstAssign(r'$x', _n(1)));
  });

  test('a token that starts nothing reads as null', () {
    expect(_parse(')'), AstNull.instance);
  });

  test('tokens after a complete expression are ignored', () {
    expect(_parse('Card() Text()'), AstCall('Card', const []));
  });

  test('commas between arguments are optional and a trailing one is ignored', () {
    expect(_parse('Card(1 2,)'), AstCall('Card', [_n(1), _n(2)]));
  });

  test('parentheses group', () {
    expect(_parse('(1 + 2) * 3'), AstBinary('*', AstBinary('+', _n(1), _n(2)), _n(3)));
  });
}

AstNode _parse(String source) => ExpressionParser.parse(Lexer.tokenize(source));

AstNumber _n(double value) => AstNumber(value);

AstRef _r(String name) => AstRef(name);
