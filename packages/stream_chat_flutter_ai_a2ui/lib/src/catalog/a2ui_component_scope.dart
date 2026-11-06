import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_debug_log.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_modal.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

part 'a2ui_node_view.dart';

/// One component of a reply's A2UI as its builder reads it: its id and type,
/// its properties, and its children.
///
/// The properties are resolved: a property the agent bound to the surface's
/// data model reads the model's current value, and the component is built
/// again when that value changes. Values are JSON: maps, lists, strings,
/// numbers, booleans and `null`, except that a component placed inside a
/// property, such as each tab's `child` in a `Tabs`'s `tabs`, is an
/// [A2UIChild], or `null` when it would show nothing; see [children].
///
/// A component a person uses, such as a field or a button, also writes what
/// the person enters back to the data model with [write], and does what the
/// agent asked for when it is used with [performAction]. Its checks, the
/// conditions the agent gave for its value to be accepted, are read with
/// [isValid] and [validationErrors].
///
/// Obtained from the arguments of an [A2UIComponentBuilder]. Not constructed
/// directly. It belongs to the build it is given to: a builder reads it, and
/// may pass it to the widgets it returns, which use it until the component is
/// built again with a new scope.
///
/// ```dart
/// Widget buildToggle(BuildContext context, A2UIComponentScope scope) {
///   final isOn = scope.boolean('value') ?? false;
///   return Switch(
///     value: isOn,
///     onChanged: (value) => scope.write('value', value),
///   );
/// }
/// ```
sealed class A2UIComponentScope {
  const A2UIComponentScope._();

  /// The id of this component, unique in its surface.
  String get id;

  /// The type of this component, such as `Text`.
  String get type;

  /// The value of the property [name], or `null` when this component doesn't
  /// set it or its value isn't there yet.
  Object? value(String name);

  /// The property [name] as text, or `null` when it is missing.
  ///
  /// A string is returned as it is. A number is written without a decimal
  /// point when it is whole, such as `3` for `3.0`, and a boolean as `true` or
  /// `false`. A list or a map is written as JSON.
  String? string(String name);

  /// The property [name] as a number, or `null` when it isn't one.
  ///
  /// A string that holds a number, such as `'2.5'`, counts as that number.
  double? number(String name);

  /// The property [name] as a boolean, or `null` when it isn't one.
  ///
  /// A number counts as `true` unless it is 0, and the strings `true` and
  /// `false` count in any capitalization. A map with a `valid` entry, such as
  /// the result of a validation function, counts as that entry.
  bool? boolean(String name);

  /// The property [name] as a list of strings, each item read as [string]
  /// reads a property, or `null` when it isn't a list.
  ///
  /// Items that are `null` are left out.
  List<String>? stringList(String name);

  /// The style hint [name], such as a `Text`'s `variant`, when the agent
  /// wrote it as a string, or `null` otherwise.
  ///
  /// A style hint chooses how a component looks and is never read from the
  /// data model: a property the agent bound to the data model, or computed
  /// with a function, gives `null`, whatever [value] gives for it. A value
  /// the component's type doesn't know, such as a `variant` of `h1`, is
  /// returned as it is, for the builder to fall back to its default.
  String? hint(String name);

  /// Whether the property [name] is bound to a path of the surface's data
  /// model, so its [value] is the value at that path.
  bool isBound(String name);

  /// The child the property [name] holds, such as a `Card`'s `child`, or
  /// `null` when it holds no single child, or one that shows nothing; see
  /// [children].
  A2UIChild? child([String name = 'child']);

  /// The children the property [name] holds, in order, such as a `Row`'s
  /// `children`.
  ///
  /// A list of ids gives one child for each id. A template gives one child for
  /// each item of the data model list it names. A property that holds no
  /// children gives an empty list.
  ///
  /// A child that would show nothing is left out: one the agent hasn't sent
  /// yet, and one whose type the surface's catalog has no builder for. So the
  /// children a builder lays out are the ones that show.
  List<A2UIChild> children([String name = 'children']);

  /// The widget of [child], built with the surface's catalog.
  ///
  /// The [child] is one this scope gave: from [child], [children], or the
  /// value of a property.
  Widget build(A2UIChild child);

