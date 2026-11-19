import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart' show StateField;
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart' show OpenUIFormScope;
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_json.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

part 'openui_node_view.dart';

/// One component of a reply's OpenUI as its builder reads it: its type, its
/// props and the components placed in them.
///
/// The props are evaluated: a prop the agent wrote as an expression, such as
/// one reading the reply's state, reads its current value, and the component
/// is built again when that value changes.
///
/// A component placed in a prop, such as each of a card's `children`, is
/// reached with [children] and [child], and drawn with [build]. A component a
/// person uses, such as a field or a button, keeps what they enter with
/// [stateField], and does what the agent asked for with [triggerAction].
///
/// Obtained from the arguments of an [OpenUIComponentBuilder]. Not constructed
/// directly. It belongs to the build it is given to: a builder reads it, and
/// may pass it to the widgets it returns, which use it until the component is
/// built again with a new scope.
///
/// ```dart
/// Widget buildBadge(BuildContext context, OpenUIComponentScope scope) {
///   // `of` gives the values the app set; the rest come from the Stream theme.
///   final theme = OpenUITheme.of(context);
///   return Text(
///     scope.text('label') ?? '',
///     style: context.streamTextTheme.metadataDefault.copyWith(
///       color: theme.accent ?? context.streamColorScheme.accentPrimary,
///     ),
///   );
/// }
/// ```
abstract base class OpenUIComponentScope {
  const OpenUIComponentScope._();

  /// The type of this component, such as `Card`.
  String get type;

  /// Whether the reply is still streaming, so this component may still
  /// change.
  bool get isStreaming;

  /// The value of the prop [name], or `null` when this component doesn't set
  /// it or its value isn't there yet.
  ///
  /// Values are JSON: maps, lists, strings, numbers as [double]s, booleans and
  /// `null`. A component placed in the prop, such as each of a card's
  /// `children`, reads as `null`; reach it with [children] or [child], or
  /// draw the whole prop with [buildProp]. A prop the agent bound to a
  /// `$variable`, such as a field's `value`, is read and written with
  /// [stateField].
  Object? value(String name);

  /// The prop [name] as the program gives it, expressions and components
  /// included, or `null` when this component doesn't set it.
  ///
  /// Internal to the package.
  @internal
  OpenUIValue? prop(String name);

  /// The prop [name] when it is a string, or `null` otherwise.
  String? string(String name);

  /// The prop [name] as the text it reads as, or `null` when it is missing or
  /// `null`.
  ///
  /// A string is returned as it is. A number is written without a decimal
  /// point when it is whole, such as `3` for `3.0`, and a boolean as `true` or
  /// `false`.
  String? text(String name);

  /// The prop [name] as a number, or `null` when it isn't one.
  ///
  /// A string that holds a number, such as `'2.5'`, counts as that number; an
  /// empty one doesn't. Not-a-number counts as `null`.
  double? number(String name);

  /// The prop [name] as a boolean, or `null` when it isn't one.
  ///
  /// The strings `true` and `false` count as booleans too.
  bool? boolean(String name);

  /// The prop [name] as a list of strings, each item read as [text] reads a
  /// prop, with `''` for an item that is `null`.
  ///
  /// A prop that is missing or `null` gives an empty list, and a prop that
  /// isn't a list gives a list of that one item.
  List<String> stringList(String name);

  /// The prop [name] as a list of numbers, each item read as a number: a
  /// string that holds a number counts as that number, `true` as 1, and any
  /// other item as 0.
  ///
  /// A prop that is missing or `null` gives an empty list, and a prop that
  /// isn't a list gives a list of that one item.
  List<double> numberList(String name);

  /// The widget of the prop [name], such as a card's `children`.
  ///
  /// A component is built with its type's builder. A list is drawn as a
  /// column of its items, [OpenUIThemeData.mSpacing] apart, each as wide as the
  /// column; an item that is `null`, an empty string, or a component whose
  /// type has no builder is left out. A string, number or
  /// boolean is drawn as text, read as [text] reads it. Anything else, such as
  /// a missing prop, draws nothing.
  Widget buildProp(String name);

  /// The widget this package draws for this component when its builder was
  /// replaced with [OpenUILibrary.replacing], for the builder that replaced it
  /// to wrap or restyle.
  ///
  /// It draws nothing when the builder wasn't replaced or this package
  /// doesn't draw this component's type.
  Widget buildDefault();

  /// The components the prop [name] holds, in order, such as a card's
  /// `children`: its items that are components, or the one component it
  /// holds. A prop that holds none gives an empty list.
  ///
  /// Every component is given, whether or not the library has a builder for
  /// its type: some, such as a `Tabs`'s `TabItem`s, only hold data for the
  /// component they are in, which reads them with [scopeOf]. Draw one with
  /// [build].
  List<OpenUIChild> children(String name);

  /// The component the prop [name] holds, such as a button's `icon`, or the
  /// first of the components it holds, as [children] gives them; `null` when
  /// it holds none.
  ///
  /// With [field], the component in that field of the prop, an object such
  /// as a `CompositeCardBlock` item's `footer`, or `null` when that field
  /// holds none.
  OpenUIChild? child(String name, {String? field});

  /// The widget of [child], built with its type's builder, as [buildProp]
  /// builds a component.
  ///
  /// The [child] is one this scope gave, from [children] or [child].
  Widget build(OpenUIChild child);

  /// The scope of [child], to read its props.
  ///
  /// The [child] is one this scope gave, from [children] or [child].
  OpenUIComponentScope scopeOf(OpenUIChild child);

  /// The state field [name] this component shows and writes, as an input
  /// keeps what the person enters, or a modal whether it is open.
  ///
  /// When the prop [bindingProp], [name] when not given, is bound to a
  /// `$variable`, the field reads and writes that variable, so every
  /// component that reads it shows what is written. Otherwise the field is
  /// kept under [name] in the form this component is in, which sends it with
  /// its actions, or in the reply's state outside a form, and shows the
  /// prop's own value until it is written.
  ///
  /// The field is read as it is now: read it in [watchState] to show it, so
  /// the widget is built again when it changes.
  OpenUIStateField stateField(String name, {String? bindingProp});

  /// The widget [builder] builds, built again each time a `$variable` or form
  /// field of the reply changes.
  ///
  /// Read [stateField] inside [builder] to show a field's current value.
  Widget watchState(WidgetBuilder builder);

  /// Runs the action the prop [name] holds, such as a button's `action`, as
  /// the person's own act, such as when they tap the component.
  ///
  /// An action the agent wrote as steps runs them, such as `@Set` writing a
  /// `$variable`, `@Run` running a query or mutation, and `@ToAssistant`
  /// sending a message. A prop that holds no action continues the
  /// conversation with [label], as a button without an action does. The
  /// action runs with the state of the form this component is in, if any.
  ///
  /// Nothing runs while the reply is still streaming; see [isStreaming].
  /// Completes once the action has run.
  Future<void> triggerAction(String label, {String name = 'action'});

  /// The component this scope is of.
  ///
  /// Internal to the package.
  @internal
  ElementNode get node;

  /// The widget of [node], a component of this one's props, built with its
  /// type's builder.
  ///
  /// Internal to the package.
  @internal
  Widget buildNode(ElementNode node);
}

