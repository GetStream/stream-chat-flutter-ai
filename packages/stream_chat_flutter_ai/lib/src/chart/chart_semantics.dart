import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// What a chart is showing, reduced to the facts a spoken summary needs.
///
/// `fl_chart` paints to a canvas and exposes no accessibility nodes, so without
/// a summary a [ChartView] is an empty box to a screen reader. This gathers the
/// facts; [AITranslations.chartSemanticsLabel] composes the sentence, which is
/// the half that gets translated.
///
/// Numbers arrive pre-formatted, so an implementation never picks decimals.
@immutable
class ChartSemantics {
  const ChartSemantics._({
    required this.kind,
    required this.seriesNames,
    required this.pointCount,
    required this.categoryCount,
    required this.rowCount,
    required this.columnLabels,
    this.title,
    this.xLabel,
    this.yLabel,
    this.valueMin,
    this.valueMax,
    this.sizeMin,
    this.sizeMax,
    this.largestSliceLabel,
    this.largestSlicePercent,
  });

  /// Reduces [spec] to its describable facts.
  ///
  /// [unnamedSeries] stands in for a series the chart data didn't name — the
  /// parser leaves those empty rather than inventing an English word for them.
  factory ChartSemantics.fromSpec(USpec spec, {required String unnamedSeries}) {
    // A pie and a histogram plot the first series and ignore the rest — see
    // `ChartView._buildPieChart` and `_buildHistogramChart`. Describing every
    // series would announce a slice or sample count the chart never draws, so
    // the summary covers exactly what is on screen.
    final drawn = switch (spec.kind) {
      USpecKind.pie || USpecKind.histogram => spec.series.take(1).toList(growable: false),
      _ => spec.series,
    };

    final points = [for (final series in drawn) ...series.points];
    final names = [
      for (final series in drawn)
        if (series.name.trim().isEmpty) unnamedSeries else series.name,
    ];
    final title = spec.title?.trim();
    final xLabel = spec.xLabel?.trim();
    final yLabel = spec.yLabel?.trim();

    // A set literal keeps insertion order, so these come out left to right.
    final columns = <String>{for (final series in drawn) ...series.points.map((p) => p.x)}.toList(growable: false);

    if (points.isEmpty) {
      return ChartSemantics._(
        kind: spec.kind,
        seriesNames: names,
        pointCount: 0,
        categoryCount: 0,
        rowCount: drawn.length,
        columnLabels: columns,
        title: _orNull(title),
        xLabel: _orNull(xLabel),
        yLabel: _orNull(yLabel),
      );
    }

    // A heatmap encodes its value in `z`, falling back to `y` the same way the
    // grid does.
    final values = spec.kind == USpecKind.heatmap ? points.map((p) => p.z ?? p.y) : points.map((p) => p.y);
    // Only a bubble chart maps `UPoint.size` onto anything — every other kind
    // draws its points at the flat `scatterRadius`. The parsers fill `size` in
    // regardless of the mark (a Vega-Lite `{"mark": "point", "encoding":
    // {"size": ...}}` is a scatter), so without this a chart of a dozen
    // identical dots announced the size range it never drew.
    final sizes = spec.kind == USpecKind.bubble
        ? points.map((p) => p.size).whereType<double>()
        : const Iterable<double>.empty();

    String? largestLabel;
    String? largestPercent;
    if (spec.kind == USpecKind.pie) {
      // `points` is already the first series alone, and non-empty past the
      // guard above — so `reduce` has something to fold.
      final slices = points;
      final total = slices.fold<double>(0, (sum, p) => sum + p.y);
      final largest = slices.reduce((a, b) => b.y > a.y ? b : a);
      largestLabel = _orNull(largest.x.trim());
      // Shares of a zero or negative total aren't percentages of anything.
      if (total > 0) largestPercent = _formatValue((largest.y / total * 100).roundToDouble());
    }

    return ChartSemantics._(
      kind: spec.kind,
      seriesNames: names,
      pointCount: points.length,
      categoryCount: _categoryCount(drawn),
      rowCount: drawn.length,
      columnLabels: columns,
      title: _orNull(title),
      xLabel: _orNull(xLabel),
      yLabel: _orNull(yLabel),
      valueMin: _formatValue(values.reduce(math.min)),
      valueMax: _formatValue(values.reduce(math.max)),
      sizeMin: sizes.isEmpty ? null : _formatValue(sizes.reduce(math.min)),
      sizeMax: sizes.isEmpty ? null : _formatValue(sizes.reduce(math.max)),
      largestSliceLabel: largestLabel,
      largestSlicePercent: largestPercent,
    );
  }

