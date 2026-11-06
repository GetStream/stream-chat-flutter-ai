/// The expression trees of OpenUI Lang, and its statements.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// An expression of OpenUI Lang, as the parser reads it.
///
/// Literals ([AstString], [AstNumber], [AstBool], [AstNull]), collections
/// ([AstArray], [AstObject]), calls ([AstCall]) and references to statements
/// ([AstRef]) are what programs are mostly made of. A reference the parser
/// couldn't resolve becomes an [AstPlaceholder]. The rest are kept for when the
/// program is evaluated: `$variables` ([AstStateRef]), references to queries
/// and mutations ([AstRuntimeRef]), operators ([AstBinary], [AstUnary],
/// [AstTernary]), member and index reads ([AstMember], [AstIndex]) and
/// assignments ([AstAssign]).
///
/// Nodes are immutable and compare by content.
@immutable
sealed class AstNode {
  const AstNode();

  /// Calls `visit` with this node and then each node under it, depth first.
  ///
  /// A mapped prop of a call that is the same node as one of its arguments is
  /// visited once, as the argument.
  void walk(void Function(AstNode node) visit) {
    final pending = <AstNode>[this];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      visit(node);
      final children = node._childNodes();
      for (var i = children.length - 1; i >= 0; i -= 1) {
        pending.add(children[i]);
      }
    }
  }

  // The nodes directly under this one, in order.
  List<AstNode> _childNodes();

  /// The names of the `$variables` this expression reads, each once, in the
  /// order they first appear.
  ///
  /// The target of an assignment, `$x` in `$x = $y`, is written, not read, so
  /// it isn't listed.
  List<String> stateReferences() {
    final names = <String>{};
    walk((node) {
      if (node case AstStateRef(:final name)) names.add(name);
    });
    return names.toList();
  }
}

/// A call: `Card(…)`, `@Count(rows)`, `Action([…])`, `Query(…)`.
final class AstCall extends AstNode {
  /// Creates the call of [name] with [args].
  ///
  /// The [mappedProps] are the arguments named after the parameters they
  /// fill, once the call is resolved against its library; [isFunction] marks
  /// an `@Name(…)` call whose name is not a built-in.
  AstCall(this.name, Iterable<AstNode> args, {Map<String, AstNode>? mappedProps, this.isFunction = false})
    : args = List.unmodifiable(args),
      mappedProps = mappedProps == null ? null : Map.unmodifiable(mappedProps);

  /// The name called, without its `@`.
  final String name;

  /// The arguments, in the order written.
  final List<AstNode> args;

  /// The arguments named after the parameters they fill, or `null` before the
  /// call is resolved.
  ///
  /// A mapped prop is usually the same node as one of [args].
  final Map<String, AstNode>? mappedProps;

  /// Whether the call was written `@Name(…)` with a name that is not a
  /// built-in, so it calls a function or action of the library.
  final bool isFunction;

  /// The index of the argument that is the same node as `prop`, or `-1` when
  /// `prop` is a node of its own.
  int argIndexOf(AstNode prop) => args.indexWhere((arg) => identical(arg, prop));

  @override
  List<AstNode> _childNodes() {
    final props = mappedProps;
    if (props == null) return args;
    // A mapped prop that is one of the args has been visited as the arg:
    // visiting it again would double the work at every level of nesting.
    final shared = Set<AstNode>.identity()..addAll(args);
    return [
      ...args,
      for (final prop in props.values)
        if (!shared.contains(prop)) prop,
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AstCall) return false;
    if (other.name != name || other.isFunction != isFunction) return false;
    if (!const ListEquality<AstNode>().equals(other.args, args)) return false;
    final props = mappedProps;
    final otherProps = other.mappedProps;
    if (props == null || otherProps == null) return props == null && otherProps == null;
    if (props.length != otherProps.length) return false;
    for (final MapEntry(:key, value: prop) in props.entries) {
      final otherProp = otherProps[key];
      if (otherProp == null) return false;
      final index = argIndexOf(prop);
      // The args are already known to be equal.
      if (index != -1 && index == other.argIndexOf(otherProp)) continue;
      if (prop != otherProp) return false;
    }
    return true;
  }

  // Mapped prop values are left out: one that is an arg is already in the
  // args' hash. The keys are hashed in any order, as `==` compares them.
  @override
  int get hashCode {
    final keys = mappedProps?.keys;
    return Object.hash(
      name,
      const ListEquality<AstNode>().hash(args),
      keys == null ? null : Object.hashAllUnordered(keys),
      isFunction,
    );
  }

