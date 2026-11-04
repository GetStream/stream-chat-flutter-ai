import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

USpec _spec({String? title, List<USeries>? series}) => USpec(
  kind: USpecKind.line,
  series:
      series ??
      const [
        USeries(
          name: 'Revenue',
          points: [
            UPoint(x: 'Q1', y: 1),
            UPoint(x: 'Q2', y: 2),
          ],
        ),
      ],
  title: title,
);

void main() {
  group('UPoint equality', () {
    test('equal points are ==, and hash alike', () {
      const a = UPoint(x: 'Q1', y: 1, size: 3, z: 4);
      const b = UPoint(x: 'Q1', y: 1, size: 3, z: 4);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('every field participates', () {
      const base = UPoint(x: 'Q1', y: 1, size: 3, z: 4);

      expect(base, isNot(const UPoint(x: 'Q2', y: 1, size: 3, z: 4)));
      expect(base, isNot(const UPoint(x: 'Q1', y: 9, size: 3, z: 4)));
      expect(base, isNot(const UPoint(x: 'Q1', y: 1, size: 9, z: 4)));
      expect(base, isNot(const UPoint(x: 'Q1', y: 1, size: 3, z: 9)));
    });

    test('an absent optional is not the same as a present one', () {
      expect(const UPoint(x: 'Q1', y: 1), isNot(const UPoint(x: 'Q1', y: 1, z: 0)));
    });
  });

  group('USeries equality', () {
    test('compares points by value, not by identity', () {
      // The reason this package declares `collection`: the fields are lists, so
      // the default identity comparison would call two identical series
      // different. `List.of` rather than a const literal, which would be
      // canonicalized to one shared instance and pass for the wrong reason.
      final a = USeries(
        name: 'Revenue',
        points: List.of(const [UPoint(x: 'Q1', y: 1)]),
      );
      final b = USeries(
        name: 'Revenue',
        points: List.of(const [UPoint(x: 'Q1', y: 1)]),
      );

      expect(identical(a.points, b.points), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('point order matters', () {
      const a = USeries(
        name: 'r',
        points: [
          UPoint(x: 'Q1', y: 1),
          UPoint(x: 'Q2', y: 2),
        ],
      );
      const b = USeries(
        name: 'r',
        points: [
          UPoint(x: 'Q2', y: 2),
          UPoint(x: 'Q1', y: 1),
        ],
      );

      expect(a, isNot(b));
    });

    test('a differing name or point count breaks equality', () {
      const base = USeries(
        name: 'r',
        points: [UPoint(x: 'Q1', y: 1)],
      );

      expect(
        base,
        isNot(
          const USeries(
            name: 'other',
            points: [UPoint(x: 'Q1', y: 1)],
          ),
        ),
      );
      expect(base, isNot(const USeries(name: 'r', points: [])));
    });
  });

  group('USpec equality', () {
    test('compares nested series by value', () {
      expect(_spec(), _spec());
      expect(_spec().hashCode, _spec().hashCode);
    });

    test('a difference nested two levels down is seen', () {
      // USpec -> USeries -> UPoint: the case a shallow comparison would miss.
      final differing = _spec(
        series: const [
          USeries(
            name: 'Revenue',
            points: [
              UPoint(x: 'Q1', y: 1),
              UPoint(x: 'Q2', y: 99),
            ],
          ),
        ],
      );

      expect(_spec(), isNot(differing));
    });

    test('optional scalar fields participate', () {
      expect(_spec(title: 'Sales'), isNot(_spec()));
      expect(_spec(title: 'Sales'), _spec(title: 'Sales'));
    });

    test('a spec without a bar layout groups its bars', () {
      expect(_spec().barLayout, USpecBarLayout.grouped);
    });

    test('a spec without a curve joins its points with straight lines', () {
      expect(_spec().curve, USpecCurve.linear);
    });

    test('a spec is not a donut unless asked', () {
      expect(_spec().donut, isFalse);
    });

    test('a spec is not a semicircle unless asked', () {
      expect(_spec().semicircle, isFalse);
    });

    test('the bar layout participates', () {
      const grouped = USpec(kind: USpecKind.bar, series: []);
      const stacked = USpec(kind: USpecKind.bar, series: [], barLayout: USpecBarLayout.stacked);

      expect(stacked, isNot(grouped));
      expect(stacked.hashCode, isNot(grouped.hashCode));
    });

    test('the curve participates', () {
      const linear = USpec(kind: USpecKind.line, series: []);
      const natural = USpec(kind: USpecKind.line, series: [], curve: USpecCurve.natural);

      expect(natural, isNot(linear));
      expect(natural.hashCode, isNot(linear.hashCode));
    });

    test('donut participates', () {
      const pie = USpec(kind: USpecKind.pie, series: []);
      const donut = USpec(kind: USpecKind.pie, series: [], donut: true);

      expect(donut, isNot(pie));
      expect(donut.hashCode, isNot(pie.hashCode));
    });

    test('semicircle participates', () {
      const pie = USpec(kind: USpecKind.pie, series: []);
      const semicircle = USpec(kind: USpecKind.pie, series: [], semicircle: true);

      expect(semicircle, isNot(pie));
      expect(semicircle.hashCode, isNot(pie.hashCode));
    });

    test('works as a map key and in a set', () {
      final set = {_spec(), _spec(), _spec(title: 'Sales')};

      expect(set, hasLength(2));
    });

    test('two specs parsed from the same JSON are equal', () {
      // What a host actually does with this: assert on a parse result.
      const json = '{"kind":"line","series":[{"name":"Revenue","points":[{"x":"Q1","y":1}]}]}';

      expect(USpecParser.tryParse(json), USpecParser.tryParse(json));
    });
  });
}
