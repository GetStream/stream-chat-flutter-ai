/// Evaluating OpenUI Lang expressions and element trees to values.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materializer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/schema_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_plan.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/builtins.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// One of the library's functions, called as `@Name(…)`: what the app runs
/// for it.
///
/// Its parameters are the library schema's; the evaluator checks the
/// arguments against them before calling [call].
@immutable
final class OpenUIFunction {
  /// Creates a function that runs [call], whose result must match the JSON
  /// Schema [returns] when given.
  const OpenUIFunction(this.call, {this.returns});

  /// Runs the function with its arguments by parameter name. A throw makes
  /// the call `null`, reported as a `runtime-error`.
  final OpenUIValue Function(Map<String, OpenUIValue> args) call;

  /// The JSON Schema the result must match, or `null` for any result.
  final OpenUIValue? returns;
}

/// Whether `prop` of `component` takes a `$variable` it reads and writes.
typedef BindablePropTest = bool Function(String component, String prop);

/// How many steps one evaluation pass may take, shared by every evaluation
/// in the pass.
///
/// Templates multiply: six nested `@Each` over ten items would build a
/// million elements. Each node evaluated, each `@Each` item and each node a
/// template is copied into costs a step. A built-in that walks a list,
/// `@Sum`, `@Avg`, `@Min`, `@Max`, `@Sort` or `@Filter`, walks it for free the
/// first time; the same call walking the same list again, such as a filter of
/// every row for each row, costs a step more for each item. Past [maxSteps]
/// values evaluate to nothing and the pass reports one `runtime-error`.
///
/// A built-in call in an `@Each` template that reads no loop variable gives
/// the same value for every item, so it is evaluated once per pass: a
/// share-of-total table, `@Each($rows, "r", Text("" + r.v / @Sum($rows.v)))`,
/// doesn't sum its rows once per row.
final class EvaluationBudget {
  /// The steps of one pass.
  static const maxSteps = 200000;

  /// The message of the error reported when a pass runs out.
  static const exceededMessage = 'evaluation budget of $maxSteps steps exceeded; the output was cut short';

  int _remaining = maxSteps;
  bool _reported = false;

  // The built-in calls `@Each` templates hold unchanged for their items, and
  // the values of the ones that read no loop variable, with the `extraScope`
  // they were evaluated in.
  final _sharedCalls = Set<AstCall>.identity();
  final _callValues = Map<AstCall, (Map<String, OpenUIValue>, OpenUIValue)>.identity();

  // The `$variables` read in the pass, and the fields read from every item of
  // a list, each read once, so a list read again is the same list.
  final _states = <String, OpenUIValue?>{};
  final _plucks = Map<OpenUIArray, Map<String, OpenUIArray>>.identity();

  // The literal of each list, object or element an `@Each` item holds, and
  // the plain value of each element, made once per pass.
  final _literals = Map<OpenUIValue, AstNode>.identity();
  final _plainValues = Map<OpenUIValue, OpenUIValue>.identity();

  // The call each copy of a list-walking call in a template was copied from,
  // and the lists each such call has walked.
  final _origins = Map<AstCall, AstCall>.identity();
  final _walked = Map<AstCall, Set<OpenUIArray>>.identity();

  // The names each shared call reads from outside it. Null when the call can
  // do more than call built-in functions, such as call a library function,
  // which can report an error.
  final _freeNames = Map<AstCall, Set<String>?>.identity();

  /// Whether the pass ran out of steps.
  bool get isExhausted => _remaining <= 0;

  /// Whether the pass ran out and has already reported it.
  bool get isReported => _reported;

  /// Spends `steps`, reporting through `report`, once per pass, when none is
  /// left; returns whether there were enough.
  bool spend(void Function(String message)? report, [int steps = 1]) {
    if (_remaining >= steps) {
      _remaining -= steps;
      return true;
    }
    _remaining = 0;
    if (!_reported && report != null) {
      _reported = true;
      report(exceededMessage);
    }
    return false;
  }
}

/// What expressions read while they evaluate.
final class EvaluationContext {
  /// Creates a context; [budget] is a fresh one when not given.
  EvaluationContext({
    required this.getState,
    required this.resolveRef,
    this.schema,
    this.isBindable,
    this.functions = const {},
    this.reportError,
    this.extraScope = const {},
    EvaluationBudget? budget,
  }) : budget = budget ?? EvaluationBudget(),
       _loopVariables = const {};

  EvaluationContext._(
    this._loopVariables, {
    required this.getState,
    required this.resolveRef,
    required this.schema,
    required this.isBindable,
    required this.functions,
    required this.reportError,
    required this.extraScope,
    required this.budget,
  });

  /// Reads a `$variable`; absent for one never set.
  final OpenUIValue? Function(String name) getState;

  /// Reads another statement's value: a query's data, a mutation's
  /// `{status, data, error}`, or an `@Each` loop variable.
  final OpenUIValue? Function(String name) resolveRef;

  /// The library's schema: its custom actions, and its functions'
  /// parameters.
  final OpenUILibrarySchema? schema;

  /// Which props take a `$variable` both ways; none without it.
  final BindablePropTest? isBindable;

  /// The library's functions the app runs, by name.
  final Map<String, OpenUIFunction> functions;