  @override
  String toString() => 'AstCall($name, $args${isFunction ? ', function' : ''})';
}

/// A string literal.
final class AstString extends AstNode {
  /// Creates the literal [value].
  const AstString(this.value);

  /// The string.
  final String value;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstString && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AstString($value)';
}

/// A number literal.
final class AstNumber extends AstNode {
  /// Creates the literal [value].
  const AstNumber(this.value);

  /// The number; `NaN` for a literal JavaScript can't read, such as `1e`.
  final double value;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstNumber && JS.sameValueZero(other.value, value);
  }

  @override
  int get hashCode => value.isNaN ? double.nan.hashCode : value.hashCode;

  @override
  String toString() => 'AstNumber($value)';
}

/// `true` or `false`.
final class AstBool extends AstNode {
  /// Creates the literal [value].
  // ignore: avoid_positional_boolean_parameters
  const AstBool(this.value);

  /// Whether this is `true`.
  final bool value;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstBool && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AstBool($value)';
}

/// `null`.
final class AstNull extends AstNode {
  const AstNull._();

  /// The `null` literal.
  static const instance = AstNull._();

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) => other is AstNull;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'AstNull';
}

/// An array literal, `[a, b]`.
final class AstArray extends AstNode {
  /// Creates the array of [elements].
  AstArray(Iterable<AstNode> elements) : elements = List.unmodifiable(elements);

  /// The elements, in order.
  final List<AstNode> elements;

  @override
  List<AstNode> _childNodes() => elements;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstArray && const ListEquality<AstNode>().equals(other.elements, elements);
  }

  @override
  int get hashCode => const ListEquality<AstNode>().hash(elements);

  @override
  String toString() => 'AstArray($elements)';
}

/// An object literal, `{key: value}`.
final class AstObject extends AstNode {
  /// Creates the object with [entries], in order.
  ///
  /// A key may appear more than once; the last one wins when the object is
  /// read as a value.
  AstObject(Iterable<(String, AstNode)> entries) : entries = List.unmodifiable(entries);

  /// The entries, in the order written.
  final List<(String, AstNode)> entries;

  @override
  List<AstNode> _childNodes() => [for (final (_, value) in entries) value];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstObject && const ListEquality<(String, AstNode)>().equals(other.entries, entries);
  }

  @override
  int get hashCode => const ListEquality<(String, AstNode)>().hash(entries);

  @override
  String toString() => 'AstObject($entries)';
}

/// A reference to another statement, by its name.
final class AstRef extends AstNode {
  /// Creates a reference to the statement [name].
  const AstRef(this.name);

  /// The statement's name.
  final String name;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstRef && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AstRef($name)';
}

/// A reference the parser couldn't resolve, which reads as `null`.
final class AstPlaceholder extends AstNode {
  /// Creates the placeholder of the reference to [name].
  const AstPlaceholder(this.name);

  /// The name referenced.
  final String name;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstPlaceholder && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AstPlaceholder($name)';
}

/// A `$variable`.
final class AstStateRef extends AstNode {
  /// Creates a read of the `$variable` [name].
  const AstStateRef(this.name);

  /// The variable's name, with its `$`.
  final String name;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstStateRef && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AstStateRef($name)';
}

/// Whether an [AstRuntimeRef] names a query or a mutation.
enum RuntimeRefType {
  /// A `Query(…)` statement.
  query,

  /// A `Mutation(…)` statement.
  mutation,
}

/// A reference to a `Query` or `Mutation` statement, whose value is the
/// result of its tool call.
final class AstRuntimeRef extends AstNode {
  /// Creates a reference to the statement [name] of [type].
  const AstRuntimeRef(this.name, this.type);

  /// The statement's name.
  final String name;

  /// Whether the statement is a query or a mutation.
  final RuntimeRefType type;

  @override
  List<AstNode> _childNodes() => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstRuntimeRef && other.name == name && other.type == type;
  }

  @override
  int get hashCode => Object.hash(name, type);

  @override
  String toString() => 'AstRuntimeRef($name, ${type.name})';
}

/// A binary operator, such as `a + b` or `x == y`.
final class AstBinary extends AstNode {
  /// Creates [left] [operator] [right].
  const AstBinary(this.operator, this.left, this.right);

  /// The operator as written, `&&` and `||` included.
  final String operator;

  /// The left operand.
  final AstNode left;

  /// The right operand.
  final AstNode right;

