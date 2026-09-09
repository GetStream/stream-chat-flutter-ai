import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('ChartThemeData', () {
    group('merge', () {
      test("takes the other theme's set fields", () {
        const base = ChartThemeData(height: 100, histogramBinCount: 4);
        final merged = base.merge(const ChartThemeData(height: 200));

        expect(merged.height, 200);
        expect(merged.histogramBinCount, 4, reason: 'an unset field leaves the base value alone');
      });

      test('with null returns this', () {
        const base = ChartThemeData(height: 100);
        expect(base.merge(null), same(base));
      });
    });

    group('lerp', () {
      test('interpolates a palette index by index', () {
        const a = ChartThemeData(seriesColors: [Color(0xFF000000), Color(0xFF000000)]);
        const b = ChartThemeData(seriesColors: [Color(0xFFFFFFFF), Color(0xFF808080)]);

        final mid = ChartThemeData.lerp(a, b, 0.5).seriesColors!;

        expect(mid, hasLength(2));
        expect(mid[0], Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5));
        expect(mid[1], Color.lerp(const Color(0xFF000000), const Color(0xFF808080), 0.5));
      });

      test('wraps the shorter palette rather than dropping indices', () {
        // Truncating to the shorter list would blank the extra series partway
        // through a theme animation; wrapping matches how the palette is
        // cycled at paint time anyway.
        const short = [Color(0xFF000000), Color(0xFF111111)];
        const long = [
          Color(0xFF200000),
          Color(0xFF210000),
          Color(0xFF220000),
          Color(0xFF230000),
          Color(0xFF240000),
          Color(0xFF250000),
        ];
        const a = ChartThemeData(seriesColors: short);
        const b = ChartThemeData(seriesColors: long);

        final mid = ChartThemeData.lerp(a, b, 0.25).seriesColors!;

        expect(mid, hasLength(6));
        expect(mid[4], Color.lerp(short[4 % short.length], long[4], 0.25));
      });

      test('rounds the histogram bin count', () {
        const a = ChartThemeData(histogramBinCount: 10);
        const b = ChartThemeData(histogramBinCount: 20);

        expect(ChartThemeData.lerp(a, b, 0.5).histogramBinCount, 15);
        expect(ChartThemeData.lerp(a, b, 0.26).histogramBinCount, 13);
      });

      test('swaps an unset field instead of interpolating it', () {
        // A null means "derive from the ColorScheme", not "transparent".
        // Color.lerp(null, red, t) fades in from transparent, which would make
        // a grid line vanish halfway through a light/dark transition.
        const unset = ChartThemeData();
        const set = ChartThemeData(gridLineColor: Color(0xFFFF0000));

        expect(ChartThemeData.lerp(unset, set, 0.4).gridLineColor, isNull);
        expect(ChartThemeData.lerp(unset, set, 0.6).gridLineColor, const Color(0xFFFF0000));
      });

      test('swaps an unset height instead of growing from zero', () {
        const unset = ChartThemeData();
        const set = ChartThemeData(height: 300);

        expect(ChartThemeData.lerp(unset, set, 0.4).height, isNull);
        expect(ChartThemeData.lerp(unset, set, 0.6).height, 300);
      });

      test('with identical themes returns the first', () {
        const theme = ChartThemeData(height: 100);
        expect(ChartThemeData.lerp(theme, theme, 0.5), same(theme));
      });
    });

    group('equality', () {
      test('compares palettes by value, not identity', () {
        // Two const lists with the same contents are canonicalized, but a
        // runtime-built one is not — an identity comparison would call these
        // unequal and re-lerp on every rebuild.
        // List.of, not a literal: two const lists with the same contents are
        // canonicalized to one object, which would let an identity comparison
        // pass this test for the wrong reason.
        final a = ChartThemeData(seriesColors: List.of(const [Color(0xFF112233)]));
        final b = ChartThemeData(seriesColors: List.of(const [Color(0xFF112233)]));

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('a different palette makes two themes unequal', () {
        const a = ChartThemeData(seriesColors: [Color(0xFF112233)]);
        const b = ChartThemeData(seriesColors: [Color(0xFF332211)]);

        expect(a, isNot(b));
      });
    });
  });

  group('ChartTheme', () {
    testWidgets('layers its data over the AITheme extension', (tester) async {
      late ChartThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AITheme(chartTheme: ChartThemeData(height: 300, histogramBinCount: 4))],
          ),
          home: ChartTheme(
            data: const ChartThemeData(height: 400),
            child: Builder(
              builder: (context) {
                resolved = ChartTheme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved.height, 400, reason: 'the nearest scope wins');
      expect(resolved.histogramBinCount, 4, reason: 'what it leaves unset still comes from AITheme');
    });

    testWidgets('of returns bare defaults with no scope and no extension', (tester) async {
      late ChartThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = ChartTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, const ChartThemeData());
    });

    test('notifies only when its data changes', () {
      const a = ChartTheme(data: ChartThemeData(height: 100), child: SizedBox.shrink());
      const b = ChartTheme(data: ChartThemeData(height: 200), child: SizedBox.shrink());
      const sameAsA = ChartTheme(data: ChartThemeData(height: 100), child: SizedBox.shrink());

      expect(b.updateShouldNotify(a), isTrue);
      expect(sameAsA.updateShouldNotify(a), isFalse);
    });
  });
}
