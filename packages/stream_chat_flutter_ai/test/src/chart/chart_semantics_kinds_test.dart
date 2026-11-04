import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

// The facts and the English sentence for the horizontal bar, radar, radial and
// single stacked bar kinds, and for the bar layout, curve and pie shape
// options.
void main() {
  test('a radial chart describes its first series alone', () {
    final chart = ChartSemantics.fromSpec(_twoSeries(USpecKind.radial), unnamedSeries: 'Series');

    expect(chart.pointCount, 2);
  });

  test('a single stacked bar describes its first series alone', () {
    final chart = ChartSemantics.fromSpec(_twoSeries(USpecKind.singleStackedBar), unnamedSeries: 'Series');

    expect(chart.pointCount, 2);
  });

  test('a radial chart names only the rings it draws', () {
    final chart = ChartSemantics.fromSpec(_withUndrawn(USpecKind.radial), unnamedSeries: 'Series');

    expect(chart.sliceLabels, ['Chat', 'Video']);
  });

  test("a radial chart's range covers only the rings it draws", () {
    final chart = ChartSemantics.fromSpec(_withUndrawn(USpecKind.radial), unnamedSeries: 'Series');

    expect((chart.valueMin, chart.valueMax), ('20', '60'));
  });

  test('a radial chart names its largest ring without a share of the total', () {
    final chart = ChartSemantics.fromSpec(_withUndrawn(USpecKind.radial), unnamedSeries: 'Series');

    expect((chart.largestSliceLabel, chart.largestSlicePercent), ('Chat', null));
  });

  test("a single stacked bar reports its largest part's share", () {
    final chart = ChartSemantics.fromSpec(_withUndrawn(USpecKind.singleStackedBar), unnamedSeries: 'Series');

    expect((chart.largestSliceLabel, chart.largestSlicePercent), ('Chat', '75'));
  });

  test('a single stacked bar reports its largest share even when its values are too large to add up', () {
    const spec = USpec(
      kind: USpecKind.singleStackedBar,
      series: [
        USeries(
          name: 'S',
          points: [
            UPoint(x: 'A', y: double.maxFinite),
            UPoint(x: 'B', y: double.maxFinite),
          ],
        ),
      ],
    );

    expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').largestSlicePercent, '50');
  });

  test('a radial chart with no positive value is empty', () {
    const spec = USpec(
      kind: USpecKind.radial,
      series: [
        USeries(
          name: 'S',
          points: [
            UPoint(x: 'A', y: 0),
            UPoint(x: 'B', y: -1),
          ],
        ),
      ],
    );

    expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').isEmpty, isTrue);
  });

  test('counts the categories of every series together', () {
    const spec = USpec(
      kind: USpecKind.radar,
      series: [
        USeries(
          name: 'A',
          points: [
            UPoint(x: 'Speed', y: 1),
            UPoint(x: 'Range', y: 2),
          ],
        ),
        USeries(
          name: 'B',
          points: [
            UPoint(x: 'Speed', y: 1),
            UPoint(x: 'Price', y: 2),
          ],
        ),
      ],
    );

    expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').categoryCount, 3);
  });

  test('is empty with fewer than three categories, which make no shape', () {
    const spec = USpec(
      kind: USpecKind.radar,
      series: [
        USeries(
          name: 'A',
          points: [
            UPoint(x: 'Speed', y: 1),
            UPoint(x: 'Range', y: 2),
          ],
        ),
      ],
    );

    expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').isEmpty, isTrue);
  });

  test('describes a horizontal bar chart like a bar chart', () {
    const spec = USpec(
      kind: USpecKind.horizontalBar,
      xLabel: 'Deals',
      series: [
        USeries(
          name: 'Won',
          points: [
            UPoint(x: 'North', y: 12),
            UPoint(x: 'South', y: 18),
          ],
        ),
        USeries(
          name: 'Lost',
          points: [
            UPoint(x: 'North', y: 5),
            UPoint(x: 'South', y: 3),
          ],
        ),
      ],
    );

    expect(
      _label(spec),
      'Horizontal bar chart, Deals on the x axis, 2 series: Won, Lost, 2 categories, values 3 to 18',
    );
  });

  test('describes a radar by its series and spokes, with no axes', () {
    const spec = USpec(
      kind: USpecKind.radar,
      xLabel: 'Ignored',
      series: [
        USeries(
          name: 'Car',
          points: [
            UPoint(x: 'Speed', y: 8),
            UPoint(x: 'Range', y: 5),
            UPoint(x: 'Price', y: 4),
          ],
        ),
        USeries(
          name: 'Bike',
          points: [
            UPoint(x: 'Speed', y: 3),
            UPoint(x: 'Range', y: 2),
            UPoint(x: 'Price', y: 9),
          ],
        ),
      ],
    );

    expect(_label(spec), 'Radar chart, 2 series: Car, Bike, 3 categories, values 2 to 9');
  });

  test('describes a radial chart by its rings and their range', () {
    expect(_label(_withUndrawn(USpecKind.radial)), 'Radial chart, 2 rings: Chat, Video, values 20 to 60');
  });

  test('describes a single stacked bar by its parts and the largest share', () {
    expect(
      _label(_withUndrawn(USpecKind.singleStackedBar)),
      'Single stacked bar chart, 2 parts: Chat, Video, largest Chat at 75 percent',
    );
  });

  test('reads a stacked bar chart like a grouped one', () {
    const grouped = USpec(kind: USpecKind.bar, series: _twoNamed);
    const stacked = USpec(kind: USpecKind.bar, barLayout: USpecBarLayout.stacked, series: _twoNamed);

    expect(_label(stacked), _label(grouped));
  });

  test('reads a natural line like a straight one', () {
    const linear = USpec(kind: USpecKind.line, series: _twoNamed);
    const natural = USpec(kind: USpecKind.line, curve: USpecCurve.natural, series: _twoNamed);

    expect(_label(natural), _label(linear));
  });

  test('reads a donut like a pie', () {
    const pie = USpec(kind: USpecKind.pie, series: _twoNamed);
    const donut = USpec(kind: USpecKind.pie, donut: true, series: _twoNamed);

    expect(_label(donut), _label(pie));
  });

  test('reads a semicircle like a pie', () {
    const pie = USpec(kind: USpecKind.pie, series: _twoNamed);
    const semicircle = USpec(kind: USpecKind.pie, semicircle: true, series: _twoNamed);

    expect(_label(semicircle), _label(pie));
  });

  test("a radar's range is where its values sit: a negative one at zero", () {
    const spec = USpec(
      kind: USpecKind.radar,
      series: [
        USeries(
          name: 'A',
          points: [
            UPoint(x: 'Speed', y: -5),
            UPoint(x: 'Range', y: 3),
            UPoint(x: 'Price', y: 10),
          ],
        ),
      ],
    );

    final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
    expect((chart.valueMin, chart.valueMax), ('0', '10'));
  });

  test("a radar's range puts a value that isn't finite at zero", () {
    const spec = USpec(
      kind: USpecKind.radar,
      series: [
        USeries(
          name: 'A',
          points: [
            UPoint(x: 'Speed', y: 4),
            UPoint(x: 'Range', y: double.infinity),
            UPoint(x: 'Price', y: 10),
          ],
        ),
      ],
    );

    final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
    expect((chart.valueMin, chart.valueMax), ('0', '10'));
  });
}

const _twoNamed = [
  USeries(
    name: 'A',
    points: [
      UPoint(x: 'Jan', y: 3),
      UPoint(x: 'Feb', y: 5),
    ],
  ),
  USeries(
    name: 'B',
    points: [
      UPoint(x: 'Jan', y: 2),
      UPoint(x: 'Feb', y: 4),
    ],
  ),
];

/// A [kind] chart with two series of two points; only the first is drawn.
USpec _twoSeries(USpecKind kind) => USpec(kind: kind, series: _twoNamed);

/// A [kind] chart whose first series draws two parts, Chat at 60 and Video at
/// 20, and holds a zero, a negative and a non-finite value it doesn't draw.
USpec _withUndrawn(USpecKind kind) => USpec(
  kind: kind,
  series: const [
    USeries(
      name: 'Share',
      points: [
        UPoint(x: 'Chat', y: 60),
        UPoint(x: 'None', y: 0),
        UPoint(x: 'Refunds', y: -10),
        UPoint(x: 'Broken', y: double.nan),
        UPoint(x: 'Video', y: 20),
      ],
    ),
  ],
);

const _translations = DefaultAITranslations();

String _label(USpec spec) => _translations.chartSemanticsLabel(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series'));
