import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_view.dart';
// Not doc-only: [ToolCallTheme.of] reads it.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/components/reasoning_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';
// Imported for the doc links below only.
import 'package:stream_core_flutter/chat.dart';

/// Overrides for how [AIToolCallView] is drawn: the title and detail text, the
/// status icon's colors and its size.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the Stream theme ([StreamTheme], which falls back to Stream's defaults for
/// the app's brightness when the app sets none) — so one instance covers light and dark
/// mode.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(toolCallTheme: ToolCallThemeData(accentColor: brandBlue)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ToolCallTheme]. [copyWith] cannot unset a
/// field — a `null` argument keeps the current value.
@immutable
class ToolCallThemeData with Diagnosticable {
  /// Creates a [ToolCallThemeData].
  const ToolCallThemeData({
    this.titleStyle,
    this.detailStyle,
    this.accentColor,
    this.successColor,
    this.failureColor,
    this.iconColor,
    this.iconSize,
  }) : assert(iconSize == null || iconSize >= 0, 'iconSize must not be negative');

  /// The title's style — "Checking the weather" — merged over
  /// the Stream theme's `bodyDefault` in `textPrimary`.
  final TextStyle? titleStyle;

  /// The style of the detail line under the title (the summary, or a status
  /// such as "Waiting for approval") and of the duration, merged over
  /// the Stream theme's `captionDefault` in `textSecondary`.
  final TextStyle? detailStyle;

  /// The spinner of a running call, and the band of light sweeping across the
  /// icon of a call waiting for approval or for a device — the same role as
  /// [ReasoningThemeData.shimmerColor]. With reduced motion on, the waiting
  /// icon is drawn in it outright. Defaults to the Stream theme's
  /// `accentPrimary`.
  final Color? accentColor;

  /// The check of a completed call. Defaults to the Stream theme's
  /// `accentSuccess`.
  final Color? successColor;

  /// The icon of a failed call. Defaults to the Stream theme's `accentError`.
  final Color? failureColor;

  /// The neutral icons: the cross of a cancelled or declined call, and a
  /// waiting call's icon beneath its [accentColor] band. Defaults to the
  /// resolved [detailStyle]'s color.
  final Color? iconColor;

  /// The status icon's size, and the spinner's. Defaults to 14.
  final double? iconSize;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ToolCallThemeData copyWith({
    TextStyle? titleStyle,
    TextStyle? detailStyle,
    Color? accentColor,
    Color? successColor,
    Color? failureColor,
    Color? iconColor,
    double? iconSize,
  }) {
    return ToolCallThemeData(
      titleStyle: titleStyle ?? this.titleStyle,
      detailStyle: detailStyle ?? this.detailStyle,
      accentColor: accentColor ?? this.accentColor,
      successColor: successColor ?? this.successColor,
      failureColor: failureColor ?? this.failureColor,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial. Like every other field, a set text style
  /// replaces this one's rather than merging into it.
  ToolCallThemeData merge(ToolCallThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      titleStyle: other.titleStyle,
      detailStyle: other.detailStyle,
      accentColor: other.accentColor,
      successColor: other.successColor,
      failureColor: other.failureColor,
      iconColor: other.iconColor,
      iconSize: other.iconSize,
    );
  }

  /// Linearly interpolates between two [ToolCallThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static ToolCallThemeData lerp(ToolCallThemeData a, ToolCallThemeData b, double t) {
    if (identical(a, b)) return a;
    return ToolCallThemeData(
      titleStyle: lerpTextStyleOrSwap(a.titleStyle, b.titleStyle, t),
      detailStyle: lerpTextStyleOrSwap(a.detailStyle, b.detailStyle, t),
      accentColor: lerpColorOrSwap(a.accentColor, b.accentColor, t),
      successColor: lerpColorOrSwap(a.successColor, b.successColor, t),
      failureColor: lerpColorOrSwap(a.failureColor, b.failureColor, t),
      iconColor: lerpColorOrSwap(a.iconColor, b.iconColor, t),
      iconSize: lerpDoubleOrSwap(a.iconSize, b.iconSize, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TextStyle>('titleStyle', titleStyle, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('detailStyle', detailStyle, defaultValue: null))
      ..add(ColorProperty('accentColor', accentColor, defaultValue: null))
      ..add(ColorProperty('successColor', successColor, defaultValue: null))
      ..add(ColorProperty('failureColor', failureColor, defaultValue: null))
      ..add(ColorProperty('iconColor', iconColor, defaultValue: null))
      ..add(DoubleProperty('iconSize', iconSize, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolCallThemeData &&
        other.titleStyle == titleStyle &&
        other.detailStyle == detailStyle &&
        other.accentColor == accentColor &&
        other.successColor == successColor &&
        other.failureColor == failureColor &&
        other.iconColor == iconColor &&
        other.iconSize == iconSize;
  }

  @override
  int get hashCode =>
      Object.hash(titleStyle, detailStyle, accentColor, successColor, failureColor, iconColor, iconSize);
}

/// Overrides the tool-call theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a color
/// leaves everything else alone:
///
/// ```dart
/// ToolCallTheme(
///   data: const ToolCallThemeData(accentColor: Colors.teal),
///   child: AIToolCallView(call: call),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [ToolCallTheme.merge] to add to an enclosing scope instead.
class ToolCallTheme extends InheritedTheme {
  /// Creates a [ToolCallTheme].
  const ToolCallTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ToolCallTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ToolCallThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ToolCallTheme>()?.data;
      return ToolCallTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ToolCallThemeData data;

  /// The tool-call theme at [context]: the nearest [ToolCallTheme] layered
  /// over [AITheme]'s.
  ///
  /// Depends on both, so tool-call views rebuild when either changes. Never
  /// `null`; with neither present every field is `null` and takes its default.
  static ToolCallThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ToolCallTheme>();
    return AITheme.of(context).toolCallTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ToolCallTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ToolCallTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ToolCallThemeData>('data', data));
  }
}
