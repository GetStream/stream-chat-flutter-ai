/// The types of a component's props, and the props themselves.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The type of a component's prop: what a program may pass for it.
///
/// Each type has the JSON Schema a value is checked against ([jsonSchema])
/// and the annotation the system prompt shows for it ([signature]).
@immutable
sealed class PropType {
  // Only the types of this file extend it.
  const PropType._();

  /// A list of values of the `items` type, at least `minItems` long when it
  /// is given.
  const factory PropType.array(PropType items, {int? minItems}) = ArrayType;

  /// One of the fixed strings `values`, shown as `"a" | "b"`.
  const factory PropType.enumeration(List<String> values) = EnumerationType;

  /// The one string `value`, shown as `"value"`.
  const factory PropType.literal(String value) = LiteralType;

  /// An object with the named `fields`.
  const factory PropType.object(List<PropSchema> fields) = ObjectType;

  /// An object of string keys whose values are all of the `value` type,
  /// shown as `Record<string, T>`.
  const factory PropType.record(PropType value) = RecordType;

  /// The component named `name`, called in place or by reference.
  const factory PropType.component(String name) = ComponentType;

  /// A value of any of the `options` types, shown as `A | B`.
  const factory PropType.union(List<PropType> options) = UnionType;

  /// An action that takes only the action steps named in `names`, such as
  /// `@CopyToClipboard | @OpenUrl`.
  const factory PropType.actions(List<String> names) = ActionsType;

  /// Any of the components named in `names`.
  factory PropType.components(List<String> names) {
    return UnionType([for (final name in names) ComponentType(name)]);
  }

  /// A string.
  static const PropType string = ScalarType._('string', {'type': 'string'});

  /// A number.
  static const PropType number = ScalarType._('number', {'type': 'number'});

  /// A boolean.
  static const PropType boolean = ScalarType._('boolean', {'type': 'boolean'});

  /// Any value.
  static const PropType any = ScalarType._('any', {});

  /// An action: one action step, or `Action([...])` with several.
  static const PropType action = ScalarType._(actionExpression, {r'$ref': '#/\$defs/$actionExpression'});

  /// The name of the JSON shape every action takes, and of the type of an
  /// action prop in a signature.
  static const actionExpression = 'ActionExpression';

  /// The JSON Schema of a value of this type.
  Map<String, Object?> get jsonSchema;

  /// The annotation of this type in a component's signature, such as
  /// `Series[]`.
  String get signature;

  /// The `$defs` entries this type refers to, in the order of its schema,
  /// depth first.
  List<DefinitionReference> get definitionReferences;

  /// This type without the components named in `names` among the options of
  /// its unions; a union that would be left with no option keeps them.
  PropType removingComponents(Set<String> names) => this;

  /// The components this type can't do without when those named in `names`
  /// are removed: a slot's only type, or the components of a union that
  /// would be left with none.
  List<String> neededComponents(Set<String> names) => const [];

  /// This type with the components named in `names` added to it when it is a
  /// union with `TextContent` in it, or a list of one.
  ///
  /// The unions inside an object or a record stay as they are.
  PropType addingContentComponents(List<String> names) => this;

  @override
  String toString() => signature;
}

/// A `$defs` entry a type refers to: a component, or the shape of an action
/// step when [isAction].
@immutable
final class DefinitionReference {
  /// Creates a reference to the `$defs` entry [name].
  const DefinitionReference(this.name, {this.isAction = false});

  /// The name of the entry.
  final String name;

  /// Whether the entry is the shape of an action step rather than a
  /// component.
  final bool isAction;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DefinitionReference && other.name == name && other.isAction == isAction;
  }

  @override
  int get hashCode => Object.hash(name, isAction);
}

/// A string, number, boolean, any value, or an action.
final class ScalarType extends PropType {
  const ScalarType._(this.signature, this.jsonSchema) : super._();

  @override
  final String signature;

  @override
  final Map<String, Object?> jsonSchema;

  @override
  List<DefinitionReference> get definitionReferences {
    if (signature != PropType.actionExpression) return const [];
    return const [DefinitionReference(PropType.actionExpression, isAction: true)];
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ScalarType && other.signature == signature;
  }

  @override
  int get hashCode => signature.hashCode;
}

/// One of a fixed set of strings.
final class EnumerationType extends PropType {
  /// Creates the type of the strings [values].
  const EnumerationType(this.values) : super._();

  /// The strings a value may be.
  final List<String> values;

  @override
  Map<String, Object?> get jsonSchema => {
    'type': 'string',
    'enum': [...values],
  };

  @override
  String get signature => values.map((value) => '"$value"').join(' | ');

  @override
  List<DefinitionReference> get definitionReferences => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EnumerationType && const ListEquality<String>().equals(other.values, values);
  }

  @override
  int get hashCode => const ListEquality<String>().hash(values);
}

