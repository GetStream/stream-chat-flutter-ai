import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_semantics.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/resolved_chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

/// Renders a [USpec] chart.
///
/// Supports every [USpecKind], with the options [USpec] carries for each.
///
/// [USpec.title] is rendered as a heading above the plot. A legend names each
/// entry next to its color: every slice of a pie, ring of a radial chart and
/// part of a single stacked bar, or every series of a chart plotting two or
/// more (see [ChartThemeData.showLegend]). Pie slices and single-stacked-bar
/// parts big enough to fit one carry their share of the whole, such as "42%"
/// (see [ChartThemeData.showPiePercentages]). Zero, negative and non-finite
/// values have no area in a pie, a radial chart or a single stacked bar, so
/// they are neither drawn nor listed.
///
/// Colors, sizes and the histogram's bucket count come from [ChartThemeData]:
/// app-wide through [AITheme], per subtree through [ChartTheme], or per chart
/// through [theme].
class ChartView extends StatelessWidget {
  /// Creates a [ChartView].
  const ChartView({super.key, required this.spec, this.theme, this.semanticsLabel});

  /// The key of a chart's legend, for finding it in tests.
  static const legendKey = ValueKey<String>('ChartView.legend');

  /// The chart data to display.
  final USpec spec;

  /// Overrides the ambient chart theme for this chart alone, layered over the
  /// nearest [ChartTheme] and the ambient [AITheme]. See [ChartThemeData].
  final ChartThemeData? theme;

  /// Replaces the summary a screen reader is given for this chart.
  ///
  /// By default the chart describes itself: [AITranslations.chartSemanticsLabel]
  /// composes one sentence from [ChartSemantics], and that labels a single node
  /// standing for the whole chart.
  ///
  /// That node **excludes** its subtree: axis ticks are real `Text` widgets, and
  /// walking them gives a reader bare numbers with nothing saying which axis
  /// they belong to.
  ///
  /// The legend is excluded with them. The default summary names the series of
  /// a multi-series chart, and the slices, rings or parts of a pie, a radial
  /// chart or a single stacked bar, so reading the legend as well would say
  /// each name twice.
  ///
  /// Pass `''` to add no node of this widget's own, which also puts those
  /// subtree labels, the legend's included, back in reach. It is the opt-out
  /// for describing the chart yourself, not a way to hide it.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final chartTheme = ResolvedChartTheme.resolve(context, override: theme);
    final translations = AITranslations.of(context);
    final slices = ChartSemantics.hasParts(spec.kind)
        ? ChartSemantics.drawnPieSlices(
            spec.series.isNotEmpty ? spec.series.first.points : const [],
            unnamed: translations.unnamedChartSlice,
          )
        : const <_PieSlice>[];
    final legendEntries = _legendEntries(chartTheme, slices, translations.unnamedChartSeries);
    final hasLegend = legendEntries.isNotEmpty;

    final plot = _buildPlot(
      chartTheme,
      switch (spec.kind) {
        // Sized from the space they get, so they can't answer a host asking for
        // their intrinsic size, as `IntrinsicWidth` and `Table` do.
        USpecKind.pie => _NoIntrinsics(child: _buildPieChart(chartTheme, slices, hasLegend: hasLegend)),
        USpecKind.bar => _NoIntrinsics(child: _buildBarChart(context, chartTheme, horizontal: false)),
        USpecKind.horizontalBar => _NoIntrinsics(child: _buildBarChart(context, chartTheme, horizontal: true)),
        USpecKind.scatter => _buildScatterChart(chartTheme, bubble: false),
        USpecKind.bubble => _buildScatterChart(chartTheme, bubble: true),
        USpecKind.histogram => _buildHistogramChart(chartTheme),
        // The theme is handed over rather than the resolved values: the grid
        // resolves from the same context with the same override, so the two
        // cannot disagree. `semanticsLabel: ''` suppresses its own node, since
        // this widget already wraps the whole thing in one.
        USpecKind.heatmap => HeatmapChartView(spec: spec, theme: theme, semanticsLabel: ''),
        USpecKind.line || USpecKind.area => _buildLineChart(chartTheme),
        USpecKind.radar => _NoIntrinsics(child: _buildRadarChart(chartTheme)),
        USpecKind.radial => _buildRadialChart(chartTheme, slices),
        USpecKind.singleStackedBar => _buildSingleStackedBar(chartTheme, slices, hasLegend: hasLegend),
      },
    );

    final title = spec.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final legend = legendEntries.isEmpty
        ? null
        : _ChartLegend(key: ChartView.legendKey, entries: legendEntries, textStyle: chartTheme.legendTextStyle);
    final legendOnTop = chartTheme.legendPosition == ChartLegendPosition.top;

