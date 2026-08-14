import 'package:alchemist/alchemist.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

void main() {
  group('ChartView', () {
    testWidgets('line renders LineChart', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _lineSpec)));
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('area renders LineChart', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _areaSpec)));
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('bar renders BarChart', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _barSpec)));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('pie renders PieChart', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _pieSpec)));
      expect(find.byType(PieChart), findsOneWidget);
    });

    group('title', () {
      testWidgets('renders spec.title above the plot', (tester) async {
        const spec = USpec(
          title: 'Messages per day',
          kind: USpecKind.bar,
          series: [
            USeries(
              name: 'Messages',
              points: [UPoint(x: 'Jan', y: 1)],
            ),
          ],
        );

        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

        expect(find.text('Messages per day'), findsOneWidget);
        final titleY = tester.getCenter(find.text('Messages per day')).dy;
        final chartY = tester.getCenter(find.byType(BarChart)).dy;
        expect(titleY, lessThan(chartY));
      });

      testWidgets('adds nothing when the spec has no title', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: _lineSpec)));
        expect(find.byType(Column), findsNothing);
      });

      testWidgets('treats a blank title as absent', (tester) async {
        const spec = USpec(
          title: '   ',
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [UPoint(x: 'Jan', y: 1)],
            ),
          ],
        );

        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
        expect(find.byType(Column), findsNothing);
      });
    });

    group('multi-series bar', () {
      // Two series of different lengths. The category count used to be read off
      // the *first* series, dropping any later series' extra points, and missing
      // points were drawn as a zero-height bar rather than omitted.
      const spec = USpec(
        kind: USpecKind.bar,
        series: [
          USeries(
            name: 'Short',
            points: [UPoint(x: 'Jan', y: 1)],
          ),
          USeries(
            name: 'Long',
            points: [
              UPoint(x: 'Jan', y: 2),
              UPoint(x: 'Feb', y: 3),
            ],
          ),
        ],
      );

      testWidgets("covers every category, not just the first series' own", (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
        final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
        expect(groups, hasLength(2));
      });

      testWidgets('omits the rod for a series with no point at that category', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
        final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

        expect(groups[0].barRods.map((r) => r.toY), [1, 2], reason: 'both series have a January point');
        expect(groups[1].barRods.map((r) => r.toY), [3], reason: 'only the long series reaches February');
      });
    });

    testWidgets('scatter plots categorical series over shared x positions', (tester) async {
      // The fallback x used to be the running count of spots across *all*
      // series, so each series was pushed to the right of the previous one
      // instead of sharing the same categories.
      const spec = USpec(
        kind: USpecKind.scatter,
        series: [
          USeries(
            name: 'A',
            points: [
              UPoint(x: 'Jan', y: 1),
              UPoint(x: 'Feb', y: 2),
            ],
          ),
          USeries(
            name: 'B',
            points: [
              UPoint(x: 'Jan', y: 3),
              UPoint(x: 'Feb', y: 4),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
      final spots = tester.widget<ScatterChart>(find.byType(ScatterChart)).data.scatterSpots;

      expect(spots.map((s) => s.x), [0, 1, 0, 1]);
      expect(spots.map((s) => s.y), [1, 2, 3, 4]);
    });

    testWidgets('bubble radii are normalized across the chart, not clamped', (tester) async {
      // Sizes arrive in the data's own units. Clamping them as raw pixel radii
      // pinned everything past the maximum to one size, flattening the encoding.
      const spec = USpec(
        kind: USpecKind.bubble,
        series: [
          USeries(
            name: 'Cities',
            points: [
              UPoint(x: '0', y: 1, size: 1000),
              UPoint(x: '1', y: 2, size: 5000),
              UPoint(x: '2', y: 3, size: 9000),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
      final spots = tester.widget<ScatterChart>(find.byType(ScatterChart)).data.scatterSpots;
      final radii = spots.map((s) => (s.dotPainter as FlDotCirclePainter).radius).toList();

      expect(radii, hasLength(3));
      expect(radii[0], lessThan(radii[1]));
      expect(radii[1], lessThan(radii[2]));
      expect(radii.toSet(), hasLength(3), reason: 'distinct sizes must map to distinct radii');
    });

    testWidgets('scatter renders ScatterChart (not a line fallback)', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _scatterSpec)));
      expect(find.byType(ScatterChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('bubble renders ScatterChart (not a line fallback)', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _bubbleSpec)));
      expect(find.byType(ScatterChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('histogram renders BarChart (not a line fallback)', (tester) async {
      await tester.pumpWidget(_wrap(const ChartView(spec: _histogramSpec)));
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    group('heatmap', () {
      testWidgets('renders a labelled grid, not a line fallback', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: _heatmapSpec)));

        expect(find.byType(HeatmapChartView), findsOneWidget);
        expect(find.byType(LineChart), findsNothing);
        // One label per series (rows) and per distinct point.x (columns).
        expect(find.text('Row 1'), findsOneWidget);
        expect(find.text('Row 2'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        // Every cell is filled, and the legend spans the full value range.
        expect(_filledCells(tester), 4);
        expect(find.text('1.0'), findsOneWidget);
        expect(find.text('9.0'), findsOneWidget);
      });

      testWidgets('leaves cells a ragged row has no value for unfilled', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: _raggedHeatmapSpec)));

        // 3 distinct columns x 2 rows, but the second row only has 2 points.
        expect(find.text('C'), findsOneWidget);
        expect(_filledCells(tester), 5);
      });

      testWidgets('renders a uniform grid at full intensity', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: _uniformHeatmapSpec)));

        expect(_filledCells(tester), 2);
        // min == max, so both ends of the legend show the same value.
        expect(find.text('4.0'), findsNWidgets(2));
      });

      testWidgets('renders nothing when there are no points', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: _emptyHeatmapSpec)));

        expect(find.byType(HeatmapChartView), findsOneWidget);
        expect(_filledCells(tester), 0);
      });
    });

    group('golden', () {
      for (final entry in _goldenCases.entries) {
        goldenTest(
          '${entry.key} chart',
          fileName: 'chart_view_${entry.key}',
          constraints: const BoxConstraints.tightFor(width: 320, height: 260),
          builder: () => _wrap(ChartView(spec: entry.value)),
        );
      }
    });
  });
}

