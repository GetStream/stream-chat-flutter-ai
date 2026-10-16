import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Not doc-only: [ReasoningTheme.of] supplies the themed fields.
import 'package:stream_chat_flutter_ai/src/theme/components/reasoning_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

const _kDefaultMaxExpandedHeight = 260.0;

/// A [ReasoningThemeData] with every field resolved.
///
/// Internal. Resolution order is: the widget's own parameters, then the nearest
/// [ReasoningTheme], then [AITheme.reasoningTheme], then defaults derived from
/// the ambient [ThemeData].
@immutable
@internal
class ResolvedReasoningTheme {
  const ResolvedReasoningTheme._({
    required this.titleStyle,
    required this.textStyle,
    required this.footnoteStyle,
    required this.shimmerColor,
    required this.ruleColor,
    required this.iconColor,
    required this.maxExpandedHeight,
  });

  /// Resolves the theme at [context], with [override] (the widget's own
  /// parameters) layered on top.
  ///
  /// Unlike the other fields, [override]'s text styles are merged over the
  /// theme's rather than replacing them, so a widget passing only a font size
  /// keeps the themed color. A negative height is rejected by the constructors'
  /// asserts; here it is clamped to zero.
  factory ResolvedReasoningTheme.resolve(BuildContext context, {ReasoningThemeData? override}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = ReasoningTheme.of(context);

    TextStyle resolveStyle(TextStyle? base, Color color, TextStyle? themed, TextStyle? local) {
      var style = mergeTextStyle(mergeTextStyle((base ?? const TextStyle()).copyWith(color: color), themed), local);
      // An `inherit: false` override replaces the base outright, color and all.
      if (style.color == null) style = style.copyWith(color: color);
      return style;
    }

    final titleStyle = resolveStyle(
      theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      colors.onSurfaceVariant,
      data.titleStyle,
      override?.titleStyle,
    );

    return ResolvedReasoningTheme._(
      titleStyle: titleStyle,
      textStyle: resolveStyle(theme.textTheme.bodyMedium, colors.onSurfaceVariant, data.textStyle, override?.textStyle),
      footnoteStyle: resolveStyle(
        theme.textTheme.bodySmall,
        colors.outline,
        data.footnoteStyle,
        override?.footnoteStyle,
      ),
      shimmerColor: override?.shimmerColor ?? data.shimmerColor ?? colors.primary,
      ruleColor: override?.ruleColor ?? data.ruleColor ?? colors.outlineVariant,
      iconColor: override?.iconColor ?? data.iconColor ?? titleStyle.color!,
      maxExpandedHeight: math.max<double>(
        0,
        override?.maxExpandedHeight ?? data.maxExpandedHeight ?? _kDefaultMaxExpandedHeight,
      ),
    );
  }

  /// See [ReasoningThemeData.titleStyle]. Always carries a color.
  final TextStyle titleStyle;

  /// See [ReasoningThemeData.textStyle]. Always carries a color.
  final TextStyle textStyle;

  /// See [ReasoningThemeData.footnoteStyle]. Always carries a color.
  final TextStyle footnoteStyle;

  /// See [ReasoningThemeData.shimmerColor].
  final Color shimmerColor;

  /// See [ReasoningThemeData.ruleColor].
  final Color ruleColor;

  /// See [ReasoningThemeData.iconColor].
  final Color iconColor;

  /// See [ReasoningThemeData.maxExpandedHeight].
  final double maxExpandedHeight;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResolvedReasoningTheme &&
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
