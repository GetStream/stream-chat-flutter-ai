/// Checking a program's values against the library's JSON Schema.
///
/// Internal to the package.
@internal
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materialization_cache.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// What one pass of resolving a program's statements shares: the statements,
/// the library, and what the pass has found.
final class MaterializeContext {
  /// Creates the context of a pass over [symbols] against [schema].
  ///
  /// When [partial], the program was cut short, so checks that more text
  /// could still satisfy are skipped. [currentStatementId] is the statement
  /// read first, and [unreached] the value statements to track as orphans.
  MaterializeContext({
    required this.symbols,
    required this.schema,
    required this.partial,
    required this.currentStatementId,
    required Iterable<String> unreached,
    this.cache,
  }) : unreached = LinkedHashSet.of(unreached);

  /// What earlier passes resolved each statement to, reused while it still
  /// holds, or `null` when nothing is kept between passes.
  final MaterializationCache? cache;

  /// The expression each statement's name stands for.
  final Map<String, AstNode> symbols;

  /// The library the program is read against.
  final OpenUILibrarySchema schema;

  /// Whether the program was cut short.
  final bool partial;

  /// The statement being resolved, which errors are attributed to.
  String? currentStatementId;

  /// The value statements no reference has reached yet, in program order.
  final LinkedHashSet<String> unreached;

  /// The problems found so far.
  final List<ValidationError> errors = [];

  /// The references that couldn't be resolved so far, once per use.
  final List<String> unresolved = [];

  /// The statements being resolved; a reference back to one of them is a
  /// cycle.
  final Set<String> visited = {};

  /// How deep resolving has gone, references included.
  int depth = 0;

  /// How many nodes have been resolved, each use of a reference counted again.
  int nodes = 0;

  /// How many nodes this pass resolved itself rather than reused.
  ///
  /// Only the tests read it.
  int debugResolvedNodes = 0;

  /// How many references led back to a statement being resolved.
  int cycles = 0;

  /// How many nodes were left out for being past the depth or node budget.
  int truncations = 0;

  /// The deepest level resolving has reached since the statement being
  /// resolved started.
  int deepest = 0;

  /// The statements looked up, in order, with the version each had, kept
  /// only with a [cache].
  final List<StatementRead> reads = [];

  /// The statements reached, in order, kept only with a [cache].
  final List<String> reachedLog = [];

  /// The expression of the statement named `name`, or `null` when nothing
  /// defines it.
  AstNode? lookUp(String name) {
    if (cache case final cache?) reads.add((name: name, version: cache.versions[name]));
    return symbols[name];
  }

  /// Marks the statement named `name` as reached, so it isn't an orphan.
  void markReached(String name) {
    unreached.remove(name);
    if (cache != null) reachedLog.add(name);
  }

  /// Records `code` in `component` at `path`, attributed to
  /// [currentStatementId].
  void report(OpenUIErrorCode code, String component, String path, String message, {bool isWarning = false}) {
    errors.add(
      ValidationError(
        code: code,
        component: component,
        path: path,
        message: message,
        statementId: currentStatementId,
        isWarning: isWarning,
      ),
    );
  }
}

/// What checking a value against a schema fragment gives: the value to keep,
/// possibly a cleaned copy, or invalid.
@immutable
final class Checked {
  /// Keeps [value]; `null` drops it.
  const Checked.keep(this.value) : isInvalid = false;

  const Checked._invalid() : value = null, isInvalid = true;

  /// A value nothing can be kept of.
  static const invalid = Checked._invalid();

  /// The value to keep, or `null` to drop it.
  final OpenUIValue? value;

  /// Whether the value can't be kept, so the one holding it decides.
  final bool isInvalid;
}

/// The checks of a program's values against the JSON Schema of the library,
/// and the messages of the problems they find.
abstract final class SchemaValidation {
  // The keywords of a shape made of other shapes.
  static const _compositeKeywords = [r'$ref', 'anyOf', 'oneOf', 'allOf'];

  /// The `default` of the JSON Schema fragment `property`, or `null` when it
  /// has none.
  static OpenUIValue? defaultValue(OpenUIValue? property) {
    return property is OpenUIObject ? property.fields['default'] : null;
  }