  @override
  List<AstNode> _childNodes() => [left, right];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstBinary && other.operator == operator && other.left == left && other.right == right;
  }

  @override
  int get hashCode => Object.hash(operator, left, right);

  @override
  String toString() => 'AstBinary($left $operator $right)';
}

/// A unary operator, `!a` or `-a`.
final class AstUnary extends AstNode {
  /// Creates [operator] [operand].
  const AstUnary(this.operator, this.operand);

  /// The operator, `!` or `-`.
  final String operator;

  /// The operand.
  final AstNode operand;

  @override
  List<AstNode> _childNodes() => [operand];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstUnary && other.operator == operator && other.operand == operand;
  }

  @override
  int get hashCode => Object.hash(operator, operand);

  @override
  String toString() => 'AstUnary($operator$operand)';
}

/// `condition ? then : otherwise`.
final class AstTernary extends AstNode {
  /// Creates [condition] `?` [then] `:` [otherwise].
  const AstTernary(this.condition, this.then, this.otherwise);

  /// The condition.
  final AstNode condition;

  /// The value when [condition] holds.
  final AstNode then;

  /// The value when it doesn't.
  final AstNode otherwise;

  @override
  List<AstNode> _childNodes() => [condition, then, otherwise];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstTernary && other.condition == condition && other.then == then && other.otherwise == otherwise;
  }

  @override
  int get hashCode => Object.hash(condition, then, otherwise);

  @override
  String toString() => 'AstTernary($condition ? $then : $otherwise)';
}

/// A member read, `object.field`.
final class AstMember extends AstNode {
  /// Creates the read of [field] from [object].
  const AstMember(this.object, this.field);

  /// What the field is read from.
  final AstNode object;

  /// The field's name; digits for an array index, such as `0` in `a.0`.
  final String field;

  @override
  List<AstNode> _childNodes() => [object];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstMember && other.object == object && other.field == field;
  }

  @override
  int get hashCode => Object.hash(object, field);

  @override
  String toString() => 'AstMember($object.$field)';
}

/// An index read, `object[index]`.
final class AstIndex extends AstNode {
  /// Creates the read of [index] from [object].
  const AstIndex(this.object, this.index);

  /// What is indexed.
  final AstNode object;

  /// The index.
  final AstNode index;

  @override
  List<AstNode> _childNodes() => [object, index];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstIndex && other.object == object && other.index == index;
  }

  @override
  int get hashCode => Object.hash(object, index);

  @override
  String toString() => 'AstIndex($object[$index])';
}

/// An assignment, `$variable = value`.
final class AstAssign extends AstNode {
  /// Creates the assignment of [value] to [target].
  const AstAssign(this.target, this.value);

  /// The `$variable` assigned, with its `$`.
  final String target;

  /// The value assigned.
  final AstNode value;

  @override
  List<AstNode> _childNodes() => [value];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AstAssign && other.target == target && other.value == value;
  }

  @override
  int get hashCode => Object.hash(target, value);

  @override
  String toString() => 'AstAssign($target = $value)';
}

/// A statement of a program, classified by what it declares.
@immutable
sealed class Statement {
  const Statement(this.id);

  /// The name the statement defines.
  final String id;

  /// The expression the statement's name stands for.
  AstNode get symbol;
}

/// A statement `name = expression` that declares a value.
final class ValueStatement extends Statement {
  /// Creates the statement [id] `=` [expression].
  const ValueStatement(super.id, this.expression);

  /// The value's expression.
  final AstNode expression;

  @override
  AstNode get symbol => expression;
}

/// A statement `$name = expression` that declares a `$variable` and its
/// default.
final class StateStatement extends Statement {
  /// Creates the declaration of [id] with the default [initial].
  const StateStatement(super.id, this.initial);

  /// The default's expression.
  final AstNode initial;

  @override
  AstNode get symbol => initial;
}

/// A statement `name = Query(tool, args, defaults, refresh)`.
final class QueryStatement extends Statement {
  /// Creates the query [id] of [call], whose arguments read [deps].
  const QueryStatement(super.id, this.call, this.deps);

  /// The `Query(…)` call.
  final AstCall call;

  /// The `$variables` its arguments read, or `null` when they read none.
  final List<String>? deps;

  @override
  AstNode get symbol => call;
}

/// A statement `name = Mutation(tool, args)`.
final class MutationStatement extends Statement {
  /// Creates the mutation [id] of [call].
  const MutationStatement(super.id, this.call);

  /// The `Mutation(…)` call.
  final AstCall call;

  @override
  AstNode get symbol => call;
}
