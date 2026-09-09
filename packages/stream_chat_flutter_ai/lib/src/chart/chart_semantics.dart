import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// What a chart is showing, reduced to the facts a spoken summary needs.
///
/// `fl_chart` paints to a canvas and contributes no accessibility nodes, so
/// without a summary a [ChartView] is an empty box to a screen reader. This
/// gathers the facts; [AITranslations.chartSemanticsLabel] turns them into a
/// sentence, which is the half that has to be translated.
///
/// Numbers arrive already formatted, so an implementation never has to decide
/// how many decimals to read out.
@immutable
class ChartSemantics {
  const ChartSemantics._({
    required this.kind,
    required this.seriesNames,
    required this.pointCount,
    required this.categoryCount,
    required this.rowCount,
    required this.columnCount,
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
    final points = [for (final series in spec.series) ...series.points];
    final names = [
      for (final series in spec.series)
        if (series.name.trim().isEmpty) unnamedSeries else series.name,
    ];
    final title = spec.title?.trim();
    final xLabel = spec.xLabel?.trim();
    final yLabel = spec.yLabel?.trim();

    final columns = <String>{for (final series in spec.series) ...series.points.map((p) => p.x)};

    if (points.isEmpty) {
      return ChartSemantics._(
        kind: spec.kind,
        seriesNames: names,
        pointCount: 0,
        categoryCount: 0,
        rowCount: spec.series.length,
        columnCount: columns.length,
        title: _orNull(title),
        xLabel: _orNull(xLabel),
        yLabel: _orNull(yLabel),
      );
    }

    // A heatmap encodes its value in `z`, falling back to `y` the same way the
    // grid does.
    final values = spec.kind == USpecKind.heatmap ? points.map((p) => p.z ?? p.y) : points.map((p) => p.y);
    final sizes = points.map((p) => p.size).whereType<double>();

    String? largestLabel;
    String? largestPercent;
    if (spec.kind == USpecKind.pie) {
      final slices = spec.series.first.points;
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
      categoryCount: _categoryCount(spec),
      rowCount: spec.series.length,
      columnCount: columns.length,
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

  /// The series names, in axis order, with unnamed series filled in.
  final List<String> seriesNames;

  /// How many data points there are across every series.
  final int pointCount;

  /// How many distinct positions the x axis holds.
  ///
  /// Mirrors how [ChartView] actually lays the axis out: the distinct labels
  /// when they can serve as category keys, and the longest series' length when
  /// they repeat and so can't.
  final int categoryCount;

  /// How many rows a [USpecKind.heatmap] grid has — one per series.
  final int rowCount;

  /// How many columns a [USpecKind.heatmap] grid has.
  final int columnCount;

  /// The smallest value plotted, formatted, or null when there is no data.
  final String? valueMin;

  /// The largest value plotted, formatted, or null when there is no data.
  final String? valueMax;

  /// The smallest [UPoint.size] among [USpecKind.bubble] points, formatted, or
  /// null when no point carries one.
  final String? sizeMin;

  /// The largest [UPoint.size] among [USpecKind.bubble] points, formatted, or
  /// null when no point carries one.
  final String? sizeMax;

  /// The label of the biggest [USpecKind.pie] slice, or null for other kinds.
  final String? largestSliceLabel;

  /// That slice's share of the whole as a whole-number percentage, formatted,
  /// or null when the slices don't sum to anything positive.
  final String? largestSlicePercent;

  /// Whether the chart has nothing to plot.
  bool get isEmpty => pointCount == 0;

  static String? _orNull(String? value) => (value == null || value.isEmpty) ? null : value;

  /// Formats a value for speech.
  ///
  /// Chart data is nearly always integral, and a screen reader reads `10.0` as
  /// "ten point zero", so whole numbers lose their decimal and the rest keep at
  /// most two.
  static String _formatValue(double value) {
    if (!value.isFinite) return value.toString();
    // Also normalizes -0.0, which toStringAsFixed(0) renders as '-0'.
    if (value == 0) return '0';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// How many x positions [spec] occupies, mirroring `ChartView`'s own
  /// category logic.
  static int _categoryCount(USpec spec) {
    final hasCategoryKeys = spec.series.every((s) => s.points.map((p) => p.x).toSet().length == s.points.length);
    if (hasCategoryKeys) {
      return <String>{for (final series in spec.series) ...series.points.map((p) => p.x)}.length;
    }
    return spec.series.fold(0, (longest, s) => math.max(longest, s.points.length));
  }
}