  /// Reports a problem found while evaluating.
  final void Function(String message)? reportError;

  /// Values that shadow `$variables`, such as `$value` in a binding's setter.
  final Map<String, OpenUIValue> extraScope;

  /// The steps left in this pass.
  final EvaluationBudget budget;

  // The loop variables of the `@Each` calls this is evaluated in, which
  // `resolveRef` resolves to their items.
  final Set<String> _loopVariables;

  /// This context with `reportError` or `extraScope` replaced.
  ///
  /// The names references resolve to stay as they are: values evaluated once
  /// per pass are reused on that basis.
  EvaluationContext copyWith({
    void Function(String message)? reportError,
    Map<String, OpenUIValue>? extraScope,
  }) {
    return EvaluationContext._(
      _loopVariables,
      getState: getState,
      resolveRef: resolveRef,
      schema: schema,
      isBindable: isBindable,
      functions: functions,
      reportError: reportError ?? this.reportError,
      extraScope: extraScope ?? this.extraScope,
      budget: budget,
    );
  }

  // This context inside an `@Each` whose loop variables are `loopVariables`,
  // resolving references with `resolveRef`.
  EvaluationContext _inLoop(OpenUIValue? Function(String name) resolveRef, Set<String> loopVariables) {
    return EvaluationContext._(
      loopVariables,
      getState: getState,
      resolveRef: resolveRef,
      schema: schema,
      isBindable: isBindable,
      functions: functions,
      reportError: reportError,
      extraScope: extraScope,
      budget: budget,
    );
  }

  bool _isBindable(String component, String prop) => isBindable?.call(component, prop) ?? false;

  // What prop evaluation passes to `Evaluator.evaluate`: never null, as the
  // tree's props are always evaluated knowing which bind.
  BindablePropTest get _bindable => _isBindable;
}

/// The `{__reactive: "assign", target, expr}` markers a `$variable` on a
/// bindable prop evaluates to.
abstract final class ReactiveBinding {
  /// The key that marks a binding.
  static const markerKey = '__reactive';

  /// A binding of `target` whose setter evaluates `expression` with `$value`
  /// as what was typed.
  static OpenUIObject marker(String target, AstNode expression) {
    return OpenUIObject({
      markerKey: const OpenUIString('assign'),
      'target': OpenUIString(target),
      'expr': OpenUIExpression(expression),
    });
  }

  /// The `$variable` `value` binds; `null` when it isn't a binding.
  static String? targetOf(OpenUIValue? value) {
    if (value case OpenUIObject(
      fields: {markerKey: OpenUIString(value: 'assign'), 'target': OpenUIString(value: final target)},
    )) {
      return target;
    }
    return null;
  }

  /// The setter expression of the binding `value`, unwrapping nested
  /// markers; `null` when it has none.
  static AstNode? expressionOf(OpenUIValue? value) {
    var current = value is OpenUIObject ? value.fields['expr'] : null;
    while (current != null) {
      if (current case OpenUIExpression(:final node)) return node;
      if (targetOf(current) == null) return null;
      current = (current as OpenUIObject).fields['expr'];
    }
    return null;
  }
}

/// Evaluates expressions with JavaScript's semantics, as OpenUI's own
/// `evaluator.ts` does.
abstract final class Evaluator {
  static const _valueVariable = r'$value';

  /// The value of `node`; `null` for JavaScript's `undefined`.
  ///
  /// With `bindable`, a component call in `node` binds the `$variables` on
  /// the props it names and has its child elements evaluated; without it, a
  /// `$variable` prop is kept as an expression for the element's own prop
  /// evaluation. As in OpenUI, only a prop's own expression, an `@Each`
  /// template and a component's args pass it on: an operand, such as a
  /// ternary's branch, doesn't.
  static OpenUIValue? evaluate(AstNode node, EvaluationContext context, [BindablePropTest? bindable]) {
    if (!context.budget.spend(context.reportError)) return null;
    switch (node) {
      case AstString(:final value):
        return OpenUIString(value);
      case AstNumber(:final value):
        return OpenUINumber(value);
      case AstBool(:final value):
        return OpenUIBool(value);
      case AstNull() || AstPlaceholder():
        return OpenUINull.instance;
      case AstStateRef(:final name):
        final scoped = context.extraScope[name];
        if (!JS.isNullish(scoped)) return scoped;
        final states = context.budget._states;
        if (states.containsKey(name)) return states[name];
        return states[name] = context.getState(name);
      case AstRef(:final name) || AstRuntimeRef(:final name):
        return context.resolveRef(name);
      case AstArray(:final elements):
        return OpenUIArray([for (final element in elements) evaluate(element, context) ?? OpenUINull.instance]);
      case AstObject(:final entries):
        return OpenUIObject({
          for (final (key, value) in entries)
            if (evaluate(value, context) case final evaluated?) key: evaluated,
        });
      case AstCall():
        return _evaluateCall(node, context, bindable);
      case AstBinary(:final operator, :final left, :final right):
        return _evaluateBinary(operator, left, right, context);
      case AstUnary(:final operator, :final operand):
        final value = evaluate(operand, context);
        return switch (operator) {
          '!' => OpenUIBool(!JS.isTruthy(value)),
          '-' => OpenUINumber(-JS.toNumber(value)),
          _ => OpenUINull.instance,
        };
      case AstTernary(:final condition, :final then, :final otherwise):
        return JS.isTruthy(evaluate(condition, context)) ? evaluate(then, context) : evaluate(otherwise, context);
      case AstMember(:final object, :final field):
        final value = evaluate(object, context);
        if (JS.isNullish(value)) return OpenUINull.instance;
        if (value case OpenUIArray(:final items)) {
          // Reading a field of a list reads it from every item.
          if (field == 'length') return OpenUINumber(items.length.toDouble());
          final plucks = context.budget._plucks.putIfAbsent(value, () => {});
          return plucks[field] ??= OpenUIArray([
            for (final item in items) JS.property(item, field) ?? OpenUINull.instance,
          ]);
        }
        return JS.property(value, field);
      case AstIndex(:final object, :final index):
        final value = evaluate(object, context);
        final key = evaluate(index, context);
        if (JS.isNullish(value) || JS.isNullish(key)) return OpenUINull.instance;
        if (value case OpenUIArray(:final items)) {
          final position = JS.toNumber(key);
          if (!position.isFinite || position != position.truncateToDouble() || position < 0) return null;
          if (position >= items.length) return null;
          return items[position.toInt()];
        }
        return JS.property(value, JS.stringOf(key));
      case AstAssign(:final target, :final value):
        return ReactiveBinding.marker(target, value);
    }
  }

