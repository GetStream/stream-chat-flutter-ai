import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/typing_indicator_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';
import 'package:stream_core_flutter/chat.dart';

/// A [TypingIndicatorThemeData] with every field resolved.
///
/// Internal. Resolution order is: the widget's own parameters, then the nearest
/// [TypingIndicatorTheme], then [AITheme.typingIndicatorTheme], then defaults
/// derived from the Stream theme ([StreamTheme]).
@immutable
@internal
class ResolvedTypingIndicatorTheme {
  const ResolvedTypingIndicatorTheme._({
    required this.textStyle,
    required this.dotColor,
    required this.dotSize,
    required this.dotSpacing,
  });

  /// Resolves the theme at [context], with [override] (the widget's own
  /// parameters) layered on top.
  ///
  /// Unlike the other fields, [override]'s text style is merged over the
  /// theme's rather than replacing it, so a widget passing only a font size
  /// keeps the themed color.
  ///
  /// Negative sizes and counts are rejected by the constructors' asserts; here
  /// they are clamped to zero, so a release build draws nothing rather than
  /// throwing at layout.
  factory ResolvedTypingIndicatorTheme.resolve(BuildContext context, {TypingIndicatorThemeData? override}) {
    final colors = context.streamColorScheme;
    final data = TypingIndicatorTheme.of(context);

    final defaultColor = colors.textSecondary;
    final base = context.streamTextTheme.bodyDefault.copyWith(color: defaultColor);
    var textStyle = mergeTextStyle(mergeTextStyle(base, data.textStyle), override?.textStyle);
    // An `inherit: false` override replaces the base outright, color and all.
    if (textStyle.color == null) textStyle = textStyle.copyWith(color: defaultColor);

    return ResolvedTypingIndicatorTheme._(
      textStyle: textStyle,
      dotColor: override?.dotColor ?? data.dotColor ?? textStyle.color!,
      dotSize: _nonNegative(override?.dotSize ?? data.dotSize),
      dotSpacing: _nonNegative(override?.dotSpacing ?? data.dotSpacing),
    );
  }

  static double? _nonNegative(double? value) => value == null ? null : math.max(0, value);

  /// See [TypingIndicatorThemeData.textStyle]. Always carries a color.
  final TextStyle textStyle;

  /// See [TypingIndicatorThemeData.dotColor].
  final Color dotColor;

  /// See [TypingIndicatorThemeData.dotSize].
  final double? dotSize;

  /// See [TypingIndicatorThemeData.dotSpacing].
  final double? dotSpacing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResolvedTypingIndicatorTheme &&
        other.textStyle == textStyle &&
        other.dotColor == dotColor &&
        other.dotSize == dotSize &&
        other.dotSpacing == dotSpacing;
  }

  @override
  int get hashCode => Object.hash(textStyle, dotColor, dotSize, dotSpacing);
}
