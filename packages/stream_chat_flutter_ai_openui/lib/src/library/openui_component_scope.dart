import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart' show StateField;
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

part 'openui_node_view.dart';

/// One component of a reply's OpenUI as its builder reads it: its type and
/// its props.
///
/// The props are evaluated: a prop the agent wrote as an expression, such as
/// one reading the reply's state, reads its current value, and the component
/// is built again when that value changes.
///
/// Obtained from the arguments of an [OpenUIComponentBuilder]. Not constructed
/// directly. It belongs to the build it is given to: a builder reads it, and
/// may pass it to the widgets it returns, which use it until the component is
/// built again with a new scope.
///
/// ```dart
/// Widget buildBadge(BuildContext context, OpenUIComponentScope scope) {
///   // Every value of the theme `of` gives is set.
///   final theme = OpenUITheme.of(context);
///   return Text(
///     scope.text('label') ?? '',
///     style: theme.caption!.copyWith(color: theme.accent),
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
  /// `children`, reads as `null`; draw it with [buildProp].
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

  /// The state the prop [name] shows and writes: a prop the agent bound to a
  /// `$variable` reads and writes that variable.
  ///
  /// A prop that isn't bound to a variable shows its own value.
  ///
  /// Internal to the package.
  @internal
  StateField stateField(String name);

  /// The widget [builder] builds, built again each time a `$variable` or form
  /// field of the reply changes.
  ///
  /// A component that shows a bound prop, such as a callout's `visible`, reads
  /// it with [stateField] inside [builder].
  ///
  /// Internal to the package.
  @internal
  Widget watchState(WidgetBuilder builder);

  /// The components in the prop [name], such as a card block's `items`: its
  /// items that are components, or the one component it holds.
  ///
  /// Internal to the package.
  @internal
  List<ElementNode> elements(String name);

  /// The component in the field [field] of the prop [name], an object such as
  /// a composite card item's `footer`, or `null` when it holds none.
  ///
  /// Internal to the package.
  @internal
  ElementNode? elementField(String name, String field);

  /// The scope of [node], a component of this one's props.
  ///
  /// Internal to the package.
  @internal
  OpenUIComponentScope scopeOf(ElementNode node);

  /// The widget of [node], a component of this one's props, built with its
  /// type's builder.
  ///
  /// Internal to the package.
  @internal
  Widget buildNode(ElementNode node);
}
