import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';

/// Builds a `BarChart`: vertical bars, grouped or, with `variant: "stacked"`,
/// stacked.
///
/// Internal to the package.
@internal
Widget buildOpenUIBarChart(BuildContext context, OpenUIComponentScope scope) {
  return _cartesian(context, scope, USpecKind.bar);
}

/// Builds a `HorizontalBarChart`: horizontal bars, grouped or stacked.
///
/// Internal to the package.
@internal
Widget buildOpenUIHorizontalBarChart(BuildContext context, OpenUIComponentScope scope) {
  return _cartesian(context, scope, USpecKind.horizontalBar);
}

/// Builds a `LineChart`: a line for each series, `linear`, `natural` or
/// `step`.
///
/// Internal to the package.
@internal
Widget buildOpenUILineChart(BuildContext context, OpenUIComponentScope scope) {
  return _cartesian(context, scope, USpecKind.line);
}

/// Builds an `AreaChart`: a `LineChart` filled down to the axis.
///
/// Internal to the package.
@internal
Widget buildOpenUIAreaChart(BuildContext context, OpenUIComponentScope scope) {
  return _cartesian(context, scope, USpecKind.area);
}

/// Builds a `RadarChart`: a polygon for each series over one spoke for each
/// label.
///
/// Internal to the package.
@internal
Widget buildOpenUIRadarChart(BuildContext context, OpenUIComponentScope scope) {
  return _cartesian(context, scope, USpecKind.radar);
}

/// Builds a `PieChart`: a slice for each label, a ring with `variant:
/// "donut"`, and a half with `appearance: "semiCircular"`.
///
/// Internal to the package.
@internal
Widget buildOpenUIPieChart(BuildContext context, OpenUIComponentScope scope) {
  return _slices(context, scope, USpecKind.pie);
}

/// Builds a `RadialChart`: a ring for each label.
///
/// Internal to the package.
@internal
Widget buildOpenUIRadialChart(BuildContext context, OpenUIComponentScope scope) {
  return _slices(context, scope, USpecKind.radial);
}

/// Builds a `SingleStackedBarChart`: one bar split into a part for each
/// label.
///
/// Internal to the package.
@internal
Widget buildOpenUISingleStackedBarChart(BuildContext context, OpenUIComponentScope scope) {
  return _slices(context, scope, USpecKind.singleStackedBar);
}

/// Builds a `ScatterChart`: a dot for each point of each dataset, sized by the
/// point's `z` when any has one.
///
/// Internal to the package.
@internal
Widget buildOpenUIScatterChart(BuildContext context, OpenUIComponentScope scope) {
  final series = <USeries>[];
  var hasSize = false;
  for (final dataset in _items(scope.prop('datasets'))) {
    final props = _propsOf(dataset);
    if (props == null) continue;
    final points = <UPoint>[];
    for (final item in _items(props['points'])) {
      final point = _propsOf(item);
      if (point == null) continue;
      final (x, y) = (_plottable(point['x']), _plottable(point['y']));
      if (x == null || y == null) continue;
      final z = JS.isNullish(point['z']) ? null : _plottable(point['z']);
      hasSize = hasSize || z != null;
      points.add(UPoint(x: _number(x), y: y, size: z));
    }
    if (points.isNotEmpty) series.add(USeries(name: JS.toStringOrEmpty(props['name']), points: points));
  }
  return _chart(
    context,
    USpec(
      kind: hasSize ? USpecKind.bubble : USpecKind.scatter,
      series: series,
      xLabel: scope.string('xLabel'),
      yLabel: scope.string('yLabel'),
    ),
  );
}

// A chart of [kind] over `labels` and `series`: categories along its axis,
// one line, bar group or polygon for each series.
Widget _cartesian(BuildContext context, OpenUIComponentScope scope, USpecKind kind) {
  final variant = scope.string('variant');
  final spec = USpec(
    kind: kind,
    series: _seriesOf(scope.prop('labels'), scope.prop('series')),
    xLabel: scope.string('xLabel'),
    yLabel: scope.string('yLabel'),
    barLayout: variant == 'stacked' ? USpecBarLayout.stacked : USpecBarLayout.grouped,
    curve: switch (variant) {
      'natural' => USpecCurve.natural,
      'step' => USpecCurve.step,
      _ => USpecCurve.linear,
    },
  );
  return _chart(context, spec, height: scope.number('height'));
}

// A chart of [kind] over `labels` and `values`: a part of the whole for each
// label.
Widget _slices(BuildContext context, OpenUIComponentScope scope, USpecKind kind) {
  final points = _slicePoints(scope.prop('labels'), scope.prop('values'));
  final spec = USpec(
    kind: kind,
    series: points.isEmpty ? const [] : [USeries(name: '', points: points)],
    donut: scope.string('variant') == 'donut',
    pieShape: scope.string('appearance') == 'semiCircular' ? USpecPieShape.semicircle : USpecPieShape.full,
  );
  return _chart(context, spec);
}

// The plot heights a chart accepts, as on Android.
const _minHeight = 60.0;
const _maxHeight = 1000.0;

