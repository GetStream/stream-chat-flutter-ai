import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _translations = DefaultAITranslations();

String _label(USpec spec) => _translations.chartSemanticsLabel(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series'));

void main() {
  group('ChartSemantics', () {
    test('gathers the facts a summary needs', () {
      final chart = ChartSemantics.fromSpec(_barSpec, unnamedSeries: 'Series');

      expect(chart.kind, USpecKind.bar);
      expect(chart.title, 'Messages per day');
      expect(chart.seriesNames, ['Messages']);
      expect(chart.pointCount, 5);
      expect(chart.categoryCount, 5);
      expect(chart.valueMin, '8');
      expect(chart.valueMax, '24');
      expect(chart.isEmpty, isFalse);
    });

    test('drops a blank title', () {
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

      expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').title, isNull);
    });

    test('names a series the data left unnamed', () {
      // The parser leaves these empty rather than inventing an English word;
      // the name is resolved here, where a translation is available.
      const spec = USpec(
        kind: USpecKind.line,
        series: [
          USeries(
            name: '',
            points: [UPoint(x: 'Jan', y: 1)],
          ),
          USeries(
            name: 'Named',
            points: [UPoint(x: 'Feb', y: 2)],
          ),
        ],
      );

      expect(
        ChartSemantics.fromSpec(spec, unnamedSeries: 'Reeks').seriesNames,
        ['Reeks', 'Named'],
      );
    });

    test('counts a heatmap by rows and columns, and reads its z values', () {
      final chart = ChartSemantics.fromSpec(_heatmapSpec, unnamedSeries: 'Series');

      expect(chart.rowCount, 2);
      expect(chart.columnCount, 3);
      expect(chart.valueMin, '1', reason: 'a heatmap encodes its value in z, not y');
      expect(chart.valueMax, '9');
    });

    test('falls back to the longest series when labels repeat', () {
      // A histogram's raw samples all share an empty x, so the labels are not
      // usable as category keys — the axis is as long as the series instead.
      const spec = USpec(
        kind: USpecKind.histogram,
        series: [
          USeries(
            name: 'Samples',
            points: [
              UPoint(x: '', y: 1),
              UPoint(x: '', y: 2),
              UPoint(x: '', y: 3),
            ],
          ),
        ],
      );

      expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').categoryCount, 3);
    });

    group('kinds that draw only the first series', () {
      // ChartView plots series.first for a pie and a histogram and ignores the
      // rest, so the spoken summary has to do the same or it announces a count
      // nobody can see.
      const twoSeriesPie = USpec(
        kind: USpecKind.pie,
        series: [
          USeries(
            name: 'Drawn',
            points: [
              UPoint(x: 'Chrome', y: 60),
              UPoint(x: 'Safari', y: 40),
            ],
          ),
          USeries(
            name: 'Ignored',
            points: [
              UPoint(x: 'Edge', y: 5),
              UPoint(x: 'Opera', y: 5),
            ],
          ),
        ],
      );

      test('a pie counts only the slices it draws', () {
        final chart = ChartSemantics.fromSpec(twoSeriesPie, unnamedSeries: 'Series');

        expect(chart.pointCount, 2, reason: 'four points, but only the first series is plotted');
        expect(chart.seriesNames, ['Drawn']);
        expect(chart.rowCount, 1);
        expect(chart.valueMax, '60');
        expect(chart.largestSliceLabel, 'Chrome');
        expect(chart.largestSlicePercent, '60', reason: 'a share of the drawn series, not of all four points');
      });

      test('a histogram counts only the samples it bins', () {
        const spec = USpec(
          kind: USpecKind.histogram,
          series: [
            USeries(
              name: 'Drawn',
              points: [
                UPoint(x: '0', y: 1),
                UPoint(x: '1', y: 9),
              ],
            ),
            USeries(
              name: 'Ignored',
              points: [UPoint(x: '2', y: 100)],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');

        expect(chart.pointCount, 2);
        expect(chart.valueMax, '9', reason: 'the ignored series must not widen the range');
      });

      test('a pie whose first series is empty describes an empty chart rather than throwing', () {
        // Reachable through the public const USpec constructor, which
        // validates nothing. ChartView renders this as an empty pie, so the
        // summary must not be the thing that crashes the frame.
        const spec = USpec(
          kind: USpecKind.pie,
          series: [
            USeries(name: 'Empty', points: []),
            USeries(
              name: 'Later',
              points: [UPoint(x: 'Chrome', y: 60)],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');

        expect(chart.isEmpty, isTrue);
        expect(chart.pointCount, 0);
        expect(chart.largestSliceLabel, isNull);
      });

      test('a line chart still describes every series', () {
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [UPoint(x: 'Jan', y: 1)],
            ),
            USeries(
              name: 'B',
              points: [UPoint(x: 'Jan', y: 2)],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');

        expect(chart.pointCount, 2);
        expect(chart.seriesNames, ['A', 'B']);
      });
    });

    group('number formatting', () {
      test('reads a whole value without its decimal', () {
        // A screen reader says "ten point zero" for a bare toString, and chart
        // data is nearly always integral.
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [
                UPoint(x: 'Jan', y: 10),
                UPoint(x: 'Feb', y: 25),
              ],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
        expect(chart.valueMin, '10');
        expect(chart.valueMax, '25');
      });

      test('keeps at most two decimals', () {
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [
                UPoint(x: 'Jan', y: 3.14159),
                UPoint(x: 'Feb', y: 2.5),
              ],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
        expect(chart.valueMin, '2.5', reason: 'a trailing zero is trimmed');
        expect(chart.valueMax, '3.14');
      });

      test('drops the decimal point when rounding clears the fraction', () {
        // toStringAsFixed(2) gives '100.00' and '4.00' here. Stripping the
        // zeros without the point left '100.' and '4.', which a screen reader
        // reads as "one hundred point".
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [
                UPoint(x: 'Jan', y: 3.999),
                UPoint(x: 'Feb', y: 99.999),
              ],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
        expect(chart.valueMin, '4');
        expect(chart.valueMax, '100');
      });

      test('reports a sub-hundredth value as zero, not a bare point', () {
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [
                UPoint(x: 'Jan', y: 0.001),
                UPoint(x: 'Feb', y: 0.5),
              ],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
        expect(chart.valueMin, '0');
        expect(chart.valueMax, '0.5');
      });

      test('renders a negative zero as zero', () {
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            // `-0` in a double context really is negative zero, whose
            // toStringAsFixed(0) is the string '-0'.
            USeries(
              name: 'A',
              points: [
                UPoint(x: 'Jan', y: -0),
                UPoint(x: 'Feb', y: 1),
              ],
            ),
          ],
        );

        expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').valueMin, '0');
      });

      test('renders a value that rounds to zero as zero, sign and all', () {
        // -0 above is the one negative the old short-circuit caught. Everything
        // in (-0.005, 0) went the other way and came back '-0', which a reader
        // voices as "minus zero".
        for (final tiny in [-0.001, -0.004, -1e-9]) {
          final spec = USpec(
            kind: USpecKind.line,
            series: [
              USeries(
                name: 'A',
                points: [
                  UPoint(x: 'Jan', y: tiny),
                  const UPoint(x: 'Feb', y: 1),
                ],
              ),
            ],
          );

          expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').valueMin, '0', reason: '$tiny');
        }
      });

      test('keeps a negative that survives rounding', () {
        const spec = USpec(
          kind: USpecKind.line,
          series: [
            USeries(
              name: 'A',
              points: [
                UPoint(x: 'Jan', y: -0.006),
                UPoint(x: 'Feb', y: -2),
              ],
            ),
          ],
        );

        final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
        expect(chart.valueMin, '-2');
        expect(chart.valueMax, '-0.01');
      });
    });

    group('point sizes', () {
      test('are gathered for a bubble chart', () {
        final chart = ChartSemantics.fromSpec(_bubbleSpec, unnamedSeries: 'Series');
        expect(chart.sizeMin, '5');
        expect(chart.sizeMax, '50');
      });

      test('are left off every other kind, which draws one radius', () {
        // A Vega-Lite `{"mark": "point", "encoding": {"size": ...}}` parses to a
        // scatter whose points carry a size ChartView never draws, so
        // describing the range would announce an encoding that isn't there.
        for (final kind in [USpecKind.scatter, USpecKind.line, USpecKind.area]) {
          final spec = USpec(
            kind: kind,
            series: const [
              USeries(
                name: 'A',
                points: [
                  UPoint(x: '1', y: 1, size: 1000000),
                  UPoint(x: '2', y: 4, size: 9000000),
                ],
              ),
            ],
          );

          final chart = ChartSemantics.fromSpec(spec, unnamedSeries: 'Series');
          expect(chart.sizeMin, isNull, reason: '$kind');
          expect(_label(spec), isNot(contains('sizes')), reason: '$kind');
        }
      });
    });

    group('heatmap rows and columns', () {
      test('are named, not just counted', () {
        final chart = ChartSemantics.fromSpec(_heatmapSpec, unnamedSeries: 'Series');
        expect(chart.seriesNames, ['Row 1', 'Row 2']);
        expect(chart.columnLabels, ['A', 'B', 'C']);
        expect(chart.columnCount, 3);
      });

      test('keep the order they are drawn in', () {
        const spec = USpec(
          kind: USpecKind.heatmap,
          series: [
            USeries(
              name: 'Mon',
              points: [
                UPoint(x: '9am', y: 0, z: 1),
                UPoint(x: '12pm', y: 0, z: 5),
              ],
            ),
            USeries(
              name: 'Tue',
              points: [
                // Repeats 9am, and introduces 3pm after it.
                UPoint(x: '9am', y: 0, z: 2),
                UPoint(x: '3pm', y: 0, z: 7),
              ],
            ),
          ],
        );

        expect(ChartSemantics.fromSpec(spec, unnamedSeries: 'Series').columnLabels, ['9am', '12pm', '3pm']);
      });

      test('fall back to the translated name for an unnamed row', () {
        const spec = USpec(
          kind: USpecKind.heatmap,
          series: [
            USeries(
              name: '',
              points: [UPoint(x: 'A', y: 0, z: 1)],
            ),
          ],
        );

        expect(_label(spec), contains('rows: Series'));
      });
    });
  });

  group('DefaultAITranslations.chartSemanticsLabel', () {
    test('describes every kind', () {
      expect(_label(_lineSpec), 'Line chart, Sales, 3 points, values 10 to 25');
      expect(_label(_areaSpec), 'Area chart, 3 points, values 10 to 25');
      expect(_label(_barSpec), 'Bar chart, Messages per day, 5 categories, values 8 to 24');
      expect(_label(_pieSpec), 'Pie chart, Browser share, 4 slices, largest Chrome at 60 percent');
      expect(_label(_scatterSpec), 'Scatter chart, 2 series: A, B, 4 points, values 1 to 8');
      expect(_label(_bubbleSpec), 'Bubble chart, 3 points, values 1 to 3, sizes 5 to 50');
      expect(
        _label(_heatmapSpec),
        'Heatmap, 2 rows by 3 columns, rows: Row 1, Row 2, columns: A, B, C, values 1 to 9',
      );
      expect(_label(_histogramSpec), 'Histogram, 5 samples, values 1 to 9');
    });

    test('reads the axis labels the data carried', () {
      // The first thing in the package ever to read USpec.xLabel/yLabel, which
      // the parsers have been filling in for nobody.
      const spec = USpec(
        kind: USpecKind.line,
        xLabel: 'Month',
        yLabel: 'Revenue',
        series: [
          USeries(
            name: 'A',
            points: [
              UPoint(x: 'Jan', y: 1),
              UPoint(x: 'Feb', y: 2),
            ],
          ),
        ],
      );

      expect(_label(spec), 'Line chart, Month on the x axis, Revenue on the y axis, 2 points, values 1 to 2');
    });

    test('leaves out a lone series name', () {
      // With one series the name almost always repeats the title or the y
      // label, so it earns nothing.
      expect(_label(_lineSpec), isNot(contains('Sales, 1 series')));
    });

    test('says no data for an empty spec', () {
      expect(_label(const USpec(kind: USpecKind.heatmap, series: [])), 'Heatmap, no data');
      expect(_label(const USpec(kind: USpecKind.bar, series: [])), 'Bar chart, no data');
    });

    test('keeps the title on an empty spec', () {
      const spec = USpec(title: 'Nothing yet', kind: USpecKind.bar, series: []);
      expect(_label(spec), 'Bar chart, Nothing yet, no data');
    });

    test('omits the pie share when the slices do not sum to anything positive', () {
      const spec = USpec(
        kind: USpecKind.pie,
        series: [
          USeries(
            name: 'Empty',
            points: [
              UPoint(x: 'A', y: 0),
              UPoint(x: 'B', y: 0),
            ],
          ),
        ],
      );

      expect(_label(spec), 'Pie chart, 2 slices');
    });

    test('counts a single anything in the singular', () {
      const one = [UPoint(x: 'A', y: 1)];
      String labelOf(USpecKind kind) => _label(
        USpec(
          kind: kind,
          series: const [USeries(name: 'A', points: one)],
        ),
      );

      expect(labelOf(USpecKind.pie), 'Pie chart, 1 slice, largest A at 100 percent');
      expect(labelOf(USpecKind.bar), 'Bar chart, 1 category, values 1 to 1');
      expect(labelOf(USpecKind.histogram), 'Histogram, 1 sample, values 1 to 1');
      expect(labelOf(USpecKind.line), 'Line chart, 1 point, values 1 to 1');
      expect(
        _label(
          const USpec(
            kind: USpecKind.heatmap,
            series: [
              USeries(
                name: 'Mon',
                points: [UPoint(x: '9am', y: 0, z: 1)],
              ),
            ],
          ),
        ),
        'Heatmap, 1 row by 1 column, rows: Mon, columns: 9am, values 1 to 1',
      );
    });
  });
}

const _lineSpec = USpec(
  title: 'Sales',
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
  title: 'Messages per day',
  kind: USpecKind.bar,
  series: [
    USeries(
      name: 'Messages',
      points: [
        UPoint(x: 'Mon', y: 8),
        UPoint(x: 'Tue', y: 24),
        UPoint(x: 'Wed', y: 12),
        UPoint(x: 'Thu', y: 19),
        UPoint(x: 'Fri', y: 15),
      ],
    ),
  ],
);

const _pieSpec = USpec(
  title: 'Browser share',
  kind: USpecKind.pie,
  series: [
    USeries(
      name: '',
      points: [
        UPoint(x: 'Chrome', y: 60),
        UPoint(x: 'Safari', y: 20),
        UPoint(x: 'Firefox', y: 15),
        UPoint(x: 'Edge', y: 5),
      ],
    ),
  ],
);

const _scatterSpec = USpec(
  kind: USpecKind.scatter,
  series: [
    USeries(
      name: 'A',
      points: [
        UPoint(x: '1', y: 1),
        UPoint(x: '2', y: 4),
      ],
    ),
    USeries(
      name: 'B',
      points: [
        UPoint(x: '3', y: 6),
        UPoint(x: '4', y: 8),
      ],
    ),
  ],
);

const _bubbleSpec = USpec(
  kind: USpecKind.bubble,
  series: [
    USeries(
      name: 'A',
      points: [
        UPoint(x: '1', y: 1, size: 5),
        UPoint(x: '2', y: 2, size: 20),
        UPoint(x: '3', y: 3, size: 50),
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
        UPoint(x: 'C', y: 0, z: 3),
      ],
    ),
    USeries(
      name: 'Row 2',
      points: [
        UPoint(x: 'A', y: 0, z: 7),
        UPoint(x: 'B', y: 0, z: 2),
        UPoint(x: 'C', y: 0, z: 9),
      ],
    ),
  ],
);

const _histogramSpec = USpec(
  kind: USpecKind.histogram,
  series: [
    USeries(
      name: 'Samples',
      points: [
        UPoint(x: '', y: 1),
        UPoint(x: '', y: 3),
        UPoint(x: '', y: 5),
        UPoint(x: '', y: 7),
        UPoint(x: '', y: 9),
      ],
    ),
  ],
);
