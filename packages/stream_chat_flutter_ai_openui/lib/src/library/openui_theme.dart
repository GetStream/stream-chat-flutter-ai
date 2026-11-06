import 'dart:ui' show lerpDouble;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_core_flutter/core.dart';

/// Gives the OpenUI components below [child] the look in [data]: their
/// colors, spacing, corner radii and text styles.
///
/// A value [data] leaves `null` takes its default, read from the app's
/// [StreamTheme], so OpenUI looks like the rest of the conversation unless an
/// app changes it:
///
/// ```dart
/// OpenUITheme(
///   data: const OpenUIThemeData(
///     colors: OpenUIColors(accent: Color(0xFFE65100)),
///   ),
///   child: conversation,
/// )
/// ```
///
/// The components of the design system that OpenUI components are drawn with,
/// such as its spinners, take the theme's colors, spacing, corner radii and
/// text styles too, and still use the builders the app gives the design
/// system through [StreamComponentFactory].
class OpenUITheme extends InheritedTheme {
  /// Creates an [OpenUITheme].
  const OpenUITheme({super.key, required this.data, required super.child});

  /// The look of the OpenUI components below; `null` values take their
  /// defaults.
  final OpenUIThemeData data;

  /// The look of the OpenUI components at [context]: the data of the nearest
  /// [OpenUITheme], with every value it leaves `null` filled in from the
  /// [StreamTheme] at [context].
  ///
  /// Every value of the returned data is set.
  static OpenUIThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<OpenUITheme>()?.data;
    return OpenUIThemeData.defaults(StreamTheme.of(context)).merge(local);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => OpenUITheme(data: data, child: child);

  @override
  bool updateShouldNotify(OpenUITheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OpenUIThemeData>('data', data));
  }
}

/// The look of OpenUI components, given to an [OpenUITheme]: [colors],
/// [spacing], corner [radius] and [textStyles].
///
/// Every value is optional: one left `null` takes its default from the app's
/// [StreamTheme]; see [OpenUITheme.of].
///
/// Two values are equal when all their values are.
@immutable
class OpenUIThemeData with Diagnosticable {
  /// Creates the look of OpenUI components.
  const OpenUIThemeData({this.colors, this.spacing, this.radius, this.textStyles});

  /// The look the [stream] theme gives: every value set, from its tokens.
  ///
  /// Internal to the package.
  @internal
  factory OpenUIThemeData.defaults(StreamTheme stream) {
    final colors = stream.colorScheme;
    final text = stream.textTheme;
    final spacing = stream.spacing;
    final radius = stream.radius;
    return OpenUIThemeData(
      colors: OpenUIColors(
        accent: colors.accentPrimary,
        onAccent: colors.textOnAccent,
        textPrimary: colors.textPrimary,
        textSecondary: colors.textSecondary,
        textTertiary: colors.textTertiary,
        surface: colors.backgroundSurfaceCard,
        sunkenSurface: colors.backgroundSurface,
        subtleFill: colors.backgroundSurfaceSubtle,
        border: colors.borderDefault,
        success: colors.accentSuccess,
        warning: colors.accentWarning,
        danger: colors.accentError,
        info: colors.accentPrimary,
        neutral: colors.accentNeutral,
        chartPalette: OpenUIColors._defaultChartPalette,
      ),
      spacing: OpenUISpacing(
        xs: spacing.xxs,
        s: spacing.xs,
        m: spacing.sm,
        l: spacing.md,
        xl: spacing.xl,
        xxl: spacing.xxl,
      ),
      radius: OpenUIRadius(small: radius.md.x, medium: radius.lg.x, large: radius.xl.x, pill: radius.max.x),
      textStyles: OpenUITextStyles(
        title: _colorless(text.headingMd),
        heading: _colorless(text.headingSm),
        body: _colorless(text.bodyDefault),
        bodyLarge: _colorless(text.headingMd.copyWith(fontWeight: text.bodyDefault.fontWeight)),
        bodySmall: _colorless(text.captionDefault),
        caption: _colorless(text.metadataDefault),
        code: OpenUITextStyles._defaultCode,
        metric: OpenUITextStyles._defaultMetric,
      ),
    );
  }

  /// The colors, such as the accent and the text colors.
  final OpenUIColors? colors;

  /// The space between and around components.
  final OpenUISpacing? spacing;

  /// The corner radii.
  final OpenUIRadius? radius;

  /// The text styles, such as of titles and body text.
  final OpenUITextStyles? textStyles;

  // [style] without its colors.
  static TextStyle _colorless(TextStyle style) {
    return TextStyle(
      inherit: style.inherit,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      overflow: style.overflow,
    );
  }

