import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

void main() {
  group('USpecParser.tryParse', () {
    test('returns null for garbage input', () {
      expect(USpecParser.tryParse('not json'), isNull);
    });

    test('returns null for unrecognised JSON shapes', () {
      expect(USpecParser.tryParse('{"foo": "bar"}'), isNull);
    });

    group('native USpec schema', () {
      test('parses kind and series', () {
        final spec = USpecParser.tryParse('''
        {
          "kind": "bar",
          "series": [
            {"name": "Sales", "points": [{"x": "Jan", "y": 10}, {"x": "Feb", "y": 20}]}
          ]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bar);
        expect(spec.series, hasLength(1));
        expect(spec.series.first.points.map((p) => p.y), [10, 20]);
      });

      test('parses optional size/z fields and beginAtZeroY', () {
        final spec = USpecParser.tryParse('''
        {
          "kind": "bubble",
          "beginAtZeroY": true,
          "series": [
            {"name": "S", "points": [{"x": "A", "y": 5, "size": 12}]}
          ]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bubble);
        expect(spec.beginAtZeroY, isTrue);
        expect(spec.series.first.points.first.size, 12);
      });

      test('accepts `type`/`label` as aliases for `kind`/`name`', () {
        // Models asked for a USpec routinely reach for the Chart.js vocabulary
        // instead; an otherwise well-formed spec shouldn't degrade to a raw
        // code block over that.
        final spec = USpecParser.tryParse('''
        {
          "type": "bar",
          "title": "Messages per day",
          "series": [
            {"label": "Messages", "points": [{"x": "Mon", "y": 12}, {"x": "Tue", "y": 19}]}
          ]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bar);
        expect(spec.title, 'Messages per day');
        expect(spec.series.first.name, 'Messages');
        expect(spec.series.first.points.map((p) => p.y), [12, 19]);
      });

      test('parses numeric strings as values', () {
        final spec = USpecParser.tryParse('''
        {"kind": "line", "series": [{"name": "S", "points": [{"x": "A", "y": "1.5"}]}]}
        ''');

        expect(spec?.series.first.points.first.y, 1.5);
      });

      test('defers to another adapter when no series yields points', () {
        // A `type` + `series` payload keying its values under something other
        // than `points` must fall through rather than being claimed here and
        // rendered as an empty chart.
        final spec = USpecParser.tryParse('''
        {
          "type": "bar",
          "xAxis": {"data": ["Mon", "Tue"]},
          "series": [{"name": "Messages", "data": [12, 19]}]
        }
        ''');

        expect(spec, isNotNull, reason: 'the ECharts adapter understands this shape');
        expect(spec!.series.first.points.map((p) => p.y), [12, 19]);
      });
    });

    group('Chart.js schema', () {
      test('parses a line chart', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "line",
          "data": {
            "labels": ["Jan", "Feb"],
            "datasets": [{"label": "Sales", "data": [10, 20]}]
          }
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.line);
        expect(spec.series.first.points.map((p) => p.x), ['Jan', 'Feb']);
      });

      test('plots plain numbers with no labels at their position in the array', () {
        // A shape models emit constantly. The no-labels branch used to accept
        // only `{x, y, r}` objects, so this parsed to a series holding nothing
        // — and the empty series was still returned, rendering bare axes rather
        // than falling back to a readable code block.
        final spec = USpecParser.tryParse('''
        {"type": "bar", "data": {"datasets": [{"label": "Sales", "data": [10, 25, 18]}]}}
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bar);
        expect(spec.series.single.points.map((p) => p.y), [10, 25, 18]);
        expect(spec.series.single.points.map((p) => p.x), ['0', '1', '2']);
      });

      test('declines a dataset it cannot decode instead of returning an empty chart', () {
        final spec = USpecParser.tryParse('''
        {"type": "bar", "data": {"datasets": [{"label": "Sales", "data": ["a", "b"]}]}}
        ''');

        expect(spec, isNull, reason: 'so the fence falls through to CodeBlockView');
      });

      test('keeps a labelled point on its own category across a null gap', () {
        // `null` is how Chart.js writes a gap. Dropping it produced a dense
        // list, and points were then plotted by their position in that list —
        // so everything after the gap was drawn one category to the left, out
        // of step with the axis and with the other series.
        final spec = USpecParser.tryParse('''
        {
          "type": "line",
          "data": {
            "labels": ["Jan", "Feb", "Mar"],
            "datasets": [
              {"label": "A", "data": [1, null, 3]},
              {"label": "B", "data": [4, 5, 6]}
            ]
          }
        }
        ''');

        expect(spec!.series.first.points.map((p) => p.x), ['Jan', 'Mar']);
        expect(spec.series.first.points.map((p) => p.y), [1, 3]);
        expect(spec.series.last.points.map((p) => p.x), ['Jan', 'Feb', 'Mar']);
      });

      test('parses a pie chart', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "pie",
          "data": {
            "labels": ["A", "B"],
            "datasets": [{"label": "Pie", "data": [30, 70]}]
          }
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.pie);
        expect(spec.series.first.points.map((p) => p.x), ['A', 'B']);
      });

      test('parses scatter with object values {x, y, r}', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "scatter",
          "data": {
            "datasets": [{"label": "S", "data": [{"x": 1, "y": 2, "r": 5}, {"x": 3, "y": 4}]}]
          }
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.scatter);
        final points = spec.series.first.points;
        expect(points, hasLength(2));
        expect(points.first.size, 5);
        expect(points.last.size, isNull);
      });

      test('parses bubble with object values {x, y, r}', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "bubble",
          "data": {
            "datasets": [{"label": "S", "data": [{"x": 1, "y": 2, "r": 20}]}]
          }
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bubble);
        expect(spec.series.first.points.first.size, 20);
      });

      test('maps radar to bar and polarArea to pie', () {
        final radar = USpecParser.tryParse('''
        {"type": "radar", "data": {"labels": ["A"], "datasets": [{"label": "S", "data": [1]}]}}
        ''');
        expect(radar!.kind, USpecKind.bar);

        final polarArea = USpecParser.tryParse('''
        {"type": "polarArea", "data": {"labels": ["A"], "datasets": [{"label": "S", "data": [1]}]}}
        ''');
        expect(polarArea!.kind, USpecKind.pie);
      });

      test('reads options.scales.y.beginAtZero', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "bar",
          "data": {"labels": ["A"], "datasets": [{"label": "S", "data": [1]}]},
          "options": {"scales": {"y": {"beginAtZero": true}}}
        }
        ''');

        expect(spec!.beginAtZeroY, isTrue);
      });
    });

    group('Plotly schema', () {
      test('parses a single-spec heatmap', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "heatmap",
          "data": {"z": [[1, 2], [3, 4]], "x": ["a", "b"], "y": ["r1", "r2"]},
          "layout": {"title": "Heat"}
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.heatmap);
        expect(spec.series, hasLength(2));
        expect(spec.series.first.points.map((p) => p.z), [1, 2]);
        expect(spec.title, 'Heat');
      });

      test('parses a figure with a heatmap trace', () {
        final spec = USpecParser.tryParse('''
        {
          "data": [{"type": "heatmap", "z": [[1, 2]], "x": ["a", "b"], "y": ["r1"]}],
          "layout": {"title": {"text": "Fig"}}
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.heatmap);
        expect(spec.title, 'Fig');
      });
    });

    group('ECharts schema', () {
      test('declines a series it cannot decode instead of returning an empty chart', () {
        final spec = USpecParser.tryParse('''
        {"xAxis": {"data": ["a", "b"]}, "series": [{"name": "S", "data": ["x", "y"]}]}
        ''');

        expect(spec, isNull, reason: 'so the fence falls through to CodeBlockView');
      });

      test('parses a category series', () {
        final spec = USpecParser.tryParse('''
        {
          "title": {"text": "Chart"},
          "xAxis": {"data": ["Mon", "Tue"]},
          "series": [{"name": "S", "type": "bar", "data": [1, 2]}]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bar);
        expect(spec.title, 'Chart');
        expect(spec.series.first.points.map((p) => p.x), ['Mon', 'Tue']);
      });

      test('parses a pie series encoded as [{name, value}]', () {
        final spec = USpecParser.tryParse('''
        {
          "xAxis": {},
          "series": [{"name": "S", "type": "pie", "data": [{"name": "Android", "value": 71.9}]}]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.pie);
        expect(spec.series.first.points.first.x, 'Android');
        expect(spec.series.first.points.first.y, 71.9);
      });
    });

    group('Highcharts schema', () {
      test('declines a series it cannot decode instead of returning an empty chart', () {
        final spec = USpecParser.tryParse('''
        {"xAxis": {"categories": ["a", "b"]}, "series": [{"name": "S", "data": ["x", "y"]}]}
        ''');

        expect(spec, isNull, reason: 'so the fence falls through to CodeBlockView');
      });

      test('maps column to bar', () {
        final spec = USpecParser.tryParse('''
        {
          "title": {"text": "HC"},
          "xAxis": {"categories": ["A", "B"]},
          "series": [{"name": "S", "type": "column", "data": [5, 6]}]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bar);
        expect(spec.series.first.points.map((p) => p.x), ['A', 'B']);
      });
    });

    group('Vega-Lite schema', () {
      test('maps bar mark', () {
        final spec = USpecParser.tryParse('''
        {
          "data": {"values": [{"cat": "A", "val": 3}, {"cat": "B", "val": 5}]},
          "mark": "bar",
          "encoding": {"x": {"field": "cat"}, "y": {"field": "val"}}
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.bar);
        expect(spec.series, hasLength(1));
      });

      test('returns null when the encoding fields do not match the data', () {
        // A mismatched `y` field used to be coerced to zero for every row,
        // producing a chart of flat zeroes that read as real data. Falling
        // through to a plain code block is the honest outcome.
        final spec = USpecParser.tryParse('''
        {
          "data": {"values": [{"cat": "A", "val": 3}]},
          "mark": "bar",
          "encoding": {"x": {"field": "cat"}, "y": {"field": "missing"}}
        }
        ''');

        expect(spec, isNull);
      });

      test('maps point mark to scatter', () {
        final spec = USpecParser.tryParse('''
        {
          "data": {"values": [{"x": 1, "y": 2}]},
          "mark": "point",
          "encoding": {"x": {"field": "x"}, "y": {"field": "y"}}
        }
        ''');

        expect(spec!.kind, USpecKind.scatter);
      });

      test('maps a rect mark to a heatmap with x and y as the two axes', () {
        // A Vega-Lite heatmap encodes the cell value in `color`, with x and y
        // as the axes — the opposite of every other mark, where `color` names
        // the series. Running it through the shared path produced one row per
        // distinct *value*, with the hour painted as the intensity.
        final spec = USpecParser.tryParse('''
        {
          "data": {
            "values": [
              {"day": "Mon", "hour": 9, "v": 5},
              {"day": "Mon", "hour": 10, "v": 8},
              {"day": "Tue", "hour": 9, "v": 2}
            ]
          },
          "mark": "rect",
          "encoding": {"x": {"field": "day"}, "y": {"field": "hour"}, "color": {"field": "v"}}
        }
        ''');

        expect(spec!.kind, USpecKind.heatmap);
        expect(spec.series.map((s) => s.name), ['9', '10'], reason: 'rows are the y encoding');
        expect(spec.series.first.points.map((p) => p.x), ['Mon', 'Tue'], reason: 'columns are the x encoding');
        expect(spec.series.first.points.map((p) => p.z), [5, 2], reason: 'intensity is the color encoding');
        expect(spec.series.last.points.single.z, 8);
      });

      test('declines a rect mark with no color encoding', () {
        // Nothing to shade the cells by, and guessing would draw a plausible
        // grid out of data that says nothing about intensity.
        final spec = USpecParser.tryParse('''
        {
          "data": {"values": [{"x": 1, "y": 2}]},
          "mark": "rect",
          "encoding": {"x": {"field": "x"}, "y": {"field": "y"}}
        }
        ''');

        expect(spec, isNull);
      });

      test('groups rows by the color field into separate series', () {
        final spec = USpecParser.tryParse('''
        {
          "data": {
            "values": [
              {"x": 1, "y": 2, "grp": "A"},
              {"x": 2, "y": 3, "grp": "B"}
            ]
          },
          "mark": "line",
          "encoding": {"x": {"field": "x"}, "y": {"field": "y"}, "color": {"field": "grp"}}
        }
        ''');

        expect(spec!.series, hasLength(2));
      });
    });

    group('Flat pie schema', () {
      test('parses label/value pairs', () {
        final spec = USpecParser.tryParse('''
        {
          "type": "pie",
          "title": "Flat",
          "data": [{"label": "A", "value": 1}, {"label": "B", "value": 2}]
        }
        ''');

        expect(spec, isNotNull);
        expect(spec!.kind, USpecKind.pie);
        expect(spec.series.first.points.map((p) => p.x), ['A', 'B']);
      });
    });
  });
}
