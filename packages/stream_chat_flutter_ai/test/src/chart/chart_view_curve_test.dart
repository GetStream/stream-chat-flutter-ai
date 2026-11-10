import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

void main() {
  testWidgets('a line chart joins its points with straight segments by default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChartView(
          spec: USpec(kind: USpecKind.line, series: _visits),
        ),
      ),
    );

    final line = _line(tester);
    expect((line.isCurved, line.isStepLineChart), (false, false));
  });

  testWidgets('a natural line is drawn from samples of a monotone curve through its points', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.natural, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    final line = _line(tester);
    expect((line.isCurved, line.preventCurveOverShooting), (false, false));
    expect(line.spots, containsAllInOrder(const [FlSpot(0, 4), FlSpot(1, 12), FlSpot(2, 6)]));
    expect(line.spots.length, greaterThan(3));
  });

  testWidgets('a straight or stepped line keeps its value tooltip, which a natural one drops', (tester) async {
    bool touchable(USpecCurve curve) => tester.widget<LineChart>(find.byType(LineChart)).data.lineTouchData.enabled;

    for (final (curve, expected) in [(USpecCurve.linear, true), (USpecCurve.step, true), (USpecCurve.natural, false)]) {
      await tester.pumpWidget(
        _wrap(
          ChartView(
            spec: USpec(kind: USpecKind.line, curve: curve, series: _visits),
          ),
        ),
      );
      expect(touchable(curve), expected, reason: '$curve');
    }
  });

  testWidgets('a step line steps halfway between points', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.step, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    final line = _line(tester);
    expect((line.isStepLineChart, line.lineChartStepData.stepDirection), (true, LineChartStepData.stepDirectionMiddle));
  });

  testWidgets('a natural curve stays between the points it joins, so it needs no clip', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.natural, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec, theme: ChartThemeData(height: 240))));

    _expectWithinSegments(_line(tester).spots, const [FlSpot(0, 4), FlSpot(1, 12), FlSpot(2, 6)]);
    expect(tester.widget<LineChart>(find.byType(LineChart)).data.clipData, const FlClipData.none());
  });

  group('monotoneCurveSpots', () {
    // Gentle, uneven rises and falls of 8 to 12 points, where a threshold on
    // the rise used to drop the smoothing.
    for (final n in [8, 10, 12]) {
      final rising = [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), 10 + i + (i.isEven ? 0.4 : 0))];
      final falling = [for (final s in rising) FlSpot(s.x, 30 - s.y)];

      test('keeps a $n-point line smooth without overshooting', () {
        final curve = monotoneCurveSpots(rising);
        _expectWithinSegments(curve, rising);
        // Smoothed: some interior sample leaves the straight chord.
        expect(_maxChordDeviation(curve, rising), greaterThan(1e-3));
      });

      test('draws a $n-point fall as the mirror of the rise', () {
        final up = monotoneCurveSpots(rising);
        final down = monotoneCurveSpots(falling);
        expect(down.length, up.length);
        for (var i = 0; i < up.length; i++) {
          expect(down[i].x, up[i].x);
          expect(down[i].y, closeTo(30 - up[i].y, 1e-9));
        }
      });
    }

    test('lays a peak and a trough level, never swinging past them', () {
      const points = [FlSpot.zero, FlSpot(1, 10), FlSpot(2, 0), FlSpot(3, 10), FlSpot(4, 9), FlSpot(5, 0)];
      final curve = monotoneCurveSpots(points);
      _expectWithinSegments(curve, points);
      expect(curve.map((s) => s.y).reduce(max), 10);
      expect(curve.map((s) => s.y).reduce(min), 0);
    });

    test('keeps a break in the line and curves each side apart', () {
      final points = [const FlSpot(0, 1), const FlSpot(1, 5), const FlSpot(2, 2), FlSpot.nullSpot, const FlSpot(4, 3)];
      final curve = monotoneCurveSpots(points);
      expect(curve.where((s) => s.isNull()).length, 1);
      expect(curve.last, const FlSpot(4, 3));
    });
  });

  testWidgets('a straight line keeps its slopes, with nothing to level', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChartView(
          spec: USpec(kind: USpecKind.line, series: _visits),
        ),
      ),
    );

    expect(_line(tester).preventCurveOverShooting, isFalse);
  });

  testWidgets('a step line, which never swings past its points, is not clipped', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.step, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    expect(tester.widget<LineChart>(find.byType(LineChart)).data.clipData, const FlClipData.none());
  });

  testWidgets("an area's fill follows its curve", (tester) async {
    const spec = USpec(kind: USpecKind.area, curve: USpecCurve.natural, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    final area = _line(tester);
    expect((area.spots.length > _visits.single.points.length, area.belowBarData.show), (true, true));
  });

  testWidgets('a bar chart ignores the curve', (tester) async {
    const straight = USpec(kind: USpecKind.bar, series: _visits);
    const curved = USpec(kind: USpecKind.bar, curve: USpecCurve.natural, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: straight)));
    // The bars themselves; the title builders are new closures every build.
    final expected = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
    await tester.pumpWidget(_wrap(const ChartView(spec: curved)));

    expect(tester.widget<BarChart>(find.byType(BarChart)).data.barGroups, expected);
  });
}

const _visits = [
  USeries(
    name: 'Visits',
    points: [
      UPoint(x: 'Mon', y: 4),
      UPoint(x: 'Tue', y: 12),
      UPoint(x: 'Wed', y: 6),
    ],
  ),
];

LineChartBarData _line(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single;

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

// Every sample lies between the values of the two points it falls between.
void _expectWithinSegments(List<FlSpot> curve, List<FlSpot> points) {
  for (final s in curve) {
    final k = points.lastIndexWhere((p) => p.x <= s.x);
    final next = points[min(k + 1, points.length - 1)];
    final lo = min(points[k].y, next.y);
    final hi = max(points[k].y, next.y);
    expect(s.y, inInclusiveRange(lo - 1e-9, hi + 1e-9), reason: 'sample at x ${s.x}');
  }
}

double _maxChordDeviation(List<FlSpot> curve, List<FlSpot> points) {
  var worst = 0.0;
  for (final s in curve) {
    final k = min(points.lastIndexWhere((p) => p.x <= s.x), points.length - 2);
    final (a, b) = (points[k], points[k + 1]);
    final chord = a.y + (b.y - a.y) * (s.x - a.x) / (b.x - a.x);
    worst = max(worst, (s.y - chord).abs());
  }
  return worst;
}