  /// The type of `property` as a signature writes it: a `$ref`'s name, an
  /// enum's values such as `"a"|"b"`, or its `type` (`integer` as `number`);
  /// `null` when it has none of these.
  static String? typeDescription(OpenUIValue? property) {
    if (property is! OpenUIObject) return null;
    final schema = property.fields;
    if (_refName(schema) case final ref?) return ref;
    final (expectedType, enumValues) = _scalarTypeInfo(schema);
    if (enumValues != null) return enumValues.map(JS.jsonStringify).join('|');
    if (expectedType != null) return expectedType;
    return switch (schema['type']) {
      OpenUIString(:final value) => value,
      _ => null,
    };
  }

  /// The signature of `component` taking `params`, such as
  /// `Header(title*: string, variant: "a"|"b")`, where `*` marks a required
  /// argument.
  static String paramsSignature(String component, List<ParamDef> params) {
    final rendered = [
      for (final param in params)
        switch (typeDescription(param.schema)) {
          final type? => '${param.required ? '${param.name}*' : param.name}: $type',
          null => param.required ? '${param.name}*' : param.name,
        },
    ];
    return '$component(${rendered.join(', ')})';
  }

  /// The message of a value of the wrong kind at `path`.
  static String typeMismatchMessage(String path, String expected, String actual) {
    return 'field "$path" expects $expected but got $actual';
  }

  /// The message of a missing required argument at `path`, with the
  /// component's `signature` when known.
  static String missingRequiredMessage(String path, String? signature) {
    return 'missing required field "$path"${signature == null ? '' : ' — signature: $signature'}';
  }

  /// The message of a required argument that is `null`, at `path`, with the
  /// component's `signature` when known.
  static String nullRequiredMessage(String path, String? signature) {
    return 'required field "$path" cannot be null${signature == null ? '' : ' — signature: $signature'}';
  }

  /// The message of a call of `component`, which the library doesn't have,
  /// listing the `available` components.
  static String unknownComponentMessage(String component, List<String> available) {
    final list = available.isEmpty ? '' : '. Available components: ${available.join(', ')}';
    return 'Unknown component "$component" — not found in catalog or builtins$list';
  }

  /// The message of a `Query` or `Mutation` written inside a value.
  static String inlineReservedMessage(String component) {
    return '$component() must be declared as a top-level statement, not used inline as a value';
  }

  /// The message of a call of `component` with `got` arguments where it takes
  /// `declared`.
  static String excessArgsMessage(String component, int declared, int got) {
    return '$component takes $declared arg(s), got $got (${got - declared} excess dropped)';
  }

  /// The message of an `@Name(…)` call of `component` that nothing defines.
  static String unknownFunctionMessage(String component) {
    return 'Unknown function "@$component": not a built-in or action step. The call evaluates to null';
  }

  /// What becomes of a value that failed its check: its `defaultValue` when
  /// there is one, invalid when it is `required`, and dropped otherwise.
  static Checked resolveInvalid({required bool required, required OpenUIValue? defaultValue}) {
    if (defaultValue != null) return Checked.keep(defaultValue);
    if (required) return Checked.invalid;
    return const Checked.keep(null);
  }

