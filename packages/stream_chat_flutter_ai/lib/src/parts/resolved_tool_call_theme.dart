import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Not doc-only: [ToolCallTheme.of] supplies the themed fields.
import 'package:stream_chat_flutter_ai/src/theme/components/tool_call_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

const _kDefaultIconSize = 14.0;

/// The default success green on light surfaces: dark enough for 4.5:1 on
/// white.
const _kSuccessOnLight = Color(0xFF1E7B34);

/// The default success green on dark surfaces.
const _kSuccessOnDark = Color(0xFF81C995);

/// A [ToolCallThemeData] with every field resolved.
///
/// Internal. Resolution order is: the widget's own parameters, then the nearest
/// [ToolCallTheme], then [AITheme.toolCallTheme], then defaults derived from
/// the ambient [ThemeData].
@immutable
@internal
class ResolvedToolCallTheme {
  const ResolvedToolCallTheme._({
    required this.titleStyle,
    required this.detailStyle,
    required this.accentColor,
    required this.successColor,
    required this.failureColor,
    required this.iconColor,
    required this.iconSize,
  });

  /// Resolves the theme at [context], with [override] (the widget's own
  /// parameters) layered on top.
  ///
  /// Unlike the other fields, [override]'s text styles are merged over the
  /// theme's rather than replacing them, so a widget passing only a font size
  /// keeps the themed color. A negative icon size is rejected by the
  /// constructors' asserts; here it is clamped to zero.
  factory ResolvedToolCallTheme.resolve(BuildContext context, {ToolCallThemeData? override}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = ToolCallTheme.of(context);

    TextStyle resolveStyle(TextStyle? base, Color color, TextStyle? themed, TextStyle? local) {
      var style = mergeTextStyle(mergeTextStyle((base ?? const TextStyle()).copyWith(color: color), themed), local);
      // An `inherit: false` override replaces the base outright, color and all.
      // A `foreground` paint stands in for a color, so that one is left alone.
      if (style.color == null && style.foreground == null) style = style.copyWith(color: color);
      return style;
    }

    final detailStyle = resolveStyle(
      theme.textTheme.bodySmall,
      colors.onSurfaceVariant,
      data.detailStyle,
      override?.detailStyle,
    );
    return ResolvedToolCallTheme._(
      titleStyle: resolveStyle(theme.textTheme.bodyMedium, colors.onSurface, data.titleStyle, override?.titleStyle),
      detailStyle: detailStyle,
      accentColor: override?.accentColor ?? data.accentColor ?? colors.primary,
      successColor:
          override?.successColor ??
          data.successColor ??
          (theme.brightness == Brightness.dark ? _kSuccessOnDark : _kSuccessOnLight),
      failureColor: override?.failureColor ?? data.failureColor ?? colors.error,
      iconColor:
          override?.iconColor ??
          data.iconColor ??
          detailStyle.color ??
          detailStyle.foreground?.color ??
          colors.onSurfaceVariant,
      iconSize: math.max<double>(0, override?.iconSize ?? data.iconSize ?? _kDefaultIconSize),
    );
  }

  /// See [ToolCallThemeData.titleStyle]. Always carries a color or a
  /// `foreground` paint.
  final TextStyle titleStyle;

  /// See [ToolCallThemeData.detailStyle]. Always carries a color or a
  /// `foreground` paint.
  final TextStyle detailStyle;

  /// See [ToolCallThemeData.accentColor].
  final Color accentColor;

  /// See [ToolCallThemeData.successColor].
  final Color successColor;

  /// See [ToolCallThemeData.failureColor].
  final Color failureColor;

  /// See [ToolCallThemeData.iconColor].
  final Color iconColor;

  /// See [ToolCallThemeData.iconSize].
  final double iconSize;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResolvedToolCallTheme &&
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
