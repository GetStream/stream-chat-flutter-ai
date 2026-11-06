/// Resolving a program's statements into a tree of components.
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
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// The resolver of a program's statements, which turns them, in one pass,
/// into what the program renders.
///
/// Resolving follows references into the statements they name, maps each
/// component call's positional arguments to the props its library names,
/// checks them against the library's schema, and turns literals into values.
/// What only evaluating can decide — `$variables`, operators, built-in and
/// library calls — is kept as an expression.
abstract final class Materializer {
  /// How deep resolving goes, references included; past it a node is `null`.
  ///
  /// Resolving recurses once per level, so a chain of references or brackets
  /// deeper than any real program reads as `null` instead of running out of
  /// stack.
  static const maxDepth = 256;

  /// How many nodes one pass resolves; past it nodes are `null`.
  ///
  /// Every use of a reference counts its statement's nodes again. Statements
  /// that each use the previous one twice double the work at every level, so
  /// this keeps such a program from exhausting memory or time; it is far more
  /// than any chat reply holds.
  static const maxNodes = 20000;

  // The arguments of `@Each`: the array, the loop variable and the template.
  static const _eachArgumentCount = 3;

  /// Whether `value` holds something that evaluating decides: an expression
  /// anywhere in it, or an object with a `steps` list.
  ///
  /// An object with a `steps` list counts, so data can't pass for the action
  /// steps a program writes.
  static bool containsDynamicValue(OpenUIValue value) {
    return switch (value) {
      OpenUIExpression() => true,
      OpenUIArray(:final items) => items.any(containsDynamicValue),
      // An element already knows: scanning its props again at every level of
      // nesting would be quadratic.
      OpenUIElement(:final node) => node.hasDynamicProps,
      OpenUIObject(:final fields) => _isDynamicObject(fields),
      OpenUINull() || OpenUIBool() || OpenUINumber() || OpenUIString() => false,
    };
  }

  static bool _isDynamicObject(Map<String, OpenUIValue> fields) {
    if (fields['steps'] is OpenUIArray) return true;
    return fields.values.any(containsDynamicValue);
  }

  /// What `node` resolves to as a prop value: an element for a component
  /// call, an expression for what evaluating decides, a plain value for a
  /// literal, and `null` for what can't be resolved.
  static OpenUIValue materializeValue(AstNode node, MaterializeContext context) {
    if (!_enter(context)) return OpenUINull.instance;
    try {
      return _lowerValue(node, context);
    } finally {
      context.depth -= 1;
    }
  }

  /// `node` made ready for evaluating: references resolved, and the
  /// arguments of component and library calls named after their parameters.
  ///
  /// The names in `scoped` are loop variables, which stay references.
  static AstNode materializeExpression(AstNode node, MaterializeContext context, [Set<String> scoped = const {}]) {
    if (!_enter(context)) return AstNull.instance;
    try {
      return _lowerExpression(node, context, scoped);
    } finally {
      context.depth -= 1;
    }
  }

  // Counts a node against the depth and node budgets, entering it; false,
  // without entering, when it is past either.
  static bool _enter(MaterializeContext context) {
    if (context.depth >= maxDepth || context.nodes >= maxNodes) return false;
    context
      ..depth += 1
      ..nodes += 1;
    return true;
  }

  static OpenUIValue _lowerValue(AstNode node, MaterializeContext context) {
    switch (node) {
      case AstRef(:final name):
        return _resolveRef(name, context, asExpression: false);
      case AstString(:final value):
        return OpenUIString(value);
      case AstNumber(:final value):
        return OpenUINumber(value);
      case AstBool(:final value):
        return OpenUIBool(value);
      case AstNull() || AstPlaceholder():
        return OpenUINull.instance;
      case AstArray(:final elements):
        final items = <OpenUIValue>[];
        for (final element in elements) {
          if (element is AstPlaceholder) continue;
          final value = materializeValue(element, context);
          // A reference or call that resolves to null leaves no hole: an
          // unresolved reference, a dropped component, a statement that is
          // null. A `null` written in the array stays.
          if (value is OpenUINull && (element is AstCall || element is AstRef)) continue;
          items.add(value);
        }
        return OpenUIArray(items);
      case AstObject(:final entries):
        return OpenUIObject({for (final (key, value) in entries) key: materializeValue(value, context)});
      case AstCall():
        return _lowerCallValue(node, context);
      case AstStateRef() || AstRuntimeRef() || AstBinary() || AstUnary() || AstTernary() || AstMember():
        return OpenUIExpression(materializeExpression(node, context));
      case AstIndex() || AstAssign():
        return OpenUIExpression(materializeExpression(node, context));
    }
  }

