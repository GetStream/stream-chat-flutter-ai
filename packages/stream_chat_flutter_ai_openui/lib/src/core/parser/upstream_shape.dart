/// Values, expressions and parse results in the JSON form OpenUI's own
/// TypeScript implementation gives them.
///
/// A call's mapped prop is usually the same node as one of its arguments.
/// Written in full, as the TypeScript implementation writes it, the JSON
/// doubles with every level of calls nested in calls; so it is written as a
/// reference to the argument, `{"k": "Arg", "i": <index>}`, unless
/// `expandSharedArgs` asks for the full form.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// `value` as plain JSON data: `null`, [bool], [double], [String], or a
/// [List] or [Map] of them.
///
/// A number that isn't finite becomes `null`, as `JSON.stringify` writes it,
/// and an element or expression becomes its JSON form ([elementJson],
/// [astJson]), with shared arguments expanded when `expandSharedArgs`.
Object? plainJson(OpenUIValue value, {bool expandSharedArgs = false}) {
  Object? recurse(OpenUIValue value) => plainJson(value, expandSharedArgs: expandSharedArgs);
  return switch (value) {
    OpenUINull() => null,
    OpenUIBool(:final value) => value,
    OpenUINumber(:final value) => value.isFinite ? value : null,
    OpenUIString(:final value) => value,
    OpenUIArray(:final items) => [for (final item in items) recurse(item)],
    OpenUIObject(:final fields) => {
      for (final MapEntry(:key, :value) in fields.entries) key: recurse(value),
    },
    OpenUIElement(:final node) => elementJson(node, expandSharedArgs: expandSharedArgs),
    OpenUIExpression(:final node) => astJson(node, expandSharedArgs: expandSharedArgs),
  };
}

/// `element` as `{type: "element", typeName, props, partial,
/// hasDynamicProps, statementId?}`, with shared arguments expanded when
/// `expandSharedArgs`.
Map<String, Object?> elementJson(ElementNode element, {bool expandSharedArgs = false}) {
  return {
    'type': 'element',
    'typeName': element.typeName,
    'props': {
      for (final MapEntry(:key, :value) in element.props.entries)
        key: plainJson(value, expandSharedArgs: expandSharedArgs),
    },
    'partial': element.partial,
    'hasDynamicProps': element.hasDynamicProps,
    if (element.statementId case final id?) 'statementId': id,
  };
}

/// `node` as `{k: <kind>, …}`.
///
/// A mapped prop that is the same node as one of the call's arguments is
/// written as `{"k": "Arg", "i": <index>}`, or in full when
/// `expandSharedArgs`; written in full, the JSON doubles with each level of
/// calls nested in calls.
Map<String, Object?> astJson(AstNode node, {bool expandSharedArgs = false}) {
  Map<String, Object?> recurse(AstNode node) => astJson(node, expandSharedArgs: expandSharedArgs);
  return switch (node) {
    AstCall(:final name, :final args, :final mappedProps, :final isFunction) => {
      'k': 'Comp',
      'name': name,
      'args': [for (final arg in args) recurse(arg)],
      if (isFunction) 'fn': true,
      if (mappedProps != null)
        'mappedProps': {
          for (final MapEntry(:key, :value) in mappedProps.entries)
            key: switch (node.argIndexOf(value)) {
              final index when index != -1 && !expandSharedArgs => {'k': 'Arg', 'i': index},
              _ => recurse(value),
            },
        },
    },
    AstString(:final value) => {'k': 'Str', 'v': value},
    AstNumber(:final value) => {'k': 'Num', 'v': value.isFinite ? value : null},
    AstBool(:final value) => {'k': 'Bool', 'v': value},
    AstNull() => {'k': 'Null'},
    AstArray(:final elements) => {
      'k': 'Arr',
      'els': [for (final element in elements) recurse(element)],
    },
    AstObject(:final entries) => {
      'k': 'Obj',
      'entries': [
        for (final (key, value) in entries) [key, recurse(value)],
      ],
    },
    AstRef(:final name) => {'k': 'Ref', 'n': name},
    AstPlaceholder(:final name) => {'k': 'Ph', 'n': name},
    AstStateRef(:final name) => {'k': 'StateRef', 'n': name},
    AstRuntimeRef(:final name, :final type) => {'k': 'RuntimeRef', 'n': name, 'refType': type.name},
    AstBinary(:final operator, :final left, :final right) => {
      'k': 'BinOp',
      'op': operator,
      'left': recurse(left),
      'right': recurse(right),
    },
    AstUnary(:final operator, :final operand) => {'k': 'UnaryOp', 'op': operator, 'operand': recurse(operand)},
    AstTernary(:final condition, :final then, :final otherwise) => {
      'k': 'Ternary',
      'cond': recurse(condition),
      'then': recurse(then),
      'else': recurse(otherwise),
    },
    AstMember(:final object, :final field) => {'k': 'Member', 'obj': recurse(object), 'field': field},
    AstIndex(:final object, :final index) => {'k': 'Index', 'obj': recurse(object), 'index': recurse(index)},
    AstAssign(:final target, :final value) => {'k': 'Assign', 'target': target, 'value': recurse(value)},
  };
}

/// `result` as OpenUI's own parser gives it: `root`, `rootExpression` when
/// set, `meta`, `stateDeclarations`, `queryStatements` and
/// `mutationStatements`, with shared arguments written in full.
///
/// Its size can double with each level of calls nested in calls, so only the
/// conformance tests write it.
Map<String, Object?> parseResultJson(ParseResult result) {
  final meta = result.meta;
  Object? optional(AstNode? node) => node == null ? null : astJson(node, expandSharedArgs: true);
  return {
    'root': switch (result.root) {
      final root? => elementJson(root, expandSharedArgs: true),
      null => null,
    },
    if (result.rootExpression case final expression?) 'rootExpression': astJson(expression, expandSharedArgs: true),
    'meta': {
      'incomplete': meta.incomplete,
      'unresolved': meta.unresolved,
      'orphaned': meta.orphaned,
      'statementCount': meta.statementCount,
      'errors': [
        for (final error in meta.errors)
          {
            'code': error.code as String,
            'component': error.component,
            'path': error.path,
            'message': error.message,
            if (error.statementId case final id?) 'statementId': id,
            if (error.isWarning) 'severity': 'warning',
          },
      ],
    },
    'stateDeclarations': {
      for (final MapEntry(:key, :value) in result.stateDeclarations.entries)
        key: plainJson(value, expandSharedArgs: true),
    },
    'queryStatements': [
      for (final query in result.queryStatements)
        {
          'statementId': query.statementId,
          'toolAST': optional(query.tool),
          'argsAST': optional(query.args),
          'defaultsAST': optional(query.defaults),
          'refreshAST': optional(query.refresh),
          if (query.deps case final deps?) 'deps': deps,
          'complete': query.complete,
        },
    ],
    'mutationStatements': [
      for (final mutation in result.mutationStatements)
        {'statementId': mutation.statementId, 'toolAST': optional(mutation.tool), 'argsAST': optional(mutation.args)},
    ],
  };
}