  /// `value` checked against the JSON Schema fragment `schema`, for an
  /// argument of `component` at `path`.
  ///
  /// Every violation is reported. A value that can't be kept is invalid, and
  /// [resolveInvalid] decides what becomes of it one level up; items of an
  /// array that can't be kept are dropped. A component in a slot for plain
  /// data is invalid, and so is data in a slot only components fill. An
  /// expression, `null`, or a value for a composite shape (`$ref`, `anyOf`,
  /// `oneOf`, `allOf`) that isn't a slot only components fill is kept as it
  /// is. While the program is cut short, required keys and enum values aren't
  /// checked, since more text could still satisfy them.
  ///
  /// The value comes back unchanged, the same instance, when nothing about it
  /// changes.
  static Checked validate(
    OpenUIValue? value,
    OpenUIValue? schema,
    String component,
    String path,
    MaterializeContext context,
  ) {
    if (schema is! OpenUIObject) return Checked.keep(value);
    final keywords = schema.fields;
    if (value == null || value is OpenUINull || value is OpenUIExpression) return Checked.keep(value);
    if (value case OpenUIElement(:final node)) {
      return _isElementMisplaced(node, keywords, component, path, context) ? Checked.invalid : Checked.keep(value);
    }
    if (_isComposite(keywords)) {
      if (!_isOnlyComponentSlot(keywords, context)) return Checked.keep(value);
      final actual = switch (value) {
        OpenUIArray() => 'array',
        OpenUIObject() => 'plain object',
        OpenUINull() ||
        OpenUIBool() ||
        OpenUINumber() ||
        OpenUIString() ||
        OpenUIElement() ||
        OpenUIExpression() => JS.typeOf(value),
      };
      final expected = _slotRefNames(keywords).map((name) => name ?? '').join(' | ');
      context.report(OpenUIErrorCode.typeMismatch, component, path, typeMismatchMessage(path, expected, actual));
      return Checked.invalid;
    }
    return switch (keywords['type']) {
      OpenUIString(value: 'object') => _validateObject(value, keywords, component, path, context),
      OpenUIString(value: 'array') => _validateArray(value, keywords, component, path, context),
      _ => _isLeafInvalid(value, keywords, component, path, context) ? Checked.invalid : Checked.keep(value),
    };
  }

  static bool _isElementMisplaced(
    ElementNode element,
    Map<String, OpenUIValue> schema,
    String component,
    String path,
    MaterializeContext context,
  ) {
    if (_isComposite(schema)) return false;
    final type = switch (schema['type']) {
      OpenUIString(:final value) => value,
      _ => null,
    };
    if (type == null && schema['enum'] is! OpenUIArray && !schema.containsKey('const')) return false;
    final message = typeMismatchMessage(path, type ?? 'a literal value', 'component "${element.typeName}"');
    context.report(OpenUIErrorCode.typeMismatch, component, path, message);
    return true;
  }

  static Checked _validateObject(
    OpenUIValue value,
    Map<String, OpenUIValue> schema,
    String component,
    String path,
    MaterializeContext context,
  ) {
    if (value is! OpenUIObject) {
      final message = typeMismatchMessage(path, 'object', JS.jsType(value));
      context.report(OpenUIErrorCode.typeMismatch, component, path, message);
      return Checked.invalid;
    }
    final fields = value.fields;
    final properties = switch (schema['properties']) {
      OpenUIObject(:final fields) => fields,
      _ => const <String, OpenUIValue>{},
    };
    final required = switch (schema['required']) {
      OpenUIArray(:final items) => [
        for (final item in items)
          if (item case OpenUIString(:final value)) value,
      ],
      _ => const <String>[],
    };
    Map<String, OpenUIValue>? out;
    var invalid = false;
    // Required keys may still arrive while the program streams in.
    if (!context.partial) {
      for (final key in required) {
        final present = fields.containsKey(key);
        if (present && fields[key] is! OpenUINull) continue;
        if (defaultValue(properties[key]) case final fallback?) {
          (out ??= {...fields})[key] = fallback;
          continue;
        }
        final keyPath = '$path/$key';
        final message = present ? nullRequiredMessage(keyPath, null) : missingRequiredMessage(keyPath, null);
        context.report(
          present ? OpenUIErrorCode.nullRequired : OpenUIErrorCode.missingRequired,
          component,
          keyPath,
          message,
        );
        invalid = true;
      }
    }
    for (final MapEntry(:key, value: subschema) in properties.entries) {
      if (!fields.containsKey(key)) continue;
      final original = fields[key];
      var next = validate(original, subschema, component, '$path/$key', context);
      if (next.isInvalid) {
        next = resolveInvalid(required: required.contains(key), defaultValue: defaultValue(subschema));
        if (next.isInvalid) {
          invalid = true;
          continue;
        }
      }
      if (identical(next.value, original)) continue;
      out ??= {...fields};
      if (next.value case final kept?) {
        out[key] = kept;
      } else {
        out.remove(key);
      }
    }
    if (invalid) return Checked.invalid;
    return Checked.keep(out == null ? value : OpenUIObject(out));
  }

