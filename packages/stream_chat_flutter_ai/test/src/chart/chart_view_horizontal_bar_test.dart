import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

void main() {
  testWidgets('puts the first category at the top', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_regions))));

    expect(tester.getCenter(find.text('North')).dy, lessThan(tester.getCenter(find.text('South')).dy));
  });

  testWidgets('puts the value axis below the bars', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_regions))));

    expect(tester.getCenter(find.text('0')).dy, greaterThan(tester.getCenter(find.text('South')).dy));
  });

  testWidgets('runs its values left to right', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_regions))));

    expect(tester.getCenter(find.text('0')).dx, lessThan(tester.getCenter(find.text('10')).dx));
  });

  testWidgets('stacks like a vertical bar chart: one rod per category', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_regions, layout: USpecBarLayout.stacked))));

    expect(_chart(tester).data.barGroups.map((g) => g.barRods.length), [1, 1]);
  });

  group('with no theme height', () {
    testWidgets('grows a row per category', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_categories(10)))));

      // 34 per row plus 40 for the value axis.
      expect(_plotHeight(tester), 10 * 34 + 40);
    });

    testWidgets('stays at least 160 tall', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_categories(2)))));

      expect(_plotHeight(tester), 160);
    });

    testWidgets('stops at 1000 tall', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_categories(40)))));

      expect(_plotHeight(tester), 1000);
    });

    testWidgets("gives each row room for the category's grouped bars", (tester) async {
      final series = [
        for (final name in ['A', 'B', 'C', 'D'])
          USeries(
            name: name,
            points: [for (var i = 0; i < 10; i++) UPoint(x: 'Row $i', y: 1)],
          ),
      ];

      await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(series))));

      // Four rods of 10 with 4 between them, plus 12 of air.
      expect(_plotHeight(tester), 10 * (4 * 10 + 3 * 4 + 12) + 40);
    });

    testWidgets('keeps a stacked row 34 tall, one bar whatever the series', (tester) async {
      final series = [
        for (final name in ['A', 'B', 'C', 'D'])
          USeries(
            name: name,
            points: [for (var i = 0; i < 10; i++) UPoint(x: 'Row $i', y: 1)],
          ),
      ];

      await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(series, layout: USpecBarLayout.stacked))));

      expect(_plotHeight(tester), 10 * 34 + 40);
    });
  });

  testWidgets('a theme height wins over the growing height', (tester) async {
    await tester.pumpWidget(
      _wrap(ChartView(spec: _horizontal(_categories(10)), theme: const ChartThemeData(height: 200))),
    );

    expect(_plotHeight(tester), 200);
  });

  testWidgets('sizes the category column to fit the widest label whole', (tester) async {
    await tester.pumpWidget(_wrapSized(ChartView(spec: _horizontal(_regions))));

    expect(tester.renderObject<RenderParagraph>(find.text('South')).didExceedMaxLines, isFalse);
  });

  testWidgets('gives short labels a column narrower than the 40% cap', (tester) async {
    await tester.pumpWidget(_wrapSized(ChartView(spec: _horizontal(_regions))));

    expect(_categoryGutter(tester), lessThan((320 - 16) * 0.4 + 8));
  });

  testWidgets('keeps the category column to 40% of the width', (tester) async {
    const long = 'A category name far too long to show whole';

    await tester.pumpWidget(_wrapSized(ChartView(spec: _horizontal(_single(long)))));

    // 320 wide, less the plot's 16 right inset.
    expect(_categoryGutter(tester), (320 - 16) * 0.4 + 8);
  });

  testWidgets('widens the category column with the text scale', (tester) async {
    await tester.pumpWidget(_wrapSized(ChartView(spec: _horizontal(_regions))));
    final normal = _categoryGutter(tester);

    await tester.pumpWidget(
      _wrapSized(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ChartView(spec: _horizontal(_regions)),
        ),
      ),
    );

    // The glyphs double; the letter spacing and the 8 between a label and its
    // bars don't.
    expect(_categoryGutter(tester) - 8, greaterThan((normal - 8) * 1.9));
  });

  testWidgets('ellipsizes a category label too long for its column', (tester) async {
    const long = 'A category name far too long to show whole';

    await tester.pumpWidget(_wrapSized(ChartView(spec: _horizontal(_single(long)))));

    expect(tester.renderObject<RenderParagraph>(find.text(long)).didExceedMaxLines, isTrue);
  });

  testWidgets('names two series in a legend', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_twoSeries))));

    final names = tester.widgetList<Text>(
      find.descendant(of: find.byKey(ChartView.legendKey), matching: find.byType(Text)),
    );
    expect(names.map((t) => t.data), ['Won', 'Lost']);
  });

  testWidgets('labels the round end of the value axis', (tester) async {
    await tester.pumpWidget(
      _wrapSized(
        ChartView(
          spec: _horizontal(const [
            USeries(
              name: 'S',
              points: [
                UPoint(x: 'A', y: 20),
                UPoint(x: 'B', y: 5),
              ],
            ),
          ]),
        ),
      ),
    );

    expect(find.text('20'), findsOneWidget);
  });

  testWidgets("leaves a negative minimum's own label off the value axis", (tester) async {
    await tester.pumpWidget(
      _wrapSized(
        ChartView(
          spec: _horizontal(const [
            USeries(
              name: 'S',
              points: [
                UPoint(x: 'A', y: 20),
                UPoint(x: 'B', y: -1),
              ],
            ),
          ]),
        ),
      ),
    );

    // At a bubble's width the axis counts in fives; side by side, "-1" would
    // run into the "0" beside it.
    expect(find.text('-1'), findsNothing);
  });

  testWidgets("leaves the largest value's own label off the value axis", (tester) async {
    await tester.pumpWidget(_wrapSized(ChartView(spec: _horizontal(_regions))));

    // At a bubble's width the axis counts in fives, and the largest value is
    // 18; side by side, its label would run into 15's.
    expect(find.text('18'), findsNothing);
  });

  testWidgets('a single series gets no legend', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _horizontal(_regions))));

    expect(find.byKey(ChartView.legendKey), findsNothing);
  });
}

