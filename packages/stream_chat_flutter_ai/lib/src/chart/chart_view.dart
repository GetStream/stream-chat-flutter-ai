import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_semantics.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/resolved_chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

/// Renders a [USpec] chart using `fl_chart`.
///
/// Supports [USpecKind.line], [USpecKind.area], [USpecKind.bar],
/// [USpecKind.pie], [USpecKind.scatter], [USpecKind.bubble],
/// [USpecKind.histogram], and [USpecKind.heatmap] — the last of which is drawn
/// by [HeatmapChartView] rather than `fl_chart`, which has no heatmap widget.
///
/// [USpec.title], when the spec carries one, is rendered as a heading above the
/// plot, matching the reference Android/iOS AI packages.
///
/// Colors, sizes and the histogram's bucket count all come from
/// [ChartThemeData] — app-wide through [AITheme], per subtree through
/// [ChartTheme], or per chart through [theme].
class ChartView extends StatelessWidget {
  /// Creates a [ChartView].
  const ChartView({super.key, required this.spec, this.theme, this.semanticsLabel});

  /// The chart data to display.
  final USpec spec;

  /// Overrides the ambient chart theme for this chart alone.
  ///
  /// Layered over the nearest [ChartTheme] and over the [AITheme] registered on
  /// the ambient [ThemeData]; see [ChartThemeData].
  final ChartThemeData? theme;

  /// Replaces the summary a screen reader is given for this chart.
  ///
  /// `fl_chart` paints to a canvas and exposes nothing, so by default the chart
  /// describes itself: [AITranslations.chartSemanticsLabel] turns the facts in
  /// [ChartSemantics] into one sentence, and that becomes the label of a single
  /// semantics node standing for the whole chart.
  ///
  /// The node **excludes** the subtree beneath it. The axis tick labels are
  /// real `Text` widgets, and letting a reader walk them produces a run of bare
  /// numbers with nothing to say which axis they belong to or how they pair up;
  /// the summary already carries the range, the category count and — when the
  /// data named them — the axis labels.
  ///
  /// Pass an empty string to add no semantics at all, which is the way to opt
  /// out and describe the chart yourself.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final chartTheme = ResolvedChartTheme.resolve(context, override: theme);
    final translations = AITranslations.of(context);

    final plot = Container(
      height: chartTheme.height,
      padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
      child: switch (spec.kind) {
        USpecKind.pie => _buildPieChart(chartTheme),
        USpecKind.bar => _buildBarChart(chartTheme),
        USpecKind.scatter => _buildScatterChart(chartTheme, bubble: false),
        USpecKind.bubble => _buildScatterChart(chartTheme, bubble: true),
        USpecKind.histogram => _buildHistogramChart(chartTheme),
        // The theme is handed over rather than the resolved values: the grid
        // resolves from the same context with the same override, so the two
        // cannot disagree. `semanticsLabel: ''` suppresses its own node, since
        // this widget already wraps the whole thing in one.
        USpecKind.heatmap => HeatmapChartView(spec: spec, theme: theme, semanticsLabel: ''),
        _ => _buildLineChart(chartTheme),
      },
    );

