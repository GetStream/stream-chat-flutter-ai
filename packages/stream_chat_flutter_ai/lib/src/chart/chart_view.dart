import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

const _kChartHeight = 220.0;

const _kSeriesColors = [
  Color(0xFF4A90D9),
  Color(0xFFE67E22),
  Color(0xFF2ECC71),
  Color(0xFFE74C3C),
  Color(0xFF9B59B6),
  Color(0xFF1ABC9C),
];

/// The fixed marker radius used for [USpecKind.scatter] points.
const _kScatterRadius = 6.0;

/// The [UPoint.size]-to-radius clamp range used for [USpecKind.bubble] points.
const _kBubbleRadiusRange = (min: 6.0, max: 40.0);

/// The number of buckets a [USpecKind.histogram] is binned into.
const _kHistogramBinCount = 10;

Color _seriesColor(int index) => _kSeriesColors[index % _kSeriesColors.length];

/// Renders a [USpec] chart using `fl_chart`.
///
/// Supports [USpecKind.line], [USpecKind.area], [USpecKind.bar],
/// [USpecKind.pie], [USpecKind.scatter], [USpecKind.bubble],
/// [USpecKind.histogram], and [USpecKind.heatmap] — the last of which is drawn
/// by [HeatmapChartView] rather than `fl_chart`, which has no heatmap widget.
///
/// [USpec.title], when the spec carries one, is rendered as a heading above the
/// plot, matching the reference Android/iOS AI packages.
class ChartView extends StatelessWidget {
  /// Creates a [ChartView].
  const ChartView({super.key, required this.spec});

  /// The chart data to display.
  final USpec spec;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plot = Container(
      height: _kChartHeight,
      padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
      child: switch (spec.kind) {
        USpecKind.pie => _buildPieChart(),
        USpecKind.bar => _buildBarChart(colorScheme),
        USpecKind.scatter => _buildScatterChart(colorScheme, bubble: false),
        USpecKind.bubble => _buildScatterChart(colorScheme, bubble: true),
        USpecKind.histogram => _buildHistogramChart(colorScheme),
        USpecKind.heatmap => HeatmapChartView(spec: spec),
        _ => _buildLineChart(colorScheme),
      },
    );

    final title = spec.title?.trim();
    if (title == null || title.isEmpty) return plot;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        plot,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Line / area chart
  // ---------------------------------------------------------------------------

