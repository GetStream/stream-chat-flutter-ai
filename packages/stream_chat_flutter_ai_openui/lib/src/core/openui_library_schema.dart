/// The components, functions and actions an OpenUI Lang program can call.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/schema_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// The components, functions and actions an OpenUI Lang program can call,
/// compiled for parsing.
///
/// A library is described by a JSON Schema document. Each component is an
/// entry of `$defs` whose `properties` are its arguments, in the order a
/// program passes them; `required` names those it must pass, and a
/// property's `default` replaces an invalid value, and also a missing or
/// `null` one when the property is required. When the document has
/// `properties`, only the `$defs` it names are components, and the rest are
/// shapes of data. The library's own functions and actions are described
/// under `functions` and `actions`, each by its `params`: there a `default`
/// replaces an invalid value, and lets a required one be missing or `null`
/// without filling it in.
///
/// Every library can also call the built-in functions and action steps.
@immutable
final class OpenUILibrarySchema {
  OpenUILibrarySchema._(
    this.root,
    Map<String, List<ParamDef>> components,
    Map<String, List<ParamDef>> definitions,
    Map<String, CallDef> calls,
  ) : _components = Map.unmodifiable(components),
      _definitions = Map.unmodifiable(definitions),
      _calls = Map.unmodifiable(calls);

  /// Compiles `jsonSchema`, a library's JSON Schema document, as `jsonDecode`
  /// gives it.
  ///
  /// The [root] component is the one a program without a `root` statement
  /// falls back to; without it, such a program has no entry.
  ///
  /// Throws a [FormatException] when `jsonSchema` isn't JSON data.
  factory OpenUILibrarySchema.fromJsonSchema(Map<String, Object?> jsonSchema, {String? root}) {
    final schema = OpenUIValue.fromJson(jsonSchema);
    final definitions = _object(_field(schema, r'$defs'));
    final componentNames = switch (_field(schema, 'properties')) {
      OpenUIObject(:final fields) => fields.keys.toSet(),
      _ => null,
    };
    final customActions = _object(_field(schema, 'actions'));
    // Action shapes (ActionExpression, OpenUrl, ToAssistant and custom
    // actions) are data a prop takes, not components, unless `properties`
    // names them.
    final actionDefinitions = <String, OpenUIValue>{};
    for (final name in [..._actionDefinitionNames, ...customActions.keys]) {
      final body = definitions[name];
      if (body != null && !(componentNames?.contains(name) ?? false)) actionDefinitions['#/\$defs/$name'] = body;
    }
    final components = <String, List<ParamDef>>{};
    for (final MapEntry(key: name, value: definition) in definitions.entries) {
      final isComponent = componentNames?.contains(name) ?? !actionDefinitions.containsKey('#/\$defs/$name');
      if (isComponent) components[name] = _compileParams(definition, actionDefinitions);
    }
    final definitionParams = {
      for (final MapEntry(key: name, value: definition) in definitions.entries)
        if (_field(definition, 'properties') is OpenUIObject)
          name: components[name] ?? _compileParams(definition, const {}),
    };
    final calls = <String, CallDef>{...BuiltinCalls.calls};
    for (final MapEntry(key: name, value: function) in _object(_field(schema, 'functions')).entries) {
      calls[name] = CallDef(CallKind.function, _compileParams(_field(function, 'params'), actionDefinitions));
    }
    for (final MapEntry(key: name, value: action) in customActions.entries) {
      calls[name] = CallDef(CallKind.action, _compileParams(_field(action, 'params'), actionDefinitions));
    }
    return OpenUILibrarySchema._(root, components, definitionParams, calls);
  }

  /// Compiles a library spec, `{"root": …, "schema": {…}}`, whose `schema` is
  /// the library's JSON Schema document and `root` its root component.
  ///
  /// Throws a [FormatException] when `spec` has no `schema` object, when its
  /// `root` is there but isn't a string, or when `schema` isn't JSON data.
  factory OpenUILibrarySchema.fromSpec(Map<String, Object?> spec) {
    final schema = spec['schema'];
    if (schema is! Map<String, Object?>) throw const FormatException('A library spec without a schema object');
    final root = spec['root'];
    if (root is! String?) throw FormatException('A library spec whose root is not a string', root);
    return OpenUILibrarySchema.fromJsonSchema(schema, root: root);
  }

  // The `$defs` of the action shapes every library's schema has.
  static const _actionDefinitionNames = ['ActionExpression', 'OpenUrl', 'ToAssistant'];

  /// The component a program without a `root` statement falls back to, or
  /// `null` when there is none.
  final String? root;

  final Map<String, List<ParamDef>> _components;
  final Map<String, List<ParamDef>> _definitions;
  final Map<String, CallDef> _calls;

  /// The component names, in the order the document declares them.
  List<String> get componentNames => List.unmodifiable(_components.keys);

  /// The arguments of `component`, in positional order, or `null` when the
  /// library has no such component.
  List<ParamDef>? paramsOf(String component) => _components[component];

  /// The properties of the `$defs` entry `name`, a component or a shape of
  /// data, in order, or `null` when it has no `properties` object.
  List<ParamDef>? definitionParamsOf(String name) => _definitions[name];

