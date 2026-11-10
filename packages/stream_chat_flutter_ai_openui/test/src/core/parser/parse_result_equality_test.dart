// Equal values are built as separate instances, never `const`, which would
// make them one instance and the equality checks pass without comparing.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

void main() {
  for (final (name, build) in _builders) {
    test('equal ${name}s are equal', () {
      expect(build(), build());
    });

    test('equal ${name}s share a hash code', () {
      expect(build().hashCode, build().hashCode);
    });
  }

  for (final (name, a, b) in _differing()) {
    test('$name are not equal', () {
      expect(a, isNot(b));
    });
  }
}

final List<(String, Object Function())> _builders = [
  ('parse result', _result),
  ('parse meta', _meta),
  ('element', _element),
  ('validation error', _error),
  ('query', _query),
  ('mutation', _mutation),
  ('parameter', _param),
  ('call definition', _call),
  ('library schema', _schema),
];

List<(String, Object, Object)> _differing() {
  return [
    ('results with different roots', _result(), _result(root: _element(typeName: 'B'))),
    ('results with different root expressions', _result(), _result(rootExpression: AstRef('x'))),
    ('results with different meta', _result(), _result(meta: _meta(statementCount: 2))),
    ('results with different state', _result(), _result(state: {r'$a': OpenUINumber(2)})),
    ('results with different queries', _result(), _result(queries: [])),
    ('results with different mutations', _result(), _result(mutations: [])),
    ('meta that differs in being incomplete', _meta(), _meta(incomplete: true)),
    ('meta with different unresolved names', _meta(), _meta(unresolved: ['b'])),
    ('meta with different orphans', _meta(), _meta(orphaned: ['b'])),
    ('meta with different statement counts', _meta(), _meta(statementCount: 2)),
    ('meta with different errors', _meta(), _meta(errors: [])),
    ('elements of different types', _element(), _element(typeName: 'B')),
    ('elements with different props', _element(), _element(props: {'a': OpenUINumber(2)})),
    ('elements that differ in being partial', _element(), _element(partial: true)),
    ('elements that differ in having dynamic props', _element(), _element(hasDynamicProps: true)),
    ('elements of different statements', _element(), _element(statementId: 'b')),
    ('errors of different codes', _error(), _error(code: OpenUIErrorCode.nullRequired)),
    ('errors of different components', _error(), _error(component: 'B')),
    ('errors at different paths', _error(), _error(path: '/b')),
    ('errors with different messages', _error(), _error(message: 'n')),
    ('errors of different statements', _error(), _error(statementId: 'b')),
    ('an error and a warning', _error(), _error(isWarning: true)),
    ('queries of different statements', _query(), _query(statementId: 'b')),
    ('queries of different tools', _query(), _query(tool: AstString('u'))),
    ('queries with different arguments', _query(), _query(args: AstNumber(2))),
    ('queries with different defaults', _query(), _query(defaults: AstNumber(2))),
    ('queries with different refreshes', _query(), _query(refresh: AstNumber(2))),
    ('queries with different dependencies', _query(), _query(deps: [r'$b'])),
    ('queries that differ in being complete', _query(), _query(complete: false)),
    ('mutations of different statements', _mutation(), _mutation(statementId: 'b')),
    ('mutations of different tools', _mutation(), _mutation(tool: AstString('u'))),
    ('mutations with different arguments', _mutation(), _mutation(args: AstNumber(2))),
    ('parameters of different names', _param(), _param(name: 'b')),
    ('parameters that differ in being required', _param(), _param(required: false)),
    ('parameters with different defaults', _param(), _param(defaultValue: OpenUINumber(2))),
    ('parameters with different schemas', _param(), _param(schema: OpenUIString('number'))),
    ('call definitions of different kinds', _call(), _call(kind: CallKind.action)),
    ('call definitions with different parameters', _call(), _call(params: [])),
    ('call definitions that differ in being built in', _call(), _call(isBuiltin: true)),
    ('call definitions that differ in being lazy', _call(), _call(isLazy: true)),
    ('library schemas with different roots', _schema(), _schema(root: 'B')),
    ('library schemas with different components', _schema(), _schema(component: 'B')),
    ('library schemas with different data shapes', _schema(), _schema(shapeKey: 'b')),
    ('library schemas with different functions', _schema(), _schema(function: 'G')),
  ];
}

