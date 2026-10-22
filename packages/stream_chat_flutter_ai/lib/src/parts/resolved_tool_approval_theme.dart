import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Not doc-only: [ToolApprovalTheme.of] supplies the themed fields.
import 'package:stream_chat_flutter_ai/src/theme/components/tool_approval_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';
import 'package:stream_core_flutter/chat.dart';

/// A [ToolApprovalThemeData] with every field resolved.
///
/// Internal. Resolution order is: the widget's own parameters, then the nearest
/// [ToolApprovalTheme], then [AITheme.toolApprovalTheme], then defaults derived
/// from the Stream theme ([StreamTheme]).
@immutable
@internal
class ResolvedToolApprovalTheme {
  const ResolvedToolApprovalTheme._({
    required this.titleStyle,
    required this.messageStyle,
    required this.backgroundColor,
    required this.borderColor,
    required this.accentColor,
    required this.onAccentColor,
    required this.failureStyle,
  });

  /// Resolves the theme at [context], with [override] (the widget's own
  /// parameters) layered on top.
  ///
  /// Unlike the other fields, [override]'s text styles are merged over the
  /// theme's rather than replacing them, so a widget passing only a font size
  /// keeps the themed color.
  factory ResolvedToolApprovalTheme.resolve(BuildContext context, {ToolApprovalThemeData? override}) {
    final colors = context.streamColorScheme;
    final text = context.streamTextTheme;
    final data = ToolApprovalTheme.of(context);

    TextStyle resolveStyle(TextStyle? base, Color color, TextStyle? themed, TextStyle? local) {
      var style = mergeTextStyle(mergeTextStyle((base ?? const TextStyle()).copyWith(color: color), themed), local);
      // An `inherit: false` override replaces the base outright, color and all.
      if (style.color == null) style = style.copyWith(color: color);
      return style;
    }

    final accentColor = override?.accentColor ?? data.accentColor ?? colors.accentPrimary;
    return ResolvedToolApprovalTheme._(
      titleStyle: resolveStyle(
        text.bodyEmphasis,
        colors.textPrimary,
        data.titleStyle,
        override?.titleStyle,
      ),
      messageStyle: resolveStyle(
        text.captionDefault,
        colors.textSecondary,
        data.messageStyle,
        override?.messageStyle,
      ),
      backgroundColor: override?.backgroundColor ?? data.backgroundColor ?? colors.backgroundSurfaceCard,
      borderColor: override?.borderColor ?? data.borderColor ?? colors.borderDefault,
      accentColor: accentColor,
      // The scheme's own pairing when the accent is the scheme's, otherwise
      // whichever of black and white reads on it.
      onAccentColor: accentColor == colors.accentPrimary
          ? colors.textOnAccent
          : switch (ThemeData.estimateBrightnessForColor(accentColor)) {
              Brightness.dark => const Color(0xFFFFFFFF),
              Brightness.light => const Color(0xFF000000),
            },
      failureStyle: resolveStyle(text.captionDefault, colors.accentError, data.failureStyle, override?.failureStyle),
    );
  }

  /// See [ToolApprovalThemeData.titleStyle]. Always carries a color.
  final TextStyle titleStyle;

  /// See [ToolApprovalThemeData.messageStyle]. Always carries a color.
  final TextStyle messageStyle;

  /// See [ToolApprovalThemeData.backgroundColor].
  final Color backgroundColor;

  /// See [ToolApprovalThemeData.borderColor].
  final Color borderColor;

  /// See [ToolApprovalThemeData.accentColor].
  final Color accentColor;

  /// The allow button's label color, derived from [accentColor].
  final Color onAccentColor;

  /// See [ToolApprovalThemeData.failureStyle]. Always carries a color.
  final TextStyle failureStyle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResolvedToolApprovalTheme &&
        other.titleStyle == titleStyle &&
        other.messageStyle == messageStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.accentColor == accentColor &&
        other.onAccentColor == onAccentColor &&
        other.failureStyle == failureStyle;
  }

  @override
  int get hashCode =>
      Object.hash(titleStyle, messageStyle, backgroundColor, borderColor, accentColor, onAccentColor, failureStyle);
}