  Widget _buildLineChart(ColorScheme colorScheme) {
    final filled = spec.kind == USpecKind.area;
    final lineBarsData = spec.series.asMap().entries.map((e) {
      final color = _seriesColor(e.key);
      return LineChartBarData(
        spots: _toSpots(e.value),
        color: color,
        dotData: const FlDotData(show: false),
        belowBarData: filled ? BarAreaData(show: true, color: color.withValues(alpha: 0.15)) : BarAreaData(show: false),
      );
    }).toList();

    return LineChart(
      LineChartData(
        lineBarsData: lineBarsData,
        titlesData: _titlesData(_categoryLabels(), colorScheme),
        gridData: _gridData(colorScheme),
        borderData: FlBorderData(show: false),
        minY: spec.beginAtZeroY ? 0 : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bar chart
  // ---------------------------------------------------------------------------

  Widget _buildBarChart(ColorScheme colorScheme) {
    final labels = _categoryLabels();

    final groups = List.generate(labels.length, (xi) {
      final rods = <BarChartRodData>[];
      for (var si = 0; si < spec.series.length; si++) {
        final points = spec.series[si].points;
        // Omit the rod where a series has no point at this position. Falling
        // back to zero drew a bar for data that doesn't exist, which reads as a
        // real measurement of nothing rather than as absent.
        if (xi >= points.length) continue;
        rods.add(BarChartRodData(toY: points[xi].y, color: _seriesColor(si), width: 10));
      }
      return BarChartGroupData(x: xi, barRods: rods, barsSpace: 4);
    });

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: _titlesData(labels, colorScheme),
        gridData: _gridData(colorScheme),
        borderData: FlBorderData(show: false),
        barTouchData: const BarTouchData(enabled: false),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pie chart
  // ---------------------------------------------------------------------------

  Widget _buildPieChart() {
    // For pie charts, use the first series; each point is one slice.
    final points = spec.series.isNotEmpty ? spec.series.first.points : <UPoint>[];
    final sections = points.asMap().entries.map((e) {
      return PieChartSectionData(
        value: e.value.y,
        color: _seriesColor(e.key),
        title: e.value.x,
        radius: 80,
        titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections, sectionsSpace: 2));
  }

  // ---------------------------------------------------------------------------
  // Scatter / bubble chart
  // ---------------------------------------------------------------------------

  Widget _buildScatterChart(ColorScheme colorScheme, {required bool bubble}) {
    // Categorical x values ('Jan', 'Feb') have no numeric position, so they're
    // plotted at their index within their own series and labelled along the
    // bottom axis. Previously the fallback used the running total of spots
    // across *all* series, so every series after the first was pushed off to
    // the right of the one before it instead of sharing the same categories.
    final numericX = _hasNumericX();
    final sizeRange = bubble ? _sizeRange() : null;

    final spots = <ScatterSpot>[];
    for (final entry in spec.series.asMap().entries) {
      final color = _seriesColor(entry.key);
      final points = entry.value.points;
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final x = numericX ? (double.tryParse(point.x) ?? i.toDouble()) : i.toDouble();
        final radius = bubble ? _bubbleRadius(point.size, sizeRange) : _kScatterRadius;
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
        titlesData: _titlesData(numericX ? const [] : _categoryLabels(), colorScheme),
        gridData: _gridData(colorScheme),
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
  double _bubbleRadius(double? size, ({double min, double max})? range) {
    if (size == null || range == null) return _kScatterRadius;

    final span = range.max - range.min;
    // Every bubble the same size: use the middle of the range rather than
    // collapsing them all to the minimum.
    if (span <= 0) return (_kBubbleRadiusRange.min + _kBubbleRadiusRange.max) / 2;

    final t = ((size - range.min) / span).clamp(0.0, 1.0);
    return _kBubbleRadiusRange.min + t * (_kBubbleRadiusRange.max - _kBubbleRadiusRange.min);
  }

  // ---------------------------------------------------------------------------
  // Histogram
  // ---------------------------------------------------------------------------

  Widget _buildHistogramChart(ColorScheme colorScheme) {
    final values = spec.series.isNotEmpty ? spec.series.first.points.map((p) => p.y).toList() : <double>[];
    final bins = _makeBins(values, _kHistogramBinCount);

    final groups = bins.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(toY: e.value.count.toDouble(), color: _seriesColor(0), width: 10)],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: _titlesData(bins.map((b) => b.label).toList(), colorScheme),
        gridData: _gridData(colorScheme),
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

  List<FlSpot> _toSpots(USeries series) =>
      series.points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.y)).toList();

  /// The x-axis category labels, taken from the series with the most points.
  ///
  /// Reading them off the *first* series dropped any category only a later
  /// series had, silently truncating the chart to the first series' length.
  List<String> _categoryLabels() {
    var labels = const <String>[];
    for (final series in spec.series) {
      if (series.points.length <= labels.length) continue;
      labels = series.points.map((p) => p.x).toList();
    }
    return labels;
  }

  /// Builds the axis titles.
  ///
  /// An empty [labels] list means the x axis is numeric, and the raw values are
  /// shown instead of category names.
  FlTitlesData _titlesData(List<String> labels, ColorScheme colorScheme) {
    final labelStyle = TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant);
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

  FlGridData _gridData(ColorScheme colorScheme) => FlGridData(
    drawVerticalLine: false,
    horizontalInterval: null,
    // Theme-derived: the grid line used to be a hardcoded translucent black,
    // which is invisible against a dark surface.
    getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
  );
}

/// A single bucket produced by [ChartView._makeBins].
class _HistogramBin {
  const _HistogramBin({required this.label, required this.count});

  final String label;
  final int count;
}