  static Checked _validateArray(
    OpenUIValue value,
    Map<String, OpenUIValue> schema,
    String component,
    String path,
    MaterializeContext context,
  ) {
    if (value is! OpenUIArray) {
      final message = typeMismatchMessage(path, 'array', JS.jsType(value));
      context.report(OpenUIErrorCode.typeMismatch, component, path, message);
      return Checked.invalid;
    }
    final itemSchema = schema['items'];
    if (itemSchema is! OpenUIObject) return Checked.keep(value);
    final items = value.items;
    List<OpenUIValue>? out;
    for (final (index, item) in items.indexed) {
      final next = validate(item, itemSchema, component, '$path/$index', context);
      if (!identical(next.value, item) || next.isInvalid) out ??= items.sublist(0, index);
      if (out != null && !next.isInvalid) out.add(next.value ?? OpenUINull.instance);
    }
    return Checked.keep(out == null ? value : OpenUIArray(out));
  }

  static bool _isLeafInvalid(
    OpenUIValue value,
    Map<String, OpenUIValue> schema,
    String component,
    String path,
    MaterializeContext context,
  ) {
    final (expectedType, enumValues) = _scalarTypeInfo(schema);
    if (expectedType == null && enumValues == null) return false;
    // An enum value may still be cut short while the program streams in.
    if (enumValues != null && context.partial) return false;
    final actual = JS.typeOf(value);
    if (enumValues != null) {
      if (actual != 'string' && actual != 'number' && actual != 'boolean') return false;
      if (enumValues.any((member) => _sameValueZero(member, value))) return false;
      final expected = 'one of [${enumValues.map(JS.jsonStringify).join(', ')}]';
      final message = typeMismatchMessage(path, expected, JS.jsonStringify(value) ?? 'undefined');
      context.report(OpenUIErrorCode.typeMismatch, component, path, message);
      return true;
    }
    if (expectedType == actual) return false;
    context.report(
      OpenUIErrorCode.typeMismatch,
      component,
      path,
      typeMismatchMessage(path, expectedType!, JS.jsType(value)),
    );
    return true;
  }

  static bool _sameValueZero(OpenUIValue a, OpenUIValue b) {
    if ((a, b) case (OpenUINumber(value: final x), OpenUINumber(value: final y))) return JS.sameValueZero(x, y);
    return a == b;
  }

  // The scalar type (`string`, `number` or `boolean`) or enum values a leaf
  // schema allows.
  static (String?, List<OpenUIValue>?) _scalarTypeInfo(Map<String, OpenUIValue> schema) {
    if (schema['enum'] case OpenUIArray(:final items)) return (null, items);
    if (schema.containsKey('const')) return (null, [schema['const']!]);
    return switch (schema['type']) {
      OpenUIString(value: 'string') => ('string', null),
      OpenUIString(value: 'number' || 'integer') => ('number', null),
      OpenUIString(value: 'boolean') => ('boolean', null),
      _ => (null, null),
    };
  }

  static String? _refName(Map<String, OpenUIValue> schema) {
    return switch (schema[r'$ref']) {
      OpenUIString(:final value) => value.split('/').last,
      _ => null,
    };
  }

  static bool _isComposite(Map<String, OpenUIValue> schema) => _compositeKeywords.any(schema.containsKey);

  // The `$ref` names the options of a slot have: one for a `$ref`, several for
  // `anyOf` or `oneOf`; `null` for an option without one.
  static List<String?> _slotRefNames(Map<String, OpenUIValue> schema) {
    final options = switch (schema['anyOf'] ?? schema['oneOf']) {
      OpenUIArray(:final items) => items,
      _ => [OpenUIObject(schema)],
    };
    return [
      for (final option in options)
        if (option is OpenUIObject) _refName(option.fields) else null,
    ];
  }

  // Whether every option of the slot is a `$ref` to a component.
  static bool _isOnlyComponentSlot(Map<String, OpenUIValue> schema, MaterializeContext context) {
    final names = _slotRefNames(schema);
    if (names.isEmpty) return false;
    return names.every((name) => name != null && context.schema.paramsOf(name) != null);
  }
}