const _goldenCases = {
  'line': _lineSpec,
  'area': _areaSpec,
  'bar': _barSpec,
  'pie': _pieSpec,
  'scatter': _scatterSpec,
  'bubble': _bubbleSpec,
  'histogram': _histogramSpec,
  'heatmap': _heatmapSpec,
};

const _lineSpec = USpec(
  kind: USpecKind.line,
  series: [
    USeries(
      name: 'Sales',
      points: [
        UPoint(x: 'Jan', y: 10),
        UPoint(x: 'Feb', y: 25),
        UPoint(x: 'Mar', y: 18),
      ],
    ),
  ],
);

const _areaSpec = USpec(
  kind: USpecKind.area,
  series: [
    USeries(
      name: 'Sales',
      points: [
        UPoint(x: 'Jan', y: 10),
        UPoint(x: 'Feb', y: 25),
        UPoint(x: 'Mar', y: 18),
      ],
    ),
  ],
);

const _barSpec = USpec(
  kind: USpecKind.bar,
  series: [
    USeries(
      name: 'Sales',
      points: [
        UPoint(x: 'Jan', y: 10),
        UPoint(x: 'Feb', y: 25),
        UPoint(x: 'Mar', y: 18),
      ],
    ),
  ],
);

const _pieSpec = USpec(
  kind: USpecKind.pie,
  series: [
    USeries(
      name: 'Share',
      points: [
        UPoint(x: 'A', y: 40),
        UPoint(x: 'B', y: 35),
        UPoint(x: 'C', y: 25),
      ],
    ),
  ],
);

const _scatterSpec = USpec(
  kind: USpecKind.scatter,
  series: [
    USeries(
      name: 'S',
      points: [
        UPoint(x: '1', y: 3),
        UPoint(x: '2', y: 7),
        UPoint(x: '3', y: 2),
        UPoint(x: '4', y: 9),
      ],
    ),
  ],
);

const _bubbleSpec = USpec(
  kind: USpecKind.bubble,
  series: [
    USeries(
      name: 'S',
      points: [
        UPoint(x: '1', y: 3, size: 8),
        UPoint(x: '2', y: 7, size: 25),
        UPoint(x: '3', y: 2, size: 40),
      ],
    ),
  ],
);

const _histogramSpec = USpec(
  kind: USpecKind.histogram,
  series: [
    USeries(
      name: 'Distribution',
      points: [
        UPoint(x: '', y: 1),
        UPoint(x: '', y: 2),
        UPoint(x: '', y: 2),
        UPoint(x: '', y: 3),
        UPoint(x: '', y: 3),
        UPoint(x: '', y: 3),
        UPoint(x: '', y: 8),
        UPoint(x: '', y: 9),
        UPoint(x: '', y: 10),
      ],
    ),
  ],
);

const _heatmapSpec = USpec(
  kind: USpecKind.heatmap,
  series: [
    USeries(
      name: 'Row 1',
      points: [
        UPoint(x: 'A', y: 0, z: 1),
        UPoint(x: 'B', y: 0, z: 5),
      ],
    ),
    USeries(
      name: 'Row 2',
      points: [
        UPoint(x: 'A', y: 0, z: 3),
        UPoint(x: 'B', y: 0, z: 9),
      ],
    ),
  ],
);

const _raggedHeatmapSpec = USpec(
  kind: USpecKind.heatmap,
  series: [
    USeries(
      name: 'Row 1',
      points: [
        UPoint(x: 'A', y: 0, z: 1),
        UPoint(x: 'B', y: 0, z: 5),
        UPoint(x: 'C', y: 0, z: 7),
      ],
    ),
    USeries(
      name: 'Row 2',
      points: [
        UPoint(x: 'A', y: 0, z: 3),
        UPoint(x: 'C', y: 0, z: 9),
      ],
    ),
  ],
);

const _uniformHeatmapSpec = USpec(
  kind: USpecKind.heatmap,
  series: [
    USeries(
      name: 'Row 1',
      points: [
        UPoint(x: 'A', y: 0, z: 4),
        UPoint(x: 'B', y: 0, z: 4),
      ],
    ),
  ],
);

const _emptyHeatmapSpec = USpec(kind: USpecKind.heatmap, series: []);

/// Counts the heatmap cells that were given a fill color — cells a row has no
/// value for are left unfilled, and the gradient legend paints a gradient
/// rather than a flat color.
int _filledCells(WidgetTester tester) {
  final containers = tester.widgetList<Container>(
    find.descendant(of: find.byType(HeatmapChartView), matching: find.byType(Container)),
  );
  return containers.where((c) {
    final decoration = c.decoration;
    return decoration is BoxDecoration && decoration.color != null;
  }).length;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}