  static OpenUIValue? _evaluateBinary(String operator, AstNode leftNode, AstNode rightNode, EvaluationContext context) {
    if (operator == '&&') {
      final left = evaluate(leftNode, context);
      return JS.isTruthy(left) ? evaluate(rightNode, context) : left;
    }
    if (operator == '||') {
      final left = evaluate(leftNode, context);
      return JS.isTruthy(left) ? left : evaluate(rightNode, context);
    }
    final left = evaluate(leftNode, context);
    final right = evaluate(rightNode, context);
    switch (operator) {
      case '+':
        if (JS.typeOf(left) == 'string' || JS.typeOf(right) == 'string') {
          return OpenUIString(JS.toStringOrEmpty(left) + JS.toStringOrEmpty(right));
        }
        return OpenUINumber(JS.toNumber(left) + JS.toNumber(right));
      case '-':
        return OpenUINumber(JS.toNumber(left) - JS.toNumber(right));
      case '*':
        return OpenUINumber(JS.toNumber(left) * JS.toNumber(right));
      case '/':
        // The language's choice: dividing by zero gives 0.
        final divisor = JS.toNumber(right);
        return OpenUINumber(divisor == 0 ? 0 : JS.toNumber(left) / divisor);
      case '%':
        final divisor = JS.toNumber(right);
        return OpenUINumber(divisor == 0 ? 0 : JS.remainder(JS.toNumber(left), divisor));
      case '==':
        return OpenUIBool(JS.looseEquals(left, right));
      case '!=':
        return OpenUIBool(!JS.looseEquals(left, right));
      case '>':
        return OpenUIBool(JS.toNumber(left) > JS.toNumber(right));
      case '<':
        return OpenUIBool(JS.toNumber(left) < JS.toNumber(right));
      case '>=':
        return OpenUIBool(JS.toNumber(left) >= JS.toNumber(right));
      case '<=':
        return OpenUIBool(JS.toNumber(left) <= JS.toNumber(right));
      default:
        return OpenUINull.instance;
    }
  }

  // A call, dispatched as OpenUI does: a built-in function, a built-in step
  // or `Action`, one of the library's functions, one of its actions, and
  // otherwise a component.
  static OpenUIValue? _evaluateCall(AstCall node, EvaluationContext context, BindablePropTest? bindable) {
    final name = node.name;
    if (name == 'Each') return _evaluateEach(node.args, context, bindable);
    if (Builtins.functions[name] case final function?) {
      final budget = context.budget;
      final reusable = budget._sharedCalls.contains(node) && _readsNoLoopVariable(node, context);
      if (budget._callValues[node] case (
        final scope,
        final value,
      ) when reusable && identical(scope, context.extraScope)) {
        return value;
      }
      final params = BuiltinCalls.functionParams[name]!;
      final named = node.mappedProps ?? _nameArgs(node.args, params);
      final args = [
        for (final param in params)
          if (named[param] case final arg?) evaluate(arg, context) else null,
      ];
      final list = args.firstOrNull;
      if (list is OpenUIArray && _walksList.contains(name)) {
        final walked = budget._walked.putIfAbsent(budget._origins[node] ?? node, Set<OpenUIArray>.identity);
        if (!walked.add(list) && !budget.spend(context.reportError, list.items.length)) return null;
      }
      final result = function(args);
      if (reusable) budget._callValues[node] = (context.extraScope, result);
      return result;
    }
    if (name == BuiltinCalls.action || BuiltinCalls.stepParams.containsKey(name)) {
      return _evaluateStep(node, context);
    }
    final definition = context.schema?.callOf(name);
    if (context.functions[name] case final function?) {
      return _callFunction(name, function, definition?.params ?? const [], node, context);
    }
    if (definition != null && definition.kind == CallKind.action && !definition.isBuiltin) {
      return _customActionPlan(name, definition.params, node, context);
    }
    final mappedProps = node.mappedProps;
    if (mappedProps == null) return OpenUINull.instance;
    return OpenUIElement(_evaluateMappedComponent(name, mappedProps, context, bindable));
  }

