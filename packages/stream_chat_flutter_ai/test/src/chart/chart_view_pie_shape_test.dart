import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

// The plot is 220 tall with 8 above and below, so a full pie gets 204 of
// height: a radius of 102 whenever the width allows it.
void main() {
  testWidgets('a pie starts its first slice at the top', (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _pie)));

    // fl_chart counts degrees clockwise from the right.
    expect(_data(tester).startDegreeOffset, -90);
  });

  testWidgets('a donut starts its first slice at the top', (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _donut)));

    expect(_data(tester).startDegreeOffset, -90);
  });

  testWidgets('a pie that is not a donut has no hole', (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _pie)));

    expect(_data(tester).centerSpaceRadius, 0);
  });

  testWidgets("a pie's slices reach the edge of its plot", (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _pie)));

    expect(_data(tester).sections.first.radius, 102);
  });

  testWidgets('centers a pie in its plot', (tester) async {
    await tester.pumpWidget(_wrapSized(const ChartView(spec: _pie)));

    // 16 in from either side, like a title and legend above and below it.
    expect(tester.getRect(find.byType(PieChart)).center.dx, _plot(tester).center.dx);
  });

  testWidgets("a donut's hole is 0.58 of its radius by default", (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _donut)));

    expect(_data(tester).centerSpaceRadius, closeTo(102 * 0.58, 1e-9));
  });

  testWidgets("a donut's ring fills the rest of its radius", (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _donut)));

    expect(_data(tester).sections.first.radius, closeTo(102 * (1 - 0.58), 1e-9));
  });

  testWidgets("a donut's hole follows the theme", (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _donut, theme: ChartThemeData(donutHoleRatio: 0.4))));

    expect(_data(tester).centerSpaceRadius, closeTo(102 * 0.4, 1e-9));
  });

  testWidgets("a donut's slices carry their shares", (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _donut)));

    expect(_data(tester).sections.map((s) => s.title), ['50%', '30%', '20%']);
  });

  testWidgets('a semicircle starts at the left', (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _semicircle)));

    expect(_data(tester).startDegreeOffset, 180);
  });

  testWidgets('a semicircle leaves the bottom half to an invisible slice as big as the rest', (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _semicircle)));

    final filler = _data(tester).sections.last;
    expect((filler.value, filler.color, filler.showTitle), (50 + 30 + 20, Colors.transparent, false));
  });

  testWidgets('a semicircle that is not a donut has no hole', (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _semicircle)));

    expect(_data(tester).centerSpaceRadius, 0);
  });

  testWidgets('a semicircle can be a donut', (tester) async {
    const spec = USpec(kind: USpecKind.pie, semicircle: true, donut: true, series: _parts);

    await tester.pumpWidget(_wrapSized(const ChartView(spec: spec)));

    // 288 wide (320 less the 16 insets) gives a radius of 144.
    expect(_data(tester).centerSpaceRadius, closeTo(144 * 0.58, 1e-9));
  });

  testWidgets("a narrow semicircle's plot is as tall as its radius", (tester) async {
    await tester.pumpWidget(_wrapSized(const ChartView(spec: _semicircle)));

    // A radius of 144, under the 204 the theme height allows, plus 8 above
    // and below.
    expect(_plot(tester).height, 144 + 2 * 8);
  });

  testWidgets("a wide semicircle's radius stops at the theme height", (tester) async {
    await tester.pumpWidget(_wrap(const ChartView(spec: _semicircle)));

    // 768 wide would allow a radius of 384; the 220 height allows 204.
    expect(_plot(tester).height, 220);
  });

  testWidgets('a semicircle sits its flat side on the bottom of its plot', (tester) async {
    await tester.pumpWidget(_wrapSized(const ChartView(spec: _semicircle)));

    final content = _plot(tester).deflate(8);
    expect(tester.getRect(find.byType(PieChart)).center, Offset(_plot(tester).center.dx, content.bottom));
  });

  testWidgets('a semicircle narrower than its insets has no radius, not a negative one', (tester) async {
    // 10 wide is less than the 32 of insets.
    await tester.pumpWidget(_wrap(const SizedBox(width: 10, child: ChartView(spec: _semicircle))));

    expect(_plot(tester).height, 2 * 8);
  });

  testWidgets('a semicircle with no slice to draw adds no filler', (tester) async {
    const spec = USpec(
      kind: USpecKind.pie,
      semicircle: true,
      series: [
        USeries(
          name: 'Share',
          points: [
            UPoint(x: 'A', y: 0),
            UPoint(x: 'B', y: -2),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    expect(_data(tester).sections, isEmpty);
  });

  testWidgets('a line chart ignores donut and semicircle', (tester) async {
    const plain = USpec(kind: USpecKind.line, series: _parts);
    const shaped = USpec(kind: USpecKind.line, donut: true, semicircle: true, series: _parts);

    await tester.pumpWidget(_wrap(const ChartView(spec: plain)));
    // The lines themselves; the title builders are new closures every build.
    final expected = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;
    await tester.pumpWidget(_wrap(const ChartView(spec: shaped)));

    expect(tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData, expected);
  });
}

const _parts = [
  USeries(
    name: 'Share',
    points: [
      UPoint(x: 'A', y: 50),
      UPoint(x: 'B', y: 30),
      UPoint(x: 'C', y: 20),
    ],
  ),
];

const _pie = USpec(kind: USpecKind.pie, series: _parts);

const _donut = USpec(kind: USpecKind.pie, donut: true, series: _parts);

const _semicircle = USpec(kind: USpecKind.pie, semicircle: true, series: _parts);

PieChartData _data(WidgetTester tester) => tester.widget<PieChart>(find.byType(PieChart)).data;

/// The plot's box, its padding included: the box just around the pie's layout.
Rect _plot(WidgetTester tester) => tester.getRect(
  find.ancestor(of: find.byType(PieChart), matching: find.byType(Container)).first,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

/// [_wrap] at a phone-bubble width.
Widget _wrapSized(Widget child) => _wrap(SizedBox(width: 320, child: child));