  static OpenUIValue _lowerCallValue(AstCall node, MaterializeContext context) {
    if (_isUnknownFunction(node, context)) return OpenUINull.instance;
    if (BuiltinCalls.isReservedCall(node.name)) {
      context.report(OpenUIErrorCode.inlineReserved, node.name, '', SchemaValidation.inlineReservedMessage(node.name));
      return OpenUINull.instance;
    }
    if (_isRuntimeCall(node.name, context)) {
      final lowered =
          _materializeLazyBuiltin(node, context, const {}) ??
          _materializeCall(node, context, (arg) => materializeExpression(arg, context));
      return OpenUIExpression(lowered);
    }
    return _materializeComponent(node, context);
  }

  static AstNode _lowerExpression(AstNode node, MaterializeContext context, Set<String> scoped) {
    AstNode recurse(AstNode child) => materializeExpression(child, context, scoped);
    switch (node) {
      case AstRef(:final name):
        if (scoped.contains(name)) return node;
        return switch (_resolveRef(name, context, asExpression: true)) {
          OpenUIExpression(node: final resolved) => resolved,
          _ => AstNull.instance,
        };
      case AstCall():
        return _lowerCallExpression(node, context, scoped);
      case AstArray(:final elements):
        return AstArray(elements.map(recurse));
      case AstObject(:final entries):
        return AstObject([for (final (key, value) in entries) (key, recurse(value))]);
      case AstBinary(:final operator, :final left, :final right):
        return AstBinary(operator, recurse(left), recurse(right));
      case AstUnary(:final operator, :final operand):
        return AstUnary(operator, recurse(operand));
      case AstTernary(:final condition, :final then, :final otherwise):
        return AstTernary(recurse(condition), recurse(then), recurse(otherwise));
      case AstMember(:final object, :final field):
        return AstMember(recurse(object), field);
      case AstIndex(:final object, :final index):
        return AstIndex(recurse(object), recurse(index));
      case AstAssign(:final target, :final value):
        return AstAssign(target, recurse(value));
      case AstString() || AstNumber() || AstBool() || AstNull() || AstPlaceholder() || AstStateRef() || AstRuntimeRef():
        return node;
    }
  }

  static AstNode _lowerCallExpression(AstCall node, MaterializeContext context, Set<String> scoped) {
    if (_isUnknownFunction(node, context)) return AstNull.instance;
    if (_materializeLazyBuiltin(node, context, scoped) case final lazy?) return lazy;
    if (_isRuntimeCall(node.name, context)) {
      return _materializeCall(node, context, (arg) => materializeExpression(arg, context, scoped));
    }
    final args = [for (final arg in node.args) materializeExpression(arg, context, scoped)];
    final params = context.schema.paramsOf(node.name);
    if (params != null) {
      return AstCall(
        node.name,
        args,
        mappedProps: {for (var i = 0; i < params.length && i < args.length; i += 1) params[i].name: args[i]},
      );
    }
    context.report(
      OpenUIErrorCode.unknownComponent,
      node.name,
      '',
      SchemaValidation.unknownComponentMessage(node.name, context.schema.componentNames),
    );
    return AstCall(node.name, args, mappedProps: node.mappedProps, isFunction: node.isFunction);
  }

  // An `@Name(…)` call that nothing defines is reported, and reads as null.
  static bool _isUnknownFunction(AstCall node, MaterializeContext context) {
    if (!node.isFunction || _isRuntimeCall(node.name, context)) return false;
    context.report(OpenUIErrorCode.unknownFunction, node.name, '', SchemaValidation.unknownFunctionMessage(node.name));
    return true;
  }

  // Calls evaluating runs, which stay expressions: functions, action steps and
  // the reserved `Query` and `Mutation`.
  static bool _isRuntimeCall(String name, MaterializeContext context) {
    if (context.schema.callOf(name) != null) return true;
    return BuiltinCalls.isReservedCall(name);
  }

