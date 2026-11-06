import 'dart:ui' show lerpDouble;

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
///   data: OpenUIThemeData(accent: const Color(0xFFE65100)),
///   child: conversation,
/// )
/// ```
///
/// The components of the design system that OpenUI components are drawn with,
/// such as its spinners, take the theme's colors, spacing, corner radii and
/// text styles too, and still use the builders the app gives the design
/// system through [StreamComponentFactory].
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [OpenUITheme.merge] to add to an enclosing scope instead.
class OpenUITheme extends InheritedTheme {
  /// Creates an [OpenUITheme].
  const OpenUITheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [OpenUITheme] rather than
  /// replacing it.
  static Widget merge({Key? key, required OpenUIThemeData data, required Widget child}) => Builder(
    builder: (context) {
      final outer = context.dependOnInheritedWidgetOfExactType<OpenUITheme>()?.data;
      return OpenUITheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

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

/// The look of OpenUI components, given to an [OpenUITheme]: the colors, the
/// spacing, the corner radii and the text styles they are drawn with.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the app's Stream theme ([StreamTheme]) at build time, so one instance
/// covers light and dark mode; see [OpenUITheme.of].
///
/// ```dart
/// OpenUIThemeData(accent: const Color(0xFFE65100), cornerRadius: 8)
/// ```
///
/// [copyWith] cannot unset a field: a `null` argument keeps the current value.
@immutable
class OpenUIThemeData with Diagnosticable {
  /// Creates an [OpenUIThemeData].
  ///
  /// The [chartPalette], when given, is the colors of a chart's series, at
  /// least one. The theme keeps its own copy of it.
  OpenUIThemeData({
    this.accent,
    this.onAccent,
    this.text,
    this.secondaryText,
    this.tertiaryText,
    this.surface,
    this.sunkenSurface,
    this.subtleFill,
    this.border,
    this.success,
    this.warning,
    this.error,
    this.info,
    this.neutral,
    List<Color>? chartPalette,
    this.xsSpacing,
    this.sSpacing,
    this.mSpacing,
    this.lSpacing,
    this.xlSpacing,
    this.xxlSpacing,
    this.smallCornerRadius,
    this.mediumCornerRadius,
    this.cornerRadius,
    this.pillCornerRadius,
    this.title,
    this.heading,
    this.body,
    this.bodyLarge,
    this.bodySmall,
    this.caption,
    this.code,
    this.metric,
  }) : assert(chartPalette == null || chartPalette.isNotEmpty, 'An OpenUIThemeData needs at least one chart color.'),
       chartPalette = chartPalette == null ? null : List.unmodifiable(chartPalette);

  /// An [OpenUIThemeData] that overrides nothing.
  const OpenUIThemeData.empty()
    : accent = null,
      onAccent = null,
      text = null,
      secondaryText = null,
      tertiaryText = null,
      surface = null,
      sunkenSurface = null,
      subtleFill = null,
      border = null,
      success = null,
      warning = null,
      error = null,
      info = null,
      neutral = null,
      chartPalette = null,
      xsSpacing = null,
      sSpacing = null,
      mSpacing = null,
      lSpacing = null,
      xlSpacing = null,
      xxlSpacing = null,
      smallCornerRadius = null,
      mediumCornerRadius = null,
      cornerRadius = null,
      pillCornerRadius = null,
      title = null,
      heading = null,
      body = null,
      bodyLarge = null,
      bodySmall = null,
      caption = null,
      code = null,
      metric = null;

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
      accent: colors.accentPrimary,
      onAccent: colors.textOnAccent,
      text: colors.textPrimary,
      secondaryText: colors.textSecondary,
      tertiaryText: colors.textTertiary,
      surface: colors.backgroundSurfaceCard,
      sunkenSurface: colors.backgroundSurface,
      subtleFill: colors.backgroundSurfaceSubtle,
      border: colors.borderDefault,
      success: colors.accentSuccess,
      warning: colors.accentWarning,
      error: colors.accentError,
      info: colors.accentPrimary,
      neutral: colors.accentNeutral,
      chartPalette: _defaultChartPalette,
      xsSpacing: spacing.xxs,
      sSpacing: spacing.xs,
      mSpacing: spacing.sm,
      lSpacing: spacing.md,
      xlSpacing: spacing.xl,
      xxlSpacing: spacing.xxl,
      smallCornerRadius: radius.md.x,
      mediumCornerRadius: radius.lg.x,
      cornerRadius: radius.xl.x,
      pillCornerRadius: radius.max.x,
      title: _colorless(text.headingMd),
      heading: _colorless(text.headingSm),
      body: _colorless(text.bodyDefault),
      bodyLarge: _colorless(text.headingMd.copyWith(fontWeight: text.bodyDefault.fontWeight)),
      bodySmall: _colorless(text.captionDefault),
      caption: _colorless(text.metadataDefault),
      code: _defaultCode,
      metric: _defaultMetric,
    );
  }

  /// The color of links, selected controls and primary buttons. Defaults to the Stream theme's
  /// `accentPrimary`.
  final Color? accent;

  /// The color of text and icons drawn on [accent]. Defaults to `textOnAccent`.
  final Color? onAccent;

  /// The color of most text, such as titles and body text. Defaults to `textPrimary`.
  final Color? text;

  /// The color of less prominent text, such as subtitles. Defaults to `textSecondary`.
  final Color? secondaryText;

  /// The color of the least prominent text, such as placeholders. Defaults to `textTertiary`.
  final Color? tertiaryText;

  /// The background of cards. Defaults to `backgroundSurfaceCard`.
  final Color? surface;

  /// The background of parts set into a card, such as a sunken card. Defaults to
  /// `backgroundSurface`.
  final Color? sunkenSurface;

  /// A light fill, such as the background of inline code. Defaults to `backgroundSurfaceSubtle`.
  final Color? subtleFill;

  /// The color of borders and dividers. Defaults to `borderDefault`.
  final Color? border;

  /// The color of success, such as a positive change. Defaults to `accentSuccess`.
  final Color? success;

  /// The color of warnings. Defaults to `accentWarning`.
  final Color? warning;

  /// The color of errors and of negative changes. Defaults to `accentError`.
  final Color? error;

  /// The color of information. Defaults to `accentPrimary`.
  final Color? info;

  /// The color of what has no other status color. Defaults to `accentNeutral`.
  final Color? neutral;

  /// The colors of a chart's series, in order. Defaults to eight colors that are the same for every
  /// Stream theme.
  final List<Color>? chartPalette;

  /// The extra small space, in logical pixels. Defaults to the Stream theme's `xxs` spacing, 4.
  final double? xsSpacing;

  /// The small space. Defaults to `xs`, 8.
  final double? sSpacing;

  /// The medium space, such as between a card's children. Defaults to `sm`, 12.
  final double? mSpacing;

  /// The large space, such as inside a card. Defaults to `md`, 16.
  final double? lSpacing;

  /// The extra large space. Defaults to `xl`, 24.
  final double? xlSpacing;

  /// The largest space. Defaults to `xxl`, 32.
  final double? xxlSpacing;

  /// The small corner radius, such as of a chip. Defaults to the Stream theme's `md` radius, 8.
  final double? smallCornerRadius;

  /// The medium corner radius, such as of a sunken card. Defaults to `lg`, 12.
  final double? mediumCornerRadius;

  /// The corner radius of cards. Defaults to `xl`, 16.
  final double? cornerRadius;

  /// The corner radius that rounds the ends of a control fully, such as of a tag. Defaults to
  /// `max`.
  final double? pillCornerRadius;

  /// The style of titles, such as a card header's title. Defaults to `headingMd`, without its
  /// color: components color their text with [text] and the other colors.
  final TextStyle? title;

  /// The style of headings, such as a section's. Defaults to `headingSm`, without its color.
  final TextStyle? heading;

  /// The style of body text. Defaults to `bodyDefault`, without its color.
  final TextStyle? body;

  /// The style of large body text. Defaults to `headingMd` at the weight of `bodyDefault`, without
  /// its color.
  final TextStyle? bodyLarge;

  /// The style of small body text, such as a card header's subtitle. Defaults to `captionDefault`,
  /// without its color.
  final TextStyle? bodySmall;

  /// The style of captions, the smallest text. Defaults to `metadataDefault`, without its color.
  final TextStyle? caption;

  /// The style of code. Defaults to a 13-point monospace style, the same for every Stream theme.
  final TextStyle? code;

  /// The style of metrics, the large numbers of a data card. Defaults to a 22-point semibold style,
  /// the same for every Stream theme.
  final TextStyle? metric;

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

  static const _defaultCode = TextStyle(
    fontFamily: 'monospace',
    // `monospace` is a font only on Android; elsewhere the first of these
    // that is installed is used.
    fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'],
    fontSize: 13,
  );

  static const _defaultMetric = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

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

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  OpenUIThemeData copyWith({
    Color? accent,
    Color? onAccent,
    Color? text,
    Color? secondaryText,
    Color? tertiaryText,
    Color? surface,
    Color? sunkenSurface,
    Color? subtleFill,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? neutral,
    List<Color>? chartPalette,
    double? xsSpacing,
    double? sSpacing,
    double? mSpacing,
    double? lSpacing,
    double? xlSpacing,
    double? xxlSpacing,
    double? smallCornerRadius,
    double? mediumCornerRadius,
    double? cornerRadius,
    double? pillCornerRadius,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyLarge,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? code,
    TextStyle? metric,
  }) {
    return OpenUIThemeData(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      surface: surface ?? this.surface,
      sunkenSurface: sunkenSurface ?? this.sunkenSurface,
      subtleFill: subtleFill ?? this.subtleFill,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      chartPalette: chartPalette ?? this.chartPalette,
      xsSpacing: xsSpacing ?? this.xsSpacing,
      sSpacing: sSpacing ?? this.sSpacing,
      mSpacing: mSpacing ?? this.mSpacing,
      lSpacing: lSpacing ?? this.lSpacing,
      xlSpacing: xlSpacing ?? this.xlSpacing,
      xxlSpacing: xxlSpacing ?? this.xxlSpacing,
      smallCornerRadius: smallCornerRadius ?? this.smallCornerRadius,
      mediumCornerRadius: mediumCornerRadius ?? this.mediumCornerRadius,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      pillCornerRadius: pillCornerRadius ?? this.pillCornerRadius,
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

  /// Returns this theme with [other]'s set fields layered on top. Like every
  /// other field, a set text style replaces this one's rather than merging
  /// into it.
  OpenUIThemeData merge(OpenUIThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      accent: other.accent,
      onAccent: other.onAccent,
      text: other.text,
      secondaryText: other.secondaryText,
      tertiaryText: other.tertiaryText,
      surface: other.surface,
      sunkenSurface: other.sunkenSurface,
      subtleFill: other.subtleFill,
      border: other.border,
      success: other.success,
      warning: other.warning,
      error: other.error,
      info: other.info,
      neutral: other.neutral,
      chartPalette: other.chartPalette,
      xsSpacing: other.xsSpacing,
      sSpacing: other.sSpacing,
      mSpacing: other.mSpacing,
      lSpacing: other.lSpacing,
      xlSpacing: other.xlSpacing,
      xxlSpacing: other.xxlSpacing,
      smallCornerRadius: other.smallCornerRadius,
      mediumCornerRadius: other.mediumCornerRadius,
      cornerRadius: other.cornerRadius,
      pillCornerRadius: other.pillCornerRadius,
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

  /// Linearly interpolates between two [OpenUIThemeData]s.
  ///
  /// A field only one side sets switches at the midpoint, since `null` means
  /// "use the default" rather than zero or transparent. Chart palettes of the
  /// same length are interpolated color by color; others switch too.
  static OpenUIThemeData lerp(OpenUIThemeData a, OpenUIThemeData b, double t) {
    if (identical(a, b)) return a;
    return OpenUIThemeData(
      accent: _lerpColor(a.accent, b.accent, t),
      onAccent: _lerpColor(a.onAccent, b.onAccent, t),
      text: _lerpColor(a.text, b.text, t),
      secondaryText: _lerpColor(a.secondaryText, b.secondaryText, t),
      tertiaryText: _lerpColor(a.tertiaryText, b.tertiaryText, t),
      surface: _lerpColor(a.surface, b.surface, t),
      sunkenSurface: _lerpColor(a.sunkenSurface, b.sunkenSurface, t),
      subtleFill: _lerpColor(a.subtleFill, b.subtleFill, t),
      border: _lerpColor(a.border, b.border, t),
      success: _lerpColor(a.success, b.success, t),
      warning: _lerpColor(a.warning, b.warning, t),
      error: _lerpColor(a.error, b.error, t),
      info: _lerpColor(a.info, b.info, t),
      neutral: _lerpColor(a.neutral, b.neutral, t),
      chartPalette: _lerpPalette(a.chartPalette, b.chartPalette, t),
      xsSpacing: _lerpDouble(a.xsSpacing, b.xsSpacing, t),
      sSpacing: _lerpDouble(a.sSpacing, b.sSpacing, t),
      mSpacing: _lerpDouble(a.mSpacing, b.mSpacing, t),
      lSpacing: _lerpDouble(a.lSpacing, b.lSpacing, t),
      xlSpacing: _lerpDouble(a.xlSpacing, b.xlSpacing, t),
      xxlSpacing: _lerpDouble(a.xxlSpacing, b.xxlSpacing, t),
      smallCornerRadius: _lerpDouble(a.smallCornerRadius, b.smallCornerRadius, t),
      mediumCornerRadius: _lerpDouble(a.mediumCornerRadius, b.mediumCornerRadius, t),
      cornerRadius: _lerpDouble(a.cornerRadius, b.cornerRadius, t),
      pillCornerRadius: _lerpDouble(a.pillCornerRadius, b.pillCornerRadius, t),
      title: _lerpStyle(a.title, b.title, t),
      heading: _lerpStyle(a.heading, b.heading, t),
      body: _lerpStyle(a.body, b.body, t),
      bodyLarge: _lerpStyle(a.bodyLarge, b.bodyLarge, t),
      bodySmall: _lerpStyle(a.bodySmall, b.bodySmall, t),
      caption: _lerpStyle(a.caption, b.caption, t),
      code: _lerpStyle(a.code, b.code, t),
      metric: _lerpStyle(a.metric, b.metric, t),
    );
  }

  static T? _swap<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

  static Color? _lerpColor(Color? a, Color? b, double t) =>
      a != null && b != null ? Color.lerp(a, b, t) : _swap(a, b, t);

  static TextStyle? _lerpStyle(TextStyle? a, TextStyle? b, double t) =>
      a != null && b != null ? TextStyle.lerp(a, b, t) : _swap(a, b, t);

  static double? _lerpDouble(double? a, double? b, double t) =>
      a != null && b != null ? lerpDouble(a, b, t) : _swap(a, b, t);

  static List<Color>? _lerpPalette(List<Color>? a, List<Color>? b, double t) {
    if (a == null || b == null || a.length != b.length) return _swap(a, b, t);
    return [for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('accent', accent, defaultValue: null))
      ..add(ColorProperty('onAccent', onAccent, defaultValue: null))
      ..add(ColorProperty('text', text, defaultValue: null))
      ..add(ColorProperty('secondaryText', secondaryText, defaultValue: null))
      ..add(ColorProperty('tertiaryText', tertiaryText, defaultValue: null))
      ..add(ColorProperty('surface', surface, defaultValue: null))
      ..add(ColorProperty('sunkenSurface', sunkenSurface, defaultValue: null))
      ..add(ColorProperty('subtleFill', subtleFill, defaultValue: null))
      ..add(ColorProperty('border', border, defaultValue: null))
      ..add(ColorProperty('success', success, defaultValue: null))
      ..add(ColorProperty('warning', warning, defaultValue: null))
      ..add(ColorProperty('error', error, defaultValue: null))
      ..add(ColorProperty('info', info, defaultValue: null))
      ..add(ColorProperty('neutral', neutral, defaultValue: null))
      ..add(IterableProperty<Color>('chartPalette', chartPalette, defaultValue: null))
      ..add(DoubleProperty('xsSpacing', xsSpacing, defaultValue: null))
      ..add(DoubleProperty('sSpacing', sSpacing, defaultValue: null))
      ..add(DoubleProperty('mSpacing', mSpacing, defaultValue: null))
      ..add(DoubleProperty('lSpacing', lSpacing, defaultValue: null))
      ..add(DoubleProperty('xlSpacing', xlSpacing, defaultValue: null))
      ..add(DoubleProperty('xxlSpacing', xxlSpacing, defaultValue: null))
      ..add(DoubleProperty('smallCornerRadius', smallCornerRadius, defaultValue: null))
      ..add(DoubleProperty('mediumCornerRadius', mediumCornerRadius, defaultValue: null))
      ..add(DoubleProperty('cornerRadius', cornerRadius, defaultValue: null))
      ..add(DoubleProperty('pillCornerRadius', pillCornerRadius, defaultValue: null))
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
    if (identical(this, other)) return true;
    return other is OpenUIThemeData &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.text == text &&
        other.secondaryText == secondaryText &&
        other.tertiaryText == tertiaryText &&
        other.surface == surface &&
        other.sunkenSurface == sunkenSurface &&
        other.subtleFill == subtleFill &&
        other.border == border &&
        other.success == success &&
        other.warning == warning &&
        other.error == error &&
        other.info == info &&
        other.neutral == neutral &&
        listEquals(other.chartPalette, chartPalette) &&
        other.xsSpacing == xsSpacing &&
        other.sSpacing == sSpacing &&
        other.mSpacing == mSpacing &&
        other.lSpacing == lSpacing &&
        other.xlSpacing == xlSpacing &&
        other.xxlSpacing == xxlSpacing &&
        other.smallCornerRadius == smallCornerRadius &&
        other.mediumCornerRadius == mediumCornerRadius &&
        other.cornerRadius == cornerRadius &&
        other.pillCornerRadius == pillCornerRadius &&
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
  int get hashCode => Object.hashAll([
    accent,
    onAccent,
    text,
    secondaryText,
    tertiaryText,
    surface,
    sunkenSurface,
    subtleFill,
    border,
    success,
    warning,
    error,
    info,
    neutral,
    Object.hashAll(chartPalette ?? const <Color>[]),
    xsSpacing,
    sSpacing,
    mSpacing,
    lSpacing,
    xlSpacing,
    xxlSpacing,
    smallCornerRadius,
    mediumCornerRadius,
    cornerRadius,
    pillCornerRadius,
    title,
    heading,
    body,
    bodyLarge,
    bodySmall,
    caption,
    code,
    metric,
  ]);
}
