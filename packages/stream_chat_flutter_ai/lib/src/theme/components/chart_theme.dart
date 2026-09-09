import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// The three chart imports are here for the doc links below only; nothing in
// this file's code uses them.
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';

/// The categorical palette [ChartView] cycles through when nothing overrides
/// it.
///
/// Six hues picked to stay distinguishable from one another rather than to
/// match any particular app, which is why a host with a brand palette wants
/// [ChartThemeData.seriesColors]. Exported so such a host can extend this list
/// rather than replace it.
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
/// [ThemeData]" rather than "nothing" — so a host overrides the two or three
/// things it cares about and leaves the rest following the app's
/// [ColorScheme]. Register one app-wide inside [AITheme]:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     colorSchemeSeed: brandBlue,
///     extensions: const [AITheme(chartTheme: ChartThemeData(seriesColors: brandPalette))],
///   ),
///   ...
/// )
/// ```
///
/// override it for a subtree with [ChartTheme], or for one chart with
/// [ChartView.theme]. The three compose: the widget's own value wins, then the
/// nearest [ChartTheme], then [AITheme]'s, then the derived default.
///
/// **[copyWith] cannot unset a field.** Passing `null` leaves the current
/// value, as everywhere else in Flutter; construct a fresh [ChartThemeData] to
/// put one back to its derived default.
///
/// **What is deliberately not here.** The bar rod width and spacing, the pie's
/// radius and slice gap, the area fill's opacity, the grid stroke width, the
/// plot padding and the axis gutter sizes all stay internal constants. They are
/// layout rather than theme, and the gutters in particular have to keep
/// matching the `reservedSize` values [ChartView] hands `fl_chart` or a heatmap
/// stops lining up with the bar chart above it. One consequence worth knowing:
/// [height] is settable but the pie's radius is not, so a much taller chart
/// leaves the pie undersized.
@immutable
class ChartThemeData {
  /// Creates a [ChartThemeData]. Every field left `null` is derived from the
  /// ambient [ThemeData] at build time.
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
  /// colors.
  ///
  /// Falls back to [kDefaultChartSeriesColors]. An empty list is ignored and
  /// falls back too, since cycling an empty palette has no answer.
  final List<Color>? seriesColors;

  /// The height of the plot area, title excluded.
  ///
  /// Falls back to 220.
  final double? height;

  /// The marker radius for a [USpecKind.scatter] point.
  ///
  /// Falls back to 6. Also the radius a [USpecKind.bubble] point falls back to
  /// when it carries no size of its own.
  final double? scatterRadius;

  /// The radius the smallest [USpecKind.bubble] point is drawn at.
  ///
  /// Falls back to 6. Bubble sizes are normalized across the chart before being
  /// mapped onto this range, since they arrive in the data's own units.
  final double? bubbleMinRadius;

  /// The radius the largest [USpecKind.bubble] point is drawn at.
  ///
  /// Falls back to 40.
  final double? bubbleMaxRadius;

  /// How many buckets a [USpecKind.histogram] is binned into.
  ///
  /// Falls back to 10. Values below 1 are treated as 1.
  final int? histogramBinCount;

  /// The style of the axis tick labels, and of a heatmap's row, column and
  /// legend labels.
  ///
  /// Falls back to 10pt in [ColorScheme.onSurfaceVariant].
  final TextStyle? axisLabelStyle;

  /// The style of the labels drawn on [USpecKind.pie] slices.
  ///
  /// Falls back to 11pt semibold. A style with no [TextStyle.color] gets one
  /// chosen per slice for contrast against that slice's fill — see
  /// [ChartView]. Set a color here to take that choice back.
  final TextStyle? pieLabelStyle;

  /// The style of the heading drawn above a chart that carries a
  /// [USpec.title].
  ///
  /// Falls back to [TextTheme.titleSmall] in [ColorScheme.onSurface].
  final TextStyle? titleTextStyle;

  /// The color of the horizontal grid lines, of a heatmap's cell borders, and
  /// of its legend bar's border.
  ///
  /// Falls back to [ColorScheme.outlineVariant]. One field for all three
  /// because they are the same hairline chrome, and today's code already draws
  /// them from that one token.
  final Color? gridLineColor;

  /// The color of the lowest cell on a heatmap's sequential scale.
  ///
  /// Falls back to a pale blue under a light [Brightness] and a very dark blue
  /// under a dark one.
  final Color? heatmapLowColor;

  /// The color of the midpoint of a heatmap's sequential scale.
  ///
  /// Falls back to a mid blue.
  final Color? heatmapMidColor;

  /// The color of the highest cell on a heatmap's sequential scale.
  ///
  /// Falls back to a deep blue under a light [Brightness] and a *pale* one
  /// under a dark theme: on a dark surface a light-to-dark ramp makes the
  /// highest cells recede into the background, inverting the intensity the
  /// color is there to encode.
  final Color? heatmapHighColor;

  /// Returns a copy of this theme with the given fields replaced.
  ///
  /// A `null` argument leaves the current value — see the note on
  /// [ChartThemeData].
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

