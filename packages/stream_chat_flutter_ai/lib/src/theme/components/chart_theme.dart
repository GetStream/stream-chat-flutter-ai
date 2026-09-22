import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// The three chart imports are here for the doc links below only; nothing in
// this file's code uses them.
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// The palette [ChartView] cycles through when nothing overrides it.
///
/// Exported so a host can extend it rather than replace it.
const kDefaultChartSeriesColors = [
  Color(0xFF4A90D9),
  Color(0xFFE67E22),
  Color(0xFF2ECC71),
  Color(0xFFE74C3C),
  Color(0xFF9B59B6),
  Color(0xFF1ABC9C),
];

/// Overrides for how [ChartView] and [HeatmapChartView] draw a chart.
///
/// Every field is nullable, and `null` means "derive it from the ambient
/// [ThemeData]" — so a host overrides what it cares about and the rest keeps
/// following the app.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [AITheme(chartTheme: ChartThemeData(seriesColors: brandPalette))],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ChartTheme], or to one chart with
/// [ChartView.theme]; most specific wins, then [AITheme], then the derived
/// default. [copyWith] cannot unset a field — a `null` argument keeps the
/// current value.
///
/// Layout stays internal: bar widths, the pie radius, slice gaps, fill opacity,
/// plot padding, and the axis gutters, which have to keep matching the
/// `reservedSize` values [ChartView] hands `fl_chart`. So a taller [height]
/// leaves the pie undersized.
@immutable
class ChartThemeData {
  /// Creates a [ChartThemeData].
  const ChartThemeData({
    this.seriesColors,
    this.height,
    this.scatterRadius,
    this.bubbleMinRadius,
    this.bubbleMaxRadius,
    this.histogramBinCount,
    this.axisLabelStyle,
    this.pieLabelStyle,
    this.titleTextStyle,
    this.gridLineColor,
    this.heatmapLowColor,
    this.heatmapMidColor,
    this.heatmapHighColor,
  });

  /// The colors series are drawn in, cycled when there are more series than
  /// colors. Falls back to [kDefaultChartSeriesColors], as does an empty list.
  final List<Color>? seriesColors;

  /// The height of the plot area, title excluded. Falls back to 220.
  final double? height;

  /// The marker radius for a [USpecKind.scatter] point, and for a
  /// [USpecKind.bubble] point carrying no size of its own. Falls back to 6.
  final double? scatterRadius;

  /// The radius of the smallest [USpecKind.bubble] point, the other end of the
  /// range sizes are normalized onto. Falls back to 6.
  final double? bubbleMinRadius;

  /// The radius of the largest [USpecKind.bubble] point. Falls back to 40.
  final double? bubbleMaxRadius;

  /// How many buckets a [USpecKind.histogram] is binned into. Falls back to 10;
  /// values below 1 are treated as 1.
  final int? histogramBinCount;

  /// The style of axis tick labels, and of a heatmap's row, column and legend
  /// labels. Falls back to 10pt in [ColorScheme.onSurfaceVariant].
  final TextStyle? axisLabelStyle;

  /// The style of the labels on [USpecKind.pie] slices. Falls back to 11pt
  /// semibold. With no [TextStyle.color] each slice picks black or white for
  /// contrast against its own fill; set one here to take that over.
  final TextStyle? pieLabelStyle;

  /// The style of the heading above a chart carrying a [USpec.title]. Falls
  /// back to [TextTheme.titleSmall] in [ColorScheme.onSurface].
  final TextStyle? titleTextStyle;

  /// The color of grid lines, heatmap cell borders and the legend bar's border
  /// — the same hairline chrome. Falls back to [ColorScheme.outlineVariant].
  final Color? gridLineColor;

  /// The lowest stop of a heatmap's scale. Falls back to a pale blue on a light
  /// [Brightness], a very dark blue on a dark one.
  final Color? heatmapLowColor;

  /// The midpoint of a heatmap's scale. Falls back to a mid blue.
  final Color? heatmapMidColor;