/// A component placed in a prop of another, such as one of a card's
/// `children`, to draw with [OpenUIComponentScope.build] or read with
/// [OpenUIComponentScope.scopeOf].
///
/// Obtained from [OpenUIComponentScope.children] and
/// [OpenUIComponentScope.child]. Two children are equal when they are the
/// same component in the same place.
@immutable
final class OpenUIChild {
  const OpenUIChild._(this.node, this.key);

  /// The component.
  ///
  /// Internal to the package.
  @internal
  final ElementNode node;

  /// A string that tells this child apart from its siblings and stays the
  /// same while the reply streams in, such as for a widget's
  /// `ValueKey(child.key)`.
  ///
  /// A component the agent defined in a statement of its own keeps its key
  /// when a sibling written before it arrives later.
  final String key;

  /// The type of the component, such as `CardHeader`.
  String get type => node.typeName;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIChild && identical(other.node, node) && other.key == key;
  }

  @override
  int get hashCode => Object.hash(identityHashCode(node), key);

  @override
  String toString() => '${objectRuntimeType(this, 'OpenUIChild')}(type: $type, key: $key)';
}

/// A state field a component shows and writes; see
/// [OpenUIComponentScope.stateField].
///
/// It holds the field's value when it was read; read it again to see a newer
/// one.
final class OpenUIStateField {
  const OpenUIStateField._(this._field);

  final StateField _field;

  /// The field's value as JSON, as [OpenUIComponentScope.value] reads a prop,
  /// or `null` when it has none.
  Object? get value => openUIJson(_field.value);

  /// Whether the field reads and writes a `$variable`.
  bool get isBound => _field.isBound;

  /// Writes [value], as the person entered it, to the field.
  ///
  /// The [value] is JSON: a string, number, boolean, list, map or `null`.
  /// Writing a value that isn't JSON throws an [ArgumentError].
  void set(Object? value) {
    final OpenUIValue json;
    try {
      json = OpenUIValue.fromJson(value);
    } on FormatException catch (error) {
      throw ArgumentError.value(value, 'value', error.message);
    }
    _field.set(json);
  }

  @override
  String toString() => '${objectRuntimeType(this, 'OpenUIStateField')}(isBound: $isBound, value: $value)';
}
