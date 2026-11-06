/// Parsing one statement's expression.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/token.dart';

/// The parser of one statement's expression, from its tokens to an
/// [AstNode].
///
/// Operators bind, loosest first: `?:`, `||`, `&&`, `==` and `!=`, the
/// comparisons, `+` and `-`, `*` `/` and `%`, the prefix `!` and `-`, and
/// member and index reads. Binary operators group to the left, and `?:` to
/// the right.
final class ExpressionParser {
  ExpressionParser._(this._tokens);

  /// How deep an expression nests, and how tall an operator chain builds it,
  /// before it reads as `null`.
  ///
  /// Parsing recurses once per level of nesting, and walking or comparing the
  /// tree takes a call per level of its height, which a chain like
  /// `1 + 1 + 1` raises without nesting. A statement past either, which no
  /// real program is, reads as `null` instead of running out of stack.
  static const maxDepth = 256;

  // Binding powers, loosest first.
  static const _ternary = 1;
  static const _or = 2;
  static const _and = 3;
  static const _equality = 4;
  static const _comparison = 5;
  static const _additive = 6;
  static const _multiplicative = 7;
  static const _unary = 8;
  static const _member = 9;

  final List<Token> _tokens;
  var _position = 0;
  var _depth = 0;

  /// The expression `tokens` hold.
  ///
  /// Parsing never fails: a token that starts nothing reads as `null`, and
  /// tokens after a complete expression are ignored. An expression nested
  /// past [maxDepth] reads as `null` at that depth, and an operator chain
  /// taller than it reads as `null` as a whole; either way, the rest of the
  /// statement is dropped.
  static AstNode parse(List<Token> tokens) => ExpressionParser._(tokens)._parseExpression(0).node;

  Token get _current => _position < _tokens.length ? _tokens[_position] : Token.eof;

  TokenKind? _peekKind(int offset) {
    final index = _position + offset;
    return index < _tokens.length ? _tokens[index].kind : null;
  }

  Token _advance() {
    final token = _current;
    _position += 1;
    return token;
  }

  void _eat(TokenKind kind) {
    if (_current.kind == kind) _position += 1;
  }

  static int _infixPrecedence(TokenKind kind) {
    return switch (kind) {
      TokenKind.question => _ternary,
      TokenKind.or => _or,
      TokenKind.and => _and,
      TokenKind.equalEqual || TokenKind.notEqual => _equality,
      TokenKind.greater || TokenKind.less || TokenKind.greaterEqual || TokenKind.lessEqual => _comparison,
      TokenKind.plus || TokenKind.minus => _additive,
      TokenKind.star || TokenKind.slash || TokenKind.percent => _multiplicative,
      TokenKind.dot || TokenKind.leftBracket => _member,
      _ => 0,
    };
  }

  static const _binaryOperators = <TokenKind, (String, int)>{
    TokenKind.plus: ('+', _additive),
    TokenKind.minus: ('-', _additive),
    TokenKind.star: ('*', _multiplicative),
    TokenKind.slash: ('/', _multiplicative),
    TokenKind.percent: ('%', _multiplicative),
    TokenKind.equalEqual: ('==', _equality),
    TokenKind.notEqual: ('!=', _equality),
    TokenKind.greater: ('>', _comparison),
    TokenKind.less: ('<', _comparison),
    TokenKind.greaterEqual: ('>=', _comparison),
    TokenKind.lessEqual: ('<=', _comparison),
    TokenKind.and: ('&&', _and),
    TokenKind.or: ('||', _or),
  };

  _Parsed _parseExpression(int minPrecedence) {
    _depth += 1;
    try {
      if (_depth > maxDepth) return _giveUp();
      var left = _parsePrefix();
      while (_infixPrecedence(_current.kind) > minPrecedence) {
        left = _parseInfix(left);
        if (left.height > maxDepth) return _giveUp();
      }
      return left;
    } finally {
      _depth -= 1;
    }
  }

  // Drops the rest of the statement, which reads as null from here.
  _Parsed _giveUp() {
    _position = _tokens.length;
    return _Parsed(AstNull.instance);
  }