  /// Returns this theme with [other]'s set fields layered on top.
  ///
  /// This is what makes a partial override partial: a [ChartTheme] that sets
  /// only a palette keeps the enclosing [AITheme]'s height rather than
  /// resetting it.
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

  /// Linearly interpolates between two [ChartThemeData]s.
  ///
  /// Called on every theme animation, including the cross-fade a
  /// [MaterialApp] runs when the platform switches between light and dark.
  static ChartThemeData lerp(ChartThemeData a, ChartThemeData b, double t) {
    if (identical(a, b)) return a;
    return ChartThemeData(
      seriesColors: _lerpPalette(a.seriesColors, b.seriesColors, t),
      height: _lerpDouble(a.height, b.height, t),
      scatterRadius: _lerpDouble(a.scatterRadius, b.scatterRadius, t),
      bubbleMinRadius: _lerpDouble(a.bubbleMinRadius, b.bubbleMinRadius, t),
      bubbleMaxRadius: _lerpDouble(a.bubbleMaxRadius, b.bubbleMaxRadius, t),
      // A count, so it interpolates and then rounds rather than snapping at
      // the midpoint.
      histogramBinCount: _bothSet(a.histogramBinCount, b.histogramBinCount)
          ? lerpDouble(a.histogramBinCount, b.histogramBinCount, t)!.round()
          : _swap(a.histogramBinCount, b.histogramBinCount, t),
      axisLabelStyle: _lerpStyle(a.axisLabelStyle, b.axisLabelStyle, t),
      pieLabelStyle: _lerpStyle(a.pieLabelStyle, b.pieLabelStyle, t),
      titleTextStyle: _lerpStyle(a.titleTextStyle, b.titleTextStyle, t),
      gridLineColor: _lerpColor(a.gridLineColor, b.gridLineColor, t),
      heatmapLowColor: _lerpColor(a.heatmapLowColor, b.heatmapLowColor, t),
      heatmapMidColor: _lerpColor(a.heatmapMidColor, b.heatmapMidColor, t),
      heatmapHighColor: _lerpColor(a.heatmapHighColor, b.heatmapHighColor, t),
    );
  }

  static bool _bothSet(Object? a, Object? b) => a != null && b != null;

  /// Picks whichever side is closer, for a field that can't be interpolated.
  ///
  /// An unset field means "derive from the ambient theme", not "zero" or
  /// "transparent", so interpolating one is wrong in a way that shows:
  /// `Color.lerp(null, c, t)` fades through transparency and would make a grid
  /// line vanish halfway through the animation, `lerpDouble(null, 220, t)`
  /// reads the null as 0 and would grow the chart up from nothing, and
  /// [TextStyle.lerp] with a null side fades its colors out of transparent.
  /// Swapping is the only honest answer, and it lands at the same place at
  /// both ends.
  static T? _swap<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

  static double? _lerpDouble(double? a, double? b, double t) => _bothSet(a, b) ? lerpDouble(a, b, t) : _swap(a, b, t);

  static Color? _lerpColor(Color? a, Color? b, double t) => _bothSet(a, b) ? Color.lerp(a, b, t) : _swap(a, b, t);

  static TextStyle? _lerpStyle(TextStyle? a, TextStyle? b, double t) =>
      _bothSet(a, b) ? TextStyle.lerp(a, b, t) : _swap(a, b, t);

  /// Interpolates two palettes index by index.
  ///
  /// Lists of different lengths are matched by *wrapping* the shorter one,
  /// exactly the way the palette is cycled at paint time, so no series loses
  /// its color partway through an animation. Truncating to the shorter list
  /// would blank the extra series; padding with a fixed color would flash.
  static List<Color>? _lerpPalette(List<Color>? a, List<Color>? b, double t) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return _swap(a, b, t);
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

  // Object.hashAll rather than Object.hash: the palette needs a deep hash of
  // its own, and a list's identity hash would make two equal themes hash
  // differently.
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
/// Layers [data] on top of the [AITheme] registered on the ambient
/// [ThemeData], so a scope that sets only a palette leaves everything else
/// alone:
///
/// ```dart
/// ChartTheme(
///   data: const ChartThemeData(seriesColors: [Colors.teal, Colors.amber]),
///   child: AIMarkdownBody(data: message),
/// )
/// ```
///
/// For one chart, [ChartView.theme] is shorter and wins over this.
class ChartTheme extends InheritedTheme {
  /// Creates a [ChartTheme].
  const ChartTheme({super.key, required this.data, required super.child});

  /// The overrides applied to the subtree.
  final ChartThemeData data;

  /// The chart theme in effect at [context]: the nearest [ChartTheme]'s
  /// overrides layered over [AITheme]'s.
  ///
  /// Registers [context] as a dependent of both, so a chart resolving its
  /// colors here repaints when either changes. Never returns `null` — with no
  /// scope and no extension the result is `const ChartThemeData()`, every
  /// field of which derives from the ambient [ThemeData].
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