  // Resolves the reference to [name]: the statement's value, or, for a query
  // or mutation, a reference evaluating resolves. A reference to nothing, or
  // back to a statement being resolved, is unresolved: `null` as a value, a
  // placeholder in an expression.
  static OpenUIValue _resolveRef(String name, MaterializeContext context, {required bool asExpression}) {
    final target = context.visited.contains(name) ? null : context.symbols[name];
    if (target == null) {
      context.unresolved.add(name);
      return asExpression ? OpenUIExpression(AstPlaceholder(name)) : OpenUINull.instance;
    }
    context.unreached.remove(name);
    if (target is AstCall && BuiltinCalls.isReservedCall(target.name)) {
      final type = target.name == BuiltinCalls.mutation ? RuntimeRefType.mutation : RuntimeRefType.query;
      return OpenUIExpression(AstRuntimeRef(name, type));
    }
    context.visited.add(name);
    final previousStatementId = context.currentStatementId;
    context.currentStatementId = name;
    try {
      if (asExpression) return OpenUIExpression(materializeExpression(target, context));
      return switch (materializeValue(target, context)) {
        OpenUIElement(:final node) => OpenUIElement(node.withStatementId(name)),
        final value => value,
      };
    } finally {
      context.currentStatementId = previousStatementId;
      context.visited.remove(name);
    }
  }

  // `@Each(array, varName, template)`: resolves the arguments with the loop
  // variable kept a reference, so the template can read it. `null` unless
  // `node` calls a lazy built-in function with at least three arguments, the
  // second a non-empty name.
  static AstNode? _materializeLazyBuiltin(AstCall node, MaterializeContext context, Set<String> scoped) {
    final definition = context.schema.callOf(node.name);
    if (definition == null || definition.kind != CallKind.function || !definition.isLazy) return null;
    if (node.args.length < _eachArgumentCount) return null;
    final variable = switch (node.args[1]) {
      AstRef(:final name) => name,
      AstString(:final value) => value,
      _ => null,
    };
    if (variable == null || variable.isEmpty) return null;
    final inner = {...scoped, variable};
    return AstCall(node.name, [
      for (final (index, arg) in node.args.indexed)
        if (index == 1) arg else materializeExpression(arg, context, inner),
    ]);
  }

  // `@Percent(3, total)`: the args resolved, and named after the parameters.
  // A library call is checked first; an invalid function reads as null, and an
  // invalid action step does nothing.
  static AstNode _materializeCall(AstCall node, MaterializeContext context, AstNode Function(AstNode) materializeArg) {
    final args = [for (final arg in node.args) materializeArg(arg)];
    final definition = context.schema.callOf(node.name);
    if (definition == null || definition.isLazy) {
      return AstCall(node.name, args, mappedProps: node.mappedProps, isFunction: node.isFunction);
    }
    final mapped = definition.isBuiltin
        ? _nameArgs(args, definition.params)
        : _mapCallArgs(node.name, args, definition, context);
    if (mapped != null) return AstCall(node.name, args, mappedProps: mapped, isFunction: node.isFunction);
    if (definition.kind == CallKind.action) return AstCall(BuiltinCalls.action, [AstArray(const [])]);
    return AstNull.instance;
  }

  // [args] named after [params] in order; extra args are left out.
  static Map<String, AstNode> _nameArgs(List<AstNode> args, List<ParamDef> params) {
    return {for (var i = 0; i < params.length && i < args.length; i += 1) params[i].name: args[i]};
  }

