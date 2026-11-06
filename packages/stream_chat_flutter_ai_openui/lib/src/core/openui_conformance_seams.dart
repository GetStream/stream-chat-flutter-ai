/// Entry points into the OpenUI Lang core that only the conformance tests
/// use.
///
/// A conformance case reads a program and compares what the core gives with
/// what OpenUI's own implementation gave. Each entry point here is the
/// narrowest way in for one kind of case, and works in plain data or the
/// package's own types, so a replacement core has to provide the same ones to
/// pass the same suites.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parser_errors.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

export 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart' show BindablePropTest, OpenUIFunction;
export 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// What reading `text` against `schema` gives, as OpenUI's own parser writes
/// it: `root`, `meta`, `stateDeclarations`, `queryStatements` and
/// `mutationStatements` (and `rootExpression` when the entry picks a
/// component only when evaluated), in plain JSON values.
///
/// Only the conformance tests use it.
Map<String, Object?> debugParse(OpenUILibrarySchema schema, String text) {
  return parseResultJson(OpenUILangParser(schema).parse(text));
}

/// The errors reading `text` against `schema` reports, with their hints.
///
/// Only the conformance tests use it.
List<OpenUIError> debugParseErrors(OpenUILibrarySchema schema, String text) {
  return parserErrors(OpenUILangParser(schema).parse(text), schema);
}

/// What reading `chunks` one after another against `schema` gives after each
/// of them, as OpenUI's own parser writes it, while the stream hasn't ended.
///
/// Only the conformance tests use it.
List<Map<String, Object?>> debugStreamParseSteps(OpenUILibrarySchema schema, List<String> chunks) {
  final parser = OpenUIStreamParser(schema);
  return [for (final chunk in chunks) parseResultJson(parser.push(chunk))];
}

/// What reading `chunks` one after another against `schema` gives once the
/// stream ends with the last of them, as OpenUI's own parser writes it; with
/// no chunks, what an ended stream of no text gives.
///
/// Only the conformance tests use it.
Map<String, Object?> debugStreamParseComplete(OpenUILibrarySchema schema, List<String> chunks) {
  final parser = OpenUIStreamParser(schema);
  var result = parser.result(complete: true);
  for (final (index, chunk) in chunks.indexed) {
    result = parser.push(chunk, complete: index == chunks.length - 1);
  }
  return parseResultJson(result);
}

/// What evaluating `text`, read against `schema`, gives, as OpenUI's own
/// evaluator writes it: `evaluatedRoot`, `queries` (each query's tool, args,
/// defaults and refresh evaluated) and `runtimeErrors`, in plain JSON values.
///
/// `$variables` read `state` over the program's declared defaults, a field
/// value `{value, …}` read as its `value`; other statements read `refs`, or,
/// without them, what they read when the stream ends and no tool has
/// answered yet: a query its defaults, a mutation `{status: "idle", data:
/// null, error: null}`. The
/// props `isBindable` names take a `$variable` both ways, and `functions`
/// are the library's functions.
///
/// Only the conformance tests use it.
Map<String, Object?> debugEvaluate(
  OpenUILibrarySchema schema,
  String text, {
  required BindablePropTest isBindable,
  Map<String, Object?> state = const {},
  Map<String, Object?>? refs,
  Map<String, OpenUIFunction> functions = const {},
}) {
  final result = OpenUILangParser(schema).parse(text);
  final store = {
    ...result.stateDeclarations,
    for (final MapEntry(:key, :value) in state.entries) key: OpenUIValue.fromJson(value),
  };
  final resolved = {for (final MapEntry(:key, :value) in (refs ?? const {}).entries) key: OpenUIValue.fromJson(value)};
  final context = EvaluationContext(
    getState: (name) => switch (store[name]) {
      OpenUIObject(:final fields) when fields.containsKey('value') => fields['value'],
      final value => value,
    },
    resolveRef: (name) => resolved[name],
    schema: schema,
    isBindable: isBindable,
    functions: functions,
  );
  if (refs == null) {
    for (final query in result.queryStatements) {
      final defaults = query.defaults;
      resolved[query.statementId] =
          (defaults == null ? null : Evaluator.evaluate(defaults, context)) ?? OpenUINull.instance;
    }
    for (final mutation in result.mutationStatements) {
      resolved[mutation.statementId] = OpenUIValue.fromJson(const {'status': 'idle', 'data': null, 'error': null});
    }
  }
  final (root, errors) = PropEvaluator.evaluateRoot(result, context);
  Object? evaluated(AstNode? node) {
    if (node == null) return null;
    final value = Evaluator.evaluate(
      node,
      EvaluationContext(
        getState: context.getState,
        resolveRef: context.resolveRef,
        schema: schema,
        functions: functions,
      ),
    );
    return value == null ? null : plainJson(value);
  }

  return {
    'evaluatedRoot': root == null ? null : elementJson(root),
    'queries': [
      for (final query in result.queryStatements)
        {
          'statementId': query.statementId,
          'toolName': query.tool == null ? '' : evaluated(query.tool),
          'args': evaluated(query.args),
          'defaults': evaluated(query.defaults),
          'refresh': evaluated(query.refresh),
        },
    ],
    'runtimeErrors': [
      for (final error in errors)
        {
          'source': error.source as String,
          'code': error.code as String,
          if (error.component case final component?) 'component': component,
          if (error.statementId case final statementId?) 'statementId': statementId,
          'message': error.message,
          if (error.hint case final hint?) 'hint': hint,
        },
    ],
  };
}