  // The built-in functions that walk the list they are given first; the rest
  // take the same time whatever its length.
  static const _walksList = {'Sum', 'Avg', 'Min', 'Max', 'Sort', 'Filter'};

  // Whether `call`, a built-in call, gives the same value wherever it is
  // evaluated in the pass: it reads no loop variable of the `@Each` calls
  // it is evaluated in, and calls only built-in functions, so it reports
  // nothing. `$variables` and queries don't change during a pass.
  static bool _readsNoLoopVariable(AstCall call, EvaluationContext context) {
    final names = _freeNamesOf(call, context.budget._freeNames);
    if (names == null) return false;
    return !names.any(context._loopVariables.contains);
  }

  // The names `node` reads from outside it: references, which `resolveRef`
  // resolves, less the loop variables of the `@Each` calls in it. Null when
  // it calls more than built-in functions. Each call's names are kept in
  // `known`, so nested calls are walked once.
  static Set<String>? _freeNamesOf(AstNode node, Map<AstCall, Set<String>?> known) {
    Set<String>? union(Iterable<AstNode> nodes) {
      final names = <String>{};
      for (final child in nodes) {
        final childNames = _freeNamesOf(child, known);
        if (childNames == null) return null;
        names.addAll(childNames);
      }
      return names;
    }

    switch (node) {
      case AstRef(:final name) || AstRuntimeRef(:final name):
        return {name};
      case AstCall():
        if (known.containsKey(node)) return known[node];
        return known[node] = _callFreeNames(node, known, union);
      case AstMember(:final object):
        return _freeNamesOf(object, known);
      case AstIndex(:final object, :final index):
        return union([object, index]);
      case AstBinary(:final left, :final right):
        return union([left, right]);
      case AstUnary(:final operand):
        return _freeNamesOf(operand, known);
      case AstTernary(:final condition, :final then, :final otherwise):
        return union([condition, then, otherwise]);
      case AstArray(:final elements):
        return union(elements);
      case AstObject(:final entries):
        return union([for (final (_, entry) in entries) entry]);
      case AstAssign(:final value):
        return _freeNamesOf(value, known);
      case AstString() || AstNumber() || AstBool() || AstNull() || AstPlaceholder() || AstStateRef():
        return const {};
    }
  }

  // The free names of a call: of the nodes it evaluates, as
  // `_evaluateCall` and `_evaluateEach` do.
  static Set<String>? _callFreeNames(
    AstCall call,
    Map<AstCall, Set<String>?> known,
    Set<String>? Function(Iterable<AstNode> nodes) union,
  ) {
    final args = call.args;
    if (call.name == 'Each') {
      if (args.length < 3) return const {};
      final variable = switch (args[1]) {
        AstRef(:final name) => name,
        AstString(:final value) => value,
        _ => '',
      };
      final items = _freeNamesOf(args[0], known);
      final template = _freeNamesOf(args[2], known);
      if (items == null || template == null) return null;
      return {...items, ...template.where((name) => name != variable)};
    }
    if (!Builtins.functions.containsKey(call.name)) return null;
    return union(call.mappedProps?.values ?? args);
  }

  static Map<String, AstNode> _nameArgs(List<AstNode> args, List<String> params) {
    return {for (var i = 0; i < params.length && i < args.length; i += 1) params[i]: args[i]};
  }

  // A component call inside an expression, such as a ternary branch or an
  // `@Each` template.
  static ElementNode _evaluateMappedComponent(
    String name,
    Map<String, AstNode> mappedProps,
    EvaluationContext context,
    BindablePropTest? bindable,
  ) {
    final props = <String, OpenUIValue>{};
    for (final MapEntry(:key, :value) in mappedProps.entries) {
      final OpenUIValue? evaluated;
      if (value is! AstStateRef) {
        evaluated = evaluate(value, context, bindable);
      } else if (bindable == null) {
        evaluated = OpenUIExpression(value);
      } else if (bindable(name, key)) {
        evaluated = ReactiveBinding.marker(value.name, const AstStateRef(_valueVariable));
      } else {
        evaluated = context.getState(value.name);
      }
      if (evaluated != null) props[key] = evaluated;
    }
    if (bindable != null) {
      for (final MapEntry(:key, :value) in props.entries) {
        props[key] = switch (value) {
          OpenUIElement(:final node) => OpenUIElement(PropEvaluator.evaluateElement(node, context)),
          OpenUIArray(:final items) => OpenUIArray([
            for (final item in items)
              if (item case OpenUIElement(:final node))
                OpenUIElement(PropEvaluator.evaluateElement(node, context))
              else
                item,
          ]),
          _ => value,
        };
      }
    }
    return ElementNode(typeName: name, props: props, partial: false, hasDynamicProps: true);
  }