  _Parsed _parsePrefix() {
    final token = _current;
    switch (token.kind) {
      case TokenKind.string:
        _advance();
        return _Parsed(AstString(token.text!));
      case TokenKind.number:
        _advance();
        return _Parsed(AstNumber(token.number!));
      case TokenKind.trueKeyword:
        _advance();
        return _Parsed(const AstBool(true));
      case TokenKind.falseKeyword:
        _advance();
        return _Parsed(const AstBool(false));
      case TokenKind.nullKeyword:
        _advance();
        return _Parsed(AstNull.instance);
      case TokenKind.leftBracket:
        return _parseArray();
      case TokenKind.leftBrace:
        return _parseObject();
      case TokenKind.stateVariable:
        _advance();
        if (_current.kind != TokenKind.equals) return _Parsed(AstStateRef(token.text!));
        _advance();
        final value = _parseExpression(0);
        return _Parsed.of(AstAssign(token.text!, value.node), [value]);
      case TokenKind.type:
        final name = token.text!;
        // A built-in needs its `@` (`Count(rows)` is a reference); only
        // `Action` is called without one.
        if (_peekKind(1) == TokenKind.leftParen && (!BuiltinCalls.isBuiltin(name) || name == BuiltinCalls.action)) {
          return _parseCall();
        }
        _advance();
        return _Parsed(AstRef(name));
      case TokenKind.builtinCall:
        if (_peekKind(1) != TokenKind.leftParen) {
          _advance();
          return _Parsed(AstRef(token.text!));
        }
        final call = _parseCall();
        final node = call.node as AstCall;
        if (BuiltinCalls.isBuiltin(node.name)) return call;
        return _Parsed(AstCall(node.name, node.args, isFunction: true), call.height);
      case TokenKind.identifier:
        _advance();
        return _Parsed(AstRef(token.text!));
      case TokenKind.not:
        _advance();
        final operand = _parseExpression(_unary);
        return _Parsed.of(AstUnary('!', operand.node), [operand]);
      case TokenKind.minus:
        _advance();
        final operand = _parseExpression(_unary);
        return _Parsed.of(AstUnary('-', operand.node), [operand]);
      case TokenKind.leftParen:
        _advance();
        final inner = _parseExpression(0);
        _eat(TokenKind.rightParen);
        return inner;
      default:
        _advance();
        return _Parsed(AstNull.instance);
    }
  }

  _Parsed _parseInfix(_Parsed left) {
    final kind = _current.kind;
    if (_binaryOperators[kind] case (final operator, final precedence)) {
      _advance();
      final right = _parseExpression(precedence);
      return _Parsed.of(AstBinary(operator, left.node, right.node), [left, right]);
    }
    switch (kind) {
      case TokenKind.question:
        _advance();
        final then = _parseExpression(0);
        _eat(TokenKind.colon);
        final otherwise = _parseExpression(0);
        return _Parsed.of(AstTernary(left.node, then.node, otherwise.node), [left, then, otherwise]);
      case TokenKind.dot:
        _advance();
        final field = _advance();
        final name = switch (field.kind) {
          TokenKind.identifier || TokenKind.type || TokenKind.string || TokenKind.number => field.valueString,
          TokenKind.stateVariable => field.text!.substring(1),
          _ => '?',
        };
        return _Parsed.of(AstMember(left.node, name), [left]);
      case TokenKind.leftBracket:
        _advance();
        final index = _parseExpression(0);
        _eat(TokenKind.rightBracket);
        return _Parsed.of(AstIndex(left.node, index.node), [left, index]);
      default:
        return left;
    }
  }

  _Parsed _parseCall() {
    final name = _advance().text!;
    _eat(TokenKind.leftParen);
    final args = <_Parsed>[];
    while (_current.kind != TokenKind.rightParen && _current.kind != TokenKind.eof) {
      args.add(_parseExpression(0));
      if (_current.kind == TokenKind.comma) _advance();
    }
    _eat(TokenKind.rightParen);
    return _Parsed.of(AstCall(name, [for (final arg in args) arg.node]), args);
  }

  _Parsed _parseArray() {
    _advance();
    final elements = <_Parsed>[];
    while (_current.kind != TokenKind.rightBracket && _current.kind != TokenKind.eof) {
      elements.add(_parseExpression(0));
      if (_current.kind == TokenKind.comma) _advance();
    }
    _eat(TokenKind.rightBracket);
    return _Parsed.of(AstArray([for (final element in elements) element.node]), elements);
  }

  // A key is a name, a string, a number as JavaScript prints it, or a `$name`
  // without its `$`; anything else reads as `?`.
  _Parsed _parseObject() {
    _advance();
    final entries = <(String, AstNode)>[];
    final values = <_Parsed>[];
    while (_current.kind != TokenKind.rightBrace && _current.kind != TokenKind.eof) {
      final key = _advance();
      final name = switch (key.kind) {
        TokenKind.identifier || TokenKind.string || TokenKind.type || TokenKind.number => key.valueString,
        TokenKind.stateVariable => key.text!.substring(1),
        _ => '?',
      };
      _eat(TokenKind.colon);
      final value = _parseExpression(0);
      entries.add((name, value.node));
      values.add(value);
      if (_current.kind == TokenKind.comma) _advance();
    }
    _eat(TokenKind.rightBrace);
    return _Parsed.of(AstObject(entries), values);
  }
}

// A parsed node with the height of its tree, so an operator chain that grows
// the tree without nesting can be bounded too.
final class _Parsed {
  _Parsed(this.node, [this.height = 1]);

  _Parsed.of(this.node, List<_Parsed> children)
    : height = 1 + children.fold(0, (tallest, child) => child.height > tallest ? child.height : tallest);

  final AstNode node;
  final int height;
}