/// What running `program`, read against `schema`, gives when `interactions`
/// happen one after another, as the specification's interaction fixtures
/// write them: `events` (each action event's `type`,
/// `humanFriendlyMessage`, `params`, `formName` and `formState`), `state`
/// (the `$variables` and fields, plain) and `toolCalls` (`{tool, args}`).
///
/// An interaction is `{"tool": name, "result": value}`, which gives the tool
/// `name` and what it returns from the start — a tool not given is not
/// found —, `{"click":
/// id}`, which runs the action of the control the statement `id` made, or
/// `{"type": [id, text]}`, which enters `text` in the field the statement
/// `id` made. A field or control inside a `Form` belongs to that form. Timers
/// run as soon as each interaction is done.
///
/// Only the conformance tests use it.
Future<Map<String, Object?>> debugInteract(
  OpenUILibrarySchema schema,
  String program,
  List<Map<String, Object?>> interactions, {
  required BindablePropTest isBindable,
  Map<String, OpenUIFunction> functions = const {},
}) async {
  final tools = _FixtureTools();
  final runtime = OpenUIRuntime(
    schema: schema,
    isBindable: isBindable,
    tools: tools,
    functions: functions,
    timer: (_, callback) => Timer(Duration.zero, callback),
  );
  final events = <Map<String, Object?>>[];
  final subscription = runtime.actions.listen(
    (event) => events.add({
      'type': event.type,
      'humanFriendlyMessage': event.message,
      'params': {for (final MapEntry(:key, :value) in event.params.entries) key: plainJson(value)},
      'formName': event.formName,
      'formState': {for (final MapEntry(:key, :value) in event.formState.entries) key: plainJson(value)},
    }),
  );
  Future<void> settle() async {
    for (var i = 0; i < 10; i += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // The tools are there from the start.
  for (final interaction in interactions) {
    if (interaction case {'tool': final String name, 'result': final result}) {
      tools.results[name] = OpenUIValue.fromJson(result);
    }
  }
  runtime.update(program, isStreaming: false);
  await settle();
  for (final interaction in interactions) {
    if (interaction case {'click': final String id}) {
      final (element, form) = _find(runtime.root.value, id)!;
      await runtime.trigger(
        label: JS.toStringOrEmpty(element.props['label']),
        formName: form,
        action: element.props['action'],
      );
    } else if (interaction case {'type': [final String id, final String text]}) {
      final (element, form) = _find(runtime.root.value, id)!;
      runtime
          .stateField(
            JS.toStringOrEmpty(element.props['name']),
            binding: element.props['value'],
            formName: form,
            componentType: element.typeName.toLowerCase(),
          )
          .set(OpenUIString(text));
    }
    await settle();
  }
  final state = {for (final MapEntry(:key, :value) in runtime.state.value.entries) key: plainJson(value)};
  await subscription.cancel();
  runtime.dispose();
  return {'events': events, 'state': state, 'toolCalls': tools.calls};
}

// The element the statement `id` made in `root`, with the name of the form
// around it.
(ElementNode, String?)? _find(ElementNode? root, String id, [String? form]) {
  if (root == null) return null;
  if (root.statementId == id) return (root, form);
  final inner = root.typeName == 'Form' ? JS.toStringOrEmpty(root.props['name']) : form;
  (ElementNode, String?)? search(OpenUIValue value) {
    return switch (value) {
      OpenUIElement(:final node) => _find(node, id, inner),
      OpenUIArray(:final items) => items.map(search).nonNulls.firstOrNull,
      _ => null,
    };
  }

  return root.props.values.map(search).nonNulls.firstOrNull;
}

final class _FixtureTools implements OpenUIToolProvider {
  final results = <String, OpenUIValue>{};
  final calls = <Map<String, Object?>>[];

  @override
  Future<OpenUIValue> callTool(String name, Map<String, OpenUIValue> args, {required bool userInitiated}) async {
    final result = results[name];
    if (result == null) throw ToolNotFoundException(name, availableTools: [...results.keys]);
    calls.add({'tool': name, 'args': plainJson(OpenUIObject(args))});
    return result;
  }
}

/// The error a field holding `value` gets from the validation `rules`, both
/// plain JSON, or `null` when it passes them.
///
/// Only the conformance tests use it.
String? debugValidate(Object? rules, Object? value) {
  return FormValidation.validate(OpenUIValue.fromJson(value), FormValidation.parse(OpenUIValue.fromJson(rules)));
}