    final Widget content;
    if (!hasTitle && legend == null) {
      content = plot;
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(title, style: chartTheme.titleTextStyle),
            ),
          if (legend != null && legendOnTop) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: legend),
          plot,
          if (legend != null && !legendOnTop) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: legend),
        ],
      );
    }

    final label =
        semanticsLabel ??
        translations.chartSemanticsLabel(
          ChartSemantics.fromSpec(
            spec,
            unnamedSeries: translations.unnamedChartSeries,
            unnamedSlice: translations.unnamedChartSlice,
          ),
        );
    if (label.isEmpty) return content;
    return Semantics(container: true, excludeSemantics: true, label: label, child: content);
  }

  // ---------------------------------------------------------------------------
  // Plot frame
  // ---------------------------------------------------------------------------

  // The plot with its padding: as tall as the kind needs, or for a
  // semicircle, whose height is its radius, as the width allows up to the
  // theme's height.
  Widget _buildPlot(ResolvedChartTheme theme, Widget child) {
    final padding = _plotPadding;
    final height = _plotHeight(theme);
    if (height != null) return Container(height: height, padding: padding, child: child);
    return _NoIntrinsics(
      height: theme.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final radius = min((constraints.maxWidth - padding.horizontal) / 2, theme.height - padding.vertical);
          // A width under the insets leaves no radius, not a negative one.
          return Container(height: max<double>(0, radius) + padding.vertical, padding: padding, child: child);
        },
      ),
    );
  }

  // The height of the plot, padding included, or null when the width decides
  // it, up to the theme's height.
  double? _plotHeight(ResolvedChartTheme theme) {
    switch (spec.kind) {
      case USpecKind.singleStackedBar:
        return _kSingleBarThickness + _kPlotVerticalPadding * 2;
      case USpecKind.pie when spec.pieShape == USpecPieShape.semicircle:
        return null;
      case USpecKind.horizontalBar when !theme.heightIsSet:
        // A row per category, tall enough for its grouped bars, so a long list
        // of categories gets the room it needs rather than squeezing into the
        // default height. A stacked category is one bar, whatever the series.
        final row = switch (spec.barLayout) {
          USpecBarLayout.grouped => max(_kHorizontalBarRowHeight, _barGroupWidth + _kHorizontalBarRowPadding),
          USpecBarLayout.stacked => _kHorizontalBarRowHeight,
        };
        final height = _categoryLabels().length * row + _kHorizontalBarAxisHeight;
        return height.clamp(_kHorizontalBarMinHeight, _kHorizontalBarMaxHeight);
      case USpecKind.line ||
          USpecKind.bar ||
          USpecKind.pie ||
          USpecKind.area ||
          USpecKind.scatter ||
          USpecKind.bubble ||
          USpecKind.heatmap ||
          USpecKind.histogram ||
          USpecKind.horizontalBar ||
          USpecKind.radar ||
          USpecKind.radial:
        return theme.height;
    }
  }

  // The plot's padding. The `fl_chart` axes reserve their own gutter on the
  // left; the kinds drawn without axes take the same inset on both sides as
  // the title and legend, so they sit centered under them.
  EdgeInsets get _plotPadding => switch (spec.kind) {
    USpecKind.line ||
    USpecKind.bar ||
    USpecKind.area ||
    USpecKind.scatter ||
    USpecKind.bubble ||
    USpecKind.heatmap ||
    USpecKind.histogram ||
    USpecKind.horizontalBar => const EdgeInsets.only(
      top: _kPlotVerticalPadding,
      right: _kPlotHorizontalPadding,
      bottom: _kPlotVerticalPadding,
    ),
    USpecKind.pie || USpecKind.radar || USpecKind.radial || USpecKind.singleStackedBar => const EdgeInsets.symmetric(
      horizontal: _kPlotHorizontalPadding,
      vertical: _kPlotVerticalPadding,
    ),
  };

  // ---------------------------------------------------------------------------
  // Legend
  // ---------------------------------------------------------------------------

  /// What the legend lists — one entry per drawn part of a pie, radial chart or
  /// single stacked bar, or per series on a chart plotting two or more — or
  /// nothing when this chart gets no legend.
  ///
  /// A single series needs no key, a histogram draws the first series alone,
  /// and a heatmap carries a scale legend of its own.
  List<_LegendEntry> _legendEntries(ResolvedChartTheme theme, List<_PieSlice> slices, String unnamed) {
    if (!theme.showLegend) return const [];
    switch (spec.kind) {
      case USpecKind.pie || USpecKind.radial || USpecKind.singleStackedBar:
        return [
          for (final (i, slice) in slices.indexed) (label: slice.label, color: theme.seriesColor(i)),
        ];
      case USpecKind.histogram || USpecKind.heatmap:
        return const [];
      // Too few spokes draw no shape, which leaves the key nothing to explain.
      case USpecKind.radar when _categoryLabels().length < _kRadarMinSpokes:
        return const [];
      case USpecKind.line ||
          USpecKind.bar ||
          USpecKind.area ||
          USpecKind.scatter ||
          USpecKind.bubble ||
          USpecKind.horizontalBar ||
          USpecKind.radar:
        if (spec.series.length < 2) return const [];
        return [
          for (final (i, series) in spec.series.indexed)
            (label: series.name.trim().isEmpty ? unnamed : series.name, color: theme.seriesColor(i)),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // Line / area chart
  // ---------------------------------------------------------------------------

  Widget _buildLineChart(ResolvedChartTheme theme) {
    final filled = spec.kind == USpecKind.area;
    final labels = _categoryLabels();
    final (curved, stepped) = switch (spec.curve) {
      USpecCurve.linear => (false, false),
      USpecCurve.natural => (true, false),
      USpecCurve.step => (false, true),
    };
    final lineBarsData = spec.series.asMap().entries.map((e) {
      final color = theme.seriesColor(e.key);
      return LineChartBarData(
        // A natural line is sampled from a monotone cubic through its points
        // and drawn straight between the samples, so it never swings past a
        // peak or a trough, nor out of the plot.
        spots: curved ? monotoneCurveSpots(_toSpots(e.value, labels)) : _toSpots(e.value, labels),
        color: color,
        isStepLineChart: stepped,
        lineChartStepData: const LineChartStepData(stepDirection: LineChartStepData.stepDirectionMiddle),
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
        // A curved line carries samples between its points, which a touch
        // would report as values, so only straight and stepped lines show one.
        lineTouchData: LineTouchData(enabled: !curved),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bar chart
  // ---------------------------------------------------------------------------

  // Draws a [USpecKind.bar] chart, or with `horizontal` a
  // [USpecKind.horizontalBar] one: the same bars turned a quarter turn
  // clockwise, which puts the first category at the top and the values along
  // the bottom.
  Widget _buildBarChart(BuildContext context, ResolvedChartTheme theme, {required bool horizontal}) {
    final labels = _categoryLabels();
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measured in the style the labels are laid out in, which inherits what
        // the label style leaves unset.
        final style = DefaultTextStyle.of(context).style.merge(theme.axisLabelStyle);
        final gutter = horizontal ? _categoryGutter(labels, style, textScaler, constraints.maxWidth) : 0.0;
        // The length the category bands share, after the other axis's gutter.
        final axisLength = horizontal
            ? constraints.maxHeight - _kBottomAxisSize
            : constraints.maxWidth - _kLeftAxisSize;
        final band = axisLength / max(1, labels.length);
        // A category's bars keep their width while the band has room, and
        // narrow with it once it doesn't, so neighbors never overlap. A stack
        // takes at most `_kStackedBandShare` of the band. Grouped bars keep at
        // least the gap between their own bars from the next category's, or
        // the same share once the band is too thin for that.
        final stackWidth = max<double>(0, min(_barGroupWidth, band * _kStackedBandShare));
        final groupLimit = max(band - _kBarsSpace, band * _kStackedBandShare);
        final groupScale = max<double>(0, min(_barGroupWidth, groupLimit)) / _barGroupWidth;
        return BarChart(
          BarChartData(
            barGroups: [
              for (var xi = 0; xi < labels.length; xi++)
                switch (spec.barLayout) {
                  USpecBarLayout.grouped => _groupedBars(theme, labels, xi, scale: groupScale),
                  USpecBarLayout.stacked => _stackedBar(theme, labels, xi, width: stackWidth),
                },
            ],
            titlesData: horizontal ? _horizontalTitlesData(labels, theme, gutter) : _titlesData(labels, theme),
            gridData: _gridData(theme),
            borderData: FlBorderData(show: false),
            barTouchData: const BarTouchData(enabled: false),
            rotationQuarterTurns: horizontal ? 1 : 0,
          ),
        );
      },
    );
  }

  // One rod per series, side by side, their widths and gaps `scale` times
  // the usual ones.
  BarChartGroupData _groupedBars(ResolvedChartTheme theme, List<String> labels, int xi, {required double scale}) {
    final rods = <BarChartRodData>[];
    for (var si = 0; si < spec.series.length; si++) {
      // Omit the rod where a series has no point in this category. Falling
      // back to zero drew a bar for data that doesn't exist, which reads as a
      // real measurement of nothing rather than as absent.
      final point = _pointAt(spec.series[si], labels[xi], xi);
      if (point == null) continue;
      rods.add(BarChartRodData(toY: point.y, color: theme.seriesColor(si), width: _kBarWidth * scale));
    }
    return BarChartGroupData(x: xi, barRods: rods, barsSpace: _kBarsSpace * scale);
  }

  // One rod `width` wide for the whole category, its series' values laid end
  // to end: positives up from zero, negatives down from it, each side on its
  // own.
  BarChartGroupData _stackedBar(ResolvedChartTheme theme, List<String> labels, int xi, {required double width}) {
    var positive = 0.0;
    var negative = 0.0;
    final items = <BarChartRodStackItem>[];
    for (var si = 0; si < spec.series.length; si++) {
      final point = _pointAt(spec.series[si], labels[xi], xi);
      // A non-finite value would turn both sums, and so the whole bar, into
      // NaN or infinity.
      if (point == null || !point.y.isFinite) continue;
      final color = theme.seriesColor(si);
      if (point.y >= 0) {
        items.add(BarChartRodStackItem(positive, positive + point.y, color));
        positive += point.y;
      } else {
        items.add(BarChartRodStackItem(negative, negative + point.y, color));
        negative += point.y;
      }
    }
    // Finite values can still add up to infinity, which has no bar to draw.
    if (items.isEmpty || !positive.isFinite || !negative.isFinite) return BarChartGroupData(x: xi);
    // A stack with nothing above zero runs down from zero, so it grows from
    // zero rather than from its far end.
    final (fromY, toY) = positive > 0 ? (negative, positive) : (0.0, negative);
    return BarChartGroupData(
      x: xi,
      barRods: [
        BarChartRodData(
          fromY: fromY,
          toY: toY,
          // Fully covered by the stack items; only their colors show.
          color: Colors.transparent,
          width: width,
          // Square ends: `fl_chart` stretches a stack shorter than its rounded
          // ends, which can carry it across zero.
          borderRadius: .zero,
          rodStackItems: items,
        ),
      ],
    );
  }

  // How wide one category's grouped bars are, gaps included, when the band
  // has room for them. A stacked bar is as wide, so switching the layout
  // keeps each category's footprint.
  double get _barGroupWidth {
    final count = max(1, spec.series.length);
    return count * _kBarWidth + (count - 1) * _kBarsSpace;
  }

  // The width of a horizontal bar chart's category column: the widest label
  // at the ambient text scale, but at most `_kCategoryGutterMaxShare` of
  // `width`, plus room between the label and its bars.
  static double _categoryGutter(List<String> labels, TextStyle style, TextScaler textScaler, double width) {
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: .ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = max(widest, painter.width);
      painter.dispose();
    }
    final limit = width.isFinite ? width * _kCategoryGutterMaxShare : widest;
    return min(widest, limit) + _kCategoryGutterSpacing;
  }

  // The titles of a horizontal bar chart, before `fl_chart` turns them: the
  // bottom titles become the category column on the left, and the right
  // titles the value axis along the bottom.
  FlTitlesData _horizontalTitlesData(List<String> labels, ResolvedChartTheme theme, double gutter) {
    final labelStyle = theme.axisLabelStyle;
    return FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _kBottomAxisSize,
          getTitlesWidget: (value, meta) {
            // Round values only. The axis also labels its own ends, which side
            // by side run into the round label next to them when the data
            // doesn't end on one.
            final steps = value / meta.appliedInterval;
            if ((steps - steps.round()).abs() > 0.001) return const SizedBox.shrink();
            // `SideTitleWidget` turns each title back upright.
            return SideTitleWidget(
              meta: meta,
              space: _kAxisLabelGap,
              child: Text(meta.formattedValue, style: labelStyle),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: gutter,
          getTitlesWidget: (value, meta) {
            // Whole positions only, as in [_titlesData].
            final i = value.round();
            if (i < 0 || i >= labels.length || (value - i).abs() > 0.01) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              space: _kCategoryGutterSpacing,
              child: SizedBox(
                width: gutter - _kCategoryGutterSpacing,
                child: Text(labels[i], style: labelStyle, textAlign: .right, maxLines: 1, overflow: .ellipsis),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pie chart
  // ---------------------------------------------------------------------------

  // Draws `slices`, the first series' drawable points: a zero, negative or
  // non-finite value has no area, and handing one to `fl_chart` skews every
  // other slice's angle.
  //
  // The first slice starts at the top. A pie fills the plot, solid unless it
  // is a [USpec.donut], and a [USpecPieShape.semicircle] spreads the slices over the
  // top half of a circle.
  Widget _buildPieChart(ResolvedChartTheme theme, List<_PieSlice> slices, {required bool hasLegend}) {
    if (spec.pieShape == USpecPieShape.semicircle) return _buildSemicircle(theme, slices, hasLegend: hasLegend);
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = constraints.biggest.shortestSide / 2;
        final hole = _pieHole(radius, theme);
        return PieChart(
          PieChartData(
            sections: _pieSections(theme, slices, hasLegend: hasLegend, radius: radius - hole),
            sectionsSpace: _kSliceGap,
            centerSpaceRadius: hole,
            startDegreeOffset: _kPieStart,
          ),
        );
      },
    );
  }

  // A pie over the top half of a circle, from the left over the top to the
  // right, its flat side along the bottom of the plot.
  Widget _buildSemicircle(ResolvedChartTheme theme, List<_PieSlice> slices, {required bool hasLegend}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final radius = min(width / 2, height);
        final hole = _pieHole(radius, theme);
        final ring = radius - hole;
        final total = slices.fold<double>(0, (sum, s) => sum + s.value);
        final sections = [
          ..._pieSections(theme, slices, hasLegend: hasLegend, radius: ring),
          // The slices always fill a whole turn, so an invisible slice as big
          // as all the others together takes the bottom half.
          if (total.isFinite && total > 0)
            PieChartSectionData(value: total, color: Colors.transparent, showTitle: false, radius: ring),
        ];
        return Stack(
          // Not clipped: the bottom half is invisible anyway, and a label on a
          // slice beside the flat edge may hang below it.
          clipBehavior: .none,
          children: [
            Positioned(
              left: width / 2 - radius,
              top: height - radius,
              width: radius * 2,
              height: radius * 2,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: _kSliceGap,
                  centerSpaceRadius: hole,
                  startDegreeOffset: _kSemicircleStart,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // The hole in the middle of a pie of `radius`: none unless it is a donut.
  double _pieHole(double radius, ResolvedChartTheme theme) => spec.donut ? radius * theme.donutHoleRatio : 0;

  // The `slices` as `fl_chart` sections `radius` thick, each labeled with its
  // share — and its name too when there is no legend to carry it.
  List<PieChartSectionData> _pieSections(
    ResolvedChartTheme theme,
    List<_PieSlice> slices, {
    required bool hasLegend,
    required double radius,
  }) {
    final labelStyle = theme.pieLabelStyle;
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    return slices.indexed.map((e) {
      final (i, slice) = e;
      final color = theme.seriesColor(i);
      final percentage = _piePercentage(slice.value, total, theme);
      // The legend names the slices, so the slice itself carries only its
      // share. Without a legend the name has nowhere else to go.
      final title = hasLegend ? (percentage ?? '') : [slice.label, ?percentage].join('\n');
      return PieChartSectionData(
        value: slice.value,
        color: color,
        title: title,
        showTitle: title.isNotEmpty,
        radius: radius,
        // Mid-ring on a donut; on a solid pie, out where the slice is wide
        // enough for it rather than crowded toward the point.
        titlePositionPercentageOffset: spec.donut ? 0.5 : _kSolidPieLabelOffset,
        // The label was hardcoded white, which vanishes on any light slice —
        // and a host palette is free to contain one. Every slice is a different
        // fill, so the choice has to be made per slice; a host that puts a
        // color on `pieLabelStyle` still wins outright.
        titleStyle: _onPart(labelStyle, color),
      );
    }).toList();
  }

  // `style` for a label drawn on a slice or part filled with `fill`: as set
  // when it carries a color, otherwise in whichever of white and `black87`
  // reads better on `fill`.
  static TextStyle _onPart(TextStyle style, Color fill) {
    if (style.color != null) return style;
    return style.copyWith(color: _onSlice(fill));
  }

  /// [value]'s share of [total] as a rounded percentage such as `42%`, or null
  /// when percentages are off, the slice is under the theme's threshold, or the
  /// slices don't sum to a positive, finite total — finite values can still
  /// overflow to infinity when added up.
  static String? _piePercentage(double value, double total, ResolvedChartTheme theme) {
    if (!theme.showPiePercentages || !total.isFinite || total <= 0) return null;
    final share = value / total;
    if (!share.isFinite || share < theme.piePercentageThreshold) return null;
    return '${(share * 100).round()}%';
  }

  /// The readable color for a label drawn on top of [slice] — whichever of
  /// white and `black87` contrasts better against it.
  ///
  /// Not [ThemeData.estimateBrightnessForColor], which switches at a luminance
  /// of 0.34 rather than the 0.15 it names and so left white on mid blue,
  /// orange and red — all under the 4.5:1 the 11px label needs.
  static Color _onSlice(Color slice) =>
      _contrast(slice, Colors.white) >= _contrast(slice, Colors.black87) ? Colors.white : Colors.black87;

  /// The WCAG contrast ratio of [label] drawn over [slice], from 1 to 21.
  ///
  /// [label] is composited on first — `black87` is 87% opaque, not pure black.
  static double _contrast(Color slice, Color label) {
    final slices = slice.computeLuminance();
    final labels = Color.alphaBlend(label, slice).computeLuminance();
    final (lighter, darker) = slices > labels ? (slices, labels) : (labels, slices);
    return (lighter + 0.05) / (darker + 0.05);
  }

  // ---------------------------------------------------------------------------
  // Radar chart
  // ---------------------------------------------------------------------------

  // Draws one closed shape per series over a spoke per category, measured from
  // a center of zero; nothing with fewer than three categories, which make no
  // shape.
  Widget _buildRadarChart(ResolvedChartTheme theme) {
    final labels = _categoryLabels();
    if (labels.length < _kRadarMinSpokes) return const SizedBox.shrink();

    final grid = BorderSide(color: theme.gridLineColor);
    final dataSets = [
      for (final (si, series) in spec.series.indexed)
        RadarDataSet(
          dataEntries: [for (final (xi, label) in labels.indexed) RadarEntry(value: _radarValue(series, label, xi))],
          fillColor: theme.seriesColor(si).withValues(alpha: _kRadarFillOpacity),
          borderColor: theme.seriesColor(si),
          borderWidth: _kRadarBorderWidth,
          entryRadius: 0,
        ),
      // The scale runs from the smallest value plotted to the largest. This
      // invisible shape puts a zero on every spoke, so the center is always
      // zero and a shape's size compares honestly with the others.
      RadarDataSet(
        dataEntries: [for (final _ in labels) const RadarEntry(value: 0)],
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        borderWidth: 0,
        entryRadius: 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final labelStyle = DefaultTextStyle.of(context).style.merge(theme.axisLabelStyle);
        final maxLabelWidth = constraints.maxWidth / 3;
        // Cut once per layout: `fl_chart` asks for each title on every paint.
        final titles = [for (final label in labels) _truncate(label, labelStyle, textScaler, maxLabelWidth)];
        return RadarChart(
          RadarChartData(
            dataSets: dataSets,
            radarShape: .polygon,
            radarBackgroundColor: Colors.transparent,
            radarBorderData: grid,
            gridBorderData: grid,
            tickBorderData: grid,
            tickCount: _kRadarRings,
            // The ring values are painted with no way to turn them off, as
            // bare numbers floating beside one spoke; a reader gets the range
            // from the summary instead. Sized to nothing, they take no room
            // either.
            ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
            isMinValueAtCenter: true,
            titleTextStyle: theme.axisLabelStyle,
            titlePositionPercentageOffset: _kRadarLabelOffset,
            getTitle: (index, angle) => RadarChartTitle(text: titles[index]),
            radarTouchData: RadarTouchData(enabled: false),
          ),
        );
      },
    );
  }

  // Where `series` sits on the spoke for `label`: its value, or the center when
  // it has none there, a negative one, or one that isn't finite. `fl_chart`
  // needs a value on every spoke, so a missing one can't be skipped.
  double _radarValue(USeries series, String label, int index) {
    final y = _pointAt(series, label, index)?.y;
    if (y == null || !y.isFinite || y < 0) return 0;
    return y;
  }

  // `text` cut to fit `maxWidth` at `textScaler`, ending in "…", and cut
  // between characters as a reader sees them so an emoji is never split.
  static String _truncate(String text, TextStyle style, TextScaler textScaler, double maxWidth) {
    if (!maxWidth.isFinite) return text;
    double widthOf(String candidate) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: .ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    if (widthOf(text) <= maxWidth) return text;
    var kept = text.characters;
    while (kept.isNotEmpty && widthOf('$kept…') > maxWidth) {
      kept = kept.skipLast(1);
    }
    return '$kept…';
  }

  // ---------------------------------------------------------------------------
  // Radial chart and single stacked bar
  // ---------------------------------------------------------------------------

  // Draws a ring per drawn value of the first series — `slices` — the first
  // outermost, each an arc whose length is its value against the largest.
  Widget _buildRadialChart(ResolvedChartTheme theme, List<_PieSlice> slices) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final largest = slices.map((s) => s.value).reduce(max);
    return SizedBox.expand(
      child: CustomPaint(
        painter: _RadialPainter(
          rings: [
            for (final (i, slice) in slices.indexed) (share: slice.value / largest, color: theme.seriesColor(i)),
          ],
          trackColor: theme.radialTrackColor,
        ),
      ),
    );
  }

  // Draws one full-width bar split into `slices`, each part as wide as its
  // share, labeled by the same rules as a pie's slices.
  Widget _buildSingleStackedBar(ResolvedChartTheme theme, List<_PieSlice> slices, {required bool hasLegend}) {
    if (slices.isEmpty) return const SizedBox.shrink();
    // Shares are taken of the parts measured against the largest, so values
    // too large to add up as they are still split the bar.
    final largest = slices.map((s) => s.value).reduce(max);
    final total = slices.fold<double>(0, (sum, s) => sum + s.value / largest);
    return Builder(
      builder: (context) => SizedBox.expand(
        child: CustomPaint(
          painter: _SingleBarPainter(
            parts: [
              for (final (i, slice) in slices.indexed)
                _singleBarPart(
                  theme,
                  label: slice.label,
                  value: slice.value / largest,
                  total: total,
                  color: theme.seriesColor(i),
                  // The labels are painted directly, so nothing else fills in
                  // what the label style leaves unset.
                  baseStyle: DefaultTextStyle.of(context).style,
                  hasLegend: hasLegend,
                ),
            ],
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }

  // One part of a single stacked bar: its share, fill, and label. The legend
  // names the parts, so a part carries only its share; without a legend, its
  // name as well.
  _SingleBarPart _singleBarPart(
    ResolvedChartTheme theme, {
    required String label,
    required double value,
    required double total,
    required Color color,
    required TextStyle baseStyle,
    required bool hasLegend,
  }) {
    final percentage = _piePercentage(value, total, theme);
    final text = hasLegend ? (percentage ?? '') : [label, ?percentage].join(' ');
    final style = baseStyle.merge(_onPart(theme.pieLabelStyle, color));
    return (share: value / total, color: color, label: text, style: style);
  }

  // ---------------------------------------------------------------------------
  // Scatter / bubble chart
  // ---------------------------------------------------------------------------

  Widget _buildScatterChart(ResolvedChartTheme theme, {required bool bubble}) {
    // Categorical x values ('Jan', 'Feb') have no numeric position, so they go
    // on the shared category axis — shared being the point, since indexing per
    // series pushes each one right of the last.
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
  /// Normalized across the chart first, since sizes arrive in the data's own
  /// units — a population or a revenue figure as often as pixels. Clamping raw
  /// values instead flattens every bubble past the maximum to one radius.
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
        barRods: [BarChartRodData(toY: e.value.count.toDouble(), color: theme.seriesColor(0), width: _kBarWidth)],
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
  /// and max.
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

  /// The series' points on the x axis. With categories to place them by, a
  /// category the series has no point in, such as one whose value was not a
  /// finite number, breaks the line rather than joining across it.
  List<FlSpot> _toSpots(USeries series, List<String> labels) {
    if (!_hasCategoryKeys || labels.isEmpty) {
      return series.points.asMap().entries.map((e) => FlSpot(_categoryX(e.value, e.key, labels), e.value.y)).toList();
    }
    final byLabel = {for (final point in series.points) point.x: point.y};
    final first = labels.indexWhere(byLabel.containsKey);
    final last = labels.lastIndexWhere(byLabel.containsKey);
    if (first < 0) return const [];
    return [
      for (var i = first; i <= last; i++)
        if (byLabel[labels[i]] case final y?) FlSpot(i.toDouble(), y) else FlSpot.nullSpot,
    ];
  }

  /// Where [point] — the [index]-th in its series — sits on the shared category
  /// axis [labels], falling back to [index] when its label isn't on the axis or
  /// labels aren't usable as keys.
  double _categoryX(UPoint point, int index, List<String> labels) {
    if (!_hasCategoryKeys) return index.toDouble();
    final at = labels.indexOf(point.x);
    return (at >= 0 ? at : index).toDouble();
  }

  /// Whether a point can be located on the x axis by its [UPoint.x] label —
  /// true when no series repeats one. A histogram's raw samples all share an
  /// empty `x`, so those fall back to plotting by position.
  bool get _hasCategoryKeys => spec.series.every((s) => s.points.map((p) => p.x).toSet().length == s.points.length);

  /// The x-axis categories, in axis order, merged across every series with the
  /// longest one first.
  ///
  /// Points are placed by *label*, not by position within their own list: a
  /// Chart.js `null` gap parses to a shorter series, so positional indexing
  /// draws everything after the gap one category too far left.
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
          reservedSize: _kLeftAxisSize,
          getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: labelStyle),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _kBottomAxisSize,
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

/// One drawable pie slice, as [ChartSemantics.drawnPieSlices] returns it.
typedef _PieSlice = ({String label, double value});

// The padding above and below every plot, and beside the ones with no axis.
const _kPlotVerticalPadding = 8.0;
const _kPlotHorizontalPadding = 16.0;

// The gutters `fl_chart` reserves for the value labels on the left and the
// category labels along the bottom, and the gap between a label and its axis.
const _kLeftAxisSize = 40.0;
const _kBottomAxisSize = 28.0;
const _kAxisLabelGap = 4.0;

// The thickness of one bar.
const _kBarWidth = 10.0;

// The gap between a category's bars when they are grouped.
const _kBarsSpace = 4.0;

// The most of its category's band a stacked bar takes, leaving the rest as
// space between neighbors.
const _kStackedBandShare = 0.6;

// The gap between two pie slices.
const _kSliceGap = 2.0;

// How far out a solid pie's labels sit, as a share of its radius.
const _kSolidPieLabelOffset = 0.65;

// Where a pie's first slice starts: at the top. `fl_chart` counts degrees
// clockwise from the right.
const _kPieStart = -90.0;

// Where a semicircle's first slice starts: at the left, so the slices run over
// the top.
const _kSemicircleStart = 180.0;

// A horizontal bar chart's height when the theme sets none: a row per
// category, at least `_kHorizontalBarRowHeight` tall and otherwise as tall as
// the category's bars plus `_kHorizontalBarRowPadding`, then
// `_kHorizontalBarAxisHeight` for the value axis — kept between a height that
// still reads as a chart and one that would outgrow any screen.
const _kHorizontalBarRowHeight = 34.0;
const _kHorizontalBarRowPadding = 12.0;
const _kHorizontalBarAxisHeight = 40.0;
const _kHorizontalBarMinHeight = 160.0;
const _kHorizontalBarMaxHeight = 1000.0;

// The largest share of the width a horizontal bar chart's category labels
// take, so long names leave the bars room.
const _kCategoryGutterMaxShare = 0.4;

// The gap between a category label and its bars.
const _kCategoryGutterSpacing = 8.0;

// How many straight pieces draw each segment of a natural line.
const _kCurveSamplesPerSegment = 16;

// The fewest spokes a radar can draw a shape with.
const _kRadarMinSpokes = 3;

// The radar's grid rings, between the center and the outer edge.
const _kRadarRings = 4;

// The opacity of a radar shape's fill, low enough that overlapping series stay
// readable.
const _kRadarFillOpacity = 0.2;

// The width of a radar shape's outline.
const _kRadarBorderWidth = 2.0;

// How far past the outer ring a radar's spoke labels sit, as a share of the
// radius.
const _kRadarLabelOffset = 0.18;

// The thickness of a single stacked bar: tall enough to hold its labels at the
// default text size.
const _kSingleBarThickness = 24.0;

/// One row of a [_ChartLegend]: what it names, and the color it is drawn in.
typedef _LegendEntry = ({String label, Color color});

/// The most entries a legend lists before the last one becomes "+N more".
///
/// Past this a legend outgrows the chart it explains, and the palette has
/// cycled anyway, so later swatches repeat earlier ones.
const _kMaxLegendEntries = 10;

/// A wrapping row of color swatches, each followed by the series or slice it
/// stands for. Lists at most [_kMaxLegendEntries].
class _ChartLegend extends StatelessWidget {
  const _ChartLegend({super.key, required this.entries, required this.textStyle});

  final List<_LegendEntry> entries;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    // Sized off the text so a larger text scale doesn't leave a speck of color
    // beside a big label.
    final swatch = MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 11) * 0.9;
    final overflows = entries.length > _kMaxLegendEntries;
    final shown = overflows ? entries.take(_kMaxLegendEntries - 1) : entries;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final entry in shown)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: swatch,
                height: swatch,
                decoration: BoxDecoration(color: entry.color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(entry.label, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        if (overflows)
          Text(
            AITranslations.of(context).chartLegendMore(entries.length - (_kMaxLegendEntries - 1)),
            style: textStyle,
          ),
      ],
    );
  }
}

// One ring of a radial chart: its value as a share of the largest, and its
// color.
typedef _RadialRing = ({double share, Color color});

// The rings of a radial chart, outermost first, in a square centered in the
// space given.
class _RadialPainter extends CustomPainter {
  const _RadialPainter({required this.rings, required this.trackColor});

  final List<_RadialRing> rings;
  final Color trackColor;

  // The largest ring pitch, center line to center line.
  static const _maxPitch = 16.0;

  // The share of the pitch a ring's stroke takes; the rest is the gap to the
  // next ring.
  static const _strokeShare = 11 / 16;

  // The radius kept clear in the middle, so even many rings leave a hole.
  static const _hole = 12.0;

  // The turn the largest value's arc sweeps: three quarters, so every ring has
  // room to show where it ends against its track.
  static const _fullSweep = 1.5 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    // Rings thin out as more are added, so they all fit between the edge and
    // the hole rather than any being left off.
    final pitch = min(_maxPitch, (radius - _hole) / rings.length);
    final stroke = pitch * _strokeShare;
    // A plot too small to keep the hole clear has no room for any ring.
    if (stroke <= 0) return;

    for (final (i, ring) in rings.indexed) {
      final ringRadius = radius - i * pitch - stroke / 2;
      final paint = Paint()
        ..style = .stroke
        ..strokeWidth = stroke;
      canvas
        ..drawCircle(center, ringRadius, paint..color = trackColor)
        ..drawArc(
          Rect.fromCircle(center: center, radius: ringRadius),
          -pi / 2,
          ring.share * _fullSweep,
          false,
          paint
            ..color = ring.color
            ..strokeCap = .round,
        );
    }
  }

  @override
  bool shouldRepaint(_RadialPainter oldDelegate) {
    if (oldDelegate.trackColor != trackColor) return true;
    return !listEquals(oldDelegate.rings, rings);
  }
}

// One part of a single stacked bar: its share of the total, its fill, and the
// label it carries if the label fits.
typedef _SingleBarPart = ({double share, Color color, String label, TextStyle style});

// A single stacked bar: the parts side by side, left to right, in a bar with
// fully rounded ends.
class _SingleBarPainter extends CustomPainter {
  const _SingleBarPainter({required this.parts, required this.textScaler, required this.textDirection});

  final List<_SingleBarPart> parts;
  final TextScaler textScaler;
  final TextDirection textDirection;

  // The gap between two parts.
  static const _gap = 2.0;

  // The room a label keeps from the ends of its part.
  static const _labelPadding = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Many parts on a narrow bar would leave the gaps no room for the parts,
    // so the gaps take at most half the bar.
    final gap = parts.length > 1 ? min(_gap, size.width / 2 / (parts.length - 1)) : 0.0;
    final available = size.width - gap * (parts.length - 1);
    final bar = Offset.zero & size;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(bar, Radius.circular(size.height / 2)));
    // The parts run from the start, as the legend's entries do: from the
    // right in a right-to-left layout.
    final rtl = textDirection == TextDirection.rtl;
    var start = 0.0;
    for (final part in parts) {
      final width = available * part.share;
      final left = rtl ? size.width - start - width : start;
      final rect = Rect.fromLTWH(left, 0, width, size.height);
      canvas.drawRect(rect, Paint()..color = part.color);
      _paintLabel(canvas, part, rect);
      start += width + gap;
    }
    canvas.restore();
  }

  // Paints `part`'s label centered on `rect`, or nothing when it doesn't fit.
  void _paintLabel(Canvas canvas, _SingleBarPart part, Rect rect) {
    if (part.label.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: part.label, style: part.style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    if (painter.width <= rect.width - _labelPadding * 2 && painter.height <= rect.height) {
      painter.paint(canvas, rect.center - Offset(painter.width / 2, painter.height / 2));
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_SingleBarPainter oldDelegate) {
    if (oldDelegate.textScaler != textScaler) return true;
    if (oldDelegate.textDirection != textDirection) return true;
    return !listEquals(oldDelegate.parts, parts);
  }
}

// Reports a fixed intrinsic size for its child instead of asking it: no width,
// and `height`. A child laid out with a `LayoutBuilder` throws when asked.
class _NoIntrinsics extends SingleChildRenderObjectWidget {
  const _NoIntrinsics({this.height = 0, required super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoIntrinsics(height);

  @override
  void updateRenderObject(BuildContext context, _RenderNoIntrinsics renderObject) => renderObject.height = height;
}

class _RenderNoIntrinsics extends RenderProxyBox {
  _RenderNoIntrinsics(this._height);

  double get height => _height;
  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}

/// A single bucket produced by [ChartView._makeBins].
class _HistogramBin {
  const _HistogramBin({required this.label, required this.count});

  final String label;
  final int count;
}

/// Samples a monotone cubic (Fritsch–Carlson, with Fritsch–Butland slopes)
/// through each unbroken run of [spots], for drawing as straight pieces.
///
/// Between two points the curve stays within their values, so it never
/// overshoots a peak or a trough, and a rise and a fall of the same shape draw
/// alike. A run whose x values don't strictly increase is returned as it is.
@visibleForTesting
List<FlSpot> monotoneCurveSpots(List<FlSpot> spots) {
  final out = <FlSpot>[];
  var run = <FlSpot>[];
  void flush() {
    out.addAll(_monotoneRun(run));
    run = <FlSpot>[];
  }

  for (final spot in spots) {
    if (spot.isNull()) {
      flush();
      out.add(spot);
    } else {
      run.add(spot);
    }
  }
  flush();
  return out;
}

List<FlSpot> _monotoneRun(List<FlSpot> p) {
  final n = p.length;
  if (n < 3) return p;
  final h = [for (var k = 0; k < n - 1; k++) p[k + 1].x - p[k].x];
  if (h.any((step) => !(step > 0))) return p;
  final d = [for (var k = 0; k < n - 1; k++) (p[k + 1].y - p[k].y) / h[k]];
  final m = List<double>.filled(n, 0);
  m[0] = d[0];
  m[n - 1] = d[n - 2];
  for (var k = 1; k < n - 1; k++) {
    final (a, b) = (d[k - 1], d[k]);
    if (a * b <= 0) continue;
    // Weighted harmonic mean: never more than three times either slope, which
    // keeps the segment monotone.
    final (h0, h1) = (h[k - 1], h[k]);
    m[k] = 3 * (h0 + h1) / ((2 * h1 + h0) / a + (h1 + 2 * h0) / b);
  }
  // An end slope pointing against its segment's would swing past the end.
  if (m[0] * d[0] <= 0) m[0] = 0;
  if (m[n - 1] * d[n - 2] <= 0) m[n - 1] = 0;
  final out = <FlSpot>[p.first];
  for (var k = 0; k < n - 1; k++) {
    for (var i = 1; i <= _kCurveSamplesPerSegment; i++) {
      final t = i / _kCurveSamplesPerSegment;
      final t2 = t * t;
      final t3 = t2 * t;
      final y =
          (2 * t3 - 3 * t2 + 1) * p[k].y +
          (t3 - 2 * t2 + t) * h[k] * m[k] +
          (-2 * t3 + 3 * t2) * p[k + 1].y +
          (t3 - t2) * h[k] * m[k + 1];
      out.add(i == _kCurveSamplesPerSegment ? p[k + 1] : FlSpot(p[k].x + t * h[k], y));
    }
  }
  return out;
}
