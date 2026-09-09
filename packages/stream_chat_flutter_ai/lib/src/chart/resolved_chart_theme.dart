import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

/// The heatmap ramp under a light [Brightness], anchored on the first default
/// series color. Higher values are darker and more saturated.
const _kLightScale = (low: Color(0xFFEAF2FB), mid: Color(0xFF4A90D9), high: Color(0xFF1B4F8A));

/// The heatmap ramp under a dark [Brightness].
///
/// Runs the other way — higher values are *lighter* — because a light-to-dark
/// ramp on a dark surface makes the highest cells recede into the background,
/// inverting the intensity the color is supposed to encode.
const _kDarkScale = (low: Color(0xFF12283F), mid: Color(0xFF3B7CB8), high: Color(0xFFC3DDF6));

/// A [ChartThemeData] with every field filled in.
///
/// Internal to the package: [ChartThemeData]'s fields are nullable so a host
/// can override two of them and leave the rest to the ambient theme, but the
/// chart widgets need a concrete value for each. Resolving once at the top of
/// `build` and passing this down is also what keeps the fallback table in one
/// place instead of scattering `?? colorScheme.something` across two files.
@immutable
class ResolvedChartTheme {
  const ResolvedChartTheme._({
    required this.seriesColors,
    required this.height,
    required this.scatterRadius,
    required this.bubbleMinRadius,
    required this.bubbleMaxRadius,
    required this.histogramBinCount,
    required this.axisLabelStyle,
    required this.pieLabelStyle,
    required this.titleTextStyle,
    required this.gridLineColor,
    required this.heatmapLowColor,
    required this.heatmapMidColor,
    required this.heatmapHighColor,
  });

  /// Resolves the chart theme in effect at [context], with [override] — a
  /// widget's own `theme` argument — layered on top of it.
  factory ResolvedChartTheme.resolve(BuildContext context, {ChartThemeData? override}) {
    final theme = ChartTheme.of(context).merge(override);
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final scale = themeData.brightness == Brightness.dark ? _kDarkScale : _kLightScale;
    final palette = theme.seriesColors;

    final axisLabel = _merge(const TextStyle(fontSize: 10), theme.axisLabelStyle);

    return ResolvedChartTheme._(
      // An empty palette would make `seriesColor` divide by zero, and cycling
      // one has no sensible answer anyway.
      seriesColors: (palette == null || palette.isEmpty) ? kDefaultChartSeriesColors : palette,
      height: theme.height ?? 220,
      scatterRadius: theme.scatterRadius ?? 6,
      bubbleMinRadius: theme.bubbleMinRadius ?? 6,
      bubbleMaxRadius: theme.bubbleMaxRadius ?? 40,
      histogramBinCount: theme.histogramBinCount ?? 10,
      axisLabelStyle: axisLabel.color == null ? axisLabel.copyWith(color: colorScheme.onSurfaceVariant) : axisLabel,
      // The color is deliberately left unset when the host set none: the pie
      // builder then picks one per slice, since each slice is a different fill.
      pieLabelStyle: _merge(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), theme.pieLabelStyle),
      titleTextStyle: theme.titleTextStyle ?? themeData.textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
      gridLineColor: theme.gridLineColor ?? colorScheme.outlineVariant,
      heatmapLowColor: theme.heatmapLowColor ?? scale.low,
      heatmapMidColor: theme.heatmapMidColor ?? scale.mid,
      heatmapHighColor: theme.heatmapHighColor ?? scale.high,
    );
  }

  /// See [ChartThemeData.seriesColors]. Never empty.
  final List<Color> seriesColors;

  /// See [ChartThemeData.height].
  final double height;

  /// See [ChartThemeData.scatterRadius].
  final double scatterRadius;

  /// See [ChartThemeData.bubbleMinRadius].
  final double bubbleMinRadius;

  /// See [ChartThemeData.bubbleMaxRadius].
  final double bubbleMaxRadius;

  /// See [ChartThemeData.histogramBinCount].
  final int histogramBinCount;

  /// See [ChartThemeData.axisLabelStyle]. Always carries a color.
  final TextStyle axisLabelStyle;

  /// See [ChartThemeData.pieLabelStyle]. Carries a color only if the host set
  /// one; [ChartView] fills it in per slice otherwise.
  final TextStyle pieLabelStyle;

  /// See [ChartThemeData.titleTextStyle]. Null only if the ambient
  /// [TextTheme.titleSmall] is.
  final TextStyle? titleTextStyle;

  /// See [ChartThemeData.gridLineColor].
  final Color gridLineColor;

  /// See [ChartThemeData.heatmapLowColor].
  final Color heatmapLowColor;

  /// See [ChartThemeData.heatmapMidColor].
  final Color heatmapMidColor;

  /// See [ChartThemeData.heatmapHighColor].
  final Color heatmapHighColor;

  /// The color for the [index]-th series, cycling when there are more series
  /// than colors.
  Color seriesColor(int index) => seriesColors[index % seriesColors.length];

  /// Lays [override] over [base].
  ///
  /// [TextStyle.merge] asserts on a style with `inherit: false`, which a host
  /// is free to build, so such a style replaces the base outright rather than
  /// crashing.
  static TextStyle _merge(TextStyle base, TextStyle? override) {
    if (override == null) return base;
    return override.inherit ? base.merge(override) : override;
  }
}
