import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

void main() {
  testWidgets('makes each part as wide as its share', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([50, 30, 20]))));

    // The 800-wide test screen less the 16 insets leaves 768, less two 2-wide
    // gaps to share out.
    const available = 768 - 2 * 2;
    expect(
      _painted(tester),
      paints
        ..rect(rect: const Rect.fromLTWH(0, 0, available * 0.5, 24))
        ..rect(rect: const Rect.fromLTWH(available * 0.5 + 2, 0, available * 0.3, 24))
        ..rect(rect: const Rect.fromLTWH(available * 0.8 + 4, 0, available * 0.2, 24)),
    );
  });

  testWidgets('runs its parts left to right in data order', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([10, 20, 30]), theme: _palette)));

    expect(
      _painted(tester),
      paints
        ..rect(color: _palette.seriesColors![0])
        ..rect(color: _palette.seriesColors![1])
        ..rect(color: _palette.seriesColors![2]),
    );
  });

  testWidgets('narrows the gaps rather than the parts when there are many', (tester) async {
    // 200 parts on a 288-wide bar: 2-wide gaps would take 398, so they share
    // half the bar instead.
    await tester.pumpWidget(_wrapSized(ChartView(spec: _bar(List.filled(200, 1)))));

    const gap = 288 / 2 / 199;
    const part = (288 - gap * 199) / 200;
    expect(
      _painted(tester),
      paints
        ..rect(rect: const Rect.fromLTWH(0, 0, part, 24))
        ..rect(rect: const Rect.fromLTWH(part + gap, 0, part, 24)),
    );
  });

  testWidgets('gives zero, negative and non-finite values no part', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([40, 0, -5, double.infinity, 10]))));

    expect(_painted(tester), paintsExactlyCountTimes(#drawRect, 2));
  });

  testWidgets('leaves zero, negative and non-finite values off the legend', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([40, 0, -5, double.infinity, 10]))));

    expect(_legendLabels(tester), ['Part 0', 'Part 4']);
  });

  testWidgets('is one bar tall whatever the theme height', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([1, 2]), theme: const ChartThemeData(height: 500))));

    // The 24-tall bar and 8 above and below it.
    expect(tester.getSize(find.ancestor(of: _paint, matching: find.byType(Container)).first).height, 24 + 2 * 8);
  });

  testWidgets('labels a part at or above the threshold with its share', (tester) async {
    // 8% is exactly the default threshold.
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([92, 8]))));

    expect(_labels(tester), ['92%', '8%']);
  });

  testWidgets('leaves a part under a threshold the theme sets unlabeled', (tester) async {
    await tester.pumpWidget(
      _wrap(ChartView(spec: _bar([80, 20]), theme: const ChartThemeData(piePercentageThreshold: 0.25))),
    );

    expect(_labels(tester), ['80%', '']);
  });

  testWidgets('leaves a part under the threshold unlabeled', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([95, 5]))));

    expect(_painted(tester), paintsExactlyCountTimes(#drawParagraph, 1));
  });

  testWidgets('labels no part when percentages are off', (tester) async {
    await tester.pumpWidget(
      _wrap(ChartView(spec: _bar([60, 40]), theme: const ChartThemeData(showPiePercentages: false))),
    );

    expect(_painted(tester), paintsExactlyCountTimes(#drawParagraph, 0));
  });

  testWidgets('without a legend, labels a part with its name and share', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _bar([60, 40]), theme: const ChartThemeData(showLegend: false))));

    expect(_labels(tester), ['Part 0 60%', 'Part 1 40%']);
  });

  testWidgets('leaves off a label too wide for its part', (tester) async {
    // A 68-wide bar leaves the 10% part about 7 wide: no room for "10%".
    await tester.pumpWidget(_wrapSized(ChartView(spec: _bar([90, 10])), width: 100));

    expect(_painted(tester), paintsExactlyCountTimes(#drawParagraph, 1));
  });

  testWidgets('picks black or white for each label against its own part', (tester) async {
    const theme = ChartThemeData(seriesColors: [Color(0xFFFFEB3B), Color(0xFF1A237E)]);

    await tester.pumpWidget(_wrap(ChartView(spec: _bar([50, 50]), theme: theme)));

    expect(_labelColors(tester), [Colors.black87, Colors.white]);
  });

  testWidgets('takes the label color the theme sets', (tester) async {
    const theme = ChartThemeData(pieLabelStyle: TextStyle(color: Color(0xFF00FF00)));

    await tester.pumpWidget(_wrap(ChartView(spec: _bar([50, 50]), theme: theme)));

    expect(_labelColors(tester), [const Color(0xFF00FF00), const Color(0xFF00FF00)]);
  });

  testWidgets('splits the bar even when the values are too large to add up', (tester) async {
    // Two of the largest finite doubles add up to infinity.
    await tester.pumpWidget(_wrapSized(ChartView(spec: _bar([double.maxFinite, double.maxFinite]))));

    // 288 wide less one 2-wide gap, halved.
    const half = (288 - 2) / 2;
    expect(
      _painted(tester),
      paints
        ..rect(rect: const Rect.fromLTWH(0, 0, half, 24))
        ..rect(rect: const Rect.fromLTWH(half + 2, 0, half, 24)),
    );
  });

  testWidgets('draws the first series alone', (tester) async {
    final spec = USpec(
      kind: USpecKind.singleStackedBar,
      series: [
        ..._bar([1, 2]).series,
        const USeries(
          name: 'Ignored',
          points: [UPoint(x: 'Extra', y: 99)],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_painted(tester), paintsExactlyCountTimes(#drawRect, 2));
  });

  group('with no positive value', () {
    final spec = _bar([0, -3]);

    testWidgets('draws nothing', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: spec)));

      expect(_paint, findsNothing);
    });

    testWidgets('tells a screen reader there is no data', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: spec)));

      expect(find.bySemanticsLabel('Single stacked bar chart, no data'), findsOneWidget);
    });
  });
}

const _palette = ChartThemeData(seriesColors: [Color(0xFF102030), Color(0xFF405060), Color(0xFF708090)]);

/// A single stacked bar of [values], named `Part 0`, `Part 1`, … by position.
USpec _bar(List<double> values) => USpec(
  kind: USpecKind.singleStackedBar,
  series: [
    USeries(
      name: 'Share',
      points: [for (final (i, v) in values.indexed) UPoint(x: 'Part $i', y: v)],
    ),
  ],
);

Finder get _paint => find.descendant(of: find.byType(ChartView), matching: find.byType(CustomPaint));

RenderObject _painted(WidgetTester tester) => tester.renderObject(_paint);

/// The labels the bar's parts carry, read off its painter: the canvas only
/// records that a paragraph was drawn, not what it said.
List<String> _labels(WidgetTester tester) => [
  // The painter is private to the library; its `parts` are read dynamically.
  for (final part in (tester.widget<CustomPaint>(_paint).painter! as dynamic).parts as List) part.label as String,
];

/// The colors of the labels the bar's parts carry.
List<Color?> _labelColors(WidgetTester tester) => [
  for (final part in (tester.widget<CustomPaint>(_paint).painter! as dynamic).parts as List)
    (part.style as TextStyle).color,
];

List<String> _legendLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byKey(ChartView.legendKey), matching: find.byType(Text)))
    .map((t) => t.data!)
    .toList();

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

/// [_wrap] at [width], 320 by default — a phone bubble.
Widget _wrapSized(Widget child, {double width = 320}) => _wrap(SizedBox(width: width, child: child));
