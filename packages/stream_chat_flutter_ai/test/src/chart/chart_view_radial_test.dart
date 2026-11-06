import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';
import 'package:stream_core_flutter/core.dart';

void main() {
  testWidgets('draws a track per value', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 30, 20]))));

    expect(_rings(tester), paintsExactlyCountTimes(#drawCircle, 3));
  });

  testWidgets('draws an arc per value', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 30, 20]))));

    expect(_rings(tester), paintsExactlyCountTimes(#drawArc, 3));
  });

  testWidgets("puts the first value's ring outermost", (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([10, 40]), theme: _palette)));

    // In a 204-tall plot the outer ring's center line sits half its 11-wide
    // stroke inside the 102 radius, and the next ring 16 further in.
    expect(
      _rings(tester),
      paints
        ..arc(
          color: _palette.seriesColors![0],
          rect: Rect.fromCircle(center: _center(tester), radius: 102 - 5.5),
        )
        ..arc(
          color: _palette.seriesColors![1],
          rect: Rect.fromCircle(center: _center(tester), radius: 102 - 16 - 5.5),
        ),
    );
  });

  testWidgets('sweeps three quarters of a turn for the largest value', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40]))));

    expect(_rings(tester), paints..arc(sweepAngle: 1.5 * math.pi));
  });

  testWidgets('sweeps a smaller value in proportion to the largest', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 20]))));

    expect(
      _rings(tester),
      paints
        ..arc(sweepAngle: 1.5 * math.pi)
        ..arc(sweepAngle: 0.75 * math.pi),
    );
  });

  testWidgets('starts every arc at the top', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 20, 10]))));

    expect(
      _rings(tester),
      paints
        ..arc(startAngle: -math.pi / 2)
        ..arc(startAngle: -math.pi / 2)
        ..arc(startAngle: -math.pi / 2),
    );
  });

  testWidgets('gives zero, negative and non-finite values no ring', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 0, -5, double.nan, 10]))));

    expect(_rings(tester), paintsExactlyCountTimes(#drawArc, 2));
  });

  testWidgets('leaves zero, negative and non-finite values off the legend', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 0, -5, double.nan, 10]))));

    expect(_legendLabels(tester), ['Ring 0', 'Ring 4']);
  });

  group('with no positive value', () {
    final spec = _radial([0, -3]);

    testWidgets('draws nothing', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: spec)));

      expect(find.descendant(of: find.byType(ChartView), matching: find.byType(CustomPaint)), findsNothing);
    });

    testWidgets('tells a screen reader there is no data', (tester) async {
      await tester.pumpWidget(_wrap(ChartView(spec: spec)));

      expect(find.bySemanticsLabel('Radial chart, no data'), findsOneWidget);
    });
  });

  testWidgets('thins its rings to fit many values rather than dropping any', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([7, 6, 5, 4, 3, 2, 1]))));

    // (102 − 12) / 7 between rings, 11/16 of that for the stroke; a paint
    // stores its stroke width in single precision.
    expect(
      _rings(tester),
      paints..circle(strokeWidth: Float32List.fromList([(102 - 12) / 7 * 11 / 16]).single),
    );
    expect(_rings(tester), paintsExactlyCountTimes(#drawCircle, 7));
  });

  testWidgets('draws nothing when the plot has no room for a ring', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40]), theme: const ChartThemeData(height: 20))));

    expect(_rings(tester), paintsExactlyCountTimes(#drawCircle, 0));
    expect(_rings(tester), paintsExactlyCountTimes(#drawArc, 0));
  });

  testWidgets('takes the palette in order', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 30]), theme: _palette)));

    expect(
      _rings(tester),
      paints
        ..arc(color: _palette.seriesColors![0])
        ..arc(color: _palette.seriesColors![1]),
    );
  });

  testWidgets("draws the track in the Stream theme's subtle surface by default", (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40]))));

    final subtle = tester.element(find.byType(ChartView)).streamColorScheme.backgroundSurfaceSubtle;
    expect(_rings(tester), paints..circle(color: subtle));
  });

  testWidgets('draws the track in the theme color when set', (tester) async {
    const track = Color(0xFF13579B);

    await tester.pumpWidget(
      _wrap(
        ChartView(
          spec: _radial([40]),
          theme: const ChartThemeData(radialTrackColor: track),
        ),
      ),
    );

    expect(_rings(tester), paints..circle(color: track));
  });

  testWidgets('draws the first series alone', (tester) async {
    final spec = USpec(
      kind: USpecKind.radial,
      series: [
        ..._radial([40, 30]).series,
        const USeries(
          name: 'Ignored',
          points: [UPoint(x: 'Extra', y: 99)],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(ChartView(spec: spec)));

    expect(_rings(tester), paintsExactlyCountTimes(#drawCircle, 2));
  });

  testWidgets('gives a ring the data left unnamed a numbered name', (tester) async {
    const spec = USpec(
      kind: USpecKind.radial,
      series: [
        USeries(
          name: 'Share',
          points: [
            UPoint(x: 'Chat', y: 40),
            UPoint(x: '', y: 20),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(const ChartView(spec: spec)));

    expect(_legendLabels(tester), ['Chat', 'Slice 2']);
  });

  testWidgets('shows no legend when the theme turns it off', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40, 30]), theme: const ChartThemeData(showLegend: false))));

    expect(find.byKey(ChartView.legendKey), findsNothing);
  });

  testWidgets('names a single ring in a legend', (tester) async {
    await tester.pumpWidget(_wrap(ChartView(spec: _radial([40]))));

    expect(_legendLabels(tester), ['Ring 0']);
  });
}

const _palette = ChartThemeData(seriesColors: [Color(0xFF102030), Color(0xFF405060)]);

/// A radial chart of [values], named `Ring 0`, `Ring 1`, … by position.
USpec _radial(List<double> values) => USpec(
  kind: USpecKind.radial,
  series: [
    USeries(
      name: 'Share',
      points: [for (final (i, v) in values.indexed) UPoint(x: 'Ring $i', y: v)],
    ),
  ],
);

Finder get _paint => find.descendant(of: find.byType(ChartView), matching: find.byType(CustomPaint));

RenderObject _rings(WidgetTester tester) => tester.renderObject(_paint);

/// The center of the rings, relative to the painter.
Offset _center(WidgetTester tester) => tester.getSize(_paint).center(Offset.zero);

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