  // A library function's or action's args by parameter name; a nullish
  // optional one is left out, so its default applies.
  static Map<String, OpenUIValue> _callArgs(List<ParamDef> params, AstCall node, EvaluationContext context) {
    final named = node.mappedProps ?? _nameArgs(node.args, [for (final param in params) param.name]);
    final result = <String, OpenUIValue>{};
    for (final MapEntry(:key, :value) in named.entries) {
      final evaluated = evaluate(value, context);
      final param = params.where((param) => param.name == key).firstOrNull;
      if (JS.isNullish(evaluated) && !(param?.required ?? false)) continue;
      result[key] = evaluated ?? OpenUINull.instance;
    }
    return result;
  }

  // Whether a required arg without a default is missing, such as
  // `@Percent($p)` with `$p` unset.
  static bool _missesRequired(Map<String, OpenUIValue> args, List<ParamDef> params) {
    return params.any((param) => param.required && JS.isNullish(args[param.name]) && param.defaultValue == null);
  }

  static OpenUIValue _paramsSchema(List<ParamDef> params) {
    return OpenUIObject({
      'type': const OpenUIString('object'),
      'properties': OpenUIObject({
        for (final param in params) param.name: param.schema ?? OpenUIObject(const {}),
      }),
      'required': OpenUIArray([
        for (final param in params)
          if (param.required) OpenUIString(param.name),
      ]),
    });
  }

  // `value` checked against `schema`, each problem reported; `null` when it
  // is invalid or, when `strict`, when anything was reported.
  static OpenUIValue? _check(
    OpenUIValue value,
    OpenUIValue schema,
    String name,
    String path,
    EvaluationContext context, {
    bool strict = false,
  }) {
    final validation = MaterializeContext(
      symbols: const {},
      schema: context.schema ?? _emptySchema,
      partial: false,
      currentStatementId: null,
      unreached: const [],
    );
    final checked = SchemaValidation.validate(value, schema, name, path, validation);
    for (final error in validation.errors) {
      context.reportError?.call('@$name: ${error.message}');
    }
    if (checked.isInvalid || (strict && validation.errors.isNotEmpty)) return null;
    return checked.value;
  }

  static final _emptySchema = OpenUILibrarySchema.fromJsonSchema(const {});

  // `@Percent(3, 4)`: the function's result for its checked args; bad args
  // or result, or a throw, give null.
  static OpenUIValue _callFunction(
    String name,
    OpenUIFunction function,
    List<ParamDef> params,
    AstCall node,
    EvaluationContext context,
  ) {
    final raw = _callArgs(params, node, context);
    if (_missesRequired(raw, params)) return OpenUINull.instance;
    final checked = _check(OpenUIObject(raw), _paramsSchema(params), name, '', context);
    if (checked is! OpenUIObject) return OpenUINull.instance;
    // An arg the check dropped, with no default to take its place, isn't
    // passed on as missing: the call gives null.
    final dropped = params.any(
      (param) => raw.containsKey(param.name) && !checked.fields.containsKey(param.name) && param.defaultValue == null,
    );
    if (dropped) return OpenUINull.instance;
    final OpenUIValue result;
    try {
      result = function.call(checked.fields);
    } on Object catch (error) {
      context.reportError?.call('@$name threw: $error');
      return OpenUINull.instance;
    }
    final returns = function.returns;
    if (returns == null) return result;
    return _check(result, returns, name, '/returns', context) ?? OpenUINull.instance;
  }

  // A custom action call: a one-step plan. Any invalid arg gives the empty
  // plan, even an optional one with a default: an action never runs with a
  // value the model didn't write.
  static OpenUIObject _customActionPlan(String name, List<ParamDef> params, AstCall node, EvaluationContext context) {
    final raw = _callArgs(params, node, context);
    if (_missesRequired(raw, params)) return ActionPlan.empty;
    final checked = _check(OpenUIObject(raw), _paramsSchema(params), name, '', context, strict: true);
    if (checked == null) return ActionPlan.empty;
    return ActionPlan.plan([ActionPlan.customStep(name, checked)]);
  }

  // A step call: a one-step plan, or the empty plan when invalid;
  // `Action([…])` flattens the plans it holds.
  static OpenUIObject _evaluateStep(AstCall node, EvaluationContext context) {
    final args = node.args;
    if (node.name == BuiltinCalls.action) {
      final list = args.isEmpty ? OpenUIArray(const []) : evaluate(args.first, context);
      return ActionPlan.flatten(list is OpenUIArray ? list.items : const []);
    }
    final OpenUIValue? step;
    switch (node.name) {
      case 'Run':
        step = switch (args.firstOrNull) {
          AstRuntimeRef(:final name, :final type) => OpenUIObject({
            'type': const OpenUIString(ActionStepType.run),
            'statementId': OpenUIString(name),
            'refType': OpenUIString(type.name),
          }),
          _ => null,
        };
      case 'ToAssistant':
        final named = _stepArgs(node, context);
        final assistantContext = named['context'];
        step = OpenUIObject({
          'type': const OpenUIString(ActionStepType.continueConversation),
          'message': OpenUIString(JS.toStringOrEmpty(named['message'])),
          // Any value, passed through as it is; null means none.
          if (!JS.isNullish(assistantContext)) 'context': assistantContext!,
        });
      case 'OpenUrl':
        step = OpenUIObject({
          'type': const OpenUIString(ActionStepType.openUrl),
          'url': OpenUIString(JS.toStringOrEmpty(_stepArgs(node, context)['url'])),
        });
      case 'Set':
        step = args.length >= 2 && args.first is AstStateRef
            ? OpenUIObject({
                'type': const OpenUIString(ActionStepType.set),
                'target': OpenUIString((args.first as AstStateRef).name),
                'valueAST': OpenUIExpression(args[1]),
              })
            : null;
      case 'Reset':
        final targets = [
          for (final arg in args)
            if (arg case AstStateRef(:final name)) OpenUIString(name),
        ];
        step = targets.isEmpty
            ? null
            : OpenUIObject({'type': const OpenUIString(ActionStepType.reset), 'targets': OpenUIArray(targets)});
      default:
        step = null;
    }
    return ActionPlan.plan([?step]);
  }

