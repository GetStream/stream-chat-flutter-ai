/// The short forms the built-in libraries' components are written in.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart' show internal;
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';

/// A string.
const PropType string = PropType.string;

/// A number.
const PropType number = PropType.number;

/// A boolean.
const PropType boolean = PropType.boolean;

/// Any value.
const PropType any = PropType.any;

/// An action: one action step, or `Action([...])` with several.
const PropType action = PropType.action;

/// The validation rules of a form field, such as
/// `{required: true, email: true, minLength: 8}`.
const PropType validationRules = PropType.object([
  PropSchema('required', PropType.boolean, required: false),
  PropSchema('email', PropType.boolean, required: false),
  PropSchema('url', PropType.boolean, required: false),
  PropSchema('numeric', PropType.boolean, required: false),
  PropSchema('min', PropType.number, required: false),
  PropSchema('max', PropType.number, required: false),
  PropSchema('minLength', PropType.number, required: false),
  PropSchema('maxLength', PropType.number, required: false),
  PropSchema('pattern', PropType.string, required: false),
]);

/// One of the strings `values`.
PropType enumeration(List<String> values) => PropType.enumeration(values);

/// A list of `items`, at least `minItems` long when it is given.
PropType array(PropType items, {int? minItems}) => PropType.array(items, minItems: minItems);

/// An object with `fields`.
PropType object(List<PropSchema> fields) => PropType.object(fields);

/// An object of string keys whose values are of the `value` type.
PropType record(PropType value) => PropType.record(value);

/// The component `name`.
PropType component(String name) => PropType.component(name);

/// Any of the components `names`.
PropType components(List<String> names) => PropType.components(names);

/// A value of any of the `options` types.
PropType union(List<PropType> options) => PropType.union(options);

/// A prop a program must pass.
PropSchema required(String name, PropType type) => PropSchema(name, type);

/// A prop a program may leave out.
PropSchema optional(String name, PropType type) => PropSchema(name, type, required: false);

/// A prop a program may leave out, which then takes `defaultValue`.
PropSchema defaulted(String name, PropType type, Object? defaultValue) {
  return PropSchema(name, type, required: false, defaultValue: defaultValue);
}

/// A prop a program may leave out, or pass a `$variable` it reads and
/// writes.
PropSchema binding(String name, PropType type) => PropSchema(name, type, required: false, bindable: true);