  // A library call's args named after its params, with the literal ones
  // checked like props; `null` when the call is invalid. References, calls and
  // expressions are checked when the call runs.
  static Map<String, AstNode>? _mapCallArgs(
    String name,
    List<AstNode> args,
    CallDef definition,
    MaterializeContext context,
  ) {
    final params = definition.params;
    if (args.length > params.length) {
      context.report(
        OpenUIErrorCode.excessArgs,
        name,
        '',
        SchemaValidation.excessArgsMessage(name, params.length, args.length),
      );
    }
    final mapped = _nameArgs(args, params);
    final errorsBefore = context.errors.length;
    var invalid = false;
    for (final param in params) {
      final arg = mapped[param.name];
      final OpenUIValue? literal;
      if (arg == null) {
        literal = null;
      } else {
        final value = literalValue(arg);
        if (value == null) continue;
        literal = value;
      }
      if (literal == null || literal is OpenUINull) {
        if (!param.required || param.defaultValue != null) continue;
        final path = '/${param.name}';
        final signature = SchemaValidation.paramsSignature(name, params);
        if (arg == null) {
          context.report(
            OpenUIErrorCode.missingRequired,
            name,
            path,
            SchemaValidation.missingRequiredMessage(path, signature),
          );
        } else {
          context.report(
            OpenUIErrorCode.nullRequired,
            name,
            path,
            SchemaValidation.nullRequiredMessage(path, signature),
          );
        }
        invalid = true;
        continue;
      }
      var next = SchemaValidation.validate(literal, param.schema, name, '/${param.name}', context);
      if (next.isInvalid) {
        next = SchemaValidation.resolveInvalid(required: param.required, defaultValue: param.defaultValue);
      }
      if (next.isInvalid) {
        invalid = true;
      } else if (next.value case final kept?) {
        if (!identical(kept, literal)) mapped[param.name] = literalAst(kept);
      } else {
        mapped.remove(param.name);
      }
    }
    // An action never runs with a value the model didn't write.
    if (definition.kind == CallKind.action && context.errors.length > errorsBefore) invalid = true;
    return invalid ? null : mapped;
  }

  /// The arguments of the calls inside a `Query` or `Mutation` statement's
  /// `args`, named after their parameters, with errors attributed to
  /// `statementId`.
  ///
  /// A library call's literal arguments are checked like props; an invalid
  /// call keeps its arguments named, and reads as `null` when it runs.
  static List<AstNode> nameRawCallArgs(List<AstNode> args, MaterializeContext context, String statementId) {
    final previousStatementId = context.currentStatementId;
    context.currentStatementId = statementId;
    try {
      return [for (final arg in args) _nameCallArgs(arg, context)];
    } finally {
      context.currentStatementId = previousStatementId;
    }
  }

  static AstNode _nameCallArgs(AstNode node, MaterializeContext context) {
    AstNode recurse(AstNode child) => _nameCallArgs(child, context);
    switch (node) {
      case AstCall(:final name, :final args, :final mappedProps, :final isFunction):
        final definition = context.schema.callOf(name);
        // A call is checked before the calls in its arguments, so its errors
        // come first.
        final checked = definition == null || definition.isLazy || definition.isBuiltin
            ? null
            : _mapCallArgs(name, args, definition, context);
        // Each arg is named once and shared with the mapped props: naming it
        // again for the props would double the work at every level.
        final named = [for (final arg in args) recurse(arg)];
        AstNode shared(AstNode prop, AstNode Function(AstNode) otherwise) {
          final index = node.argIndexOf(prop);
          return index == -1 ? otherwise(prop) : named[index];
        }

        final Map<String, AstNode>? props;
        if (definition == null || definition.isLazy) {
          props = mappedProps?.map((key, prop) => MapEntry(key, shared(prop, recurse)));
        } else {
          final mapped = checked ?? _nameArgs(args, definition.params);
          props = mapped.map((key, prop) => MapEntry(key, shared(prop, (it) => it)));
        }
        return AstCall(name, named, mappedProps: props, isFunction: isFunction);
      case AstArray(:final elements):
        return AstArray(elements.map(recurse));
      case AstObject(:final entries):
        return AstObject([for (final (key, value) in entries) (key, recurse(value))]);
      case AstBinary(:final operator, :final left, :final right):
        return AstBinary(operator, recurse(left), recurse(right));
      case AstUnary(:final operator, :final operand):
        return AstUnary(operator, recurse(operand));
      case AstTernary(:final condition, :final then, :final otherwise):
        return AstTernary(recurse(condition), recurse(then), recurse(otherwise));
      case AstMember(:final object, :final field):
        return AstMember(recurse(object), field);
      case AstIndex(:final object, :final index):
        return AstIndex(recurse(object), recurse(index));
      case AstAssign(:final target, :final value):
        return AstAssign(target, recurse(value));
      case AstString() || AstNumber() || AstBool() || AstNull() || AstRef() || AstPlaceholder() || AstStateRef():
        return node;
      case AstRuntimeRef():
        return node;
    }
  }

