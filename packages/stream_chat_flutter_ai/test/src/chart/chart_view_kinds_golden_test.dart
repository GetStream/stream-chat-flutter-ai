import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

// The horizontal bar, radar, radial and single stacked bar kinds, and every
// bar layout, curve and pie shape, in the default theme, light and dark. The
// other kinds' goldens, with the same pairing, are in chart_view_test.dart.
void main() {
  for (final MapEntry(key: name, value: spec) in _cases.entries) {
    goldenTest(
      '$name chart',
      fileName: 'chart_view_$name',
      constraints: const BoxConstraints.tightFor(width: 320, height: 260),
      builder: () => _wrap(ChartView(spec: spec)),
    );

    goldenTest(
      '$name chart under a dark theme',
      fileName: 'chart_view_dark_$name',
      constraints: const BoxConstraints.tightFor(width: 320, height: 260),
      builder: () => _wrapDark(ChartView(spec: spec)),
    );
  }
}

/// Each case, drawn in light and dark.
const _cases = {
  'stacked_bar': USpec(kind: USpecKind.bar, barLayout: USpecBarLayout.stacked, series: _twoSeriesWithNegative),
  'horizontal_bar': USpec(kind: USpecKind.horizontalBar, series: _twoSeries),
  'horizontal_stacked_bar': USpec(
    kind: USpecKind.horizontalBar,
    barLayout: USpecBarLayout.stacked,
    series: _twoSeries,
  ),
  'radar': USpec(kind: USpecKind.radar, series: _radarSeries),
  'radial': USpec(kind: USpecKind.radial, series: _parts),
  'single_stacked_bar': USpec(kind: USpecKind.singleStackedBar, series: _parts),
  'donut': USpec(kind: USpecKind.pie, donut: true, series: _parts),
  'semicircle': USpec(kind: USpecKind.pie, semicircle: true, series: _parts),
  'semicircle_donut': USpec(kind: USpecKind.pie, semicircle: true, donut: true, series: _parts),
  'natural_line': USpec(kind: USpecKind.line, curve: USpecCurve.natural, series: _wavySeries),
  'step_line': USpec(kind: USpecKind.line, curve: USpecCurve.step, series: _wavySeries),
  'natural_area': USpec(kind: USpecKind.area, curve: USpecCurve.natural, series: _wavySeries),
  'step_area': USpec(kind: USpecKind.area, curve: USpecCurve.step, series: _wavySeries),
};

const _twoSeries = [
  USeries(
    name: 'Won',
    points: [
      UPoint(x: 'North', y: 12),
      UPoint(x: 'South', y: 18),
      UPoint(x: 'East', y: 7),
      UPoint(x: 'West', y: 15),
    ],
  ),
  USeries(
    name: 'Lost',
    points: [
      UPoint(x: 'North', y: 5),
      UPoint(x: 'South', y: 3),
      UPoint(x: 'East', y: 9),
      UPoint(x: 'West', y: 4),
    ],
  ),
];

/// Two series, one category holding a negative value, so the stack shows both
/// sides of zero.
const _twoSeriesWithNegative = [
  USeries(
    name: 'Income',
    points: [
      UPoint(x: 'Jan', y: 12),
      UPoint(x: 'Feb', y: 18),
      UPoint(x: 'Mar', y: 9),
    ],
  ),
  USeries(
    name: 'Adjustments',
    points: [
      UPoint(x: 'Jan', y: 5),
      UPoint(x: 'Feb', y: -6),
      UPoint(x: 'Mar', y: 4),
    ],
  ),
];

const _radarSeries = [
  USeries(
    name: 'Phone',
    points: [
      UPoint(x: 'Battery', y: 8),
      UPoint(x: 'Camera', y: 9),
      UPoint(x: 'Screen', y: 7),
      UPoint(x: 'Price', y: 4),
      UPoint(x: 'Size', y: 6),
    ],
  ),
  USeries(
    name: 'Tablet',
    points: [
      UPoint(x: 'Battery', y: 9),
      UPoint(x: 'Camera', y: 5),
      UPoint(x: 'Screen', y: 10),
      UPoint(x: 'Price', y: 3),
      UPoint(x: 'Size', y: 2),
    ],
  ),
];

const _parts = [
  USeries(
    name: 'Share',
    points: [
      UPoint(x: 'Chat', y: 45),
      UPoint(x: 'Video', y: 25),
      UPoint(x: 'Feeds', y: 18),
      UPoint(x: 'Other', y: 12),
    ],
  ),
];

/// Points that rise and fall, so a curve or a step reads differently from a
/// straight line.
const _wavySeries = [
  USeries(
    name: 'Visits',
    points: [
      UPoint(x: 'Mon', y: 4),
      UPoint(x: 'Tue', y: 12),
      UPoint(x: 'Wed', y: 6),
      UPoint(x: 'Thu', y: 14),
      UPoint(x: 'Fri', y: 9),
    ],
  ),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

/// [_wrap] under a dark [ThemeData], which the chart resolves its defaults
/// from.
Widget _wrapDark(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}