  /// The highest stop of a heatmap's scale. Falls back to a deep blue on a
  /// light [Brightness] and a *pale* one on a dark theme, where a light-to-dark
  /// ramp would make the busiest cells recede.
  final Color? heatmapHighColor;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ChartThemeData copyWith({
    List<Color>? seriesColors,
    double? height,
    double? scatterRadius,
    double? bubbleMinRadius,
    double? bubbleMaxRadius,
    int? histogramBinCount,
    TextStyle? axisLabelStyle,
    TextStyle? pieLabelStyle,
    TextStyle? titleTextStyle,
    Color? gridLineColor,
    Color? heatmapLowColor,
    Color? heatmapMidColor,
    Color? heatmapHighColor,
  }) {
    return ChartThemeData(
      seriesColors: seriesColors ?? this.seriesColors,
      height: height ?? this.height,
      scatterRadius: scatterRadius ?? this.scatterRadius,
      bubbleMinRadius: bubbleMinRadius ?? this.bubbleMinRadius,
      bubbleMaxRadius: bubbleMaxRadius ?? this.bubbleMaxRadius,
      histogramBinCount: histogramBinCount ?? this.histogramBinCount,
      axisLabelStyle: axisLabelStyle ?? this.axisLabelStyle,
      pieLabelStyle: pieLabelStyle ?? this.pieLabelStyle,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      heatmapLowColor: heatmapLowColor ?? this.heatmapLowColor,
      heatmapMidColor: heatmapMidColor ?? this.heatmapMidColor,
      heatmapHighColor: heatmapHighColor ?? this.heatmapHighColor,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial.
  ChartThemeData merge(ChartThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      seriesColors: other.seriesColors,
      height: other.height,
      scatterRadius: other.scatterRadius,
      bubbleMinRadius: other.bubbleMinRadius,
      bubbleMaxRadius: other.bubbleMaxRadius,
      histogramBinCount: other.histogramBinCount,
      axisLabelStyle: other.axisLabelStyle,
      pieLabelStyle: other.pieLabelStyle,
      titleTextStyle: other.titleTextStyle,
      gridLineColor: other.gridLineColor,
      heatmapLowColor: other.heatmapLowColor,
      heatmapMidColor: other.heatmapMidColor,
      heatmapHighColor: other.heatmapHighColor,
    );
  }

  /// Linearly interpolates between two [ChartThemeData]s. Runs on every theme
  /// animation, including a light/dark switch.
  static ChartThemeData lerp(ChartThemeData a, ChartThemeData b, double t) {
    if (identical(a, b)) return a;
    return ChartThemeData(
      seriesColors: _lerpPalette(a.seriesColors, b.seriesColors, t),
      height: lerpDoubleOrSwap(a.height, b.height, t),
      scatterRadius: lerpDoubleOrSwap(a.scatterRadius, b.scatterRadius, t),
      bubbleMinRadius: lerpDoubleOrSwap(a.bubbleMinRadius, b.bubbleMinRadius, t),
      bubbleMaxRadius: lerpDoubleOrSwap(a.bubbleMaxRadius, b.bubbleMaxRadius, t),
      // A count, so it interpolates and then rounds rather than snapping at
      // the midpoint.
      histogramBinCount: bothSet(a.histogramBinCount, b.histogramBinCount)
          ? lerpDouble(a.histogramBinCount, b.histogramBinCount, t)!.round()
          : swapAtMidpoint(a.histogramBinCount, b.histogramBinCount, t),
      axisLabelStyle: lerpTextStyleOrSwap(a.axisLabelStyle, b.axisLabelStyle, t),
      pieLabelStyle: lerpTextStyleOrSwap(a.pieLabelStyle, b.pieLabelStyle, t),
      titleTextStyle: lerpTextStyleOrSwap(a.titleTextStyle, b.titleTextStyle, t),
      gridLineColor: lerpColorOrSwap(a.gridLineColor, b.gridLineColor, t),
      heatmapLowColor: lerpColorOrSwap(a.heatmapLowColor, b.heatmapLowColor, t),
      heatmapMidColor: lerpColorOrSwap(a.heatmapMidColor, b.heatmapMidColor, t),
      heatmapHighColor: lerpColorOrSwap(a.heatmapHighColor, b.heatmapHighColor, t),
    );
  }

  /// Interpolates two palettes index by index, *wrapping* the shorter one the
  /// way it is cycled at paint time so no series loses its color mid-animation.
  static List<Color>? _lerpPalette(List<Color>? a, List<Color>? b, double t) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return swapAtMidpoint(a, b, t);
    if (identical(a, b)) return a;
    final length = a.length > b.length ? a.length : b.length;
    return List<Color>.generate(
      length,
      (i) => Color.lerp(a[i % a.length], b[i % b.length], t)!,
      growable: false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChartThemeData &&
        listEquals(other.seriesColors, seriesColors) &&
        other.height == height &&
        other.scatterRadius == scatterRadius &&
        other.bubbleMinRadius == bubbleMinRadius &&
        other.bubbleMaxRadius == bubbleMaxRadius &&
        other.histogramBinCount == histogramBinCount &&
        other.axisLabelStyle == axisLabelStyle &&
        other.pieLabelStyle == pieLabelStyle &&
        other.titleTextStyle == titleTextStyle &&
        other.gridLineColor == gridLineColor &&
        other.heatmapLowColor == heatmapLowColor &&
        other.heatmapMidColor == heatmapMidColor &&
        other.heatmapHighColor == heatmapHighColor;
  }

  // Object.hashAll, not Object.hash: a list's identity hash would make two
  // equal palettes hash differently.
  @override
  int get hashCode => Object.hashAll([
    if (seriesColors != null) Object.hashAll(seriesColors!),
    height,
    scatterRadius,
    bubbleMinRadius,
    bubbleMaxRadius,
    histogramBinCount,
    axisLabelStyle,
    pieLabelStyle,
    titleTextStyle,
    gridLineColor,
    heatmapLowColor,
    heatmapMidColor,
    heatmapHighColor,
  ]);
}

/// Overrides the chart theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a palette
/// leaves everything else alone:
///
/// ```dart
/// ChartTheme(
///   data: const ChartThemeData(seriesColors: [Colors.teal, Colors.amber]),
///   child: AIMarkdownBody(data: message),
/// )
/// ```
///
/// For one chart, [ChartView.theme] is shorter and wins over this. Nesting one
/// inside another replaces rather than layers, the way `IconTheme` does — use
/// [ChartTheme.merge] to add to an enclosing scope instead.
class ChartTheme extends InheritedTheme {
  /// Creates a [ChartTheme].
  const ChartTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ChartTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ChartThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ChartTheme>()?.data;
      return ChartTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ChartThemeData data;

  /// The chart theme at [context]: the nearest [ChartTheme] layered over
  /// [AITheme]'s.
  ///
  /// Depends on both, so a chart repaints when either changes. Never `null`;
  /// with neither present every field derives from the ambient [ThemeData].
  static ChartThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ChartTheme>();
    return AITheme.of(context).chartTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ChartTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ChartTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ChartThemeData>('data', data));
  }
}
