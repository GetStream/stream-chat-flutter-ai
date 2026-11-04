import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

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

  testWidgets('a natural line curves through its points as a Catmull-Rom spline', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.natural, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    final line = _line(tester);
    // fl_chart reaches half the neighbours' chord times the smoothness; a
    // Catmull-Rom spline reaches a sixth of it.
    expect((line.isCurved, line.curveSmoothness), (true, 1 / 3));
  });

  testWidgets('a step line steps halfway between points', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.step, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    final line = _line(tester);
    expect((line.isStepLineChart, line.lineChartStepData.stepDirection), (true, LineChartStepData.stepDirectionMiddle));
  });

  testWidgets('a natural curve is clipped along the bottom, off the axis labels', (tester) async {
    const spec = USpec(kind: USpecKind.line, curve: USpecCurve.natural, series: _visits);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    final clip = tester.widget<LineChart>(find.byType(LineChart)).data.clipData;
    expect((clip.bottom, clip.top), (true, false));
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
    expect((area.isCurved, area.belowBarData.show), (true, true));
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
