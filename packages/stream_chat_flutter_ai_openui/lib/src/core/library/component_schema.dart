/// What a program can call: components, functions and action steps, and how
/// the system prompt groups components.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';

/// A component as a program calls it: its name, what it is for, and its
/// props in positional order.
@immutable
final class ComponentSchema {
  /// Creates the component [name] with [props], in the order a program
  /// passes them.
  const ComponentSchema(this.name, {required this.description, required this.props});

  /// The name a program calls the component by, such as `Card`.
  final String name;

  /// What the component is for, as the system prompt tells the model.
  final String description;

  /// The props, in positional order.
  final List<PropSchema> props;

  /// The component as the system prompt shows it, such as
  /// `CardHeader(title?: string, subtitle?: string)`.
  String get signature => '$name(${props.map((prop) => prop.signature).join(', ')})';

  /// The JSON Schema of the component's props, with its description.
  Map<String, Object?> get jsonSchema => PropSchema.objectSchema(props, description: description);

  /// A copy of this component whose props have their types changed by
  /// `update`.
  ComponentSchema mappingPropTypes(PropType Function(PropType type) update) {
    return ComponentSchema(
      name,
      description: description,
      props: [for (final prop in props) prop.withType(update(prop.type))],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ComponentSchema &&
        other.name == name &&
        other.description == description &&
        const ListEquality<PropSchema>().equals(other.props, props);
  }

  @override
  int get hashCode => Object.hash(name, description, const ListEquality<PropSchema>().hash(props));

  @override
  String toString() => signature;
}

/// A heading the system prompt lists components under, followed by notes on
/// using them.
@immutable
final class ComponentGroup {
  /// Creates the group [name] of [components], with [notes].
  const ComponentGroup(this.name, {required this.components, this.notes = const []});

  /// The heading, such as `Forms`.
  final String name;

  /// The names of the components listed under the heading, in order.
  final List<String> components;

  /// The lines printed after the components, each as written.
  final List<String> notes;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ComponentGroup &&
        other.name == name &&
        const ListEquality<String>().equals(other.components, components) &&
        const ListEquality<String>().equals(other.notes, notes);
  }

  @override
  int get hashCode {
    return Object.hash(name, const ListEquality<String>().hash(components), const ListEquality<String>().hash(notes));
  }
}

/// A function of the app's that a program calls as `@Name(...)` for a value.
@immutable
final class FunctionSchema {
  /// Creates the function [name] taking [params], in positional order, and
  /// giving a value of the [returns] type when it is given.
  const FunctionSchema(this.name, {required this.description, required this.params, this.returns});

  /// The name a program calls it by.
  final String name;

  /// What it gives, as the system prompt tells the model.
  final String description;

  /// The parameters, in positional order.
  final List<PropSchema> params;

  /// The type of the value it gives, or `null` when it isn't stated.
  final PropType? returns;

  /// The function as the system prompt shows it, such as
  /// `Upper(text: string) → string`.
  String get signature {
    final call = '$name(${params.map((param) => param.signature).join(', ')})';
    if (returns case final returns?) return '$call → ${returns.signature}';
    return call;
  }

  /// The JSON Schema of the parameters.
  Map<String, Object?> get paramsSchema => PropSchema.objectSchema(params);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FunctionSchema &&
        other.name == name &&
        other.description == description &&
        const ListEquality<PropSchema>().equals(other.params, params) &&
        other.returns == returns;
  }

  @override
  int get hashCode => Object.hash(name, description, const ListEquality<PropSchema>().hash(params), returns);
}

/// An action step of the app's, used like the built-in ones, such as
/// `Button("Copy", @CopyToClipboard(text))`.
@immutable
final class ActionSchema {
  /// Creates the step [name] taking [params], in positional order.
  const ActionSchema(this.name, {required this.description, required this.params});

  /// The name a program uses it by.
  final String name;

  /// What it does, as the system prompt tells the model.
  final String description;

  /// The parameters, in positional order.
  final List<PropSchema> params;

  /// The step as the system prompt shows it, such as
  /// `CopyToClipboard(text: string)`.
  String get signature => '$name(${params.map((param) => param.signature).join(', ')})';

  /// The JSON Schema of the parameters.
  Map<String, Object?> get paramsSchema => PropSchema.objectSchema(params);

  /// The JSON shape of one use of this step, `{type: name, params: {...}}`,
  /// which an action prop that takes only some steps refers to.
  Map<String, Object?> get stepSchema {
    return PropSchema.objectSchema([
      PropSchema('type', PropType.literal(name)),
      PropSchema('params', PropType.object(params)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ActionSchema &&
        other.name == name &&
        other.description == description &&
        const ListEquality<PropSchema>().equals(other.params, params);
  }

  @override
  int get hashCode => Object.hash(name, description, const ListEquality<PropSchema>().hash(params));
}