  static Map<String, OpenUIValue> _stepArgs(AstCall node, EvaluationContext context) {
    final named = node.mappedProps ?? _nameArgs(node.args, BuiltinCalls.stepParams[node.name]!);
    return {
      for (final MapEntry(:key, :value) in named.entries) key: evaluate(value, context) ?? OpenUINull.instance,
    };
  }

  // `@Each(array, varName, template)`: the template once per item, with the
  // loop variable written into it as a literal, so what is evaluated later,
  // such as an action step when it's clicked, keeps the item's value.
  static OpenUIValue _evaluateEach(List<AstNode> args, EvaluationContext context, BindablePropTest? bindable) {
    if (args.length < 3) return OpenUIArray(const []);
    final items = evaluate(args[0], context);
    if (items is! OpenUIArray) return OpenUIArray(const []);
    final variable = switch (args[1]) {
      AstRef(:final name) => name,
      AstString(:final value) => value,
      _ => '',
    };
    if (variable.isEmpty) return OpenUIArray(const []);
    final template = args[2];
    final loopVariables = {...context._loopVariables, variable};
    final results = <OpenUIValue>[];
    for (final item in items.items) {
      if (!context.budget.spend(context.reportError)) break;
      // Each field the template reads, or the item itself, built once
      // however often it is read.
      final literals = <String, AstNode>{};
      AstNode itemLiteral(List<String> fields) =>
          literals[_pathKey(fields)] ??= _fieldLiteral(item, fields, context.budget);

      final substituted = _substitute(template, variable, itemLiteral, context);
      final itemContext = context._inLoop(
        (name) => name == variable ? item : context.resolveRef(name),
        loopVariables,
      );
      final result = evaluate(substituted, itemContext, bindable);
      results.add(switch (result) {
        OpenUIElement(:final node) when bindable != null => OpenUIElement(
          PropEvaluator.evaluateElement(node, itemContext),
        ),
        _ => result ?? OpenUINull.instance,
      });
    }
    return OpenUIArray(results);
  }

  // The literal expression of `value`.
  //
  // A list, object or element is built once per pass however many items hold
  // it, so building literals takes no longer than the values they copy.
  static AstNode _literalAst(OpenUIValue? value, EvaluationBudget budget) {
    switch (value) {
      case null || OpenUINull():
        return AstNull.instance;
      case OpenUIString(:final value):
        return AstString(value);
      case OpenUINumber(:final value):
        return AstNumber(value);
      case OpenUIBool(:final value):
        return AstBool(value);
      case OpenUIArray(:final items):
        return budget._literals[value] ??= AstArray([for (final item in items) _literalAst(item, budget)]);
      case OpenUIObject(:final fields):
        return budget._literals[value] ??= AstObject([
          for (final MapEntry(:key, :value) in fields.entries) (key, _literalAst(value, budget)),
        ]);
      case OpenUIElement() || OpenUIExpression():
        return budget._literals[value] ??= _literalAst(_plainValue(value, budget), budget);
    }
  }

  // An element or expression as the plain value its literal holds, made once
  // per pass.
  static OpenUIValue _plainValue(OpenUIValue value, EvaluationBudget budget) {
    return budget._plainValues[value] ??= OpenUIValue.fromJson(plainJson(value));
  }

  // A key for the field path `fields`: its length, then its fields, which
  // can't hold a NUL, apart.
  static String _pathKey(List<String> fields) => '${fields.length}\u0000${fields.join('\u0000')}';

  // The literal of `item`'s field at the path `fields`. A field path stops at
  // a value that isn't an object, as `_substitute` reading it from the item's
  // literal would: the rest is read when it is evaluated.
  static AstNode _fieldLiteral(OpenUIValue item, List<String> fields, EvaluationBudget budget) {
    var value = item;
    var read = 0;
    for (; read < fields.length; read += 1) {
      if (value is OpenUIElement || value is OpenUIExpression) value = _plainValue(value, budget);
      if (value case OpenUIObject(fields: final entries) when entries.containsKey(fields[read])) {
        value = entries[fields[read]]!;
      } else {
        break;
      }
    }
    var literal = _literalAst(value, budget);
    for (final field in fields.skip(read)) {
      literal = AstMember(literal, field);
    }
    return literal;
  }

  // The fields `node` reads from the loop variable `variable`, outermost
  // last, such as `[a, b]` for `r.a.b`; null when it doesn't read one.
  static List<String>? _loopVariableFields(AstNode node, String variable) {
    final fields = <String>[];
    var current = node;
    while (current is AstMember) {
      fields.add(current.field);
      current = current.object;
    }
    if (current case AstRef(:final name) when name == variable) return fields.reversed.toList();
    return null;
  }

