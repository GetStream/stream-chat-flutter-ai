import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_semantics.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/resolved_chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

/// The width of the row-label gutter, matching the `leftTitles` reserved size
/// used by the `fl_chart`-backed kinds so a heatmap lines up with them.
///
/// Not themeable for that reason: it and the `fl_chart` reserved size have to
/// move together or a heatmap stops lining up with the bar chart above it.
const _kRowLabelWidth = 40.0;

/// The height of the column-label strip, matching the `bottomTitles` reserved
/// size used by the `fl_chart`-backed kinds.
const _kColumnLabelHeight = 28.0;

/// The height of the gradient scale bar shown below the grid.
const _kLegendBarHeight = 10.0;

/// Renders a [USpecKind.heatmap] [USpec] as a grid of color-scaled cells.
///
/// `fl_chart` has no heatmap widget, so the grid is drawn with plain Material
/// widgets. The layout mirrors Swift's `HeatmapChart`: one row per [USeries]
/// (labelled with [USeries.name]), one column per distinct [UPoint.x], and a
/// cell color derived from [UPoint.z] (falling back to [UPoint.y]).
///
/// A gradient scale bar with the minimum and maximum cell values is shown
/// below the grid, since cell color is the only encoding of the value.
class HeatmapChartView extends StatelessWidget {
  /// Creates a [HeatmapChartView].
  const HeatmapChartView({super.key, required this.spec, this.theme, this.semanticsLabel});

  /// The chart data to display. Its [USpec.kind] is expected to be
  /// [USpecKind.heatmap].
  final USpec spec;

  /// Overrides the ambient chart theme for this grid alone.
  ///
  /// Layered over the nearest [ChartTheme] and over the [AITheme] registered on
  /// the ambient [ThemeData]; see [ChartThemeData].
  final ChartThemeData? theme;

  /// See [ChartView.semanticsLabel].
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final chartTheme = ResolvedChartTheme.resolve(context, override: theme);
    final translations = AITranslations.of(context);
    final unnamed = translations.unnamedChartSeries;
    final grid = _HeatmapGrid.fromSpec(spec, unnamedSeries: unnamed);
    final labelStyle = chartTheme.axisLabelStyle;
    final borderColor = chartTheme.gridLineColor;

    final Widget content;
    if (grid == null) {
      content = const SizedBox.shrink();
    } else {
      content = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: _kRowLabelWidth,
                  child: Column(
                    children: [
                      for (final row in grid.rows)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                row.label,
                                style: labelStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      for (final row in grid.rows)
                        Expanded(
                          child: Row(
                            children: [
                              for (final column in grid.columns)
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(0.5),
                                    decoration: BoxDecoration(
                                      color: _cellColor(row.values[column], grid, chartTheme),
                                      border: Border.all(color: borderColor),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _kColumnLabelHeight,
            child: Row(
              children: [
                const SizedBox(width: _kRowLabelWidth),
                Expanded(
                  child: Row(
                    children: [
                      for (final column in grid.columns)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              column,
                              style: labelStyle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: _kRowLabelWidth),
            child: _ScaleLegend(
              min: grid.min,
              max: grid.max,
              theme: chartTheme,
              borderColor: borderColor,
              labelStyle: labelStyle,
            ),
          ),
        ],
      );
    }

    final label =
        semanticsLabel ?? translations.chartSemanticsLabel(ChartSemantics.fromSpec(spec, unnamedSeries: unnamed));
    if (label.isEmpty) return content;
    // Excluding the subtree is deliberate — see [ChartView.semanticsLabel].
    // The row, column and legend labels are real Text widgets, and a reader
    // walking them one by one gets a list of bare numbers with nothing saying
    // which axis they belong to.
    return Semantics(container: true, excludeSemantics: true, label: label, child: content);
  }

  /// Maps a cell's value onto the sequential scale, or returns `null` for a
  /// cell the series has no value for (leaving it unfilled).
  Color? _cellColor(double? value, _HeatmapGrid grid, ResolvedChartTheme theme) {
    if (value == null) return null;
    final t = grid.max > grid.min ? (value - grid.min) / (grid.max - grid.min) : 1.0;
    return t <= 0.5
        ? Color.lerp(theme.heatmapLowColor, theme.heatmapMidColor, t * 2)
        : Color.lerp(theme.heatmapMidColor, theme.heatmapHighColor, (t - 0.5) * 2);
  }
}

/// The gradient scale bar shown below the grid, labelled with the value range
/// the colors span.
class _ScaleLegend extends StatelessWidget {
  const _ScaleLegend({
    required this.min,
    required this.max,
    required this.theme,
    required this.borderColor,
    required this.labelStyle,
  });

  final double min;
  final double max;
  final ResolvedChartTheme theme;
  final Color borderColor;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _kLegendBarHeight,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            gradient: LinearGradient(
              colors: [theme.heatmapLowColor, theme.heatmapMidColor, theme.heatmapHighColor],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(min.toStringAsFixed(1), style: labelStyle),
              Text(max.toStringAsFixed(1), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single heatmap row — one [USeries] keyed by column label.
class _HeatmapRow {
  const _HeatmapRow({required this.label, required this.values});

  final String label;
  final Map<String, double> values;
}

/// The grid derived from a [USpec], plus the value range its colors span.
class _HeatmapGrid {
  const _HeatmapGrid({
    required this.columns,
    required this.rows,
    required this.min,
    required this.max,
  });

  final List<String> columns;
  final List<_HeatmapRow> rows;
  final double min;
  final double max;

  /// Builds a grid from [spec], or returns `null` when there is nothing to
  /// draw (no series, or no series holding any point).
  ///
  /// Columns are the distinct [UPoint.x] values across *all* series, in first
  /// seen order — rows can be ragged (the Plotly adapter drops cells whose `z`
  /// isn't numeric), so a row is keyed by column label rather than by index.
  ///
  /// [unnamedSeries] labels a series the data didn't name; the parser leaves
  /// those empty rather than inventing an English word for them.
  static _HeatmapGrid? fromSpec(USpec spec, {required String unnamedSeries}) {
    // A LinkedHashSet keeps first-seen order while making the membership check
    // O(1) — `List.contains` made building the column list quadratic in the
    // number of cells.
    final columns = <String>{};
    final rows = <_HeatmapRow>[];
    var min = double.infinity;
    var max = double.negativeInfinity;

    for (final series in spec.series) {
      final values = <String, double>{};
      for (final point in series.points) {
        columns.add(point.x);
        final value = point.z ?? point.y;
        values[point.x] = value;
        if (value < min) min = value;
        if (value > max) max = value;
      }
      final label = series.name.trim().isEmpty ? unnamedSeries : series.name;
      rows.add(_HeatmapRow(label: label, values: values));
    }
    if (columns.isEmpty) return null;

    return _HeatmapGrid(columns: columns.toList(), rows: rows, min: min, max: max);
  }
}
