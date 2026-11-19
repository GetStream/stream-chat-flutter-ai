import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart' show StateField;
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart'
    show OpenUIFormScope, OpenUIFormValidation, openUIActionChecksForm;
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_form_fields.dart' show openUIIsPasswordInput;
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_json.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

part 'openui_node_view.dart';

/// One component of a reply's OpenUI as its builder reads it: its type, its
/// props and the components placed in them.
///
/// The props are evaluated: a prop the agent wrote as an expression, such as
/// one reading the reply's state, reads its current value, and the component
/// is built again when that value changes. A prop the agent bound to a
/// `$variable`, such as a field's `value`, reads as `null` with [value] and
/// the other readers of a prop's value; it is read and written with
/// [stateField].
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
  /// `$variable`, such as a field's `value`, reads as `null`; read and write
  /// it with [stateField].
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
  /// holds.
  ///
  /// A prop that holds none gives an empty list. Every component is given,
  /// whether or not the library has a builder for its type: some, such as a
  /// `Tabs`'s `TabItem`s, only hold data for the component they are in,
  /// which reads them with [scopeOf]. Draw one with [build], which draws
  /// nothing for a type without a builder.
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
  /// It draws nothing when the library has no builder for the child's type,
  /// such as a `TabItem`, whose data the component it is in reads instead.
  ///
  /// The [child] is one this scope gave, from [children] or [child].
  Widget build(OpenUIChild child);

  /// The scope of [child], to read its props.
  ///
  /// The [child] is one this scope gave, from [children] or [child]. Its
  /// [stateField] and [triggerAction] use the form this component is in,
  /// which may differ from the form the child's own builder is in when
  /// [build] draws it.
  OpenUIComponentScope scopeOf(OpenUIChild child);

  /// The state field [name] this component shows and writes.
  ///
  /// An input keeps what the person enters in its field, and a modal whether
  /// it is open.
  ///
  /// When the agent bound the prop [bindingProp] to a `$variable`, or the
  /// prop [name] when [bindingProp] is omitted, the field reads and writes
  /// that variable, so every component that reads it shows what is written.
  /// Otherwise the field is kept under [name] in the form this component is
  /// in, which sends it with its actions, or in the reply's state outside a
  /// form, and shows the prop's own value while it holds nothing, such as
  /// before it is written or after `null` is. Only a prop the library lets
  /// the agent bind, such as a field's `value`, is bound: a `$variable` in
  /// any other prop reads as its value.
  ///
  /// The field of a password `Input`, one whose `type` is `password`, is
  /// kept secret, as the package's own `Input` keeps it: never bound to a
  /// `$variable`, and left out of the form state an action sends.
  ///
  /// The field is read as it is now. A widget that reads it in [watchState]
  /// is built again when it changes.
  OpenUIStateField stateField(String name, {String? bindingProp});

  /// The widget [builder] builds, built again each time a `$variable` or form
  /// field of the reply changes.
  ///
  /// A field read with [stateField] inside [builder] shows its current value.
  Widget watchState(WidgetBuilder builder);

  /// Runs the action the prop [name] holds, such as a button's `action`, as
  /// the person's own act, for example a tap on the component.
  ///
  /// An action the agent wrote as steps runs them, such as `@Set` writing a
  /// `$variable`, `@Run` running a query or mutation, and `@ToAssistant`
  /// sending a message. A prop that holds no action continues the
  /// conversation with [label], as a button without an action does. The
  /// action runs with, and sends, the state of the form this component is
  /// in, if any, unless [inForm] is `false`, as for a list's rows, which
  /// don't belong to the form around them.
  ///
  /// With [validate], the form this component is in is checked first, as the
  /// package's primary `Button` checks it, and nothing runs while a field
  /// fails; the fields show their errors. Nothing is checked outside a form
  /// or without [inForm],
  /// once the form has left the tree, or for an action whose steps neither
  /// send a message to the assistant nor run a mutation, such as `@Set`
  /// steps alone.
  ///
  /// Nothing runs while the reply is still streaming; see [isStreaming].
  /// Completes once the action has run, or at once when nothing runs.
  Future<void> triggerAction(String label, {String name = 'action', bool validate = false, bool inForm = true});

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
/// same component, as the reply evaluated it, in the same place: a component
/// that changes while the reply streams gives a new child. Its [key] stays
/// the same across such changes; see [key].
@immutable
final class OpenUIChild {
  const OpenUIChild._(this._node, this.key);

  final ElementNode _node;

  /// A string that tells this child apart from the other children of the
  /// same prop, such as for a widget's `ValueKey(child.key)`.
  ///
  /// A component the agent defined in a statement of its own keeps its key
  /// while the reply streams in, even when a sibling written before it
  /// arrives later. One written in place is keyed by where it is: its field,
  /// or its place in a list, which moves when a sibling before it arrives.
  ///
  /// Children of different props can share a key, so a widget that lays out
  /// the children of several props together keys each by its prop too.
  final String key;

  /// The type of the component, such as `CardHeader`.
  String get type => _node.typeName;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIChild && identical(other._node, _node) && other.key == key;
  }

  @override
  int get hashCode => Object.hash(identityHashCode(_node), key);

  @override
  String toString() => '${objectRuntimeType(this, 'OpenUIChild')}(type: $type, key: $key)';
}

/// The component [child] is.
///
/// Internal to the package.
@internal
ElementNode openUINodeOf(OpenUIChild child) => child._node;

/// A state field a component shows and writes; see
/// [OpenUIComponentScope.stateField].
///
/// It holds the field's value when it was read; a field read again holds the
/// newer one.
///
/// Obtained from [OpenUIComponentScope.stateField]. Not constructed directly.
@immutable
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
  String toString() => '${objectRuntimeType(this, 'OpenUIStateField')}(isBound: $isBound)';
}