/// A single string.
final class LiteralType extends PropType {
  /// Creates the type of the string [value].
  const LiteralType(this.value) : super._();

  /// The string a value must be.
  final String value;

  @override
  Map<String, Object?> get jsonSchema => {'type': 'string', 'const': value};

  @override
  String get signature => '"$value"';

  @override
  List<DefinitionReference> get definitionReferences => const [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiteralType && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// A list of values of one type.
final class ArrayType extends PropType {
  /// Creates the type of a list of [items], at least [minItems] long when it
  /// is given.
  const ArrayType(this.items, {this.minItems}) : super._();

  /// The type of each value.
  final PropType items;

  /// The fewest values the list may have, or `null` when it may be empty.
  final int? minItems;

  @override
  Map<String, Object?> get jsonSchema => {
    'minItems': ?minItems,
    'type': 'array',
    'items': items.jsonSchema,
  };

  @override
  String get signature {
    if (items is UnionType) return '(${items.signature})[]';
    return '${items.signature}[]';
  }

  @override
  List<DefinitionReference> get definitionReferences => items.definitionReferences;

  @override
  PropType removingComponents(Set<String> names) => ArrayType(items.removingComponents(names), minItems: minItems);

  @override
  List<String> neededComponents(Set<String> names) => items.neededComponents(names);

  @override
  PropType addingContentComponents(List<String> names) {
    return ArrayType(items.addingContentComponents(names), minItems: minItems);
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ArrayType && other.items == items && other.minItems == minItems;
  }

  @override
  int get hashCode => Object.hash(items, minItems);
}

/// An object with named fields.
final class ObjectType extends PropType {
  /// Creates the type of an object with [fields].
  const ObjectType(this.fields) : super._();

  /// The fields, in order.
  final List<PropSchema> fields;

  @override
  Map<String, Object?> get jsonSchema => PropSchema.objectSchema(fields);

  @override
  String get signature => '{${fields.map((field) => field.signature).join(', ')}}';

  @override
  List<DefinitionReference> get definitionReferences => [
    for (final field in fields) ...field.type.definitionReferences,
  ];

  @override
  PropType removingComponents(Set<String> names) {
    return ObjectType([for (final field in fields) field.withType(field.type.removingComponents(names))]);
  }

  @override
  List<String> neededComponents(Set<String> names) => [
    for (final field in fields) ...field.type.neededComponents(names),
  ];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ObjectType && const ListEquality<PropSchema>().equals(other.fields, fields);
  }

  @override
  int get hashCode => const ListEquality<PropSchema>().hash(fields);
}

/// An object of string keys whose values share one type.
final class RecordType extends PropType {
  /// Creates the type of an object whose values are of the [value] type.
  const RecordType(this.value) : super._();

  /// The type of each value.
  final PropType value;

  @override
  Map<String, Object?> get jsonSchema => {
    'type': 'object',
    'propertyNames': {'type': 'string'},
    'additionalProperties': value.jsonSchema,
  };

  @override
  String get signature => 'Record<string, ${value.signature}>';

  @override
  List<DefinitionReference> get definitionReferences => value.definitionReferences;

  @override
  PropType removingComponents(Set<String> names) => RecordType(value.removingComponents(names));

  @override
  List<String> neededComponents(Set<String> names) => value.neededComponents(names);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RecordType && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// A component of the library.
final class ComponentType extends PropType {
  /// Creates the type of the component [name].
  const ComponentType(this.name) : super._();

  /// The component's name.
  final String name;

  @override
  Map<String, Object?> get jsonSchema => {r'$ref': '#/\$defs/$name'};

  @override
  String get signature => name;

  @override
  List<DefinitionReference> get definitionReferences => [DefinitionReference(name)];

  @override
  List<String> neededComponents(Set<String> names) => [name];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ComponentType && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

/// A value of any of several types.
final class UnionType extends PropType {
  /// Creates the type of a value of any of the [options] types.
  const UnionType(this.options) : super._();

  /// The types a value may be of.
  final List<PropType> options;

  static const _content = ComponentType('TextContent');

  @override
  Map<String, Object?> get jsonSchema => {
    'anyOf': [for (final option in options) option.jsonSchema],
  };

  @override
  String get signature => options.map((option) => option.signature).join(' | ');

  @override
  List<DefinitionReference> get definitionReferences => [
    for (final option in options) ...option.definitionReferences,
  ];

  @override
  PropType removingComponents(Set<String> names) {
    final kept = [
      for (final option in options)
        if (!(option is ComponentType && names.contains(option.name))) option,
    ];
    if (kept.isEmpty) return this;
    return UnionType([for (final option in kept) option.removingComponents(names)]);
  }

