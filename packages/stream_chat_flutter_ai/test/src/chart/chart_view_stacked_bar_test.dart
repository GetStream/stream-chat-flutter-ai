import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

void main() {
  testWidgets('without a bar layout, each series gets its own rod in a category', (tester) async {
    const spec = USpec(kind: USpecKind.bar, series: _twoPositive);

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    expect(_groups(tester).first.barRods, hasLength(2));
  });

  testWidgets('a stacked chart draws one rod per category', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _stacked(_twoPositive))));

    expect(_groups(tester).map((g) => g.barRods.length), [1, 1]);
  });

  testWidgets('a stacked rod runs from zero to the sum of its positive values', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _stacked(_twoPositive))));

    final rod = _groups(tester).first.barRods.single;
    expect((rod.fromY, rod.toY), (0, 12 + 5));
  });

  testWidgets('stack items follow series order, each starting where the last ended', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _stacked(_twoPositive))));

    final items = _groups(tester).first.barRods.single.rodStackItems;
    expect(items.map((i) => (i.fromY, i.toY)), [(0, 12), (12, 12 + 5)]);
  });

  testWidgets('negative values stack downward from zero', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [UPoint(x: 'Jan', y: -3)],
      ),
      USeries(
        name: 'B',
        points: [UPoint(x: 'Jan', y: -4)],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    final items = _groups(tester).single.barRods.single.rodStackItems;
    expect(items.map((i) => (i.fromY, i.toY)), [(0, -3), (-3, -3 - 4)]);
  });

  testWidgets('mixed signs stack each side on its own, the rod spanning both sums', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [UPoint(x: 'Jan', y: 6)],
      ),
      USeries(
        name: 'B',
        points: [UPoint(x: 'Jan', y: -2)],
      ),
      USeries(
        name: 'C',
        points: [UPoint(x: 'Jan', y: 3)],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    final rod = _groups(tester).single.barRods.single;
    expect((rod.fromY, rod.toY), (-2, 6 + 3));
    expect(rod.rodStackItems.map((i) => (i.fromY, i.toY)), [(0, 6), (0, -2), (6, 6 + 3)]);
  });

  testWidgets('each stack item takes its series color', (tester) async {
    const palette = [Color(0xFF111111), Color(0xFF222222)];

    await tester.pumpWidget(
      _wrap(
        ChartView(
          spec: _stacked(_twoPositive),
          theme: const ChartThemeData(seriesColors: palette),
        ),
      ),
    );

    expect(_groups(tester).first.barRods.single.rodStackItems.map((i) => i.color), palette);
  });

  testWidgets('a series with no point in a category is left out of that stack', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [
          UPoint(x: 'Jan', y: 1),
          UPoint(x: 'Feb', y: 2),
        ],
      ),
      USeries(
        name: 'B',
        points: [UPoint(x: 'Jan', y: 3)],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_groups(tester)[1].barRods.single.rodStackItems.map((i) => (i.fromY, i.toY)), [(0, 2)]);
  });

  testWidgets('a value that is not finite is left out of the stack', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [UPoint(x: 'Jan', y: 4)],
      ),
      USeries(
        name: 'B',
        points: [UPoint(x: 'Jan', y: double.nan)],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    final rod = _groups(tester).single.barRods.single;
    expect((rod.toY, rod.rodStackItems.length), (4, 1));
  });

  testWidgets('a category whose sum overflows to infinity draws no rod', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [UPoint(x: 'Jan', y: double.maxFinite)],
      ),
      USeries(
        name: 'B',
        points: [UPoint(x: 'Jan', y: double.maxFinite)],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_groups(tester).single.barRods, isEmpty);
  });

  testWidgets("a stacked rod is as wide as the category's grouped rods", (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _stacked(_twoPositive))));

    // Two grouped rods of 10 with the 4 between them.
    expect(_groups(tester).first.barRods.single.width, 10 + 4 + 10);
  });

  testWidgets('a stack with nothing above zero runs down from zero', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [UPoint(x: 'Jan', y: -3)],
      ),
      USeries(
        name: 'B',
        points: [UPoint(x: 'Jan', y: -4)],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    final rod = _groups(tester).single.barRods.single;
    expect((rod.fromY, rod.toY), (0, -3 - 4));
  });

  testWidgets('a stacked rod narrows to leave room between crowded categories', (tester) async {
    // Eight grouped rods would take 8 × 10 + 7 × 4 = 108. Three categories
    // share the 264 right of the 40 value gutter in a 320-wide chart less its
    // 16 inset, 88 each, and a stack takes 0.6 of that.
    final spec = _stacked([
      for (var s = 0; s < 8; s++)
        USeries(
          name: 'S$s',
          points: const [
            UPoint(x: 'A', y: 1),
            UPoint(x: 'B', y: 1),
            UPoint(x: 'C', y: 1),
          ],
        ),
    ]);

    await tester.pumpWidget(_wrap(SizedBox(width: 320, child: ChartView(spec: spec))));

    expect(_groups(tester).first.barRods.single.width, closeTo((320 - 16 - 40) / 3 * 0.6, 1e-9));
  });

  testWidgets('grouped rods and their gaps narrow alike between crowded categories', (tester) async {
    // The same 108 of rods and gaps narrow evenly to fit the 88 band, less
    // the 4 gap they keep from the next category.
    final spec = USpec(
      kind: USpecKind.bar,
      series: [
        for (var s = 0; s < 8; s++)
          USeries(
            name: 'S$s',
            points: const [
              UPoint(x: 'A', y: 1),
              UPoint(x: 'B', y: 1),
              UPoint(x: 'C', y: 1),
            ],
          ),
      ],
    );

    await tester.pumpWidget(_wrap(SizedBox(width: 320, child: ChartView(spec: spec))));

    final group = _groups(tester).first;
    const scale = ((320 - 16 - 40) / 3 - 4) / 108;
    expect(group.barRods.map((r) => r.width), everyElement(closeTo(10 * scale, 1e-9)));
    expect(group.barsSpace, closeTo(4 * scale, 1e-9));
  });

  testWidgets('grouped rods in a band too thin to keep their gap take 0.6 of it, as a stack does', (tester) async {
    // 30 categories share 264, 8.8 each; 8.8 less the gap is under 0.6 of it.
    final spec = USpec(
      kind: USpecKind.bar,
      series: [
        for (var s = 0; s < 2; s++)
          USeries(
            name: 'S$s',
            points: [for (var c = 0; c < 30; c++) UPoint(x: 'C$c', y: 1)],
          ),
      ],
    );

    await tester.pumpWidget(_wrap(SizedBox(width: 320, child: ChartView(spec: spec))));

    final group = _groups(tester).first;
    const scale = (320 - 16 - 40) / 30 * 0.6 / 24;
    expect(group.barRods.map((r) => r.width), everyElement(closeTo(10 * scale, 1e-9)));
    expect(group.barsSpace, closeTo(4 * scale, 1e-9));
  });

  testWidgets('grouped rods keep their width while the band has room', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChartView(
          spec: USpec(kind: USpecKind.bar, series: _twoPositive),
        ),
      ),
    );

    final group = _groups(tester).first;
    expect(group.barRods.map((r) => r.width), [10, 10]);
    expect(group.barsSpace, 4);
  });

  testWidgets('gives a stacked rod no width when the chart is narrower than its value gutter', (tester) async {
    // 50 wide leaves 34 inside the inset, less than the 40 value gutter.
    await tester.pumpWidget(_wrap(SizedBox(width: 50, child: ChartView(spec: _stacked(_twoPositive)))));
    // The axis labels themselves overflow a chart this narrow, whatever the
    // layout; that is not what this test is about, but nothing else may throw.
    expect(tester.takeException(), isA<FlutterError>().having((e) => e.message, 'message', contains('overflowed')));

    expect(_groups(tester).first.barRods.single.width, 0);
  });

  // fl_chart stretches a stack shorter than its rounded ends to fit them, which
  // at zero height divides by zero; square ends leave nothing to stretch.
  testWidgets('a stacked chart with a stack too thin to see draws without error', (tester) async {
    final spec = _stacked(const [
      USeries(
        name: 'A',
        points: [
          UPoint(x: 'Big', y: 1000000),
          UPoint(x: 'Tiny', y: 1e-12),
        ],
      ),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a histogram ignores the bar layout', (tester) async {
    const series = [
      USeries(
        name: 'Samples',
        points: [
          UPoint(x: '', y: 1),
          UPoint(x: '', y: 2),
        ],
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        const ChartView(
          spec: USpec(kind: USpecKind.histogram, series: series),
        ),
      ),
    );
    final expected = _groups(tester);
    expect(expected, isNotEmpty);
    await tester.pumpWidget(
      _wrap(
        const ChartView(
          spec: USpec(kind: USpecKind.histogram, barLayout: USpecBarLayout.stacked, series: series),
        ),
      ),
    );

    expect(_groups(tester), expected);
  });
}

const _twoPositive = [
  USeries(
    name: 'Won',
    points: [
      UPoint(x: 'Jan', y: 12),
      UPoint(x: 'Feb', y: 18),
    ],
  ),
  USeries(
    name: 'Lost',
    points: [
      UPoint(x: 'Jan', y: 5),
      UPoint(x: 'Feb', y: 3),
    ],
  ),
];

/// A stacked bar chart of [series].
USpec _stacked(List<USeries> series) => USpec(kind: USpecKind.bar, barLayout: USpecBarLayout.stacked, series: series);

List<BarChartGroupData> _groups(WidgetTester tester) => tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}
