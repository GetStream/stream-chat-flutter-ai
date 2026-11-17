import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_card.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_card_header.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_text_content.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';

/// Signature for a function that builds the widget of one component of a
/// reply's OpenUI, from what [scope] reads of it.
///
/// The widget it returns is placed where the component shows. It is called
/// again when the component's props change, such as while the reply streams.
/// A builder that throws draws nothing; the error goes to
/// [FlutterError.reportError].
typedef OpenUIComponentBuilder = Widget Function(BuildContext context, OpenUIComponentScope scope);

/// The components an agent writes a reply's OpenUI with, and a builder for
/// each component that draws it.
///
/// [OpenUILibrary.chat] is OpenUI's chat library, made for answers in a chat,
/// and [OpenUILibrary.standard] its standard library. The builder of one of
/// their components can be replaced to draw it another way; the agent still
/// writes the component as the library describes it:
///
/// ```dart
/// final library = OpenUILibrary.chat.replacing('Card', (context, scope) {
///   return BrandCard(child: scope.buildProp('children'));
/// });
/// ```
///
/// A component whose type has no builder in the library shows nothing.
///
/// A library doesn't change: [replacing] and [removing] return new ones. Two
/// libraries are equal when they describe the same components and have the
/// same builders for them, compared as functions, so a library made again in
/// a `build` method, with a new closure, is never equal to the last one and
/// everything drawn with it builds again. Keep a library in a `final` or
/// `static` field instead.
@immutable
final class OpenUILibrary {
  OpenUILibrary._(this._base, this._removed, this._builders, this._defaults);

  /// OpenUI's chat library, whose programs are a `Card` with the answer in
  /// it.
  ///
  /// This package draws its `Card`, `CardHeader` and `TextContent`.
  static final OpenUILibrary chat = OpenUILibrary._(LibraryDefinition.chat, const {}, _chatBuilders, _chatBuilders);

  /// OpenUI's standard library, whose programs are a `Stack` of components.
  ///
  /// This package draws its `CardHeader` and `TextContent`.
  static final OpenUILibrary standard = OpenUILibrary._(
    LibraryDefinition.standard,
    const {},
    _standardBuilders,
    _standardBuilders,
  );

  static const Map<String, OpenUIComponentBuilder> _chatBuilders = {
    'Card': buildOpenUIChatCard,
    'CardHeader': buildOpenUICardHeader,
    'TextContent': buildOpenUITextContent,
  };

  static const Map<String, OpenUIComponentBuilder> _standardBuilders = {
    'CardHeader': buildOpenUICardHeader,
    'TextContent': buildOpenUITextContent,
  };

  // The library this one was made from, chat or standard.
  final LibraryDefinition _base;

  // Every component asked to be removed from [_base], also those it keeps
  // because a remaining component needs them.
  final Set<String> _removed;

  final Map<String, OpenUIComponentBuilder> _builders;

  // The builders of [_base]'s own components, before any were replaced.
  final Map<String, OpenUIComponentBuilder> _defaults;

  /// The components the agent writes with, as the model is taught them.
  ///
  /// Internal to the package.
  @internal
  late final LibraryDefinition definition = _removed.isEmpty ? _base : _base.removing(_removed);

  /// The names of this library's components, in the order the library
  /// declares them.
  ///
  /// It has every component the agent may write, also those that have no
  /// builder; see [operator []].
  Iterable<String> get types => definition.componentNames;

  /// The builder of the components of [type], or `null` when this library has
  /// none.
  OpenUIComponentBuilder? operator [](String type) => _builders[type];

  /// The builder this package draws the components of [type] with, when
  /// another builder replaced it; `null` otherwise.
  ///
  /// Internal to the package.
  @internal
  OpenUIComponentBuilder? replacedBuilderOf(String type) {
    final builder = _defaults[type];
    if (builder == null || identical(builder, _builders[type])) return null;
    return builder;
  }

  /// A copy of this library in which [builder] draws the components of
  /// [type].
  ///
  /// The [type] must be one of [types], also one this package doesn't draw.
  /// Without asserts, the copy for any other [type] is equal to this library.
  /// The [builder] can draw what this package draws for [type] with
  /// [OpenUIComponentScope.buildDefault].
  OpenUILibrary replacing(String type, OpenUIComponentBuilder builder) {
    final has = types.contains(type);
    assert(has, "OpenUILibrary has no component '$type' to replace. It has ${types.join(', ')}.");
    if (!has) return this;
    return OpenUILibrary._(_base, _removed, Map.unmodifiable({..._builders, type: builder}), _defaults);
  }

  /// A copy of this library without the components named in [types], so the
  /// agent isn't taught them and they show nothing.
  ///
  /// The root component stays, and so does a component that is the only one
  /// a remaining component's prop takes, such as the items of a list.
  ///
  /// Each of [types] must be one of [OpenUILibrary.types]. Without asserts,
  /// the others are left out.
  OpenUILibrary removing(Iterable<String> types) {
    final known = this.types.toSet();
    final removing = types.toSet();
    assert(
      known.containsAll(removing),
      'OpenUILibrary has no component ${removing.difference(known).join(', ')} to remove. '
      'It has ${known.join(', ')}.',
    );
    final removed = Set<String>.unmodifiable({..._removed, ...removing.intersection(known)});
    final kept = _base.removing(removed).componentNames.toSet();
    return OpenUILibrary._(
      _base,
      removed,
      Map.unmodifiable({
        for (final MapEntry(:key, :value) in _builders.entries)
          if (kept.contains(key)) key: value,
      }),
      _defaults,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUILibrary &&
        identical(other._base, _base) &&
        const SetEquality<String>().equals(other._removed, _removed) &&
        const MapEquality<String, OpenUIComponentBuilder>().equals(other._builders, _builders);
  }

  @override
  int get hashCode {
    return Object.hash(
      identityHashCode(_base),
      const SetEquality<String>().hash(_removed),
      const MapEquality<String, OpenUIComponentBuilder>().hash(_builders),
    );
  }

  @override
  String toString() => '${objectRuntimeType(this, 'OpenUILibrary')}(root: ${_base.root}, types: ${types.length})';
}