  @override
  List<String> neededComponents(Set<String> names) {
    final components = [
      for (final option in options)
        if (option is ComponentType) option.name,
    ];
    final nested = [
      for (final option in options)
        if (option is! ComponentType) ...option.neededComponents(names),
    ];
    final keepsOne = options.length > components.length || components.any((name) => !names.contains(name));
    if (keepsOne) return nested;
    return [...components, ...nested];
  }

  @override
  PropType addingContentComponents(List<String> names) {
    if (!options.contains(_content)) return this;
    return UnionType([
      ...options,
      for (final name in names)
        if (!options.contains(ComponentType(name))) ComponentType(name),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UnionType && const ListEquality<PropType>().equals(other.options, options);
  }

  @override
  int get hashCode => const ListEquality<PropType>().hash(options);
}

/// An action that takes only some action steps.
final class ActionsType extends PropType {
  /// Creates the type of an action that takes only the steps [names].
  const ActionsType(this.names) : super._();

  /// The names of the steps it takes.
  final List<String> names;

  @override
  Map<String, Object?> get jsonSchema => {
    'anyOf': [
      for (final name in names) {r'$ref': '#/\$defs/$name'},
    ],
  };

  @override
  String get signature => names.map((name) => '@$name').join(' | ');

  @override
  List<DefinitionReference> get definitionReferences => [
    for (final name in names) DefinitionReference(name, isAction: true),
  ];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ActionsType && const ListEquality<String>().equals(other.names, names);
  }

  @override
  int get hashCode => const ListEquality<String>().hash(names);
}

/// One prop of a component, one field of an object prop, or one parameter of
/// a function or action.
@immutable
final class PropSchema {
  /// Creates the prop [name], which takes values of the [type].
  ///
  /// A program must pass a prop that is [required], and may leave an optional
  /// one out from the end of a call.
  ///
  /// When a [defaultValue], plain JSON, is given, a prop that is left out or
  /// passed an invalid value reads as it, and the prop is optional.
  ///
  /// A [bindable] prop also takes a `$variable`, which it reads and writes.
  const PropSchema(
    this.name,
    this.type, {
    this._required = true,
    this._defaultValue = _noDefault,
    this.bindable = false,
  });

  /// The prop's name, such as `title`.
  final String name;

  /// The values the prop takes.
  final PropType type;

  final bool _required;

  /// Whether this prop also takes a `$variable`, which it reads and writes.
  final bool bindable;

  final Object? _defaultValue;

  /// The JSON Schema of an object with `fields`, and with `description` when
  /// it isn't empty.
  static Map<String, Object?> objectSchema(List<PropSchema> fields, {String? description}) {
    final required = [
      for (final field in fields)
        if (field.isSchemaRequired) field.name,
    ];
    return {
      'type': 'object',
      'properties': {for (final field in fields) field.name: field.jsonSchema},
      if (required.isNotEmpty) 'required': required,
      'additionalProperties': false,
      if (description != null && description.isNotEmpty) 'description': description,
    };
  }

  // Tells a `null` default apart from none.
  static const Object _noDefault = _NoDefault();

  /// Whether this prop has a default value, which may be `null`.
  bool get hasDefault => !identical(_defaultValue, _noDefault);

  /// Whether a program must pass this prop: one created required, with no
  /// default value.
  bool get required => _required && !hasDefault;

  /// The value this prop takes when a program passes none or an invalid one,
  /// or `null` when it has none (see [hasDefault]).
  Object? get defaultValue => hasDefault ? _defaultValue : null;

  /// Whether the JSON Schema of an object holding this prop lists it as
  /// required: a required prop, or one with a default value.
  bool get isSchemaRequired => required || hasDefault;

  /// The JSON Schema of this prop: its type's, with its `default` first when
  /// it has one.
  Map<String, Object?> get jsonSchema {
    if (!hasDefault) return type.jsonSchema;
    return {'default': _defaultValue, ...type.jsonSchema};
  }

  /// This prop as a signature shows it: `name: type`, `name?: type` or
  /// `name?: $binding<type>`.
  String get signature {
    final annotation = bindable ? '\$binding<${type.signature}>' : type.signature;
    if (required) return '$name: $annotation';
    return '$name?: $annotation';
  }

  /// A copy of this prop with `type` as its type.
  PropSchema withType(PropType type) {
    return PropSchema(name, type, required: _required, defaultValue: _defaultValue, bindable: bindable);
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PropSchema &&
        other.name == name &&
        other.type == type &&
        other.required == required &&
        other.bindable == bindable &&
        other.hasDefault == hasDefault &&
        const DeepCollectionEquality().equals(other.defaultValue, defaultValue);
  }

  @override
  int get hashCode {
    return Object.hash(name, type, required, bindable, hasDefault, const DeepCollectionEquality().hash(defaultValue));
  }

  @override
  String toString() => signature;
}

final class _NoDefault {
  const _NoDefault();
}