  // A component call: props from its positional args, each checked against
  // its schema, then its required props. `null` when the library has no such
  // component, or a required prop is missing or can't be kept.
  static OpenUIValue _materializeComponent(AstCall node, MaterializeContext context) {
    final name = node.name;
    final args = node.args;
    final params = context.schema.paramsOf(name);
    if (params == null) {
      context.report(
        OpenUIErrorCode.unknownComponent,
        name,
        '',
        SchemaValidation.unknownComponentMessage(name, context.schema.componentNames),
      );
      return OpenUINull.instance;
    }

    final props = <String, OpenUIValue>{};
    var dropComponent = false;
    for (var i = 0; i < params.length && i < args.length; i += 1) {
      final param = params[i];
      final value = materializeValue(args[i], context);
      props[param.name] = value;
      if (param.schema == null) continue;
      var next = SchemaValidation.validate(value, param.schema, name, '/${param.name}', context);
      if (next.isInvalid) {
        next = SchemaValidation.resolveInvalid(required: param.required, defaultValue: param.defaultValue);
        if (next.isInvalid) {
          dropComponent = true;
          continue;
        }
      }
      if (next.value case final kept?) {
        props[param.name] = kept;
      } else {
        props.remove(param.name);
      }
    }

    if (args.length > params.length) {
      context.report(
        OpenUIErrorCode.excessArgs,
        name,
        '',
        SchemaValidation.excessArgsMessage(name, params.length, args.length),
      );
    }

    final missing = [
      for (final param in params)
        if (param.required && (props[param.name] == null || props[param.name] is OpenUINull)) param,
    ];
    final stillMissing = <ParamDef>[];
    for (final param in missing) {
      if (param.defaultValue case final fallback?) {
        props[param.name] = fallback;
      } else {
        stillMissing.add(param);
      }
    }
    if (stillMissing.isNotEmpty) {
      final signature = SchemaValidation.paramsSignature(name, params);
      for (final param in stillMissing) {
        final path = '/${param.name}';
        if (props.containsKey(param.name)) {
          context.report(
            OpenUIErrorCode.nullRequired,
            name,
            path,
            SchemaValidation.nullRequiredMessage(path, signature),
          );
        } else {
          context.report(
            OpenUIErrorCode.missingRequired,
            name,
            path,
            SchemaValidation.missingRequiredMessage(path, signature),
          );
        }
      }
      return OpenUINull.instance;
    }
    if (dropComponent) return OpenUINull.instance;

    return OpenUIElement(
      ElementNode(
        typeName: name,
        props: props,
        partial: context.partial,
        hasDynamicProps: props.values.any(containsDynamicValue),
      ),
    );
  }

  /// The value of `node` when it is a literal, such as `{n: [1]}`; `null`
  /// when it holds a reference, call or expression.
  static OpenUIValue? literalValue(AstNode node) {
    switch (node) {
      case AstString(:final value):
        return OpenUIString(value);
      case AstNumber(:final value):
        return OpenUINumber(value);
      case AstBool(:final value):
        return OpenUIBool(value);
      case AstNull():
        return OpenUINull.instance;
      case AstArray(:final elements):
        final items = <OpenUIValue>[];
        for (final element in elements) {
          final item = literalValue(element);
          if (item == null) return null;
          items.add(item);
        }
        return OpenUIArray(items);
      case AstObject(:final entries):
        final fields = <String, OpenUIValue>{};
        for (final (key, element) in entries) {
          final item = literalValue(element);
          if (item == null) return null;
          fields[key] = item;
        }
        return OpenUIObject(fields);
      case AstCall() || AstRef() || AstPlaceholder() || AstStateRef() || AstRuntimeRef() || AstBinary():
        return null;
      case AstUnary() || AstTernary() || AstMember() || AstIndex() || AstAssign():
        return null;
    }
  }

  /// The literal expression of `value`, such as `{n: [1]}` for an object
  /// holding a list; elements and expressions become `null`.
  static AstNode literalAst(OpenUIValue value) {
    return switch (value) {
      OpenUIString(:final value) => AstString(value),
      OpenUINumber(:final value) => AstNumber(value),
      OpenUIBool(:final value) => AstBool(value),
      OpenUIArray(:final items) => AstArray(items.map(literalAst)),
      OpenUIObject(:final fields) => AstObject([
        for (final MapEntry(:key, :value) in fields.entries) (key, literalAst(value)),
      ]),
      OpenUINull() || OpenUIElement() || OpenUIExpression() => AstNull.instance,
    };
  }
}