    final title = spec.title?.trim();
    final Widget content;
    if (title == null || title.isEmpty) {
      content = plot;
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(title, style: chartTheme.titleTextStyle),
          ),
          plot,
        ],
      );
    }

    final label =
        semanticsLabel ??
        translations.chartSemanticsLabel(
          ChartSemantics.fromSpec(spec, unnamedSeries: translations.unnamedChartSeries),
        );
    if (label.isEmpty) return content;
    return Semantics(container: true, excludeSemantics: true, label: label, child: content);
  }

  // ---------------------------------------------------------------------------
  // Line / area chart
  // ---------------------------------------------------------------------------

  Widget _buildLineChart(ResolvedChartTheme theme) {
    final filled = spec.kind == USpecKind.area;
    final labels = _categoryLabels();
    final lineBarsData = spec.series.asMap().entries.map((e) {
      final color = theme.seriesColor(e.key);
      return LineChartBarData(
        spots: _toSpots(e.value, labels),
        color: color,
        dotData: const FlDotData(show: false),
        belowBarData: filled ? BarAreaData(show: true, color: color.withValues(alpha: 0.15)) : BarAreaData(show: false),
      );
    }).toList();

    return LineChart(
      LineChartData(
        lineBarsData: lineBarsData,
        titlesData: _titlesData(labels, theme),
        gridData: _gridData(theme),
        borderData: FlBorderData(show: false),
        minY: spec.beginAtZeroY ? 0 : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bar chart
  // ---------------------------------------------------------------------------

  Widget _buildBarChart(ResolvedChartTheme theme) {
    final labels = _categoryLabels();

    final groups = List.generate(labels.length, (xi) {
      final rods = <BarChartRodData>[];
      for (var si = 0; si < spec.series.length; si++) {
        // Omit the rod where a series has no point in this category. Falling
        // back to zero drew a bar for data that doesn't exist, which reads as a
        // real measurement of nothing rather than as absent.
        final point = _pointAt(spec.series[si], labels[xi], xi);
        if (point == null) continue;
        rods.add(BarChartRodData(toY: point.y, color: theme.seriesColor(si), width: 10));
      }
      return BarChartGroupData(x: xi, barRods: rods, barsSpace: 4);
    });

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: _titlesData(labels, theme),
        gridData: _gridData(theme),
        borderData: FlBorderData(show: false),
        barTouchData: const BarTouchData(enabled: false),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pie chart
  // ---------------------------------------------------------------------------

  Widget _buildPieChart(ResolvedChartTheme theme) {
    // For pie charts, use the first series; each point is one slice.
    final points = spec.series.isNotEmpty ? spec.series.first.points : <UPoint>[];
    final labelStyle = theme.pieLabelStyle;
    final sections = points.asMap().entries.map((e) {
      final color = theme.seriesColor(e.key);
      return PieChartSectionData(
        value: e.value.y,
        color: color,
        title: e.value.x,
        radius: 80,
        // The label was hardcoded white, which vanishes on any light slice —
        // and a host palette is free to contain one. Every slice is a different
        // fill, so the choice has to be made per slice; a host that puts a
        // color on `pieLabelStyle` still wins outright.
        titleStyle: labelStyle.color != null ? labelStyle : labelStyle.copyWith(color: _onSlice(color)),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections, sectionsSpace: 2));
  }

  /// The readable color for a label drawn on top of [slice].
  ///
  /// Material's own threshold, so a slice that reads as a dark surface gets
  /// light text and vice versa.
  static Color _onSlice(Color slice) =>
      ThemeData.estimateBrightnessForColor(slice) == Brightness.dark ? Colors.white : Colors.black87;

  // ---------------------------------------------------------------------------
  // Scatter / bubble chart
  // ---------------------------------------------------------------------------

  Widget _buildScatterChart(ResolvedChartTheme theme, {required bool bubble}) {
    // Categorical x values ('Jan', 'Feb') have no numeric position, so they're
    // placed on the shared category axis and labelled along the bottom.
    // Previously the fallback used the running total of spots across *all*
    // series, so every series after the first was pushed off to the right of the
    // one before it instead of sharing the same categories.
    final numericX = _hasNumericX();
    final labels = numericX ? const <String>[] : _categoryLabels();
    final sizeRange = bubble ? _sizeRange() : null;

    final spots = <ScatterSpot>[];
    for (final entry in spec.series.asMap().entries) {
      final color = theme.seriesColor(entry.key);
      final points = entry.value.points;
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final x = numericX ? (double.tryParse(point.x) ?? i.toDouble()) : _categoryX(point, i, labels);
        final radius = bubble ? _bubbleRadius(point.size, sizeRange, theme) : theme.scatterRadius;
        spots.add(
          ScatterSpot(
            x,
            point.y,
            dotPainter: FlDotCirclePainter(radius: radius, color: color),
          ),
        );
      }
    }

    return ScatterChart(
      ScatterChartData(
        scatterSpots: spots,
        // An empty label list means "show the raw numeric x values".
        titlesData: _titlesData(labels, theme),
        gridData: _gridData(theme),
        borderData: FlBorderData(show: false),
        minY: spec.beginAtZeroY ? 0 : null,
      ),
    );
  }

  /// Whether every point's [UPoint.x] parses as a number, meaning the x axis is
  /// a real numeric scale rather than a list of categories.
  bool _hasNumericX() =>
      spec.series.isNotEmpty &&
      spec.series.every((s) => s.points.isNotEmpty && s.points.every((p) => double.tryParse(p.x) != null));

  /// The span of [UPoint.size] values across every point that has one, or `null`
  /// when no point does.
  ({double min, double max})? _sizeRange() {
    final sizes = spec.series.expand((s) => s.points).map((p) => p.size).whereType<double>();
    if (sizes.isEmpty) return null;
    return (min: sizes.reduce(min), max: sizes.reduce(max));
  }

  /// Maps a bubble's [UPoint.size] onto a pixel radius.
  ///
  /// Sizes are normalized across every bubble in the chart first, because they
  /// arrive in the data's own units — Chart.js's `r` is already pixels, but a
  /// USpec `size` is just as likely to be a population or a revenue figure.
  /// Clamping the raw value instead pinned every bubble past the maximum to the
  /// same radius, flattening the very encoding the chart exists to show.
  double _bubbleRadius(double? size, ({double min, double max})? range, ResolvedChartTheme theme) {
    if (size == null || range == null) return theme.scatterRadius;

    final span = range.max - range.min;
    // Every bubble the same size: use the middle of the range rather than
    // collapsing them all to the minimum.
    if (span <= 0) return (theme.bubbleMinRadius + theme.bubbleMaxRadius) / 2;

    final t = ((size - range.min) / span).clamp(0.0, 1.0);
    return theme.bubbleMinRadius + t * (theme.bubbleMaxRadius - theme.bubbleMinRadius);
  }

  // ---------------------------------------------------------------------------
  // Histogram
  // ---------------------------------------------------------------------------

  Widget _buildHistogramChart(ResolvedChartTheme theme) {
    final values = spec.series.isNotEmpty ? spec.series.first.points.map((p) => p.y).toList() : <double>[];
    final bins = _makeBins(values, theme.histogramBinCount);

    final groups = bins.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(toY: e.value.count.toDouble(), color: theme.seriesColor(0), width: 10)],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: _titlesData(bins.map((b) => b.label).toList(), theme),
        gridData: _gridData(theme),
        borderData: FlBorderData(show: false),
        barTouchData: const BarTouchData(enabled: false),
      ),
    );
  }

  /// Bins [values] into [targetBins] equal-width buckets between their min
  /// and max, mirroring Swift's `makeBins`.
  List<_HistogramBin> _makeBins(List<double> values, int targetBins) {
    if (values.isEmpty) return const [];
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    // Every value identical: one bin holding all of them. Returning nothing
    // rendered a blank chart for data that does have a perfectly good story.
    if (maxV <= minV) {
      return [_HistogramBin(label: minV.toStringAsFixed(1), count: values.length)];
    }

    final bins = targetBins < 1 ? 1 : targetBins;
    final step = (maxV - minV) / bins;
    final counts = List<int>.filled(bins, 0);
    for (final v in values) {
      final idx = ((v - minV) / step).floor().clamp(0, bins - 1);
      counts[idx]++;
    }

    return List.generate(bins, (i) {
      final lo = minV + i * step;
      final hi = minV + (i + 1) * step;
      return _HistogramBin(label: '${lo.toStringAsFixed(1)}–${hi.toStringAsFixed(1)}', count: counts[i]);
    });
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  List<FlSpot> _toSpots(USeries series, List<String> labels) =>
      series.points.asMap().entries.map((e) => FlSpot(_categoryX(e.value, e.key, labels), e.value.y)).toList();

  /// Where [point] — the [index]-th in its series — sits on the shared category
  /// axis [labels].
  ///
  /// Falls back to the position within its own series when the point's label
  /// isn't on the axis, or when labels aren't usable as keys at all.
  double _categoryX(UPoint point, int index, List<String> labels) {
    if (!_hasCategoryKeys) return index.toDouble();
    final at = labels.indexOf(point.x);
    return (at >= 0 ? at : index).toDouble();
  }

  /// Whether a point can be located on the x axis by its [UPoint.x] label.
  ///
  /// True when no series repeats a label. One that does carries no usable
  /// category key — a histogram's raw samples all share an empty `x` — so those
  /// charts keep plotting each point at its position within its own series.
  bool get _hasCategoryKeys => spec.series.every((s) => s.points.map((p) => p.x).toSet().length == s.points.length);

  /// The x-axis categories, in axis order.
  ///
  /// Every series' labels are merged rather than read off the longest one
  /// alone, and points are then placed by *label* rather than by their position
  /// within their own list. Position was wrong for any series with a hole in it:
  /// a Chart.js `null` — the documented way to write a gap — parses to a series
  /// that is simply shorter, so every point after the gap was drawn one category
  /// to the left, out of step with both the axis and the other series.
  ///
  /// Longest series first, so the fullest one sets the order and the rest only
  /// contribute categories it is missing.
  List<String> _categoryLabels() {
    if (!_hasCategoryKeys) {
      var labels = const <String>[];
      for (final series in spec.series) {
        if (series.points.length <= labels.length) continue;
        labels = series.points.map((p) => p.x).toList();
      }
      return labels;
    }

    final ordered = <String>[];
    final bySize = [...spec.series]..sort((a, b) => b.points.length.compareTo(a.points.length));
    for (final series in bySize) {
      // Where the previous point of *this* series landed, so a category no
      // other series carried is inserted next to its neighbours rather than
      // appended to the end.
      var cursor = -1;
      for (final point in series.points) {
        final at = ordered.indexOf(point.x);
        if (at >= 0) {
          cursor = at;
          continue;
        }
        ordered.insert(++cursor, point.x);
      }
    }
    return ordered;
  }

  /// The point [series] holds for the category [label], or `null` if it has
  /// none — a gap, or a series that doesn't reach this far.
  UPoint? _pointAt(USeries series, String label, int index) {
    if (!_hasCategoryKeys) return index < series.points.length ? series.points[index] : null;
    for (final point in series.points) {
      if (point.x == label) return point;
    }
    return null;
  }

  /// Builds the axis titles.
  ///
  /// An empty [labels] list means the x axis is numeric, and the raw values are
  /// shown instead of category names.
  FlTitlesData _titlesData(List<String> labels, ResolvedChartTheme theme) {
    final labelStyle = theme.axisLabelStyle;
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: labelStyle),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final String text;
            if (labels.isEmpty) {
              text = meta.formattedValue;
            } else {
              // Only label whole positions — fl_chart also asks for the
              // fractional values in between. Compared with a tolerance rather
              // than exactly, since the values it derives from its interval
              // aren't guaranteed to land precisely on the integer.
              final i = value.round();
              if (i < 0 || i >= labels.length || (value - i).abs() > 0.01) return const SizedBox.shrink();
              text = labels[i];
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: labelStyle, overflow: TextOverflow.ellipsis),
            );
          },
        ),
      ),
    );
  }

  FlGridData _gridData(ResolvedChartTheme theme) => FlGridData(
    drawVerticalLine: false,
    horizontalInterval: null,
    // Theme-derived: the grid line used to be a hardcoded translucent black,
    // which is invisible against a dark surface.
    getDrawingHorizontalLine: (_) => FlLine(color: theme.gridLineColor, strokeWidth: 1),
  );
}

/// A single bucket produced by [ChartView._makeBins].
class _HistogramBin {
  const _HistogramBin({required this.label, required this.count});

  final String label;
  final int count;
}
