import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

void main() {
  testWidgets('draws a spoke per category, in axis order', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radar(_twoSeries))));

    final data = _data(tester);
    expect([for (var i = 0; i < data.titleCount; i++) data.getTitle!(i, 0).text], ['Speed', 'Range', 'Price']);
  });

  testWidgets('fills each series in its color at 0.2 opacity, outlined in it', (tester) async {
    const palette = [Color(0xFF112233), Color(0xFF445566)];

    await tester.pumpWidget(
      _wrap(
        ChartView(
          spec: _radar(_twoSeries),
          theme: const ChartThemeData(seriesColors: palette),
        ),
      ),
    );

    final shapes = _data(tester).dataSets.take(2);
    expect(shapes.map((s) => (s.fillColor, s.borderColor)), [
      for (final color in palette) (color.withValues(alpha: 0.2), color),
    ]);
  });

  testWidgets('measures from a center of zero, not from the smallest value', (tester) async {
    // The smallest value is 2; fl_chart puts the smallest value plotted at the
    // center, so the chart has to plot a zero for the center to be zero.
    await tester.pumpWidget(_wrap(ChartView(spec: _radar(_twoSeries))));

    final data = _data(tester);
    expect((data.isMinValueAtCenter, data.minEntry.value), (true, 0));
  });

  testWidgets('draws the zero it measures from invisibly', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radar(_twoSeries))));

    final zero = _data(tester).dataSets.last;
    expect((zero.fillColor, zero.borderColor), (Colors.transparent, Colors.transparent));
  });

  testWidgets('puts a negative value at the center', (tester) async {
    final spec = _radar([
      _series('A', {'Speed': 4, 'Range': -2, 'Price': 3}),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_values(tester, 0), [4, 0, 3]);
  });

  testWidgets('puts a category the series has no point for at the center', (tester) async {
    final spec = _radar([
      _series('A', {'Speed': 4, 'Range': 5, 'Price': 3}),
      _series('B', {'Speed': 2, 'Price': 1}),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_values(tester, 1), [2, 0, 1]);
  });

  testWidgets('puts a value that is not finite at the center', (tester) async {
    final spec = _radar([
      _series('A', {'Speed': 4, 'Range': double.infinity, 'Price': 3}),
    ]);

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_values(tester, 0), [4, 0, 3]);
  });

  group('with fewer than three categories', () {
    final spec = _radar([
      _series('A', {'Speed': 4, 'Range': 5}),
    ]);

    testWidgets('draws nothing', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: spec)));

      expect(find.byType(RadarChart), findsNothing);
    });

    testWidgets('tells a screen reader there is no data', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: spec)));

      expect(find.bySemanticsLabel('Radar chart, no data'), findsOneWidget);
    });

    testWidgets('shows no legend, there being no shape to explain', (tester) async {
      final twoSeries = _radar([
        _series('A', {'Speed': 4, 'Range': 5}),
        _series('B', {'Speed': 2, 'Range': 1}),
      ]);

      await tester.pumpWidget(_wrap(ChartView(spec: twoSeries)));

      expect(find.byKey(ChartView.legendKey), findsNothing);
    });
  });

  testWidgets('draws its rings, spokes and edge in the grid line color', (tester) async {
    const grid = Color(0xFFABCDEF);

    await tester.pumpWidget(
      _wrap(
        ChartView(
          spec: _radar(_twoSeries),
          theme: const ChartThemeData(gridLineColor: grid),
        ),
      ),
    );

    final data = _data(tester);
    expect([data.tickBorderData.color, data.gridBorderData.color, data.radarBorderData.color], [grid, grid, grid]);
  });

  testWidgets('labels its spokes in the axis label style', (tester) async {
    const style = TextStyle(fontSize: 13, color: Color(0xFF654321));

    await tester.pumpWidget(
      _wrap(
        ChartView(
          spec: _radar(_twoSeries),
          theme: const ChartThemeData(axisLabelStyle: style),
        ),
      ),
    );

    final title = _data(tester).titleTextStyle!;
    expect((title.fontSize, title.color), (13, const Color(0xFF654321)));
  });

  testWidgets('paints no ring values', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radar(_twoSeries))));

    expect(_data(tester).ticksTextStyle?.color, Colors.transparent);
  });

  testWidgets('cuts a label wider than a third of the chart without splitting an emoji', (tester) async {
    const long = 'AB🔋🔋🔋🔋🔋🔋🔋🔋🔋🔋🔋🔋🔋🔋';
    final spec = _radar([
      _series('A', {long: 4, 'Range': 5, 'Price': 3}),
    ]);

    await tester.pumpWidget(_wrapSized(ChartView(spec: spec)));

    final label = _data(tester).getTitle!(0, 0).text;
    final kept = label.substring(0, label.length - 1);
    expect(label, endsWith('…'));
    // Cut inside the run of emoji, not before it, so a split one would show.
    expect(kept.characters.length, greaterThan(2));
    expect(long.characters.take(kept.characters.length).string, kept);
  });

  testWidgets('names two series in a legend', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radar(_twoSeries))));

    final names = tester.widgetList<Text>(
      find.descendant(of: find.byKey(ChartView.legendKey), matching: find.byType(Text)),
    );
    expect(names.map((t) => t.data), ['Car', 'Bike']);
  });
}

final _twoSeries = [
  _series('Car', {'Speed': 8, 'Range': 5, 'Price': 4}),
  _series('Bike', {'Speed': 3, 'Range': 2, 'Price': 9}),
];

USeries _series(String name, Map<String, double> values) => USeries(
  name: name,
  points: [for (final MapEntry(:key, :value) in values.entries) UPoint(x: key, y: value)],
);

USpec _radar(List<USeries> series) => USpec(kind: USpecKind.radar, series: series);

RadarChartData _data(WidgetTester tester) => tester.widget<RadarChart>(find.byType(RadarChart)).data;

/// Where the [index]-th series sits on each spoke.
List<double> _values(WidgetTester tester, int index) =>
    _data(tester).dataSets[index].dataEntries.map((e) => e.value).toList();

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

/// [_wrap] at a phone-bubble width.
Widget _wrapSized(Widget child) => _wrap(SizedBox(width: 320, child: child));
