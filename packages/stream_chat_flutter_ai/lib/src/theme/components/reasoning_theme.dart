import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/reasoning/streaming_reasoning_view.dart';
// Not doc-only: [ReasoningTheme.of] reads it.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// Overrides for how [StreamingReasoningView] is drawn: the header, the
/// reasoning text and footnote, the shimmer and rule colors, and how tall the
/// open panel grows.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the ambient [ThemeData] — so one instance covers light and dark mode.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(reasoningTheme: ReasoningThemeData(shimmerColor: brandBlue)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ReasoningTheme]. [copyWith] cannot unset a
/// field — a `null` argument keeps the current value.
@immutable
class ReasoningThemeData with Diagnosticable {
  /// Creates a [ReasoningThemeData].
  const ReasoningThemeData({
    this.titleStyle,
    this.textStyle,
    this.footnoteStyle,
    this.shimmerColor,
    this.ruleColor,
    this.iconColor,
    this.maxExpandedHeight,
  }) : assert(maxExpandedHeight == null || maxExpandedHeight >= 0, 'maxExpandedHeight must not be negative');

  /// The header's style — "Thinking… 7s", "Thought for 12s" — merged over
  /// [TextTheme.bodyMedium] in [ColorScheme.onSurfaceVariant] at a medium
  /// weight. The summary beside it uses [textStyle].
  final TextStyle? titleStyle;

  /// The reasoning's style, and the summary's, merged over
  /// [TextTheme.bodyMedium] in [ColorScheme.onSurfaceVariant].
  final TextStyle? textStyle;

  /// The footnote's style, merged over [TextTheme.bodySmall] in
  /// [ColorScheme.outline].
  final TextStyle? footnoteStyle;

  /// The highlight sweeping across the header while the model thinks, the
  /// color of the rule beside the panel meanwhile, and the color of links in
  /// the reasoning. Defaults to [ColorScheme.primary].
  final Color? shimmerColor;

  /// The 2pt rule beside the reasoning once the model is done. Defaults to
  /// [ColorScheme.outlineVariant].
  final Color? ruleColor;

  /// The thinking icon and the chevron. Defaults to the resolved
  /// [titleStyle]'s color.
  final Color? iconColor;

  /// How tall the open reasoning grows before it scrolls. Defaults to 260.
  final double? maxExpandedHeight;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ReasoningThemeData copyWith({
    TextStyle? titleStyle,
    TextStyle? textStyle,
    TextStyle? footnoteStyle,
    Color? shimmerColor,
    Color? ruleColor,
    Color? iconColor,
    double? maxExpandedHeight,
  }) {
    return ReasoningThemeData(
      titleStyle: titleStyle ?? this.titleStyle,
      textStyle: textStyle ?? this.textStyle,
      footnoteStyle: footnoteStyle ?? this.footnoteStyle,
      shimmerColor: shimmerColor ?? this.shimmerColor,
      ruleColor: ruleColor ?? this.ruleColor,
      iconColor: iconColor ?? this.iconColor,
      maxExpandedHeight: maxExpandedHeight ?? this.maxExpandedHeight,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial. Like every other field, a set text style
  /// replaces this one's rather than merging into it.
  ReasoningThemeData merge(ReasoningThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      titleStyle: other.titleStyle,
      textStyle: other.textStyle,
      footnoteStyle: other.footnoteStyle,
      shimmerColor: other.shimmerColor,
      ruleColor: other.ruleColor,
      iconColor: other.iconColor,
      maxExpandedHeight: other.maxExpandedHeight,
    );
  }

  /// Linearly interpolates between two [ReasoningThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static ReasoningThemeData lerp(ReasoningThemeData a, ReasoningThemeData b, double t) {
    if (identical(a, b)) return a;
    return ReasoningThemeData(
      titleStyle: lerpTextStyleOrSwap(a.titleStyle, b.titleStyle, t),
      textStyle: lerpTextStyleOrSwap(a.textStyle, b.textStyle, t),
      footnoteStyle: lerpTextStyleOrSwap(a.footnoteStyle, b.footnoteStyle, t),
      shimmerColor: lerpColorOrSwap(a.shimmerColor, b.shimmerColor, t),
      ruleColor: lerpColorOrSwap(a.ruleColor, b.ruleColor, t),
      iconColor: lerpColorOrSwap(a.iconColor, b.iconColor, t),
      maxExpandedHeight: lerpDoubleOrSwap(a.maxExpandedHeight, b.maxExpandedHeight, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TextStyle>('titleStyle', titleStyle, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('textStyle', textStyle, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('footnoteStyle', footnoteStyle, defaultValue: null))
      ..add(ColorProperty('shimmerColor', shimmerColor, defaultValue: null))
      ..add(ColorProperty('ruleColor', ruleColor, defaultValue: null))
      ..add(ColorProperty('iconColor', iconColor, defaultValue: null))
      ..add(DoubleProperty('maxExpandedHeight', maxExpandedHeight, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReasoningThemeData &&
        other.titleStyle == titleStyle &&
        other.textStyle == textStyle &&
        other.footnoteStyle == footnoteStyle &&
        other.shimmerColor == shimmerColor &&
        other.ruleColor == ruleColor &&
        other.iconColor == iconColor &&
        other.maxExpandedHeight == maxExpandedHeight;
  }

  @override
  int get hashCode =>
      Object.hash(titleStyle, textStyle, footnoteStyle, shimmerColor, ruleColor, iconColor, maxExpandedHeight);
}

/// Overrides the reasoning theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a color
/// leaves everything else alone:
///
/// ```dart
/// ReasoningTheme(
///   data: const ReasoningThemeData(shimmerColor: Colors.teal),
///   child: StreamingReasoningView(text: reasoning, isThinking: true),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [ReasoningTheme.merge] to add to an enclosing scope instead.
class ReasoningTheme extends InheritedTheme {
  /// Creates a [ReasoningTheme].
  const ReasoningTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ReasoningTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ReasoningThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ReasoningTheme>()?.data;
      return ReasoningTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ReasoningThemeData data;

  /// The reasoning theme at [context]: the nearest [ReasoningTheme] layered
  /// over [AITheme]'s.
  ///
  /// Depends on both, so reasoning views rebuild when either changes. Never
  /// `null`; with neither present every field is `null` and takes its default.
  static ReasoningThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ReasoningTheme>();
    return AITheme.of(context).reasoningTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ReasoningTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ReasoningTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ReasoningThemeData>('data', data));
  }
}