ParseResult _result({
  ElementNode? root,
  AstNode? rootExpression,
  ParseMeta? meta,
  Map<String, OpenUIValue>? state,
  List<QueryStatementInfo>? queries,
  List<MutationStatementInfo>? mutations,
}) {
  return ParseResult(
    root: root ?? _element(),
    rootExpression: rootExpression,
    meta: meta ?? _meta(),
    stateDeclarations: state ?? {r'$a': OpenUINumber(1)},
    queryStatements: queries ?? [_query()],
    mutationStatements: mutations ?? [_mutation()],
  );
}

ParseMeta _meta({
  bool incomplete = false,
  List<String>? unresolved,
  List<String>? orphaned,
  int statementCount = 1,
  List<ValidationError>? errors,
}) {
  return ParseMeta(
    incomplete: incomplete,
    unresolved: unresolved ?? ['a'],
    orphaned: orphaned ?? ['a'],
    statementCount: statementCount,
    errors: errors ?? [_error()],
  );
}

ElementNode _element({
  String typeName = 'A',
  Map<String, OpenUIValue>? props,
  bool partial = false,
  bool hasDynamicProps = false,
  String? statementId = 'a',
}) {
  return ElementNode(
    typeName: typeName,
    props: props ?? {'a': OpenUINumber(1)},
    partial: partial,
    hasDynamicProps: hasDynamicProps,
    statementId: statementId,
  );
}

ValidationError _error({
  OpenUIErrorCode code = OpenUIErrorCode.missingRequired,
  String component = 'A',
  String path = '/a',
  String message = 'm',
  String? statementId = 'a',
  bool isWarning = false,
}) {
  return ValidationError(
    code: code,
    component: component,
    path: path,
    message: message,
    statementId: statementId,
    isWarning: isWarning,
  );
}

QueryStatementInfo _query({
  String statementId = 'a',
  AstNode? tool,
  AstNode? args,
  AstNode? defaults,
  AstNode? refresh,
  List<String>? deps,
  bool complete = true,
}) {
  return QueryStatementInfo(
    statementId: statementId,
    tool: tool ?? AstString('t'),
    args: args ?? AstNumber(1),
    defaults: defaults ?? AstNumber(1),
    refresh: refresh ?? AstNumber(1),
    deps: deps ?? [r'$a'],
    complete: complete,
  );
}

MutationStatementInfo _mutation({String statementId = 'a', AstNode? tool, AstNode? args}) {
  return MutationStatementInfo(statementId: statementId, tool: tool ?? AstString('t'), args: args ?? AstNumber(1));
}

ParamDef _param({String name = 'a', bool required = true, OpenUIValue? defaultValue, OpenUIValue? schema}) {
  return ParamDef(
    name,
    required: required,
    defaultValue: defaultValue ?? OpenUINumber(1),
    schema: schema ?? OpenUIString('string'),
  );
}

CallDef _call({
  CallKind kind = CallKind.function,
  List<ParamDef>? params,
  bool isBuiltin = false,
  bool isLazy = false,
}) {
  return CallDef(kind, params ?? [_param()], isBuiltin: isBuiltin, isLazy: isLazy);
}

OpenUILibrarySchema _schema({String root = 'A', String component = 'A', String shapeKey = 'a', String function = 'F'}) {
  return OpenUILibrarySchema.fromJsonSchema({
    'properties': {component: <String, Object?>{}},
    r'$defs': {
      component: {
        'properties': {'title': <String, Object?>{}},
      },
      'Shape': {
        'properties': {shapeKey: <String, Object?>{}},
      },
    },
    'functions': {
      function: {
        'params': {
          'properties': {'x': <String, Object?>{}},
        },
      },
    },
  }, root: root);
}
