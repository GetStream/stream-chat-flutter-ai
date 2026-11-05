import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// The look of a reply's A2UI: the colors, fonts and corners its components
/// are drawn with.
///
/// A reply's A2UI is drawn with the theme [A2UITheme.fromStream] makes from
/// the app's [StreamTheme], so it looks like the rest of the conversation. A
/// theme that changes only A2UI, such as its accent, starts from that one; the
/// renderer that takes a theme comes in a later version of the package:
///
/// ```dart
/// final theme = A2UITheme.fromStream(StreamTheme.of(context)).copyWith(
///   accent: const Color(0xFFE65100),
/// );
/// ```
///
/// Two themes are equal when all their values are.
@immutable
final class A2UITheme {
  /// Creates a theme from its colors, its text styles and its corner radii.
  ///
  /// The [headings] are the styles of headings from level 1 down, at least
  /// one; see [heading]. The theme keeps its own copy of them.
  A2UITheme({
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
  }) : assert(headings.isNotEmpty, 'An A2UITheme needs at least one heading style.'),
       headings = List.unmodifiable(headings);

  /// Creates the theme of the Stream design system's [theme]: its colors,
  /// text styles and corner radii.
  ///
  /// The text styles set no color, so text takes [text], or [secondaryText]
  /// for captions.
  factory A2UITheme.fromStream(StreamTheme theme) {
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final radius = theme.radius;
    return A2UITheme(
      accent: colors.accentPrimary,
      onAccent: colors.textOnAccent,
      text: colors.textPrimary,
      secondaryText: colors.textSecondary,
      surface: colors.backgroundSurfaceCard,
      subtleSurface: colors.backgroundSurface,
      border: colors.borderDefault,
      error: colors.accentError,
      warning: colors.accentWarning,
      body: _colorless(text.bodyDefault),
      caption: _colorless(text.metadataDefault),
      label: _colorless(text.captionDefault),
      headings: [
        _colorless(text.headingLg),
        _colorless(text.headingMd),
        _colorless(text.headingSm),
        _colorless(text.headingXs),
      ],
      cornerRadius: radius.xl.x,
      buttonCornerRadius: radius.max.x,
      controlCornerRadius: radius.xl.x,
    );
  }

  /// The theme of the surface a component is drawn in, for a builder of the
  /// surface's catalog, or a widget it builds, to draw with.
  ///
  /// Asserts that [context] is inside a surface.
  static A2UITheme of(BuildContext context) => A2UISurfaceScope.of(context).theme;

  /// The color of primary buttons, selected options and the active parts of
  /// controls, such as the selected tab.
  final Color accent;

  /// The color of text and icons on [accent], such as a primary button's
  /// title.
  final Color onAccent;

  /// The color of text and icons.
  final Color text;

  /// The color of captions, labels and other quieter text.
  final Color secondaryText;

  /// The background of cards.
  final Color surface;

  /// The background of buttons, fields and options, and of images while they
  /// load.
  final Color subtleSurface;

  /// The color of dividers and outlines.
  final Color border;

  /// The color of a field's errors.
  final Color error;

  /// The color of a field's warnings.
  final Color warning;

  /// The style of text.
  final TextStyle body;

  /// The style of captions, such as text in the `caption` variant, and of a
  /// field's messages.
  final TextStyle caption;

  /// The style of labels, such as tab titles and a field's label.
  final TextStyle label;

  /// The styles of headings in text, from level 1 down.
  ///
  /// A level deeper than it has uses the last one; see [heading].
  final List<TextStyle> headings;

  /// The corner radius of cards.
  final double cornerRadius;

  /// The corner radius of buttons.
  final double buttonCornerRadius;

  /// The corner radius of fields, images and players.
  final double controlCornerRadius;

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

  /// The style of headings of [level], counted from 1.
  ///
  /// A [level] below 1 gives the first of [headings], and one past the last
  /// gives the last.
  TextStyle heading(int level) {
    return headings[level.clamp(1, headings.length) - 1];
  }

  /// A copy of this theme with the given values in place of its own.
  A2UITheme copyWith({
    Color? accent,
    Color? onAccent,
    Color? text,
    Color? secondaryText,
    Color? surface,
    Color? subtleSurface,
    Color? border,
    Color? error,
    Color? warning,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? label,
    List<TextStyle>? headings,
    double? cornerRadius,
    double? buttonCornerRadius,
    double? controlCornerRadius,
  }) {
    return A2UITheme(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      surface: surface ?? this.surface,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      border: border ?? this.border,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      label: label ?? this.label,
      headings: headings ?? this.headings,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      buttonCornerRadius: buttonCornerRadius ?? this.buttonCornerRadius,
      controlCornerRadius: controlCornerRadius ?? this.controlCornerRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    return other is A2UITheme &&
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

  @override
  String toString() {
    return '${objectRuntimeType(this, 'A2UITheme')}(accent: $accent, text: $text, surface: $surface, '
        'cornerRadius: $cornerRadius)';
  }
}