// [spec] drawn with the OpenUI theme's chart palette, or nothing when it has
// no data to draw.
Widget _chart(BuildContext context, USpec spec, {double? height}) {
  if (!_hasShape(spec)) return const SizedBox.shrink();
  return ChartView(
    spec: spec,
    theme: ChartThemeData(
      seriesColors: OpenUITheme.of(context).chartPalette,
      height: height != null && height.isFinite && height > 0 ? height.clamp(_minHeight, _maxHeight) : null,
    ),
  );
}

// Whether [spec] has anything to draw: a series, and for the parts of a whole
// a value above zero, and for a radar at least three spokes, as on iOS and
// Android, which draw nothing otherwise.
bool _hasShape(USpec spec) {
  if (spec.series.isEmpty) return false;
  final points = spec.series.expand((series) => series.points);
  return switch (spec.kind) {
    USpecKind.pie || USpecKind.radial || USpecKind.singleStackedBar => points.any((point) => point.y > 0),
    USpecKind.radar => points.map((point) => point.x).toSet().length >= 3,
    _ => true,
  };
}

// The series of `labels` and `series`.
//
// `series` is `Series(category, values)` components, whose value at the index
// of a label belongs to it, or, as iOS and Android also read it, tabular rows,
// `[[label, v1, v2…]]`, which a program gets from a tool's result or a
// `$variable`: the series are then named by `labels` after its first, and a
// row's first cell is its category. A value that isn't a finite number is
// left out.
List<USeries> _seriesOf(OpenUIValue? labelsValue, OpenUIValue? seriesValue) {
  final labels = [for (final label in _items(labelsValue)) JS.toStringOrEmpty(label)];
  final items = _items(seriesValue);
  if (items.isNotEmpty && items.first is OpenUIArray) {
    final names = labels.skip(1).toList();
    final byName = <String, List<UPoint>>{for (final name in names) name: []};
    for (final row in items) {
      final cells = _items(row);
      final category = cells.isEmpty ? '' : JS.toStringOrEmpty(cells.first);
      for (final (index, name) in names.indexed) {
        final value = _plottable(index + 1 < cells.length ? cells[index + 1] : null);
        if (value != null) byName[name]!.add(UPoint(x: category, y: value));
      }
    }
    return [
      for (final MapEntry(:key, :value) in byName.entries)
        if (value.isNotEmpty) USeries(name: key, points: value),
    ];
  }
  final series = <USeries>[];
  for (final item in items) {
    final props = _propsOf(item);
    if (props == null) continue;
    final (name, values) = (props['category'], props['values']);
    if (values is! OpenUIArray) continue;
    final points = [
      for (final (index, label) in labels.indexed)
        if (index < values.items.length)
          if (_plottable(values.items[index]) case final value?) UPoint(x: label, y: value),
    ];
    if (points.isNotEmpty) series.add(USeries(name: JS.toStringOrEmpty(name), points: points));
  }
  return series;
}

// The parts of `labels` and `values`: a part of the whole for each label, a
// label past the last value counting as nothing, and a value read as a number
// as elsewhere (`"42"` is 42), and left out when it isn't finite.
//
// Without `values`, `labels` holds `Slice(category, value)` components, as
// OpenUI's legacy form has them, which a program gets from a `$variable`.
List<UPoint> _slicePoints(OpenUIValue? labelsValue, OpenUIValue? valuesValue) {
  final labels = _items(labelsValue);
  final values = _items(valuesValue);
  if (labels.isNotEmpty && values.isNotEmpty) {
    return [
      for (final (index, label) in labels.indexed)
        if (_plottable(index < values.length ? values[index] : const OpenUINumber(0)) case final value?)
          UPoint(x: JS.toStringOrEmpty(label), y: value),
    ];
  }
  return [
    for (final label in labels)
      if (_propsOf(label) case final slice?)
        if (_plottable(slice['value']) case final value?) UPoint(x: JS.toStringOrEmpty(slice['category']), y: value),
  ];
}

// The items of [value], or none when it isn't an array.
List<OpenUIValue> _items(OpenUIValue? value) => value is OpenUIArray ? value.items : const [];

// The props of [value] when it is a component or an object.
Map<String, OpenUIValue>? _propsOf(OpenUIValue value) => switch (value) {
  OpenUIElement(:final node) => node.props,
  OpenUIObject(:final fields) => fields,
  _ => null,
};

// The largest magnitude a chart plots, as on iOS and Android.
const _maxMagnitude = 1e15;

// [value] as a number a chart can plot, clamped to ±1e15, or `null` when it
// isn't finite.
double? _plottable(OpenUIValue? value) {
  final number = JS.toNumber(value);
  if (!number.isFinite) return null;
  return number.clamp(-_maxMagnitude, _maxMagnitude);
}

// [value] as the text of a point's x, without a trailing `.0`.
String _number(double value) =>
    value == value.roundToDouble() && value.abs() <= _maxMagnitude ? value.toInt().toString() : '$value';