  // `node` with each `AstRef(variable)` replaced by the literal of the item,
  // or of the field of it that node reads, from `literal`; each node copied
  // costs a step. A node holding no such reference is kept as it is, the
  // same node for every item, and a built-in call kept is marked shared.
  static AstNode _substitute(
    AstNode node,
    String variable,
    AstNode Function(List<String> fields) literal,
    EvaluationContext context,
  ) {
    if (!context.budget.spend(context.reportError)) return AstNull.instance;
    AstNode recurse(AstNode child) => _substitute(child, variable, literal, context);
    switch (node) {
      case AstRef(:final name):
        return name == variable ? literal(const []) : node;
      case AstMember(:final object, :final field):
        if (_loopVariableFields(node, variable) case final fields?) return literal(fields);
        final substituted = recurse(object);
        if (substituted case AstObject(:final entries)) {
          for (final (key, entry) in entries) {
            if (key == field) return entry;
          }
        }
        return identical(substituted, object) ? node : AstMember(substituted, field);
      case AstIndex(:final object, :final index):
        final (newObject, newIndex) = (recurse(object), recurse(index));
        return identical(newObject, object) && identical(newIndex, index) ? node : AstIndex(newObject, newIndex);
      case AstBinary(:final operator, :final left, :final right):
        final (newLeft, newRight) = (recurse(left), recurse(right));
        return identical(newLeft, left) && identical(newRight, right) ? node : AstBinary(operator, newLeft, newRight);
      case AstUnary(:final operator, :final operand):
        final newOperand = recurse(operand);
        return identical(newOperand, operand) ? node : AstUnary(operator, newOperand);
      case AstTernary(:final condition, :final then, :final otherwise):
        final (newCondition, newThen, newOtherwise) = (recurse(condition), recurse(then), recurse(otherwise));
        if (!identical(newCondition, condition) || !identical(newThen, then) || !identical(newOtherwise, otherwise)) {
          return AstTernary(newCondition, newThen, newOtherwise);
        }
        return node;
      case AstArray(:final elements):
        final newElements = [for (final element in elements) recurse(element)];
        return _allIdentical(newElements, elements) ? node : AstArray(newElements);
      case AstObject(:final entries):
        final newEntries = [for (final (key, entry) in entries) (key, recurse(entry))];
        var unchanged = true;
        for (var i = 0; i < entries.length && unchanged; i += 1) {
          unchanged = identical(newEntries[i].$2, entries[i].$2);
        }
        return unchanged ? node : AstObject(newEntries);
      case AstCall(:final name, :final args, :final mappedProps, :final isFunction):
        // An inner `@Each` with the same loop variable shadows this one in
        // its template.
        final shadows =
            name == 'Each' && args.length >= 3 && (args[1] == AstRef(variable) || args[1] == AstString(variable));
        // A mapped prop is usually one of the args: substitute it once.
        final substituted = Map<AstNode, AstNode>.identity();
        AstNode once(AstNode child) => substituted[child] ??= recurse(child);
        final newArgs = [
          for (final (index, arg) in args.indexed)
            if (shadows && index > 0) arg else once(arg),
        ];
        final newProps = mappedProps == null
            ? null
            : {
                for (final MapEntry(:key, value: prop) in mappedProps.entries)
                  key: shadows && node.argIndexOf(prop) != 0 ? prop : once(prop),
              };
        final unchanged =
            _allIdentical(newArgs, args) &&
            (mappedProps == null || mappedProps.entries.every((prop) => identical(newProps![prop.key], prop.value)));
        final budget = context.budget;
        if (unchanged) {
          if (Builtins.functions.containsKey(name)) budget._sharedCalls.add(node);
          return node;
        }
        final copy = AstCall(name, newArgs, mappedProps: newProps, isFunction: isFunction);
        if (_walksList.contains(name)) budget._origins[copy] = budget._origins[node] ?? node;
        return copy;
      case AstAssign(:final target, value: final expression):
        final newExpression = recurse(expression);
        return identical(newExpression, expression) ? node : AstAssign(target, newExpression);
      case AstString() || AstNumber() || AstBool() || AstNull() || AstPlaceholder() || AstStateRef() || AstRuntimeRef():
        return node;
    }
  }

  static bool _allIdentical(List<AstNode> a, List<AstNode> b) {
    for (var i = 0; i < a.length; i += 1) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}

/// Evaluating the props of element trees, as OpenUI's `evaluate-tree.ts`
/// does.
abstract final class PropEvaluator {
  /// The program's entry evaluated, with the runtime errors evaluating it
  /// reported, in the order found.
  ///
  /// The entry is the parsed root, or the component its expression picks
  /// (`root = $t ? A : B`); an expression that picks none reports `no-root`.
  static (ElementNode?, List<OpenUIError>) evaluateRoot(ParseResult? result, EvaluationContext context) {
    final errors = <OpenUIError>[];
    final rootContext = EvaluationContext(
      getState: context.getState,
      resolveRef: context.resolveRef,
      schema: context.schema,
      isBindable: context.isBindable,
      functions: context.functions,
      extraScope: context.extraScope,
    );
    ElementNode? root;
    if (result?.root case final element?) {
      root = _evaluateElement(element, rootContext, errors);
    } else if (result?.rootExpression case final expression?) {
      if (Evaluator.evaluate(expression, rootContext, rootContext._bindable) case OpenUIElement(:final node)) {
        root = _evaluateElement(node, rootContext, errors);
      } else {
        errors.add(
          const OpenUIError(
            source: OpenUIErrorSource.runtime,
            code: OpenUIErrorCode.noRoot,
            message: 'root does not evaluate to a component',
            statementId: 'root',
          ),
        );
      }
    }
    // Ran out where no prop could report it, such as the entry's expression.
    if (rootContext.budget.isExhausted && !rootContext.budget.isReported) {
      errors.add(
        const OpenUIError(
          source: OpenUIErrorSource.runtime,
          code: OpenUIErrorCode.runtimeError,
          message: EvaluationBudget.exceededMessage,
          statementId: 'root',
        ),
      );
    }
    return (root, errors);
  }

