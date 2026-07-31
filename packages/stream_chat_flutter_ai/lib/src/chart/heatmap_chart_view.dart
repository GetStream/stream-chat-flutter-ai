import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

/// The width of the row-label gutter, matching the `leftTitles` reserved size
/// used by the `fl_chart`-backed kinds so a heatmap lines up with them.
const _kRowLabelWidth = 40.0;

/// The height of the column-label strip, matching the `bottomTitles` reserved
/// size used by the `fl_chart`-backed kinds.
const _kColumnLabelHeight = 28.0;

/// The height of the gradient scale bar shown below the grid.
const _kLegendBarHeight = 10.0;

/// The label style shared by the row, column, and legend labels — matching the
/// axis label style used by the `fl_chart`-backed kinds.
const _kLabelStyle = TextStyle(fontSize: 10);

/// A sequential color scale for cell intensity: three stops the cell value is
/// interpolated between.
typedef _Scale = ({Color low, Color mid, Color high});

/// The scale used in a light theme, anchored on the chart palette's first series
/// color. Higher values are darker and more saturated.
const _kLightScale = (low: Color(0xFFEAF2FB), mid: Color(0xFF4A90D9), high: Color(0xFF1B4F8A));

/// The scale used in a dark theme.
///
/// The ramp runs the other way — higher values are *lighter* — because a
/// light-to-dark ramp on a dark surface makes the highest cells recede into the
/// background, inverting the intensity the color is supposed to encode.
const _kDarkScale = (low: Color(0xFF12283F), mid: Color(0xFF3B7CB8), high: Color(0xFFC3DDF6));

_Scale _scaleFor(Brightness brightness) => brightness == Brightness.dark ? _kDarkScale : _kLightScale;

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
  const HeatmapChartView({super.key, required this.spec});

  /// The chart data to display. Its [USpec.kind] is expected to be
  /// [USpecKind.heatmap].
  final USpec spec;

  @override
  Widget build(BuildContext context) {
    final grid = _HeatmapGrid.fromSpec(spec);
    if (grid == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scale = _scaleFor(theme.brightness);
    // Theme-derived: the cell border used to be a hardcoded translucent black,
    // invisible against a dark surface.
    final borderColor = theme.colorScheme.outlineVariant;
    final labelStyle = _kLabelStyle.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
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
                                    color: _cellColor(row.values[column], grid, scale),
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
            scale: scale,
            borderColor: borderColor,
            labelStyle: labelStyle,
          ),
        ),
      ],
    );
  }

  /// Maps a cell's value onto the sequential scale, or returns `null` for a
  /// cell the series has no value for (leaving it unfilled).
  Color? _cellColor(double? value, _HeatmapGrid grid, _Scale scale) {
    if (value == null) return null;
    final t = grid.max > grid.min ? (value - grid.min) / (grid.max - grid.min) : 1.0;
    return t <= 0.5 ? Color.lerp(scale.low, scale.mid, t * 2) : Color.lerp(scale.mid, scale.high, (t - 0.5) * 2);
  }
}

/// The gradient scale bar shown below the grid, labelled with the value range
/// the colors span.
class _ScaleLegend extends StatelessWidget {
  const _ScaleLegend({
    required this.min,
    required this.max,
    required this.scale,
    required this.borderColor,
    required this.labelStyle,
  });

  final double min;
  final double max;
  final _Scale scale;
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
            gradient: LinearGradient(colors: [scale.low, scale.mid, scale.high]),
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
  static _HeatmapGrid? fromSpec(USpec spec) {
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
      rows.add(_HeatmapRow(label: series.name, values: values));
    }
    if (columns.isEmpty) return null;

    return _HeatmapGrid(columns: columns.toList(), rows: rows, min: min, max: max);
  }
}
