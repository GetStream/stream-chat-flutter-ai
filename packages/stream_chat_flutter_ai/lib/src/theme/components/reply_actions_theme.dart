import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';
// Not doc-only: [ReplyActionsTheme.of] reads it.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// Overrides for how [AIReplyActionsView] is drawn: the color and size of its
/// icons.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the ambient [ThemeData] — so one instance covers light and dark mode.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(replyActionsTheme: ReplyActionsThemeData(iconColor: brandGrey)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ReplyActionsTheme]. [copyWith] cannot unset a
/// field — a `null` argument keeps the current value.
@immutable
class ReplyActionsThemeData with Diagnosticable {
  /// Creates a [ReplyActionsThemeData].
  const ReplyActionsThemeData({this.iconColor, this.selectedIconColor, this.iconSize});

  /// The icons' color. Defaults to [ColorScheme.onSurfaceVariant].
  final Color? iconColor;

  /// The color of the rating the person gave. Defaults to [iconColor]; the
  /// filled icon is what marks it.
  final Color? selectedIconColor;

  /// The icons' size. Defaults to 18.
  final double? iconSize;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ReplyActionsThemeData copyWith({Color? iconColor, Color? selectedIconColor, double? iconSize}) {
    return ReplyActionsThemeData(
      iconColor: iconColor ?? this.iconColor,
      selectedIconColor: selectedIconColor ?? this.selectedIconColor,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial.
  ReplyActionsThemeData merge(ReplyActionsThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      iconColor: other.iconColor,
      selectedIconColor: other.selectedIconColor,
      iconSize: other.iconSize,
    );
  }

  /// Linearly interpolates between two [ReplyActionsThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static ReplyActionsThemeData lerp(ReplyActionsThemeData a, ReplyActionsThemeData b, double t) {
    if (identical(a, b)) return a;
    return ReplyActionsThemeData(
      iconColor: lerpColorOrSwap(a.iconColor, b.iconColor, t),
      selectedIconColor: lerpColorOrSwap(a.selectedIconColor, b.selectedIconColor, t),
      iconSize: lerpDoubleOrSwap(a.iconSize, b.iconSize, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('iconColor', iconColor, defaultValue: null))
      ..add(ColorProperty('selectedIconColor', selectedIconColor, defaultValue: null))
      ..add(DoubleProperty('iconSize', iconSize, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReplyActionsThemeData &&
        other.iconColor == iconColor &&
        other.selectedIconColor == selectedIconColor &&
        other.iconSize == iconSize;
  }

  @override
  int get hashCode => Object.hash(iconColor, selectedIconColor, iconSize);
}

/// Overrides the reply-actions theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a color
/// leaves everything else alone:
///
/// ```dart
/// ReplyActionsTheme(
///   data: const ReplyActionsThemeData(iconColor: Colors.teal),
///   child: AIReplyActionsView(text: reply.text),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [ReplyActionsTheme.merge] to add to an enclosing scope instead.
class ReplyActionsTheme extends InheritedTheme {
  /// Creates a [ReplyActionsTheme].
  const ReplyActionsTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ReplyActionsTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ReplyActionsThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ReplyActionsTheme>()?.data;
      return ReplyActionsTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ReplyActionsThemeData data;

  /// The reply-actions theme at [context]: the nearest [ReplyActionsTheme]
  /// layered over [AITheme]'s.
  ///
  /// Depends on both, so the actions rebuild when either changes. Never
  /// `null`; with neither present every field is `null` and takes its default.
  static ReplyActionsThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ReplyActionsTheme>();
    return AITheme.of(context).replyActionsTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ReplyActionsTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ReplyActionsTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ReplyActionsThemeData>('data', data));
  }
}
