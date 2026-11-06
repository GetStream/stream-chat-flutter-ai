/// Evaluating OpenUI Lang expressions and element trees to values.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';
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
/// template is copied into costs a step; past [maxSteps] values evaluate to
/// nothing and the pass reports one `runtime-error`.
final class EvaluationBudget {
  /// The steps of one pass.
  static const maxSteps = 200000;

  /// The message of the error reported when a pass runs out.
  static const exceededMessage = 'evaluation budget of $maxSteps steps exceeded; the output was cut short';

  int _remaining = maxSteps;
  bool _reported = false;

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
  }) : budget = budget ?? EvaluationBudget();

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

  /// This context with `resolveRef`, `reportError` or `extraScope` replaced.
  EvaluationContext copyWith({
    OpenUIValue? Function(String name)? resolveRef,
    void Function(String message)? reportError,
    Map<String, OpenUIValue>? extraScope,
  }) {
    return EvaluationContext(
      getState: getState,
      resolveRef: resolveRef ?? this.resolveRef,
      schema: schema,
      isBindable: isBindable,
      functions: functions,
      reportError: reportError ?? this.reportError,
      extraScope: extraScope ?? this.extraScope,
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
        return context.getState(name);
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
          return OpenUIArray([for (final item in items) JS.property(item, field) ?? OpenUINull.instance]);
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
      final params = BuiltinCalls.functionParams[name]!;
      final named = node.mappedProps ?? _nameArgs(node.args, params);
      return function([
        for (final param in params)
          if (named[param] case final arg?) evaluate(arg, context) else null,
      ]);
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
    final results = <OpenUIValue>[];
    for (final item in items.items) {
      if (!context.budget.spend(context.reportError)) break;
      final substituted = _substitute(template, variable, item, context);
      final itemContext = context.copyWith(
        resolveRef: (name) => name == variable ? item : context.resolveRef(name),
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

  /// The literal expression of `value`.
  static AstNode literalAst(OpenUIValue? value) {
    return switch (value) {
      null || OpenUINull() => AstNull.instance,
      OpenUIString(:final value) => AstString(value),
      OpenUINumber(:final value) => AstNumber(value),
      OpenUIBool(:final value) => AstBool(value),
      OpenUIArray(:final items) => AstArray([for (final item in items) literalAst(item)]),
      OpenUIObject(:final fields) => AstObject([
        for (final MapEntry(:key, :value) in fields.entries) (key, literalAst(value)),
      ]),
      OpenUIElement() || OpenUIExpression() => literalAst(OpenUIValue.fromJson(plainJson(value))),
    };
  }

  // `node` with each `AstRef(variable)` replaced by the literal of `value`;
  // each node copied costs a step.
  static AstNode _substitute(AstNode node, String variable, OpenUIValue value, EvaluationContext context) {
    if (!context.budget.spend(context.reportError)) return AstNull.instance;
    AstNode recurse(AstNode child) => _substitute(child, variable, value, context);
    switch (node) {
      case AstRef(:final name):
        return name == variable ? literalAst(value) : node;
      case AstMember(:final object, :final field):
        final substituted = recurse(object);
        if (substituted case AstObject(:final entries)) {
          for (final (key, entry) in entries) {
            if (key == field) return entry;
          }
        }
        return AstMember(substituted, field);
      case AstIndex(:final object, :final index):
        return AstIndex(recurse(object), recurse(index));
      case AstBinary(:final operator, :final left, :final right):
        return AstBinary(operator, recurse(left), recurse(right));
      case AstUnary(:final operator, :final operand):
        return AstUnary(operator, recurse(operand));
      case AstTernary(:final condition, :final then, :final otherwise):
        return AstTernary(recurse(condition), recurse(then), recurse(otherwise));
      case AstArray(:final elements):
        return AstArray([for (final element in elements) recurse(element)]);
      case AstObject(:final entries):
        return AstObject([for (final (key, entry) in entries) (key, recurse(entry))]);
      case AstCall(:final name, :final args, :final mappedProps, :final isFunction):
        // An inner `@Each` with the same loop variable shadows this one in
        // its template.
        final shadows =
            name == 'Each' && args.length >= 3 && (args[1] == AstRef(variable) || args[1] == AstString(variable));
        // A mapped prop is usually one of the args: substitute it once.
        final substituted = Map<AstNode, AstNode>.identity();
        AstNode once(AstNode child) => substituted[child] ??= recurse(child);
        return AstCall(
          name,
          [
            for (final (index, arg) in args.indexed)
              if (shadows && index > 0) arg else once(arg),
          ],
          mappedProps: mappedProps == null
              ? null
              : {
                  for (final MapEntry(:key, value: prop) in mappedProps.entries)
                    key: shadows && node.argIndexOf(prop) != 0 ? prop : once(prop),
                },
          isFunction: isFunction,
        );
      case AstAssign(:final target, value: final expression):
        return AstAssign(target, recurse(expression));
      case AstString() || AstNumber() || AstBool() || AstNull() || AstPlaceholder() || AstStateRef() || AstRuntimeRef():
        return node;
    }
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