  /// The function or action `name` calls, a built-in or one of the library's
  /// own, or `null` when there is none.
  CallDef? callOf(String name) => _calls[name];

  static List<ParamDef> _compileParams(OpenUIValue? definition, Map<String, OpenUIValue> actionDefinitions) {
    final properties = _object(_field(definition, 'properties'));
    final required = switch (_field(definition, 'required')) {
      OpenUIArray(:final items) => {
        for (final item in items)
          if (item case OpenUIString(:final value)) value,
      },
      _ => const <String>{},
    };
    return [
      for (final MapEntry(key: name, value: property) in properties.entries)
        ParamDef(
          name,
          required: required.contains(name),
          defaultValue: SchemaValidation.defaultValue(property),
          schema: actionDefinitions.isEmpty ? property : _inlineActionRefs(property, actionDefinitions),
        ),
    ];
  }

  // `{"$ref": "#/$defs/ActionExpression"}` → the shape it names, so an action
  // prop validates as the union it is. A `$ref` back to a shape being inlined
  // stays a `$ref`, so cyclic shapes end.
  static OpenUIValue _inlineActionRefs(
    OpenUIValue node,
    Map<String, OpenUIValue> definitions, [
    Set<String> expanding = const {},
  ]) {
    switch (node) {
      case OpenUIObject(:final fields):
        if (fields[r'$ref'] case OpenUIString(value: final ref)) {
          final target = definitions[ref];
          if (target == null || expanding.contains(ref)) return node;
          return _inlineActionRefs(target, definitions, {...expanding, ref});
        }
        return OpenUIObject(
          fields.map((key, value) => MapEntry(key, _inlineActionRefs(value, definitions, expanding))),
        );
      case OpenUIArray(:final items):
        return OpenUIArray([for (final item in items) _inlineActionRefs(item, definitions, expanding)]);
      case OpenUINull() || OpenUIBool() || OpenUINumber() || OpenUIString() || OpenUIElement() || OpenUIExpression():
        return node;
    }
  }

  static OpenUIValue? _field(OpenUIValue? value, String key) => value is OpenUIObject ? value.fields[key] : null;

  static Map<String, OpenUIValue> _object(OpenUIValue? value) => value is OpenUIObject ? value.fields : const {};

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUILibrarySchema &&
        other.root == root &&
        const DeepCollectionEquality().equals(other._components, _components) &&
        const DeepCollectionEquality().equals(other._definitions, _definitions) &&
        const MapEquality<String, CallDef>().equals(other._calls, _calls);
  }

  @override
  int get hashCode {
    return Object.hash(
      root,
      const DeepCollectionEquality().hash(_components),
      const DeepCollectionEquality().hash(_definitions),
      const MapEquality<String, CallDef>().hash(_calls),
    );
  }
}

/// One argument of a component, function or action.
@immutable
final class ParamDef {
  /// Creates the argument [name].
  ///
  /// When [required], a call must pass it, unless it has a [defaultValue].
  /// The [defaultValue] replaces an invalid value, and for a component's
  /// argument also a missing or `null` one; [schema] is the JSON Schema
  /// fragment its value is checked against.
  const ParamDef(this.name, {this.required = false, this.defaultValue, this.schema});

  /// The argument's name, such as `title`.
  final String name;

  /// Whether a call must pass this argument.
  final bool required;

  /// The value that replaces an invalid argument, and for a component's
  /// argument also a missing or `null` one; `null` when there is none.
  final OpenUIValue? defaultValue;

  /// The JSON Schema fragment the argument's value is checked against, or
  /// `null` when it isn't checked.
  final OpenUIValue? schema;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ParamDef &&
        other.name == name &&
        other.required == required &&
        other.defaultValue == defaultValue &&
        other.schema == schema;
  }

  @override
  int get hashCode => Object.hash(name, required, defaultValue, schema);
}

/// Whether a [CallDef] computes a value or is an action step.
enum CallKind {
  /// A function, such as `@Count(rows)`.
  function,

  /// An action step, such as `@Set($page, 2)`.
  action,
}

/// A function or action step a program calls with `@Name(…)`.
@immutable
final class CallDef {
  /// Creates a call of [kind] taking [params].
  ///
  /// A built-in ([isBuiltin]) coerces its arguments, so they aren't checked
  /// against [params]; a lazy one ([isLazy]) gets its arguments unevaluated.
  const CallDef(this.kind, this.params, {this.isBuiltin = false, this.isLazy = false});

  /// Whether the call computes a value or is an action step.
  final CallKind kind;

  /// The arguments, in positional order.
  final List<ParamDef> params;

  /// Whether the call is one of the language's own.
  final bool isBuiltin;

  /// Whether the call gets its arguments unevaluated, such as `@Each`.
  final bool isLazy;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CallDef &&
        other.kind == kind &&
        const ListEquality<ParamDef>().equals(other.params, params) &&
        other.isBuiltin == isBuiltin &&
        other.isLazy == isLazy;
  }

  @override
  int get hashCode => Object.hash(kind, const ListEquality<ParamDef>().hash(params), isBuiltin, isLazy);
}