  /// `element` with every prop evaluated, problems reported through
  /// `context`.
  static ElementNode evaluateElement(ElementNode element, EvaluationContext context) {
    if (!element.hasDynamicProps) return element;
    return ElementNode(
      typeName: element.typeName,
      props: {
        for (final MapEntry(:key, :value) in element.props.entries)
          if (_evaluateProp(value, context, isBindable: context._isBindable(element.typeName, key), (child) {
                return evaluateElement(child, context);
              })
              case final evaluated?)
            key: evaluated,
      },
      partial: element.partial,
      hasDynamicProps: element.hasDynamicProps,
      statementId: element.statementId,
    );
  }

  static ElementNode _evaluateElement(ElementNode element, EvaluationContext context, List<OpenUIError> errors) {
    if (!element.hasDynamicProps) return element;
    final props = <String, OpenUIValue>{};
    for (final MapEntry(:key, :value) in element.props.entries) {
      final propContext = context.copyWith(
        reportError: (message) => errors.add(
          OpenUIError(
            source: OpenUIErrorSource.runtime,
            code: OpenUIErrorCode.runtimeError,
            message: 'Evaluating prop "$key" on ${element.typeName} failed: $message',
            statementId: element.statementId,
            component: element.typeName,
            hint: 'Check the expression used for prop "$key"',
          ),
        ),
      );
      final evaluated = _evaluateProp(
        value,
        propContext,
        isBindable: context._isBindable(element.typeName, key),
        (child) => _evaluateElement(child, propContext, errors),
      );
      if (evaluated != null) props[key] = evaluated;
    }
    return ElementNode(
      typeName: element.typeName,
      props: props,
      partial: element.partial,
      hasDynamicProps: element.hasDynamicProps,
      statementId: element.statementId,
    );
  }

  // One prop: expressions evaluated (or made bindings), elements walked,
  // plans kept for when they run. Only real calls make custom steps, so a
  // plan read from data loses them.
  static OpenUIValue? _evaluateProp(
    OpenUIValue? value,
    EvaluationContext context,
    ElementNode Function(ElementNode child) walk, {
    required bool isBindable,
  }) {
    final result = _evaluatePropValue(value, context, walk, isBindable: isBindable);
    return result is OpenUIObject && ActionPlan.isPlan(result) ? ActionPlan.ownSteps(result) : result;
  }

  static OpenUIValue? _evaluatePropValue(
    OpenUIValue? value,
    EvaluationContext context,
    ElementNode Function(ElementNode child) walk, {
    required bool isBindable,
  }) {
    switch (value) {
      case null || OpenUINull() || OpenUIBool() || OpenUINumber() || OpenUIString():
        return value;
      case OpenUIExpression(:final node):
        if (isBindable && node is AstStateRef) {
          return ReactiveBinding.marker(node.name, const AstStateRef(Evaluator._valueVariable));
        }
        final result = Evaluator.evaluate(node, context, context._bindable);
        switch (result) {
          case OpenUIElement(node: final element):
            return OpenUIElement(walk(element));
          case OpenUIArray(:final items):
            return OpenUIArray([
              for (final item in items)
                if (item case OpenUIElement(node: final element)) OpenUIElement(walk(element)) else item,
            ]);
          default:
            final target = isBindable ? null : ReactiveBinding.targetOf(result);
            // A binding on a prop that doesn't bind reads the value.
            if (target != null) return context.getState(target) ?? OpenUINull.instance;
            return result;
        }
      case OpenUIArray(:final items):
        return OpenUIArray([
          for (final item in items) _evaluateProp(item, context, walk, isBindable: isBindable) ?? OpenUINull.instance,
        ]);
      case OpenUIElement(node: final element):
        return OpenUIElement(walk(element));
      case OpenUIObject(:final fields):
        // A plan is kept as it is, to run when it's used.
        if (fields['steps'] is OpenUIArray) return value;
        final needsEvaluating = fields.values.any(
          (nested) =>
              nested is OpenUIArray || nested is OpenUIObject || nested is OpenUIElement || nested is OpenUIExpression,
        );
        if (!needsEvaluating) return value;
        return OpenUIObject({
          for (final MapEntry(:key, value: nested) in fields.entries)
            if (_evaluateProp(nested, context, walk, isBindable: isBindable) case final evaluated?) key: evaluated,
        });
    }
  }
}
