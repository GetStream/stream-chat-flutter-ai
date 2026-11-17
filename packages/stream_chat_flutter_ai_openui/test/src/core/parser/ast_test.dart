// Equal values are built as separate instances, never `const`, which would
// make them one instance and the equality checks pass without comparing.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';

void main() {
  for (final (index, (name, node)) in _nodes().indexed) {
    test('equal $name are equal', () {
      expect(node, _nodes()[index].$2);
    });

    test('equal $name share a hash code', () {
      expect(node.hashCode, _nodes()[index].$2.hashCode);
    });
  }

  for (final (name, a, b) in _differing()) {
    test('$name are not equal', () {
      expect(a, isNot(b));
    });
  }

  test('NaN numbers of different bits share a hash code', () {
    expect(AstNumber(double.nan).hashCode, AstNumber(_otherNaN()).hashCode);
  });

  test('calls whose mapped props differ only in order are equal', () {
    final title = AstString('t');
    final body = AstString('b');
    final a = AstCall('Card', [title, body], mappedProps: {'title': title, 'body': body});
    final b = AstCall('Card', [title, body], mappedProps: {'body': body, 'title': title});

    expect(a, b);
  });

  test('calls whose mapped props differ only in order share a hash code', () {
    final title = AstString('t');
    final body = AstString('b');
    final a = AstCall('Card', [title, body], mappedProps: {'title': title, 'body': body});
    final b = AstCall('Card', [title, body], mappedProps: {'body': body, 'title': title});

    expect(a.hashCode, b.hashCode);
  });

  test('a mapped prop that is an argument equals the same argument of an equal call', () {
    final a = AstString('t');
    final b = AstString('t');

    expect(
      AstCall('Card', [a], mappedProps: {'title': a}),
      AstCall('Card', [b], mappedProps: {'title': b}),
    );
  });

  test('a walk visits a mapped prop that is an argument once', () {
    final arg = AstString('t');
    final visited = <AstNode>[];
    AstCall('Card', [arg], mappedProps: {'title': arg}).walk(visited.add);

    expect(visited.whereType<AstString>(), hasLength(1));
  });

  test('a walk visits a mapped prop of its own', () {
    final visited = <AstNode>[];
    AstCall('Card', [AstString('t')], mappedProps: {'title': AstString('u')}).walk(visited.add);

    expect(visited.whereType<AstString>().map((node) => node.value), ['t', 'u']);
  });

  test('the state references are the variables read, each once, in order', () {
    final node = AstBinary('+', AstStateRef(r'$b'), AstArray([AstStateRef(r'$a'), AstStateRef(r'$b')]));

    expect(node.stateReferences(), [r'$b', r'$a']);
  });

  test('the target of an assignment is not a state reference', () {
    expect(AstAssign(r'$x', AstStateRef(r'$y')).stateReferences(), [r'$y']);
  });
}

// One node of each kind, built fresh on every call.
List<(String, AstNode)> _nodes() {
  final title = AstString('t');
  return [
    ('calls', AstCall('Card', [title], mappedProps: {'title': title})),
    ('strings', AstString('a')),
    ('numbers', AstNumber(1)),
    ('NaN numbers', AstNumber(double.nan)),
    ('booleans', AstBool(true)),
    ('nulls', AstNull.instance),
    ('arrays', AstArray([AstNumber(1)])),
    ('objects', AstObject([('a', AstNumber(1))])),
    ('references', AstRef('a')),
    ('placeholders', AstPlaceholder('a')),
    ('state references', AstStateRef(r'$a')),
    ('runtime references', AstRuntimeRef('q', RuntimeRefType.query)),
    ('binary operations', AstBinary('+', AstNumber(1), AstNumber(2))),
    ('unary operations', AstUnary('!', AstBool(true))),
    ('ternaries', AstTernary(AstBool(true), AstNumber(1), AstNumber(2))),
    ('member reads', AstMember(AstRef('a'), 'b')),
    ('index reads', AstIndex(AstRef('a'), AstNumber(0))),
    ('assignments', AstAssign(r'$a', AstNumber(1))),
  ];
}

List<(String, AstNode, AstNode)> _differing() {
  final title = AstString('t');
  return [
    ('calls of different names', AstCall('A', []), AstCall('B', [])),
    ('calls with different arguments', AstCall('A', [AstNumber(1)]), AstCall('A', [AstNumber(2)])),
    ('a function call and a call', AstCall('A', [], isFunction: true), AstCall('A', [])),
    (
      'a resolved and an unresolved call',
      AstCall('A', [title], mappedProps: {'t': title}),
      AstCall('A', [title]),
    ),
    (
      'calls mapping different props',
      AstCall('A', [title], mappedProps: {'t': title}),
      AstCall('A', [title], mappedProps: {'u': title}),
    ),
    (
      'calls with different mapped prop values',
      AstCall('A', [title], mappedProps: {'t': AstNumber(1)}),
      AstCall('A', [title], mappedProps: {'t': AstNumber(2)}),
    ),
    (
      'calls mapping a different number of props',
      AstCall('A', [title], mappedProps: {'t': title}),
      AstCall('A', [title], mappedProps: {'t': title, 'u': title}),
    ),
    ('different strings', AstString('a'), AstString('b')),
    ('different numbers', AstNumber(1), AstNumber(2)),
    ('different booleans', AstBool(true), AstBool(false)),
    ('arrays of different elements', AstArray([AstNumber(1)]), AstArray([AstNumber(2)])),
    ('objects of different keys', AstObject([('a', AstNumber(1))]), AstObject([('b', AstNumber(1))])),
    ('different references', AstRef('a'), AstRef('b')),
    ('a reference and a placeholder', AstRef('a'), AstPlaceholder('a')),
    ('different state references', AstStateRef(r'$a'), AstStateRef(r'$b')),
    (
      'runtime references of different types',
      AstRuntimeRef('q', RuntimeRefType.query),
      AstRuntimeRef('q', RuntimeRefType.mutation),
    ),
    (
      'binary operations of different operators',
      AstBinary('+', AstNumber(1), AstNumber(2)),
      AstBinary('-', AstNumber(1), AstNumber(2)),
    ),
    ('unary operations of different operators', AstUnary('!', AstNumber(1)), AstUnary('-', AstNumber(1))),
    (
      'ternaries of different branches',
      AstTernary(AstBool(true), AstNumber(1), AstNumber(2)),
      AstTernary(AstBool(true), AstNumber(1), AstNumber(3)),
    ),
    ('member reads of different fields', AstMember(AstRef('a'), 'b'), AstMember(AstRef('a'), 'c')),
    (
      'index reads of different indexes',
      AstIndex(AstRef('a'), AstNumber(0)),
      AstIndex(AstRef('a'), AstNumber(1)),
    ),
    ('assignments of different targets', AstAssign(r'$a', AstNumber(1)), AstAssign(r'$b', AstNumber(1))),
  ];
}

// A NaN whose bits differ from `double.nan`'s, so its `hashCode` differs too.
double _otherNaN() => (ByteData(8)..setUint64(0, 0x7ff8000000000001)).getFloat64(0);
