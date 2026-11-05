import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// What a chart is showing, reduced to the facts a spoken summary needs.
///
/// `fl_chart` paints to a canvas and exposes no accessibility nodes, so without
/// a summary a [ChartView] is an empty box to a screen reader. This gathers the
/// facts, already formatted; [AITranslations.chartSemanticsLabel] composes the
/// sentence, which is the half that gets translated.
@immutable
class ChartSemantics {
  const ChartSemantics._({
    required this.kind,
    required this.seriesNames,
    required this.pointCount,
    required this.categoryCount,
    required this.rowCount,
    required this.columnLabels,
    this.sliceLabels = const [],
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
  /// [unnamedSlice] does the same for a [USpecKind.pie] slice, a
  /// [USpecKind.radial] ring or a [USpecKind.singleStackedBar] part, given its
  /// 1-based position in the data; it falls back to [unnamedSeries].
  factory ChartSemantics.fromSpec(
    USpec spec, {
    required String unnamedSeries,
    String Function(int number)? unnamedSlice,
  }) {
    // A pie, a histogram, a radial chart and a single stacked bar plot the
    // first series and ignore the rest, so describing every one would announce
    // a count the chart never draws.
    final drawn = switch (spec.kind) {
      USpecKind.pie ||
      USpecKind.histogram ||
      USpecKind.radial ||
      USpecKind.singleStackedBar => spec.series.take(1).toList(growable: false),
      USpecKind.line ||
      USpecKind.bar ||
      USpecKind.area ||
      USpecKind.scatter ||
      USpecKind.bubble ||
      USpecKind.heatmap ||
      USpecKind.horizontalBar ||
      USpecKind.radar => spec.series,
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

    // `points` is already the first series alone for the kinds that split one
    // series into parts. Only the parts actually drawn count: a zero, negative
    // or non-finite one has no area.
    final parts = hasParts(spec.kind)
        ? drawnPieSlices(points, unnamed: unnamedSlice ?? (_) => unnamedSeries)
        : const <({String label, double value})>[];

    final values = switch (spec.kind) {
      // Encoded in `z`, falling back to `y` the same way the grid does.
      USpecKind.heatmap => points.map((p) => p.z ?? p.y),
      // The rings and parts drawn, not the values left out.
      USpecKind.radial || USpecKind.singleStackedBar when parts.isNotEmpty => parts.map((part) => part.value),
      // Where the stacks end, as the bars and the axis show them, not the
      // values stacked.
      USpecKind.bar || USpecKind.horizontalBar
          when spec.barLayout == USpecBarLayout.stacked && _stackEnds(drawn).isNotEmpty =>
        _stackEnds(drawn),
      // Where each value sits: a negative or non-finite one at the center.
      USpecKind.radar => points.map((p) => p.y.isFinite ? math.max<double>(0, p.y) : 0.0),
      USpecKind.line ||
      USpecKind.bar ||
      USpecKind.pie ||
      USpecKind.area ||
      USpecKind.scatter ||
      USpecKind.bubble ||
      USpecKind.histogram ||
      USpecKind.horizontalBar ||
      USpecKind.radial ||
      USpecKind.singleStackedBar => points.map((p) => p.y),
    };
    // Only a bubble draws `UPoint.size`, but the parsers fill it in regardless
    // of the mark — a Vega-Lite `{"mark": "point", "encoding": {"size": ...}}`
    // is a scatter — so without this guard identical dots announce a range.
    final sizes = spec.kind == USpecKind.bubble
        ? points.map((p) => p.size).whereType<double>()
        : const Iterable<double>.empty();

    String? largestLabel;
    String? largestPercent;
    final sliceLabels = [for (final part in parts) part.label];
    if (parts.isNotEmpty) {
      final largest = parts.reduce((a, b) => b.value > a.value ? b : a);
      largestLabel = largest.label;
      final total = parts.fold<double>(0, (sum, s) => sum + s.value);
      final share = switch (spec.kind) {
        // A sum of finite values can still overflow to infinity, which leaves
        // a pie no share to draw or read.
        USpecKind.pie => total.isFinite && total > 0 ? largest.value / total : null,
        // Measured against the largest part, as the bar is drawn, so values
        // too large to add up as they are still have shares.
        USpecKind.singleStackedBar => 1 / parts.fold<double>(0, (sum, s) => sum + s.value / largest.value),
        // A share of the total means nothing for a radial chart, whose rings
        // are measured against the largest.
        USpecKind.radial ||
        USpecKind.line ||
        USpecKind.bar ||
        USpecKind.area ||
        USpecKind.scatter ||
        USpecKind.bubble ||
        USpecKind.heatmap ||
        USpecKind.histogram ||
        USpecKind.horizontalBar ||
        USpecKind.radar => null,
      };
      if (share != null) largestPercent = _formatValue((share * 100).roundToDouble());
    }

    return ChartSemantics._(
      kind: spec.kind,
      seriesNames: names,
      pointCount: points.length,
      categoryCount: _categoryCount(drawn),
      rowCount: drawn.length,
      columnLabels: columns,
      sliceLabels: sliceLabels,
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

  // Where each category's stack ends: the sum of its positive values above
  // zero, and of its negative ones below, leaving out the values a stacked bar
  // leaves out.
  static List<double> _stackEnds(List<USeries> series) {
    final positive = <String, double>{};
    final negative = <String, double>{};
    for (final s in series) {
      for (final point in s.points) {
        if (!point.y.isFinite) continue;
        final sums = point.y >= 0 ? positive : negative;
        sums[point.x] = (sums[point.x] ?? 0) + point.y;
      }
    }
    return [...positive.values, ...negative.values].where((end) => end.isFinite).toList(growable: false);
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

  /// How many data points are plotted — for a pie, a histogram, a radial chart
  /// and a single stacked bar, the first series alone, which is all they draw.
  final int pointCount;

  /// How many distinct positions the x axis holds, mirroring how [ChartView]
  /// lays it out: distinct labels when they can serve as category keys, the
  /// longest series' length when they repeat.
  final int categoryCount;

  /// One per described series — a [USpecKind.heatmap]'s row count. The rows are
  /// named in [seriesNames], in the same order.
  final int rowCount;

  /// The distinct x positions, left to right — a [USpecKind.heatmap]'s column
  /// labels, drawn along its bottom. Its rows are [seriesNames].
  final List<String> columnLabels;

  /// How many distinct x positions there are — a [USpecKind.heatmap]'s column
  /// count.
  int get columnCount => columnLabels.length;

  /// The smallest value plotted, formatted, or null when there is no data.
  final String? valueMin;

  /// The largest value plotted, formatted, or null when there is no data.
  final String? valueMax;

  /// The smallest [UPoint.size] among [USpecKind.bubble] points, formatted, or
  /// null when no point carries one. Always null for every other kind, which
  /// draws all points at one radius.
  final String? sizeMin;

  /// The largest [UPoint.size] among [USpecKind.bubble] points, formatted, or
  /// null when no point carries one.
  final String? sizeMax;

  /// The names of the parts that are drawn — those with a positive, finite
  /// value — in data order, with unnamed ones filled in: a [USpecKind.pie]'s
  /// slices, a [USpecKind.radial] chart's rings or a
  /// [USpecKind.singleStackedBar]'s parts. Empty for every other kind.
  ///
  /// The summary is where a screen reader hears them: the legend, or the
  /// labels on the slices without one, are excluded from the semantics tree.
  final List<String> sliceLabels;

  /// The label of the largest entry of [sliceLabels], or null when there are
  /// none.
  final String? largestSliceLabel;

  /// The share of the total taken by the largest entry of [sliceLabels], as a
  /// whole-number percentage, formatted.
  ///
  /// Null for a [USpecKind.radial] chart, whose rings are measured against the
  /// largest rather than the total; when there is no [largestSliceLabel]; and
  /// when the parts don't sum to anything positive.
  final String? largestSlicePercent;

  /// Whether the chart has nothing to plot, such as a pie whose slices are all
  /// zero, negative or not finite, or a [USpecKind.radar] with fewer than three
  /// categories.
  bool get isEmpty {
    if (pointCount == 0) return true;
    return switch (kind) {
      USpecKind.pie || USpecKind.radial || USpecKind.singleStackedBar => sliceLabels.isEmpty,
      // Fewer than three spokes make no shape.
      USpecKind.radar => categoryCount < 3,
      USpecKind.line ||
      USpecKind.bar ||
      USpecKind.area ||
      USpecKind.scatter ||
      USpecKind.bubble ||
      USpecKind.heatmap ||
      USpecKind.histogram ||
      USpecKind.horizontalBar => false,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartSemantics &&
          other.kind == kind &&
          other.title == title &&
          other.xLabel == xLabel &&
          other.yLabel == yLabel &&
          const ListEquality<String>().equals(other.seriesNames, seriesNames) &&
          other.pointCount == pointCount &&
          other.categoryCount == categoryCount &&
          other.rowCount == rowCount &&
          const ListEquality<String>().equals(other.columnLabels, columnLabels) &&
          const ListEquality<String>().equals(other.sliceLabels, sliceLabels) &&
          other.valueMin == valueMin &&
          other.valueMax == valueMax &&
          other.sizeMin == sizeMin &&
          other.sizeMax == sizeMax &&
          other.largestSliceLabel == largestSliceLabel &&
          other.largestSlicePercent == largestSlicePercent;

  @override
  int get hashCode => Object.hash(
    kind,
    title,
    xLabel,
    yLabel,
    // The lists need a deep hash of their own; an identity hash would make two
    // equal summaries hash differently.
    Object.hashAll(seriesNames),
    pointCount,
    categoryCount,
    rowCount,
    Object.hashAll(columnLabels),
    Object.hashAll(sliceLabels),
    valueMin,
    valueMax,
    sizeMin,
    sizeMax,
    largestSliceLabel,
    largestSlicePercent,
  );

  /// The [points] of a pie, a radial chart or a single stacked bar that are
  /// actually drawn — positive and finite — paired with a display name,
  /// [unnamed] standing in for a blank one.
  ///
  /// Internal: shared by [ChartView] and the summary, so the legend, the
  /// slices and what a screen reader hears all agree.
  @internal
  static List<({String label, double value})> drawnPieSlices(
    List<UPoint> points, {
    required String Function(int number) unnamed,
  }) => [
    for (final (i, point) in points.indexed)
      if (point.y.isFinite && point.y > 0) (label: point.x.trim().isEmpty ? unnamed(i + 1) : point.x, value: point.y),
  ];

  /// Whether [kind] splits its first series into parts — a pie's slices, a
  /// radial chart's rings, a single stacked bar's parts — drawing only the
  /// positive, finite ones.
  ///
  /// Internal: shared by [ChartView] and the summary, like [drawnPieSlices].
  @internal
  static bool hasParts(USpecKind kind) => switch (kind) {
    USpecKind.pie || USpecKind.radial || USpecKind.singleStackedBar => true,
    USpecKind.line ||
    USpecKind.bar ||
    USpecKind.area ||
    USpecKind.scatter ||
    USpecKind.bubble ||
    USpecKind.heatmap ||
    USpecKind.histogram ||
    USpecKind.horizontalBar ||
    USpecKind.radar => false,
  };

  static String? _orNull(String? value) => (value == null || value.isEmpty) ? null : value;

  /// Formats a value for speech: a reader says "ten point zero" for `10.0`, so
  /// whole numbers lose their decimal and the rest keep at most two.
  static String _formatValue(double value) {
    if (!value.isFinite) return value.toString();
    // Round before deciding how to render. Deciding first got both edges wrong:
    // 99.999 is not whole but rounds to one, and -0.001 is neither zero nor
    // whole, so it came out '-0' — voiced as "minus zero".
    final rounded = double.parse(value.toStringAsFixed(2));
    if (rounded == 0) return '0';
    if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
    // Always has a fraction here, so stripping zeros can't leave a bare point.
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