const _regions = [
  USeries(
    name: 'Won',
    points: [
      UPoint(x: 'North', y: 12),
      UPoint(x: 'South', y: 18),
    ],
  ),
];

const _twoSeries = [
  ..._regions,
  USeries(
    name: 'Lost',
    points: [
      UPoint(x: 'North', y: 5),
      UPoint(x: 'South', y: 3),
    ],
  ),
];

/// One series with [count] categories.
List<USeries> _categories(int count) => [
  USeries(
    name: 'S',
    points: [for (var i = 0; i < count; i++) UPoint(x: 'Row $i', y: i + 1)],
  ),
];

/// One series with a single category named [label].
List<USeries> _single(String label) => [
  USeries(
    name: 'S',
    points: [UPoint(x: label, y: 1)],
  ),
];

USpec _horizontal(List<USeries> series, {USpecBarLayout layout = USpecBarLayout.grouped}) =>
    USpec(kind: USpecKind.horizontalBar, barLayout: layout, series: series);

BarChart _chart(WidgetTester tester) => tester.widget<BarChart>(find.byType(BarChart));

/// The width `fl_chart` reserves for the category labels, which it lays out as
/// bottom titles before turning the chart.
double _categoryGutter(WidgetTester tester) => _chart(tester).data.titlesData.bottomTitles.sideTitles.reservedSize;

/// The height of the plot, padding included: the box the chart sits in.
double _plotHeight(WidgetTester tester) =>
    tester.getSize(find.ancestor(of: find.byType(BarChart), matching: find.byType(Container)).first).height;

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// [_wrap] at a phone-bubble width.
Widget _wrapSized(Widget child) => _wrap(Center(child: SizedBox(width: 320, child: child)));
