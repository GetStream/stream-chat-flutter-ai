import 'package:alchemist/alchemist.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_semantics.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/heatmap_chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

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

    group('gapped series', () {
      // A Chart.js `null` — the documented way to write a gap — parses to a
      // series that is simply shorter. Plotting each point at its position
      // within its own list then drew everything after the gap one category to
      // the left of where it belongs.
      const series = [
        USeries(
          name: 'A',
          points: [
            UPoint(x: 'Jan', y: 1),
            UPoint(x: 'Mar', y: 3),
          ],
        ),
        USeries(
          name: 'B',
          points: [
            UPoint(x: 'Jan', y: 4),
            UPoint(x: 'Feb', y: 5),
            UPoint(x: 'Mar', y: 6),
          ],
        ),
      ];
      const spec = USpec(kind: USpecKind.line, series: series);

      testWidgets('places each point on its own category, not its own index', (tester) async {
        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
        final bars = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;

        expect(bars.first.spots.map((s) => s.x), [0, 2], reason: 'March is category 2, not category 1');
        expect(bars.first.spots.map((s) => s.y), [1, 3]);
        expect(bars.last.spots.map((s) => s.x), [0, 1, 2]);
      });

      testWidgets('leaves the gap out of the bar group rather than shifting it', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const ChartView(
              spec: USpec(kind: USpecKind.bar, series: series),
            ),
          ),
        );
        final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

        expect(groups, hasLength(3));
        expect(groups[0].barRods.map((r) => r.toY), [1, 4]);
        expect(groups[1].barRods.map((r) => r.toY), [5], reason: 'A has no February value');
        expect(groups[2].barRods.map((r) => r.toY), [3, 6]);
      });
    });

    testWidgets('a histogram keeps positional bars despite its repeated empty labels', (tester) async {
      // Its samples all carry the same (empty) x, so labels are no use as keys
      // and the positional fallback has to stay.
      await tester.pumpWidget(_wrap(const ChartView(spec: _histogramSpec)));
      final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

      expect(groups.length, greaterThan(1));
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

    group('theming', () {
      testWidgets('a host palette overrides the line series color', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _lineSpec),
            const ChartThemeData(seriesColors: [Color(0xFFFF0000)]),
          ),
        );

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.lineBarsData.single.color, const Color(0xFFFF0000));
      });

      testWidgets('the area fill follows the palette', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _areaSpec),
            const ChartThemeData(seriesColors: [Color(0xFFFF0000)]),
          ),
        );

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.lineBarsData.single.belowBarData.color, const Color(0xFFFF0000).withValues(alpha: 0.15));
      });

      testWidgets('a host palette overrides the bar rod colors', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _barSpec),
            const ChartThemeData(seriesColors: [Color(0xFF00FF00)]),
          ),
        );

        final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
        expect(groups.first.barRods.first.color, const Color(0xFF00FF00));
      });

      testWidgets('the palette cycles when it is shorter than the data', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _pieSpec),
            const ChartThemeData(seriesColors: [Color(0xFFFF0000), Color(0xFF00FF00)]),
          ),
        );

        final sections = tester.widget<PieChart>(find.byType(PieChart)).data.sections;
        expect(sections.map((s) => s.color), [
          const Color(0xFFFF0000),
          const Color(0xFF00FF00),
          const Color(0xFFFF0000),
        ]);
      });

      testWidgets('an empty palette falls back to the default one', (tester) async {
        // Cycling an empty palette has no answer, and `index % 0` throws.
        await tester.pumpWidget(
          _wrapThemed(const ChartView(spec: _lineSpec), const ChartThemeData(seriesColors: [])),
        );

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.lineBarsData.single.color, kDefaultChartSeriesColors.first);
      });

      testWidgets('the chart height follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(const ChartView(spec: _lineSpec), const ChartThemeData(height: 320)),
        );

        final plot = find.descendant(of: find.byType(ChartView), matching: find.byType(Container));
        expect(tester.getSize(plot.first).height, 320);
      });

      testWidgets('the histogram bucket count follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(const ChartView(spec: _histogramSpec), const ChartThemeData(histogramBinCount: 4)),
        );

        expect(tester.widget<BarChart>(find.byType(BarChart)).data.barGroups, hasLength(4));
      });

      testWidgets('the scatter marker radius follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(const ChartView(spec: _scatterSpec), const ChartThemeData(scatterRadius: 12)),
        );

        final spots = tester.widget<ScatterChart>(find.byType(ScatterChart)).data.scatterSpots;
        expect(spots.map((s) => (s.dotPainter as FlDotCirclePainter).radius), everyElement(12.0));
      });

      testWidgets('the bubble radius range follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _bubbleSpec),
            const ChartThemeData(bubbleMinRadius: 4, bubbleMaxRadius: 10),
          ),
        );

        final spots = tester.widget<ScatterChart>(find.byType(ScatterChart)).data.scatterSpots;
        final radii = spots.map((s) => (s.dotPainter as FlDotCirclePainter).radius).toList();
        expect(radii.first, 4, reason: 'the smallest size sits at the bottom of the range');
        expect(radii.last, 10, reason: 'the largest at the top');
      });

      testWidgets('the grid line color follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(const ChartView(spec: _lineSpec), const ChartThemeData(gridLineColor: Color(0xFF123456))),
        );

        final grid = tester.widget<LineChart>(find.byType(LineChart)).data.gridData;
        expect(grid.getDrawingHorizontalLine(0).color, const Color(0xFF123456));
      });

      testWidgets('the axis label style follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _barSpec),
            const ChartThemeData(axisLabelStyle: TextStyle(color: Color(0xFF654321), fontSize: 14)),
          ),
        );

        final label = tester.widget<Text>(find.text('Jan'));
        expect(label.style?.color, const Color(0xFF654321));
        expect(label.style?.fontSize, 14);
      });

      testWidgets('the title style follows the theme', (tester) async {
        const spec = USpec(
          title: 'Titled',
          kind: USpecKind.bar,
          series: [
            USeries(
              name: 'A',
              points: [UPoint(x: 'Jan', y: 1)],
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: spec),
            const ChartThemeData(titleTextStyle: TextStyle(color: Color(0xFFABCDEF))),
          ),
        );

        expect(tester.widget<Text>(find.text('Titled')).style?.color, const Color(0xFFABCDEF));
      });

      testWidgets('the heatmap ramp follows the theme', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            const ChartView(spec: _heatmapSpec),
            const ChartThemeData(
              heatmapLowColor: Color(0xFFFF0000),
              heatmapMidColor: Color(0xFF00FF00),
              heatmapHighColor: Color(0xFF0000FF),
            ),
          ),
        );

        final fills = tester
            .widgetList<Container>(
              find.descendant(of: find.byType(HeatmapChartView), matching: find.byType(Container)),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.color)
            .whereType<Color>();

        expect(fills, contains(const Color(0xFFFF0000)), reason: 'the minimum cell sits at the low stop');
        expect(fills, contains(const Color(0xFF0000FF)), reason: 'the maximum at the high stop');
      });

      group('precedence', () {
        testWidgets('the theme parameter wins over the ambient extension', (tester) async {
          await tester.pumpWidget(
            _wrapThemed(
              const ChartView(
                spec: _lineSpec,
                theme: ChartThemeData(seriesColors: [Color(0xFF0000FF)]),
              ),
              const ChartThemeData(seriesColors: [Color(0xFFFF0000)]),
            ),
          );

          final data = tester.widget<LineChart>(find.byType(LineChart)).data;
          expect(data.lineBarsData.single.color, const Color(0xFF0000FF));
        });

        testWidgets('a ChartTheme scope wins over the ambient extension', (tester) async {
          await tester.pumpWidget(
            _wrapThemed(
              const ChartTheme(
                data: ChartThemeData(seriesColors: [Color(0xFF0000FF)]),
                child: ChartView(spec: _lineSpec),
              ),
              const ChartThemeData(seriesColors: [Color(0xFFFF0000)], height: 320),
            ),
          );

          final data = tester.widget<LineChart>(find.byType(LineChart)).data;
          expect(data.lineBarsData.single.color, const Color(0xFF0000FF));

          final plot = find.descendant(of: find.byType(ChartView), matching: find.byType(Container));
          expect(
            tester.getSize(plot.first).height,
            320,
            reason: 'what the scope leaves unset still comes from AITheme',
          );
        });
      });

      group('pie slice labels', () {
        // The label was hardcoded white, which disappears on a light slice —
        // and a host palette is free to contain one.
        testWidgets('are chosen for contrast against their own slice', (tester) async {
          await tester.pumpWidget(
            _wrapThemed(
              const ChartView(spec: _pieSpec),
              const ChartThemeData(
                seriesColors: [Color(0xFF000080), Color(0xFFFFFF00), Color(0xFF000080)],
              ),
            ),
          );

          final sections = tester.widget<PieChart>(find.byType(PieChart)).data.sections;
          expect(sections[0].titleStyle?.color, Colors.white, reason: 'navy slice');
          expect(sections[1].titleStyle?.color, Colors.black87, reason: 'yellow slice');
        });

        testWidgets('take a color the host set outright', (tester) async {
          await tester.pumpWidget(
            _wrapThemed(
              const ChartView(spec: _pieSpec),
              const ChartThemeData(
                seriesColors: [Color(0xFFFFFF00)],
                pieLabelStyle: TextStyle(color: Color(0xFF112233)),
              ),
            ),
          );

          final sections = tester.widget<PieChart>(find.byType(PieChart)).data.sections;
          expect(sections.first.titleStyle?.color, const Color(0xFF112233));
        });
      });
    });

    group('semantics', () {
      // ensureSemantics' handle has to be disposed inside the test body: the
      // framework checks for live handles before addTearDown callbacks run.
      testWidgets('summarises the chart in one node', (tester) async {
        final handle = tester.ensureSemantics();

        const spec = USpec(
          title: 'Messages per day',
          kind: USpecKind.bar,
          series: [
            USeries(
              name: 'Messages',
              points: [
                UPoint(x: 'Mon', y: 8),
                UPoint(x: 'Tue', y: 24),
              ],
            ),
          ],
        );

        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

        expect(
          tester.getSemantics(find.byType(ChartView)).label,
          'Bar chart, Messages per day, 2 categories, values 8 to 24',
        );
        handle.dispose();
      });

      testWidgets('excludes the axis labels from the semantics tree', (tester) async {
        // Deliberate: fl_chart contributes nothing, but the tick labels are
        // real Text widgets, and walking them gives a reader a run of bare
        // numbers with nothing saying which axis they belong to.
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_wrap(const ChartView(spec: _barSpec)));

        expect(find.text('Jan'), findsOneWidget);
        expect(find.bySemanticsLabel('Jan'), findsNothing);
        handle.dispose();
      });

      testWidgets('semanticsLabel replaces the derived summary', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_wrap(const ChartView(spec: _barSpec, semanticsLabel: 'Sales by month')));

        expect(tester.getSemantics(find.byType(ChartView)).label, 'Sales by month');
        handle.dispose();
      });

      testWidgets('an empty semanticsLabel adds no node at all', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_wrap(const ChartView(spec: _barSpec, semanticsLabel: '')));

        expect(find.bySemanticsLabel(RegExp('Bar chart')), findsNothing);
        expect(find.bySemanticsLabel('Jan'), findsOneWidget, reason: 'nothing excludes the tick labels now');
        handle.dispose();
      });

      testWidgets('a heatmap gets one node rather than two', (tester) async {
        // ChartView wraps the whole thing, so the delegated grid must not add
        // a nested node of its own.
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_wrap(const ChartView(spec: _heatmapSpec)));

        expect(tester.getSemantics(find.byType(ChartView)).label, 'Heatmap, 2 rows by 2 columns, values 1 to 9');
        expect(find.bySemanticsLabel('Row 1'), findsNothing);
        handle.dispose();
      });

      testWidgets('a standalone heatmap describes itself', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_wrap(const HeatmapChartView(spec: _heatmapSpec)));

        expect(
          tester.getSemantics(find.byType(HeatmapChartView)).label,
          'Heatmap, 2 rows by 2 columns, values 1 to 9',
        );
        handle.dispose();
      });

      testWidgets('the summary follows the translations', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrap(
            const AITranslationsScope(
              translations: _TestTranslations(),
              child: ChartView(spec: _barSpec),
            ),
          ),
        );

        expect(tester.getSemantics(find.byType(ChartView)).label, 'STAAFDIAGRAM');
        handle.dispose();
      });

      testWidgets('a heatmap row the data did not name gets the translated fallback', (tester) async {
        const spec = USpec(
          kind: USpecKind.heatmap,
          series: [
            USeries(
              name: '',
              points: [UPoint(x: 'A', y: 0, z: 1)],
            ),
          ],
        );

        await tester.pumpWidget(_wrap(const ChartView(spec: spec)));
        expect(find.text('Series'), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            const AITranslationsScope(
              translations: _TestTranslations(),
              child: ChartView(spec: spec),
            ),
          ),
        );
        expect(find.text('Reeks'), findsOneWidget);
        expect(find.text('Series'), findsNothing);
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

/// [_wrap] with [chartTheme] registered the way a host app would register it.
Widget _wrapThemed(Widget child, ChartThemeData chartTheme) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(extensions: [AITheme(chartTheme: chartTheme)]),
    home: Scaffold(body: Center(child: child)),
  );
}

class _TestTranslations extends DefaultAITranslations {
  const _TestTranslations();

  @override
  String get unnamedChartSeries => 'Reeks';

  @override
  String chartSemanticsLabel(ChartSemantics chart) => 'STAAFDIAGRAM';
}