  /// A copy of this data with the given groups replaced.
  OpenUIThemeData copyWith({
    OpenUIColors? colors,
    OpenUISpacing? spacing,
    OpenUIRadius? radius,
    OpenUITextStyles? textStyles,
  }) {
    return OpenUIThemeData(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      textStyles: textStyles ?? this.textStyles,
    );
  }

  /// This data with the values [other] sets in place of its own, group by
  /// group and value by value.
  OpenUIThemeData merge(OpenUIThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return OpenUIThemeData(
      colors: colors?.merge(other.colors) ?? other.colors,
      spacing: spacing?.merge(other.spacing) ?? other.spacing,
      radius: radius?.merge(other.radius) ?? other.radius,
      textStyles: textStyles?.merge(other.textStyles) ?? other.textStyles,
    );
  }

  /// The data between [a] and [b] at [t], from 0 for [a] to 1 for [b].
  ///
  /// A value set on only one side switches over at the middle.
  static OpenUIThemeData lerp(OpenUIThemeData a, OpenUIThemeData b, double t) {
    if (identical(a, b)) return a;
    return OpenUIThemeData(
      colors: _lerpOrSwap(a.colors, b.colors, t, OpenUIColors.lerp),
      spacing: _lerpOrSwap(a.spacing, b.spacing, t, OpenUISpacing.lerp),
      radius: _lerpOrSwap(a.radius, b.radius, t, OpenUIRadius.lerp),
      textStyles: _lerpOrSwap(a.textStyles, b.textStyles, t, OpenUITextStyles.lerp),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<OpenUIColors>('colors', colors, defaultValue: null))
      ..add(DiagnosticsProperty<OpenUISpacing>('spacing', spacing, defaultValue: null))
      ..add(DiagnosticsProperty<OpenUIRadius>('radius', radius, defaultValue: null))
      ..add(DiagnosticsProperty<OpenUITextStyles>('textStyles', textStyles, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIThemeData &&
        other.colors == colors &&
        other.spacing == spacing &&
        other.radius == radius &&
        other.textStyles == textStyles;
  }

  @override
  int get hashCode => Object.hash(colors, spacing, radius, textStyles);
}

/// The colors of an [OpenUIThemeData].
///
/// A color left `null` takes the default [OpenUITheme.of] names for it.
///
/// Two values are equal when all their colors are.
@immutable
class OpenUIColors with Diagnosticable {
  /// Creates the colors of an [OpenUIThemeData].
  const OpenUIColors({
    this.accent,
    this.onAccent,
    this.textPrimary,
    this.textSecondary,
    this.textTertiary,
    this.surface,
    this.sunkenSurface,
    this.subtleFill,
    this.border,
    this.success,
    this.warning,
    this.danger,
    this.info,
    this.neutral,
    this.chartPalette,
  });

  /// The color of links, selected controls and primary buttons; the design
  /// system's `accentPrimary` by default.
  final Color? accent;

  /// The color of text and icons drawn on [accent]; `textOnAccent` by
  /// default.
  final Color? onAccent;

  /// The color of most text, such as titles and body text; `textPrimary` by
  /// default.
  final Color? textPrimary;

  /// The color of less prominent text, such as subtitles; `textSecondary` by
  /// default.
  final Color? textSecondary;

  /// The color of the least prominent text, such as placeholders;
  /// `textTertiary` by default.
  final Color? textTertiary;

  /// The background of cards; `backgroundSurfaceCard` by default.
  final Color? surface;

  /// The background of parts set into a card, such as a sunken card;
  /// `backgroundSurface` by default.
  final Color? sunkenSurface;

  /// A light fill, such as the background of inline code;
  /// `backgroundSurfaceSubtle` by default.
  final Color? subtleFill;

  /// The color of borders and dividers; `borderDefault` by default.
  final Color? border;

  /// The color of success, such as a positive change; `accentSuccess` by
  /// default.
  final Color? success;

  /// The color of warnings; `accentWarning` by default.
  final Color? warning;

  /// The color of errors and of negative changes; `accentError` by default.
  final Color? danger;

  /// The color of information; `accentPrimary` by default.
  final Color? info;

  /// The color of what has no other status color; `accentNeutral` by
  /// default.
  final Color? neutral;

  /// The colors of a chart's series, in order; eight colors that are the
  /// same for every Stream theme by default.
  final List<Color>? chartPalette;

  // The chart colors of OpenUI's iOS and Android components.
  static const _defaultChartPalette = [
    Color(0xFF4078F5),
    Color(0xFF1CB59E),
    Color(0xFFFA9E29),
    Color(0xFFE04A75),
    Color(0xFF8C61ED),
    Color(0xFF29ADE0),
    Color(0xFF9EB833),
    Color(0xFFED6945),
  ];

  /// A copy of these colors with the given ones replaced.
  OpenUIColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? surface,
    Color? sunkenSurface,
    Color? subtleFill,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? neutral,
    List<Color>? chartPalette,
  }) {
    return OpenUIColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      surface: surface ?? this.surface,
      sunkenSurface: sunkenSurface ?? this.sunkenSurface,
      subtleFill: subtleFill ?? this.subtleFill,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  /// These colors with the ones [other] sets in place of their own.
  OpenUIColors merge(OpenUIColors? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      accent: other.accent,
      onAccent: other.onAccent,
      textPrimary: other.textPrimary,
      textSecondary: other.textSecondary,
      textTertiary: other.textTertiary,
      surface: other.surface,
      sunkenSurface: other.sunkenSurface,
      subtleFill: other.subtleFill,
      border: other.border,
      success: other.success,
      warning: other.warning,
      danger: other.danger,
      info: other.info,
      neutral: other.neutral,
      chartPalette: other.chartPalette,
    );
  }