  /// Writes [value] where the property `name` is bound in the surface's data
  /// model, as a field does when the person changes it.
  ///
  /// Every component bound to that place shows the new value. A property the
  /// agent wrote as a value rather than binding it isn't changed, and nothing
  /// happens; see [isBound]. The [value] is JSON: a string, number, boolean,
  /// list, map or `null`.
  void write(String name, Object? value);

  /// Whether this component does something when the person uses it: the
  /// agent gave it an `action`, such as a button's.
  bool get hasAction;

  /// Runs this component's action as the person's own act, such as when they
  /// tap a button.
  ///
  /// Call it only in response to the person's gesture: it runs as their
  /// act, so a link the action opens opens only while it runs.
  ///
  /// An action that names an event lets the agent hear about it, with the
  /// values the agent asked for read from the data model now. An action that
  /// calls a function runs it, such as one opening a link the agent gave.
  ///
  /// A component in the `trigger` of a `Modal` also opens the modal's
  /// content, with or without an action of its own.
  ///
  /// Completes once the action has run. When this component has no action,
  /// see [hasAction], it runs nothing, and only opens the modal it is the
  /// trigger of. A problem with the action, or with opening the modal, is
  /// reported through the processor's `onError`, not thrown.
  Future<void> performAction();

  /// The messages of this component's checks that fail now and block it,
  /// such as a form that isn't complete yet, in the order the agent wrote the
  /// checks.
  ///
  /// A check whose condition reads nothing yet, such as data still on its
  /// way, passes. A failing check that calls a function gives the message the
  /// agent wrote for it, else the function's; one that reads its result from
  /// the data model gives that result's message, else the agent's. Without
  /// either, it gives the code of its result, and with none of them it blocks
  /// without being listed. A check marked as a warning or information fails
  /// without blocking, and isn't listed. The list is empty when the component
  /// has no checks.
  List<String> get validationErrors;

  /// Whether none of this component's checks blocks it; see
  /// [validationErrors].
  bool get isValid;
}

/// A child component, to place with [A2UIComponentScope.build].
///
/// Obtained from [A2UIComponentScope.child], [A2UIComponentScope.children]
/// and the property values of [A2UIComponentScope.value]. Two children are
/// equal when they are the same component in the same place.
@immutable
final class A2UIChild {
  const A2UIChild._(this._node);

  final A2UINode _node;

  /// A key that tells this child apart from its siblings and stays the same
  /// while the agent updates the surface, such as for a widget's [Key].
  String get key => _node.key;

  /// The id of the child component.
  String get id => _node.id;

  /// The share of the free space this child takes in a `Row` or `Column`, or
  /// `null` when it has no weight.
  ///
  /// Only a finite weight above 0 counts.
  double? get weight {
    final weight = _node.property('weight');
    if (weight is! num || weight <= 0 || !weight.isFinite) return null;
    return weight.toDouble();
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    return other is A2UIChild && identical(other._node, _node);
  }

  @override
  int get hashCode => identityHashCode(_node);

  @override
  String toString() => '${objectRuntimeType(this, 'A2UIChild')}(id: $id, key: $key)';
}

/// Whether the person can change the `value` of the input [scope] reads:
/// whether the agent bound it to the data model, where what the person
/// enters goes. One the agent wrote as a value instead has nowhere to keep
/// what the person enters, so it shows its value read-only, and is reported
/// once.
///
/// Internal to the package.
@internal
bool a2uiCanEdit(A2UIComponentScope scope) {
  if (scope.isBound('value')) return true;
  a2uiReportOnce(scope, 'value', "Its 'value' isn't bound to the data model, so it can't be changed.");
  return false;
}

/// How strongly an input that can't be changed shows.
///
/// Internal to the package.
@internal
const a2uiReadOnlyOpacity = 0.5;

/// Reports [message], a problem with what the agent wrote for the component
/// [scope] reads, such as a bound value it can't be read as, through the
/// processor's `onError`, once for each [key] while the component lasts.
///
/// Internal to the package.
@internal
void a2uiReportOnce(A2UIComponentScope scope, String key, String message) {
  switch (scope) {
    case _NodeScope(:final _node):
      _node.reportOnce(key, message);
  }
}
