import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';
import 'package:stream_core_flutter/chat.dart';

/// The heatmap ramp on a light [Brightness]: higher values darker.
const _kLightScale = (low: Color(0xFFEAF2FB), mid: Color(0xFF4A90D9), high: Color(0xFF1B4F8A));

/// The heatmap ramp on a dark [Brightness]: higher values *lighter*, because a
/// light-to-dark ramp on a dark surface makes the busiest cells recede.
const _kDarkScale = (low: Color(0xFF12283F), mid: Color(0xFF3B7CB8), high: Color(0xFFC3DDF6));

/// A [ChartThemeData] with every field resolved.
///
/// Internal. [ChartThemeData]'s fields are nullable, but the chart widgets need
/// a concrete value for each, so resolving once at the top of `build` keeps the
/// fallback table in one place.
@immutable
@internal
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
    required this.showLegend,
    required this.legendPosition,
    required this.legendTextStyle,
    required this.showPiePercentages,
    required this.piePercentageThreshold,
  });

  /// Resolves the theme at [context], with [override] — a widget's own `theme`
  /// argument — layered on top.
  factory ResolvedChartTheme.resolve(BuildContext context, {ChartThemeData? override}) {
    final theme = ChartTheme.of(context).merge(override);
    final colors = context.streamColorScheme;
    final text = context.streamTextTheme;
    final scale = colors.brightness == Brightness.dark ? _kDarkScale : _kLightScale;
    final palette = theme.seriesColors;

    final axisLabel = mergeTextStyle(const TextStyle(fontSize: 10), theme.axisLabelStyle);
    final legendText = mergeTextStyle(const TextStyle(fontSize: 11), theme.legendTextStyle);

    return ResolvedChartTheme._(
      // An empty palette would make `seriesColor` divide by zero, and cycling
      // one has no sensible answer anyway.
      seriesColors: (palette == null || palette.isEmpty) ? kDefaultChartSeriesColors : palette,
      height: theme.height ?? 220,
      scatterRadius: theme.scatterRadius ?? 6,
      bubbleMinRadius: theme.bubbleMinRadius ?? 6,
      bubbleMaxRadius: theme.bubbleMaxRadius ?? 40,
      histogramBinCount: theme.histogramBinCount ?? 10,
      axisLabelStyle: axisLabel.color == null ? axisLabel.copyWith(color: colors.textSecondary) : axisLabel,
      // The color is deliberately left unset when the host set none: the pie
      // builder then picks one per slice, since each slice is a different fill.
      pieLabelStyle: mergeTextStyle(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), theme.pieLabelStyle),
      titleTextStyle: theme.titleTextStyle ?? text.bodyEmphasis.copyWith(color: colors.textPrimary),
      gridLineColor: theme.gridLineColor ?? colors.borderDefault,
      heatmapLowColor: theme.heatmapLowColor ?? scale.low,
      heatmapMidColor: theme.heatmapMidColor ?? scale.mid,
      heatmapHighColor: theme.heatmapHighColor ?? scale.high,
      showLegend: theme.showLegend ?? true,
      legendPosition: theme.legendPosition ?? ChartLegendPosition.bottom,
      legendTextStyle: legendText.color == null ? legendText.copyWith(color: colors.textSecondary) : legendText,
      showPiePercentages: theme.showPiePercentages ?? true,
      piePercentageThreshold: switch (theme.piePercentageThreshold) {
        // The constructor asserts the range; this keeps release builds sane.
        final threshold? when threshold.isFinite => threshold.clamp(0.0, 1.0),
        _ => 0.08,
      },
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

  /// See [ChartThemeData.titleTextStyle].
  final TextStyle? titleTextStyle;

  /// See [ChartThemeData.gridLineColor].
  final Color gridLineColor;

  /// See [ChartThemeData.heatmapLowColor].
  final Color heatmapLowColor;

  /// See [ChartThemeData.heatmapMidColor].
  final Color heatmapMidColor;

  /// See [ChartThemeData.heatmapHighColor].
  final Color heatmapHighColor;

  /// See [ChartThemeData.showLegend].
  final bool showLegend;

  /// See [ChartThemeData.legendPosition].
  final ChartLegendPosition legendPosition;

  /// See [ChartThemeData.legendTextStyle]. Always carries a color.
  final TextStyle legendTextStyle;

  /// See [ChartThemeData.showPiePercentages].
  final bool showPiePercentages;

  /// See [ChartThemeData.piePercentageThreshold].
  final double piePercentageThreshold;

  /// The color for the [index]-th series, cycling when there are more series
  /// than colors.
  Color seriesColor(int index) => seriesColors[index % seriesColors.length];
}