  /// Which kind of chart this is.
  final USpecKind kind;

  /// The chart's title, or null when it has none or only whitespace.
  final String? title;

  /// The x-axis label, or null when the data carried none.
  final String? xLabel;

  /// The y-axis label, or null when the data carried none.
  final String? yLabel;

  /// The series names in [USpec.series] order, with unnamed ones filled in.
  final List<String> seriesNames;

  /// How many data points are plotted.
  ///
  /// A pie and a histogram draw only the first series, so this counts that one
  /// alone for them — the summary describes what is on screen.
  final int pointCount;

  /// How many distinct positions the x axis holds, mirroring how [ChartView]
  /// lays it out: distinct labels when they can serve as category keys, the
  /// longest series' length when they repeat.
  final int categoryCount;

  /// One per described series — a [USpecKind.heatmap]'s row count.
  ///
  /// The rows themselves are named in [seriesNames], in the same order.
  final int rowCount;

  /// The distinct x positions, left to right — a [USpecKind.heatmap]'s column
  /// labels.
  ///
  /// A heatmap draws these down the side and along the bottom, and the
  /// semantics node excludes them, so the summary is where a screen reader
  /// hears which cell is which.
  final List<String> columnLabels;

  /// How many distinct x positions there are — a [USpecKind.heatmap]'s column
  /// count.
  int get columnCount => columnLabels.length;

  /// The smallest value plotted, formatted, or null when there is no data.
  final String? valueMin;

  /// The largest value plotted, formatted, or null when there is no data.
  final String? valueMax;

  /// The smallest [UPoint.size] among [USpecKind.bubble] points, formatted, or
  /// null when no point carries one.
  ///
  /// Always null for every other kind: they draw all points at one radius, so
  /// a size range would describe an encoding that isn't on screen.
  final String? sizeMin;

  /// The largest [UPoint.size] among [USpecKind.bubble] points, formatted, or
  /// null when no point carries one.
  final String? sizeMax;

  /// The label of the biggest [USpecKind.pie] slice, or null for other kinds.
  final String? largestSliceLabel;

  /// That slice's share as a whole-number percentage, formatted. Null for other
  /// kinds, and when the slices don't sum to anything positive.
  final String? largestSlicePercent;

  /// Whether the chart has nothing to plot.
  bool get isEmpty => pointCount == 0;

  static String? _orNull(String? value) => (value == null || value.isEmpty) ? null : value;

  /// Formats a value for speech: a screen reader reads `10.0` as "ten point
  /// zero", so whole numbers lose their decimal and the rest keep at most two.
  static String _formatValue(double value) {
    if (!value.isFinite) return value.toString();
    // Round first, then decide how to render — deciding first got both edges
    // wrong. 99.999 is not whole but rounds to one, and -0.001 is neither zero
    // nor whole, so it reached the last branch as '-0.00' -> '-0', voiced as
    // "minus zero" for every value in (-0.005, 0).
    final rounded = double.parse(value.toStringAsFixed(2));
    // Covers -0.0, whose toStringAsFixed(0) is '-0'.
    if (rounded == 0) return '0';
    if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
    // Always has a fraction past the guard above, so stripping its trailing
    // zeros can never leave a dangling point.
    return rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// How many x positions [series] occupies. Mirrors `ChartView._categoryLabels`
  /// — change both together, or the spoken count drifts from the drawn axis.
  static int _categoryCount(List<USeries> series) {
    final hasCategoryKeys = series.every((s) => s.points.map((p) => p.x).toSet().length == s.points.length);
    if (hasCategoryKeys) {
      return <String>{for (final s in series) ...s.points.map((p) => p.x)}.length;
    }
    return series.fold(0, (longest, s) => math.max(longest, s.points.length));
  }
}
