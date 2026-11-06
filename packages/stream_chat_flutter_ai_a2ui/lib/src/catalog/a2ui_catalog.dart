import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_audio_player.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_button.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_card.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_check_box.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_choice_picker.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_date_time_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_divider.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_icon.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_image.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_list.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_modal.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_slider.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_tabs.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_text.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_text_field.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_video.dart';

/// Signature for a function that builds the widget of one component of a
/// reply's A2UI, from what [scope] reads of it.
///
/// The widget it returns is placed where the component shows. It is called
/// again when the component's properties or children change.
///
/// A `Row` or `Column` measures each of its children through its dry layout,
/// [RenderBox.getDryLayout], before laying it out once, so nesting them stays
/// cheap. A widget that can't measure itself that way, such as a
/// [LayoutBuilder], can't be a child of one, even inside a box of a fixed
/// size. When the children don't fit, the row or column also asks each of
/// them how short it can be, through its intrinsic size such as
/// [RenderBox.getMinIntrinsicWidth], so a widget that can't say, such as a
/// [ListView], needs a fixed size there. A child of a
/// `Row` without a weight is first laid out with no width limit, as in a
/// Flutter [Row], so a widget that needs one, such as a `TextField`, needs a
/// weight or a width of its own.
///
/// A component a person interacts with, such as a `Button`, a `TextField`,
/// a `CheckBox`, a `ChoicePicker`, a `Slider`, a `DateTimeInput` or a
/// `Modal`, gets the agent's accessibility label and description on the part
/// the person interacts with, so it is read as one control; a builder that
/// replaces one reads them from `value('accessibility')`. Other components
/// get them around what their builder returns.
typedef A2UIComponentBuilder = Widget Function(BuildContext context, A2UIComponentScope scope);

/// The components a reply's A2UI is drawn with: a builder for each component
/// type, such as `Text` or `Card`.
///
/// [A2UICatalog.basic] draws the components of A2UI's basic catalog. The
/// builder of one of them can be replaced to draw it another way; the agent
/// still writes the component as the basic catalog describes it:
///
/// ```dart
/// final catalog = A2UICatalog.basic.replacing('Card', (context, scope) {
///   final child = scope.child();
///   return BrandCard(child: child == null ? null : scope.build(child));
/// });
/// ```
///
/// A basic component whose type has no builder in the catalog, such as one
/// taken out with [removing], isn't in the catalog the agent is told about,
/// and one the agent writes anyway shows nothing and is reported as a
/// component the catalog doesn't have.
///
/// A catalog doesn't change: [replacing] and [removing] return new ones. Two
/// catalogs are equal when they have the same builders for the same types,
/// compared as functions, so a catalog made again in a `build` method, with a
/// new closure, is never equal to the last one and everything drawn with it
/// builds again. Keep a catalog in a `final` or `static` field instead.
@immutable
final class A2UICatalog {
  const A2UICatalog._(this._builders);

  /// The components of A2UI's basic catalog that this package draws: `Text`,
  /// `Image`, `Icon`, `Video`, `AudioPlayer`, `Row`, `Column`, `List`, `Card`,
  /// `Divider`, `Tabs`, `Modal`, `Button`, `TextField`, `CheckBox`,
  /// `ChoicePicker`, `Slider` and `DateTimeInput`.
  static const A2UICatalog basic = A2UICatalog._({
    'Text': buildA2UIText,
    'Image': buildA2UIImage,
    'Icon': buildA2UIIcon,
    'Video': buildA2UIVideo,
    'AudioPlayer': buildA2UIAudioPlayer,
    'Row': buildA2UIRow,
    'Column': buildA2UIColumn,
    'List': buildA2UIList,
    'Card': buildA2UICard,
    'Divider': buildA2UIDivider,
    'Tabs': buildA2UITabs,
    'Modal': buildA2UIModal,
    'Button': buildA2UIButton,
    'TextField': buildA2UITextField,
    'CheckBox': buildA2UICheckBox,
    'ChoicePicker': buildA2UIChoicePicker,
    'Slider': buildA2UISlider,
    'DateTimeInput': buildA2UIDateTimeInput,
  });

  final Map<String, A2UIComponentBuilder> _builders;

  /// The component types this catalog has a builder for.
  Iterable<String> get types => _builders.keys;

  /// The builder of the components of [type], or `null` when this catalog has
  /// none.
  A2UIComponentBuilder? operator [](String type) => _builders[type];

  /// A copy of this catalog in which [builder] draws the components of [type].
  ///
  /// The [type] must be one this catalog has. Without asserts, the copy for
  /// any other [type] is equal to this catalog.
  A2UICatalog replacing(String type, A2UIComponentBuilder builder) {
    assert(
      _builders.containsKey(type),
      "A2UICatalog has no builder for '$type' to replace. It has ${types.join(', ')}.",
    );
    if (!_builders.containsKey(type)) return this;
    return A2UICatalog._(Map.unmodifiable({..._builders, type: builder}));
  }

  /// A copy of this catalog without the builders of [types], so the agent
  /// isn't told about components of those types, and one it writes anyway
  /// shows nothing and is reported as a component the catalog doesn't have.
  ///
  /// Each of [types] must be one this catalog has. Without asserts, the others
  /// are left out.
  A2UICatalog removing(Iterable<String> types) {
    final removed = types.toSet();
    assert(
      removed.every(_builders.containsKey),
      'A2UICatalog has no builder for ${removed.where((type) => !_builders.containsKey(type)).join(', ')} to remove. '
      'It has ${this.types.join(', ')}.',
    );
    return A2UICatalog._(
      Map.unmodifiable({
        for (final MapEntry(:key, :value) in _builders.entries)
          if (!removed.contains(key)) key: value,
      }),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    return other is A2UICatalog && const MapEquality<String, A2UIComponentBuilder>().equals(other._builders, _builders);
  }

  @override
  int get hashCode => const MapEquality<String, A2UIComponentBuilder>().hash(_builders);

  @override
  String toString() => '${objectRuntimeType(this, 'A2UICatalog')}(types: ${types.join(', ')})';
}

/// A copy of [catalog] in which [builders] also draw the components of their
/// types, such as the app's own components; a type [catalog] has keeps its
/// own builder.
///
/// Internal to the package.
@internal
A2UICatalog a2uiCatalogAdding(A2UICatalog catalog, Map<String, A2UIComponentBuilder> builders) {
  if (builders.isEmpty) return catalog;
  return A2UICatalog._(Map.unmodifiable({...builders, ...catalog._builders}));
}
