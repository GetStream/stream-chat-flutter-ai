import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';

import '../../core/runtime/fake_tools.dart';
import '../../openui_test_app.dart';

// Draws `root = Card([program])` and returns the chart it shows, or `null`
// when it shows none.
Future<ChartView?> _draw(
  WidgetTester tester,
  String program, {
  bool isStreaming = false,
  OpenUIThemeData? theme,
  String before = '',
}) async {
  final runtime = testRuntime();
  addTearDown(runtime.dispose);
  await pumpOpenUI(
    tester,
    runtime,
    program: '$before\nroot = Card([$program])',
    isStreaming: isStreaming,
    theme: theme,
  );
  await tester.pump();
  final charts = find.byType(ChartView).evaluate();
  return charts.isEmpty ? null : charts.single.widget as ChartView;
}

// The points of [series] as `x: y`.
List<String> _points(USeries series) => [for (final point in series.points) '${point.x}: ${point.y}'];

const _two = 'BarChart(["Q1", "Q2", "Q3"], [Series("Open", [4, 5, 6]), Series("Closed", [1, 2, 3])]';

void main() {
  group('cartesian charts', () {
    testWidgets('a BarChart draws a series for each Series, with the value at each label', (tester) async {
      final chart = await _draw(tester, '$_two)');

      final spec = chart!.spec;
      expect(spec.kind, USpecKind.bar);
      expect(spec.barLayout, USpecBarLayout.grouped);
      expect([for (final series in spec.series) series.name], ['Open', 'Closed']);
      expect(_points(spec.series.first), ['Q1: 4.0', 'Q2: 5.0', 'Q3: 6.0']);
    });

    testWidgets('a stacked variant stacks the bars, and the axis labels carry over', (tester) async {
      final chart = await _draw(tester, '$_two, "stacked", "Quarter", "Tickets")');

      expect(chart!.spec.barLayout, USpecBarLayout.stacked);
      expect(chart.spec.xLabel, 'Quarter');
      expect(chart.spec.yLabel, 'Tickets');
    });

    testWidgets('a HorizontalBarChart draws horizontal bars, grouped or stacked', (tester) async {
      final grouped = await _draw(tester, 'HorizontalBarChart(["A", "B"], [Series("S", [1, 2])])');
      expect(grouped!.spec.kind, USpecKind.horizontalBar);
      expect(grouped.spec.barLayout, USpecBarLayout.grouped);

      final stacked = await _draw(tester, 'HorizontalBarChart(["A", "B"], [Series("S", [1, 2])], "stacked")');
      expect(stacked!.spec.barLayout, USpecBarLayout.stacked);
    });

    for (final (variant, curve) in [
      ('linear', USpecCurve.linear),
      ('natural', USpecCurve.natural),
      ('step', USpecCurve.step),
    ]) {
      testWidgets('a LineChart and an AreaChart draw their $variant curve', (tester) async {
        final line = await _draw(tester, 'LineChart(["A", "B"], [Series("S", [1, 2])], "$variant")');
        expect((line!.spec.kind, line.spec.curve), (USpecKind.line, curve));

        final area = await _draw(tester, 'AreaChart(["A", "B"], [Series("S", [1, 2])], "$variant")');
        expect((area!.spec.kind, area.spec.curve), (USpecKind.area, curve));
      });
    }

    testWidgets('a RadarChart draws a polygon for each Series over its labels', (tester) async {
      final chart = await _draw(tester, 'RadarChart(["Speed", "Power", "Range"], [Series("A", [3, 4, 5])])');

      expect(chart!.spec.kind, USpecKind.radar);
      expect(_points(chart.spec.series.single), ['Speed: 3.0', 'Power: 4.0', 'Range: 5.0']);
    });

    testWidgets('a value that is not finite is left out, and a huge one is clamped to 1e15', (tester) async {
      final chart = await _draw(tester, 'BarChart(["A", "B", "C"], [Series("S", [1e308 * 10, 1e20, -1e20])])');

      expect(_points(chart!.spec.series.single), ['B: 1000000000000000.0', 'C: -1000000000000000.0']);
    });

    testWidgets('a value without a label is left out, and a label without a value has none', (tester) async {
      final chart = await _draw(tester, 'LineChart(["A", "B"], [Series("S", [1, 2, 3]), Series("T", [5])])');

      expect(
        [for (final series in chart!.spec.series) _points(series)],
        [
          ['A: 1.0', 'B: 2.0'],
          ['A: 5.0'],
        ],
      );
    });

    testWidgets('a height is kept between 60 and 1000', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (given, kept) in [(5, 60.0), (300, 300.0), (1e9, 1000.0), (-4, null), (0, null)]) {
        final chart = await _draw(tester, 'BarChart(["A"], [Series("S", [1])], "grouped", "x", "y", $given)');
        expect(chart!.theme!.height, kept, reason: 'height $given');
      }
    });

    testWidgets('a height sets the plot height, and without one the chart keeps its own', (tester) async {
      final tall = await _draw(tester, 'BarChart(["A"], [Series("S", [1])], "grouped", "x", "y", 300)');
      expect(tall!.theme!.height, 300);

      final plain = await _draw(tester, 'BarChart(["A"], [Series("S", [1])])');
      expect(plain!.theme!.height, isNull);
    });

    testWidgets('a chart with nothing to draw shows nothing', (tester) async {
      expect(await _draw(tester, 'BarChart([], [])'), isNull);
      expect(await _draw(tester, 'BarChart(["A"], [Series("S", ["x"])])'), isNull);
    });

    testWidgets('a chart draws the points that have arrived while the reply streams, and the rest after', (
      tester,
    ) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'root = Card([BarChart(["A", "B"], [s])])\ns = Series("S", [1',
        isStreaming: true,
      );
      await tester.pump();
      expect(tester.widget<ChartView>(find.byType(ChartView)).spec.series.single.points, hasLength(1));

      runtime.update('root = Card([BarChart(["A", "B"], [s])])\ns = Series("S", [1, 2])', isStreaming: false);
      await tester.pump();

      expect(tester.widget<ChartView>(find.byType(ChartView)).spec.series.single.points, hasLength(2));
    });

    testWidgets("rows from a tool's result give a series for each label after the first", (tester) async {
      final tools = FakeTools()
        ..results['rows'] = OpenUIValue.fromJson(const [
          ['Q1', 4, 1],
          ['Q2', 5, 2],
        ]);
      final runtime = testRuntime(tools: tools);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'q = Query("rows", {}, [])\nroot = Card([BarChart(["Quarter", "Open", "Closed"], q)])',
      );
      await tester.pump(const Duration(seconds: 1));

      final spec = tester.widget<ChartView>(find.byType(ChartView)).spec;
      expect([for (final series in spec.series) series.name], ['Open', 'Closed']);
      expect(_points(spec.series.first), ['Q1: 4.0', 'Q2: 5.0']);
      expect(_points(spec.series.last), ['Q1: 1.0', 'Q2: 2.0']);
    });

    testWidgets('a row cell that is not a number, or is missing, is a zero, as the language coerces it', (
      tester,
    ) async {
      final tools = FakeTools()
        ..results['rows'] = OpenUIValue.fromJson(const [
          ['Q1', 'x', 1],
          ['Q2', 5],
        ]);
      final runtime = testRuntime(tools: tools);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'q = Query("rows", {}, [])\nroot = Card([BarChart(["Quarter", "Open", "Closed"], q)])',
      );
      await tester.pump(const Duration(seconds: 1));

      final spec = tester.widget<ChartView>(find.byType(ChartView)).spec;
      expect(
        [for (final series in spec.series) _points(series)],
        [
          ['Q1: 0.0', 'Q2: 5.0'],
          ['Q1: 1.0', 'Q2: 0.0'],
        ],
      );
    });

    testWidgets("literal rows and Slice components, which the library's schema drops, draw nothing", (tester) async {
      expect(await _draw(tester, 'BarChart(["Quarter", "Open"], [["Q1", 4], ["Q2", 5]])'), isNull);
      expect(await _draw(tester, 'PieChart([Slice("A", 1), Slice("B", 3)], [])'), isNull);
    });
  });

  group('charts of parts', () {
    testWidgets('a PieChart draws a slice for each label and value', (tester) async {
      final chart = await _draw(tester, 'PieChart(["A", "B"], [30, 70])');

      final spec = chart!.spec;
      expect((spec.kind, spec.donut, spec.pieShape), (USpecKind.pie, false, USpecPieShape.full));
      expect(_points(spec.series.single), ['A: 30.0', 'B: 70.0']);
    });

    testWidgets('a donut variant draws a ring, and a semiCircular appearance a half', (tester) async {
      final donut = await _draw(tester, 'PieChart(["A", "B"], [30, 70], "donut")');
      expect(donut!.spec.donut, isTrue);

      final half = await _draw(tester, 'PieChart(["A", "B"], [30, 70], "pie", "semiCircular")');
      expect(half!.spec.pieShape, USpecPieShape.semicircle);
    });

    testWidgets('a label past the last value is a slice of nothing', (tester) async {
      final chart = await _draw(tester, 'PieChart(["A", "B", "C"], [30])');

      expect(_points(chart!.spec.series.single), ['A: 30.0', 'B: 0.0', 'C: 0.0']);
    });

    testWidgets('parts with no value above zero, and a radar with fewer than three spokes, draw nothing', (
      tester,
    ) async {
      expect(await _draw(tester, 'PieChart(["A", "B"], [0, -3])'), isNull);
      expect(await _draw(tester, 'RadialChart(["A"], [0])'), isNull);
      expect(await _draw(tester, 'SingleStackedBarChart(["A"], [0])'), isNull);
      expect(await _draw(tester, 'RadarChart(["A", "B"], [Series("S", [1, 2])])'), isNull);
    });

    testWidgets('Slice components from a variable, without values, draw the legacy form', (tester) async {
      final chart = await _draw(tester, r'PieChart($d, [])', before: r'$d = [Slice("A", 1), Slice("B", 3)]');

      expect(_points(chart!.spec.series.single), ['A: 1.0', 'B: 3.0']);
    });

    testWidgets('a RadialChart and a SingleStackedBarChart draw their parts', (tester) async {
      final radial = await _draw(tester, 'RadialChart(["A", "B"], [40, 60])');
      expect(radial!.spec.kind, USpecKind.radial);
      expect(_points(radial.spec.series.single), ['A: 40.0', 'B: 60.0']);

      final stacked = await _draw(tester, 'SingleStackedBarChart(["A", "B"], [40, 60])');
      expect(stacked!.spec.kind, USpecKind.singleStackedBar);
    });
  });

  group('ScatterChart', () {
    testWidgets('draws a series for each dataset, with its points as numbers', (tester) async {
      final chart = await _draw(
        tester,
        'ScatterChart([ScatterSeries("A", [Point(1, 2), Point(3.5, 4)]), ScatterSeries("B", [Point(5, 6)])], "Weight", "Height")',
      );

      final spec = chart!.spec;
      expect(spec.kind, USpecKind.scatter);
      expect([for (final series in spec.series) series.name], ['A', 'B']);
      expect(_points(spec.series.first), ['1: 2.0', '3.5: 4.0']);
      expect((spec.xLabel, spec.yLabel), ('Weight', 'Height'));
    });

    testWidgets('sizes the dots by z when a point has one', (tester) async {
      final chart = await _draw(tester, 'ScatterChart([ScatterSeries("A", [Point(1, 2, 10), Point(3, 4)])])');

      expect(chart!.spec.kind, USpecKind.bubble);
      expect([for (final point in chart.spec.series.single.points) point.size], [10, null]);
    });

    testWidgets('leaves out a point whose x or y is not a number', (tester) async {
      final chart = await _draw(tester, 'ScatterChart([ScatterSeries("A", [Point("x", 2), Point(3, 4)])])');

      expect(_points(chart!.spec.series.single), ['3: 4.0']);
    });
  });

  group('colors', () {
    testWidgets("the series take the theme's chart palette", (tester) async {
      final chart = await _draw(tester, '$_two)');

      final palette = OpenUIThemeData.defaults(StreamTheme.light()).chartPalette;
      expect(chart!.theme!.seriesColors, palette);
    });

    testWidgets('a palette in the renderer theme takes its place', (tester) async {
      const palette = [Color(0xFF112233), Color(0xFF445566)];
      final chart = await _draw(
        tester,
        '$_two)',
        theme: OpenUIThemeData(chartPalette: palette),
      );

      expect(chart!.theme!.seriesColors, palette);
    });
  });
}