  /// The colors between [a] and [b] at [t], from 0 for [a] to 1 for [b].
  ///
  /// A color set on only one side, and a chart palette whose length changes,
  /// switch over at the middle.
  static OpenUIColors lerp(OpenUIColors a, OpenUIColors b, double t) {
    if (identical(a, b)) return a;
    Color? color(Color? a, Color? b) => _lerpOrSwap(a, b, t, (a, b, t) => Color.lerp(a, b, t)!);
    final (paletteA, paletteB) = (a.chartPalette, b.chartPalette);
    return OpenUIColors(
      accent: color(a.accent, b.accent),
      onAccent: color(a.onAccent, b.onAccent),
      textPrimary: color(a.textPrimary, b.textPrimary),
      textSecondary: color(a.textSecondary, b.textSecondary),
      textTertiary: color(a.textTertiary, b.textTertiary),
      surface: color(a.surface, b.surface),
      sunkenSurface: color(a.sunkenSurface, b.sunkenSurface),
      subtleFill: color(a.subtleFill, b.subtleFill),
      border: color(a.border, b.border),
      success: color(a.success, b.success),
      warning: color(a.warning, b.warning),
      danger: color(a.danger, b.danger),
      info: color(a.info, b.info),
      neutral: color(a.neutral, b.neutral),
      chartPalette: paletteA != null && paletteB != null && paletteA.length == paletteB.length
          ? [for (final (index, color) in paletteA.indexed) Color.lerp(color, paletteB[index], t)!]
          : (t < 0.5 ? paletteA : paletteB),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('accent', accent, defaultValue: null))
      ..add(ColorProperty('onAccent', onAccent, defaultValue: null))
      ..add(ColorProperty('textPrimary', textPrimary, defaultValue: null))
      ..add(ColorProperty('textSecondary', textSecondary, defaultValue: null))
      ..add(ColorProperty('textTertiary', textTertiary, defaultValue: null))
      ..add(ColorProperty('surface', surface, defaultValue: null))
      ..add(ColorProperty('sunkenSurface', sunkenSurface, defaultValue: null))
      ..add(ColorProperty('subtleFill', subtleFill, defaultValue: null))
      ..add(ColorProperty('border', border, defaultValue: null))
      ..add(ColorProperty('success', success, defaultValue: null))
      ..add(ColorProperty('warning', warning, defaultValue: null))
      ..add(ColorProperty('danger', danger, defaultValue: null))
      ..add(ColorProperty('info', info, defaultValue: null))
      ..add(ColorProperty('neutral', neutral, defaultValue: null))
      ..add(IterableProperty<Color>('chartPalette', chartPalette, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIColors &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textTertiary == textTertiary &&
        other.surface == surface &&
        other.sunkenSurface == sunkenSurface &&
        other.subtleFill == subtleFill &&
        other.border == border &&
        other.success == success &&
        other.warning == warning &&
        other.danger == danger &&
        other.info == info &&
        other.neutral == neutral &&
        const ListEquality<Color>().equals(other.chartPalette, chartPalette);
  }

  @override
  int get hashCode {
    return Object.hash(
      accent,
      onAccent,
      textPrimary,
      textSecondary,
      textTertiary,
      surface,
      sunkenSurface,
      subtleFill,
      border,
      success,
      warning,
      danger,
      info,
      neutral,
      const ListEquality<Color>().hash(chartPalette),
    );
  }
}

/// The spacing of an [OpenUIThemeData], from [xs], the smallest, to [xxl],
/// the largest, in logical pixels.
///
/// A size left `null` takes the design system's spacing token named for it.
///
/// Two values are equal when all their sizes are.
@immutable
class OpenUISpacing with Diagnosticable {
  /// Creates the spacing of an [OpenUIThemeData].
  const OpenUISpacing({this.xs, this.s, this.m, this.l, this.xl, this.xxl});

  /// The extra small space; the `xxs` token, 4, by default.
  final double? xs;

  /// The small space; the `xs` token, 8, by default.
  final double? s;

  /// The medium space, such as between a card's children; the `sm` token,
  /// 12, by default.
  final double? m;

  /// The large space, such as inside a card; the `md` token, 16, by default.
  final double? l;

  /// The extra large space; the `xl` token, 24, by default.
  final double? xl;

  /// The largest space; the `xxl` token, 32, by default.
  final double? xxl;

  /// A copy of this spacing with the given sizes replaced.
  OpenUISpacing copyWith({double? xs, double? s, double? m, double? l, double? xl, double? xxl}) {
    return OpenUISpacing(
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  /// This spacing with the sizes [other] sets in place of its own.
  OpenUISpacing merge(OpenUISpacing? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(xs: other.xs, s: other.s, m: other.m, l: other.l, xl: other.xl, xxl: other.xxl);
  }

  /// The spacing between [a] and [b] at [t], from 0 for [a] to 1 for [b].
  ///
  /// A size set on only one side switches over at the middle.
  static OpenUISpacing lerp(OpenUISpacing a, OpenUISpacing b, double t) {
    if (identical(a, b)) return a;
    double? size(double? a, double? b) => _lerpOrSwap(a, b, t, (a, b, t) => lerpDouble(a, b, t)!);
    return OpenUISpacing(
      xs: size(a.xs, b.xs),
      s: size(a.s, b.s),
      m: size(a.m, b.m),
      l: size(a.l, b.l),
      xl: size(a.xl, b.xl),
      xxl: size(a.xxl, b.xxl),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('xs', xs, defaultValue: null))
      ..add(DoubleProperty('s', s, defaultValue: null))
      ..add(DoubleProperty('m', m, defaultValue: null))
      ..add(DoubleProperty('l', l, defaultValue: null))
      ..add(DoubleProperty('xl', xl, defaultValue: null))
      ..add(DoubleProperty('xxl', xxl, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUISpacing &&
        other.xs == xs &&
        other.s == s &&
        other.m == m &&
        other.l == l &&
        other.xl == xl &&
        other.xxl == xxl;
  }

  @override
  int get hashCode => Object.hash(xs, s, m, l, xl, xxl);
}

/// The corner radii of an [OpenUIThemeData], in logical pixels.
///
/// A radius left `null` takes the design system's radius token named for it.
///
/// Two values are equal when all their radii are.
@immutable
class OpenUIRadius with Diagnosticable {
  /// Creates the corner radii of an [OpenUIThemeData].
  const OpenUIRadius({this.small, this.medium, this.large, this.pill});

  /// The small radius, such as of a chip; the `md` token, 8, by default.
  final double? small;

  /// The medium radius, such as of a sunken card; the `lg` token, 12, by
  /// default.
  final double? medium;

  /// The large radius, such as of a card; the `xl` token, 16, by default.
  final double? large;

  /// The radius that rounds the ends of a control fully, such as of a tag;
  /// the `max` token by default.
  final double? pill;

  /// A copy of these radii with the given ones replaced.
  OpenUIRadius copyWith({double? small, double? medium, double? large, double? pill}) {
    return OpenUIRadius(
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      pill: pill ?? this.pill,
    );
  }

  /// These radii with the ones [other] sets in place of their own.
  OpenUIRadius merge(OpenUIRadius? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(small: other.small, medium: other.medium, large: other.large, pill: other.pill);
  }

  /// The radii between [a] and [b] at [t], from 0 for [a] to 1 for [b].
  ///
  /// A radius set on only one side switches over at the middle.
  static OpenUIRadius lerp(OpenUIRadius a, OpenUIRadius b, double t) {
    if (identical(a, b)) return a;
    double? radius(double? a, double? b) => _lerpOrSwap(a, b, t, (a, b, t) => lerpDouble(a, b, t)!);
    return OpenUIRadius(
      small: radius(a.small, b.small),
      medium: radius(a.medium, b.medium),
      large: radius(a.large, b.large),
      pill: radius(a.pill, b.pill),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('small', small, defaultValue: null))
      ..add(DoubleProperty('medium', medium, defaultValue: null))
      ..add(DoubleProperty('large', large, defaultValue: null))
      ..add(DoubleProperty('pill', pill, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIRadius &&
        other.small == small &&
        other.medium == medium &&
        other.large == large &&
        other.pill == pill;
  }

  @override
  int get hashCode => Object.hash(small, medium, large, pill);
}

/// The text styles of an [OpenUIThemeData].
///
/// A style left `null` takes its default: the design system's text style
/// named for it, without its color, as components color their text with
/// [OpenUIColors].
///
/// Two values are equal when all their styles are.
@immutable
class OpenUITextStyles with Diagnosticable {
  /// Creates the text styles of an [OpenUIThemeData].
  const OpenUITextStyles({
    this.title,
    this.heading,
    this.body,
    this.bodyLarge,
    this.bodySmall,
    this.caption,
    this.code,
    this.metric,
  });

  /// The style of titles, such as a card header's title; `headingMd` by
  /// default.
  final TextStyle? title;

  /// The style of headings, such as a section's; `headingSm` by default.
  final TextStyle? heading;

  /// The style of body text; `bodyDefault` by default.
  final TextStyle? body;

  /// The style of large body text; `headingMd` at the weight of
  /// `bodyDefault` by default.
  final TextStyle? bodyLarge;

  /// The style of small body text, such as a card header's subtitle;
  /// `captionDefault` by default.
  final TextStyle? bodySmall;

  /// The style of captions, the smallest text; `metadataDefault` by default.
  final TextStyle? caption;

  /// The style of code; a 13-point monospace style, the same for every
  /// Stream theme, by default.
  final TextStyle? code;

  /// The style of metrics, the large numbers of a data card; a 22-point
  /// semibold style, the same for every Stream theme, by default.
  final TextStyle? metric;

  static const _defaultCode = TextStyle(
    fontFamily: 'monospace',
    // `monospace` is a font only on Android; elsewhere the first of these
    // that is installed is used.
    fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'],
    fontSize: 13,
  );

  static const _defaultMetric = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

  /// A copy of these styles with the given ones replaced.
  OpenUITextStyles copyWith({
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? code,
    TextStyle? metric,
  }) {
    return OpenUITextStyles(
      title: title ?? this.title,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodySmall: bodySmall ?? this.bodySmall,
      caption: caption ?? this.caption,
      code: code ?? this.code,
      metric: metric ?? this.metric,
    );
  }

  /// These styles with the ones [other] sets in place of their own.
  ///
  /// A style [other] sets replaces the whole style, not only the values it
  /// sets.
  OpenUITextStyles merge(OpenUITextStyles? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      title: other.title,
      heading: other.heading,
      body: other.body,
      bodyLarge: other.bodyLarge,
      bodySmall: other.bodySmall,
      caption: other.caption,
      code: other.code,
      metric: other.metric,
    );
  }

  /// The styles between [a] and [b] at [t], from 0 for [a] to 1 for [b].
  ///
  /// A style set on only one side switches over at the middle.
  static OpenUITextStyles lerp(OpenUITextStyles a, OpenUITextStyles b, double t) {
    if (identical(a, b)) return a;
    TextStyle? style(TextStyle? a, TextStyle? b) => _lerpOrSwap(a, b, t, (a, b, t) => TextStyle.lerp(a, b, t)!);
    return OpenUITextStyles(
      title: style(a.title, b.title),
      heading: style(a.heading, b.heading),
      body: style(a.body, b.body),
      bodyLarge: style(a.bodyLarge, b.bodyLarge),
      bodySmall: style(a.bodySmall, b.bodySmall),
      caption: style(a.caption, b.caption),
      code: style(a.code, b.code),
      metric: style(a.metric, b.metric),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TextStyle>('title', title, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('heading', heading, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('body', body, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('bodyLarge', bodyLarge, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('bodySmall', bodySmall, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('caption', caption, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('code', code, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('metric', metric, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUITextStyles &&
        other.title == title &&
        other.heading == heading &&
        other.body == body &&
        other.bodyLarge == bodyLarge &&
        other.bodySmall == bodySmall &&
        other.caption == caption &&
        other.code == code &&
        other.metric == metric;
  }

  @override
  int get hashCode => Object.hash(title, heading, body, bodyLarge, bodySmall, caption, code, metric);
}

// [a] and [b] blended at [t] with [lerp] when both are set; otherwise the one
// on the side of [t].
T? _lerpOrSwap<T extends Object>(T? a, T? b, double t, T Function(T a, T b, double t) lerp) {
  if (a != null && b != null) return lerp(a, b, t);
  return t < 0.5 ? a : b;
}
