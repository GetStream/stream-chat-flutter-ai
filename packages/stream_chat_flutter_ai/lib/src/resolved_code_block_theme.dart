import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// `ai_theme.dart` (the next import) is for doc links only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// The code color on a light background when no theme sets one.
const _kDefaultLightCodeForegroundColor = Color(0xFF1F2328);

/// The copied check mark on a light background; [Colors.greenAccent] is too
/// pale to read there.
const _kDefaultLightCopiedIconColor = Color(0xFF2E7D32);

/// How much of the code color the header chrome keeps by default.
const _kLabelOpacity = 0.6;

/// The font stack for code text.
///
/// `monospace` is a real family only on Android; elsewhere it silently resolves
/// to the default sans face, so the fallbacks name each platform's real one.
const _kMonoFontFamily = 'monospace';
const _kMonoFontFamilyFallback = ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'];

/// A [CodeBlockThemeData] with every field resolved.
///
/// Internal. Resolution order is: the widget's own theme, then the nearest
/// [CodeBlockTheme], then [AITheme.codeBlockTheme], then the defaults.
@immutable
@internal
class ResolvedCodeBlockTheme {
  const ResolvedCodeBlockTheme._({
    required this.backgroundColor,
    required this.headerBackgroundColor,
    required this.languageLabelStyle,
    required this.copyIconColor,
    required this.copiedIconColor,
    required this.codeTextStyle,
    required this.brightness,
  });

  /// Resolves the theme at [context], with [override] (the widget's own
  /// theme) layered on top.
  factory ResolvedCodeBlockTheme.resolve(BuildContext context, {CodeBlockThemeData? override}) =>
      ResolvedCodeBlockTheme.fromData(CodeBlockTheme.of(context).merge(override));

  /// Fills [theme]'s unset fields with the defaults.
  factory ResolvedCodeBlockTheme.fromData(CodeBlockThemeData theme) {
    final backgroundColor = theme.backgroundColor ?? kDefaultCodeBackgroundColor;
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    final isDark = brightness == Brightness.dark;

    final defaultCodeColor = isDark ? kDefaultCodeForegroundColor : _kDefaultLightCodeForegroundColor;
    final codeTextStyle = _withColor(
      mergeTextStyle(
        TextStyle(
          fontFamily: _kMonoFontFamily,
          fontFamilyFallback: _kMonoFontFamilyFallback,
          fontSize: 13,
          color: defaultCodeColor,
          height: 1.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        theme.codeTextStyle,
      ),
      defaultCodeColor,
    );

    // Scaled rather than replaced, so a translucent code color never gets
    // chrome more opaque than itself.
    final codeColor = codeTextStyle.color!;
    final chromeColor = codeColor.withValues(alpha: codeColor.a * _kLabelOpacity);
    final languageLabelStyle = _withColor(
      mergeTextStyle(
        TextStyle(
          // The code's own font, so a host restyling the code restyles the label.
          fontFamily: codeTextStyle.fontFamily,
          fontFamilyFallback: codeTextStyle.fontFamilyFallback,
          fontSize: 12,
          color: chromeColor,
        ),
        theme.languageLabelStyle,
      ),
      chromeColor,
    );

    return ResolvedCodeBlockTheme._(
      backgroundColor: backgroundColor,
      headerBackgroundColor: theme.headerBackgroundColor ?? backgroundColor,
      languageLabelStyle: languageLabelStyle,
      copyIconColor: theme.copyIconColor ?? chromeColor,
      copiedIconColor: theme.copiedIconColor ?? (isDark ? Colors.greenAccent : _kDefaultLightCopiedIconColor),
      codeTextStyle: codeTextStyle,
      brightness: brightness,
    );
  }

  /// An `inherit: false` override replaces the base outright, color and all.
  static TextStyle _withColor(TextStyle style, Color color) =>
      style.color == null ? style.copyWith(color: color) : style;

  /// See [CodeBlockThemeData.backgroundColor].
  final Color backgroundColor;

  /// See [CodeBlockThemeData.headerBackgroundColor].
  final Color headerBackgroundColor;

  /// See [CodeBlockThemeData.languageLabelStyle]. Always carries a color.
  final TextStyle languageLabelStyle;

  /// See [CodeBlockThemeData.copyIconColor].
  final Color copyIconColor;

  /// See [CodeBlockThemeData.copiedIconColor].
  final Color copiedIconColor;

  /// See [CodeBlockThemeData.codeTextStyle]. Always carries a color.
  final TextStyle codeTextStyle;

  /// The estimated brightness of [backgroundColor].
  final Brightness brightness;

  /// This theme as a [CodeBlockThemeData] with every field set, as handed to a
  /// highlighter.
  CodeBlockThemeData toData() => CodeBlockThemeData(
    backgroundColor: backgroundColor,
    headerBackgroundColor: headerBackgroundColor,
    languageLabelStyle: languageLabelStyle,
    copyIconColor: copyIconColor,
    copiedIconColor: copiedIconColor,
    codeTextStyle: codeTextStyle,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // [brightness] is derived from [backgroundColor], so it needn't be compared.
    return other is ResolvedCodeBlockTheme &&
        other.backgroundColor == backgroundColor &&
        other.headerBackgroundColor == headerBackgroundColor &&
        other.languageLabelStyle == languageLabelStyle &&
        other.copyIconColor == copyIconColor &&
        other.copiedIconColor == copiedIconColor &&
        other.codeTextStyle == codeTextStyle;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    headerBackgroundColor,
    languageLabelStyle,
    copyIconColor,
    copiedIconColor,
    codeTextStyle,
  );
}
