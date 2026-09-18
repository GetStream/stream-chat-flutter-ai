import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('ChartThemeData', () {
    // Every field, rather than a spot-check: copyWith, merge, == and hashCode
    // are four hand-written 13-line tables, and a crossed line in any of them
    // (`scatterRadius: bubbleMinRadius ?? this.scatterRadius`) is invisible
    // until someone themes that particular field. The loop below is what makes
    // a 14th field added to only three of the four fail loudly.
    group('every field', () {
      const base = ChartThemeData(
        seriesColors: [Color(0xFF111111)],
        height: 100,
        scatterRadius: 1,
        bubbleMinRadius: 2,
        bubbleMaxRadius: 3,
        histogramBinCount: 4,
        axisLabelStyle: TextStyle(fontSize: 11),
        pieLabelStyle: TextStyle(fontSize: 12),
        titleTextStyle: TextStyle(fontSize: 13),
        gridLineColor: Color(0xFF222222),
        heatmapLowColor: Color(0xFF333333),
        heatmapMidColor: Color(0xFF444444),
        heatmapHighColor: Color(0xFF555555),
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              ChartThemeData only,
              ChartThemeData Function() copied,
              Object? Function(ChartThemeData) read,
            })
          >[
            (
              name: 'seriesColors',
              only: const ChartThemeData(seriesColors: [Color(0xFFAAAAAA)]),
              copied: () => base.copyWith(seriesColors: const [Color(0xFFAAAAAA)]),
              read: (t) => t.seriesColors,
            ),
            (
              name: 'height',
              only: const ChartThemeData(height: 900),
              copied: () => base.copyWith(height: 900),
              read: (t) => t.height,
            ),
            (
              name: 'scatterRadius',
              only: const ChartThemeData(scatterRadius: 91),
              copied: () => base.copyWith(scatterRadius: 91),
              read: (t) => t.scatterRadius,
            ),
            (
              name: 'bubbleMinRadius',
              only: const ChartThemeData(bubbleMinRadius: 92),
              copied: () => base.copyWith(bubbleMinRadius: 92),
              read: (t) => t.bubbleMinRadius,
            ),
            (
              name: 'bubbleMaxRadius',
              only: const ChartThemeData(bubbleMaxRadius: 93),
              copied: () => base.copyWith(bubbleMaxRadius: 93),
              read: (t) => t.bubbleMaxRadius,
            ),
            (
              name: 'histogramBinCount',
              only: const ChartThemeData(histogramBinCount: 94),
              copied: () => base.copyWith(histogramBinCount: 94),
              read: (t) => t.histogramBinCount,
            ),
            (
              name: 'axisLabelStyle',
              only: const ChartThemeData(axisLabelStyle: TextStyle(fontSize: 95)),
              copied: () => base.copyWith(axisLabelStyle: const TextStyle(fontSize: 95)),
              read: (t) => t.axisLabelStyle,
            ),
            (
              name: 'pieLabelStyle',
              only: const ChartThemeData(pieLabelStyle: TextStyle(fontSize: 96)),
              copied: () => base.copyWith(pieLabelStyle: const TextStyle(fontSize: 96)),
              read: (t) => t.pieLabelStyle,
            ),
            (
              name: 'titleTextStyle',
              only: const ChartThemeData(titleTextStyle: TextStyle(fontSize: 97)),
              copied: () => base.copyWith(titleTextStyle: const TextStyle(fontSize: 97)),
              read: (t) => t.titleTextStyle,
            ),
            (
              name: 'gridLineColor',
              only: const ChartThemeData(gridLineColor: Color(0xFFBBBBBB)),
              copied: () => base.copyWith(gridLineColor: const Color(0xFFBBBBBB)),
              read: (t) => t.gridLineColor,
            ),
            (
              name: 'heatmapLowColor',
              only: const ChartThemeData(heatmapLowColor: Color(0xFFCCCCCC)),
              copied: () => base.copyWith(heatmapLowColor: const Color(0xFFCCCCCC)),
              read: (t) => t.heatmapLowColor,
            ),
            (
              name: 'heatmapMidColor',
              only: const ChartThemeData(heatmapMidColor: Color(0xFFDDDDDD)),
              copied: () => base.copyWith(heatmapMidColor: const Color(0xFFDDDDDD)),
              read: (t) => t.heatmapMidColor,
            ),
            (
              name: 'heatmapHighColor',
              only: const ChartThemeData(heatmapHighColor: Color(0xFFEEEEEE)),
              copied: () => base.copyWith(heatmapHighColor: const Color(0xFFEEEEEE)),
              read: (t) => t.heatmapHighColor,
            ),
          ];

      test('the table covers every field the class declares', () {
        // Guards the loop itself: add a field without a row here and this
        // fails rather than silently leaving the new field untested.
        expect(fields, hasLength(13));
        expect(fields.map((f) => f.name).toSet(), hasLength(13));
      });

      for (final field in fields) {
        test('${field.name} survives copyWith, merge, == and hashCode', () {
          final copied = field.copied();
          final merged = base.merge(field.only);

          expect(field.read(copied), field.read(field.only), reason: 'copyWith set ${field.name}');
          expect(field.read(merged), field.read(field.only), reason: 'merge took ${field.name}');

          // Nothing else moved — this is what catches a crossed line.
          for (final other in fields.where((f) => f.name != field.name)) {
            expect(other.read(copied), other.read(base), reason: 'copyWith(${field.name}) disturbed ${other.name}');
            expect(other.read(merged), other.read(base), reason: 'merge(${field.name}) disturbed ${other.name}');
          }

          expect(copied, merged, reason: 'copyWith and merge disagree on ${field.name}');
          expect(copied, isNot(base), reason: '== ignores ${field.name}');
          expect(copied.hashCode, isNot(base.hashCode), reason: 'hashCode ignores ${field.name}');
        });
      }
    });

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

  group('ChartTheme crosses a route', () {
    // ChartTheme is an InheritedTheme purely so `wrap` carries it to routes
    // pushed from inside the scope — showDialog, showModalBottomSheet, a
    // pushed page. Return `child` from `wrap` and nothing else in the suite
    // notices, while every chart in a dialog silently loses the host's theme.
    // Mirrors the AITranslationsScope route test for the same reason: pin the
    // mechanism, not one caller.
    testWidgets('a chart in a dialog pushed from inside the scope keeps the theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: ChartTheme(
              data: const ChartThemeData(height: 321),
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => Text('${ChartTheme.of(context).height}'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('321.0'), findsOneWidget);
    });

    testWidgets('without the scope the same dialog falls back to the ambient theme', (tester) async {
      // The control: otherwise the test above would pass just as well if the
      // dialog were reading a default that happened to match.
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Text('${ChartTheme.of(context).height}'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('321.0'), findsNothing);
      expect(find.text('null'), findsOneWidget, reason: 'unset, for ResolvedChartTheme to fill in');
    });
  });
}
