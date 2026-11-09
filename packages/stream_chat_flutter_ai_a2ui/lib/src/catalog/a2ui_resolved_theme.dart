import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';

/// An [A2UIThemeData] with every field resolved, which the basic components
/// draw with.
///
/// Resolution order is: the surface's own theme, then the nearest
/// [A2UITheme], then the defaults from the app's [StreamTheme].
///
/// Internal to the package.
@immutable
@internal
final class A2UIResolvedTheme {
  /// Creates a theme from its colors, its text styles and its corner radii.
  A2UIResolvedTheme({
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.secondaryText,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.error,
    required this.warning,
    required this.body,
    required this.caption,
    required this.label,
    required List<TextStyle> headings,
    required this.cornerRadius,
    required this.buttonCornerRadius,
    required this.controlCornerRadius,
  }) : assert(headings.isNotEmpty, 'A theme needs at least one heading style.'),
       headings = List.unmodifiable(headings);

  /// Resolves the theme at [context], with [override], the surface's own
  /// theme, layered on top.
  factory A2UIResolvedTheme.resolve(BuildContext context, {A2UIThemeData? override}) {
    return A2UIResolvedTheme.fromData(A2UITheme.of(context).merge(override), StreamTheme.of(context));
  }

  /// Fills [data]'s unset fields from [stream].
  ///
  /// The default text styles set no color, so text takes [text], or
  /// [secondaryText] for captions.
  factory A2UIResolvedTheme.fromData(A2UIThemeData data, StreamTheme stream) {
    final colors = stream.colorScheme;
    final textTheme = stream.textTheme;
    final radius = stream.radius;
    final typography = stream.typography;
    final largest = typography.fontSize.xxl;
    return A2UIResolvedTheme(
      accent: data.accent ?? colors.accentPrimary,
      onAccent: data.onAccent ?? colors.textOnAccent,
      text: data.text ?? colors.textPrimary,
      secondaryText: data.secondaryText ?? colors.textSecondary,
      surface: data.surface ?? colors.backgroundSurfaceCard,
      subtleSurface: data.subtleSurface ?? colors.backgroundSurface,
      border: data.border ?? colors.borderDefault,
      error: data.error ?? colors.accentError,
      warning: data.warning ?? colors.accentWarning,
      body: data.body ?? _colorless(textTheme.bodyDefault),
      caption: data.caption ?? _colorless(textTheme.metadataDefault),
      label: data.label ?? _colorless(textTheme.captionDefault),
      headings:
          data.headings ??
          [
            // A level-two heading is the large heading style, so a level-one
            // heading stands above it at the largest text size, with the
            // large style's line spacing.
            _colorless(textTheme.headingLg.copyWith(fontSize: largest)),
            _colorless(textTheme.headingLg),
            _colorless(textTheme.headingMd),
            _colorless(textTheme.headingSm),
            _colorless(textTheme.headingSm),
            _colorless(textTheme.headingXs),
          ],
      cornerRadius: data.cornerRadius ?? radius.xl.x,
      buttonCornerRadius: data.buttonCornerRadius ?? radius.max.x,
      controlCornerRadius: data.controlCornerRadius ?? radius.xl.x,
    );
  }

  /// See [A2UIThemeData.accent].
  final Color accent;

  /// See [A2UIThemeData.onAccent].
  final Color onAccent;

  /// See [A2UIThemeData.text].
  final Color text;

  /// See [A2UIThemeData.secondaryText].
  final Color secondaryText;

  /// See [A2UIThemeData.surface].
  final Color surface;

  /// See [A2UIThemeData.subtleSurface].
  final Color subtleSurface;

  /// See [A2UIThemeData.border].
  final Color border;

  /// See [A2UIThemeData.error].
  final Color error;

  /// See [A2UIThemeData.warning].
  final Color warning;

  /// See [A2UIThemeData.body].
  final TextStyle body;

  /// See [A2UIThemeData.caption].
  final TextStyle caption;

  /// See [A2UIThemeData.label].
  final TextStyle label;

  /// See [A2UIThemeData.headings].
  final List<TextStyle> headings;

  /// See [A2UIThemeData.cornerRadius].
  final double cornerRadius;

  /// See [A2UIThemeData.buttonCornerRadius].
  final double buttonCornerRadius;

  /// See [A2UIThemeData.controlCornerRadius].
  final double controlCornerRadius;

  /// The style of headings of [level], counted from 1.
  ///
  /// A [level] below 1 gives the first of [headings], and one past the last
  /// gives the last.
  TextStyle heading(int level) => headings[level.clamp(1, headings.length) - 1];

  // [style] without its color, so text drawn with it takes the color around
  // it, such as the color of text on a button.
  static TextStyle _colorless(TextStyle style) {
    return TextStyle(
      inherit: style.inherit,
      backgroundColor: style.backgroundColor,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      overflow: style.overflow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is A2UIResolvedTheme &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.text == text &&
        other.secondaryText == secondaryText &&
        other.surface == surface &&
        other.subtleSurface == subtleSurface &&
        other.border == border &&
        other.error == error &&
        other.warning == warning &&
        other.body == body &&
        other.caption == caption &&
        other.label == label &&
        listEquals(other.headings, headings) &&
        other.cornerRadius == cornerRadius &&
        other.buttonCornerRadius == buttonCornerRadius &&
        other.controlCornerRadius == controlCornerRadius;
  }

  @override
  int get hashCode => Object.hash(
    accent,
    onAccent,
    text,
    secondaryText,
    surface,
    subtleSurface,
    border,
    error,
    warning,
    body,
    caption,
    label,
    Object.hashAll(headings),
    cornerRadius,
    buttonCornerRadius,
    controlCornerRadius,
  );
}
