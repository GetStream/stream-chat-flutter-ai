import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('AITheme', () {
    testWidgets('of falls back to defaults when the host registered none', (tester) async {
      // The whole thing is opt-in: an app that never heard of AITheme has to
      // keep rendering exactly as it did.
      late AITheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = AITheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, const AITheme());
      expect(resolved.chartTheme, const ChartThemeData());
    });

    testWidgets('of returns the registered extension', (tester) async {
      const theme = AITheme(chartTheme: ChartThemeData(height: 300));
      late AITheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [theme]),
          home: Builder(
            builder: (context) {
              resolved = AITheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, theme);
    });

    test('copyWith replaces the chart theme', () {
      const theme = AITheme(chartTheme: ChartThemeData(height: 300));
      expect(theme.copyWith().chartTheme.height, 300);
      expect(theme.copyWith(chartTheme: const ChartThemeData(height: 400)).chartTheme.height, 400);
    });

    test('lerp interpolates the chart theme', () {
      const a = AITheme(chartTheme: ChartThemeData(height: 100));
      const b = AITheme(chartTheme: ChartThemeData(height: 200));

      expect(a.lerp(b, 0).chartTheme.height, 100);
      expect(a.lerp(b, 0.5).chartTheme.height, 150);
      expect(a.lerp(b, 1).chartTheme.height, 200);
    });

    test('lerp with null returns this', () {
      const theme = AITheme(chartTheme: ChartThemeData(height: 100));
      expect(theme.lerp(null, 0.5), same(theme));
    });

    test('equal themes are equal and hash equally', () {
      // Load-bearing: ThemeData.== compares its extensions with mapEquals, so
      // without this every rebuild of an equal ThemeData would compare unequal
      // and start a fresh interpolation.
      const a = AITheme(chartTheme: ChartThemeData(seriesColors: [Color(0xFF112233)]));
      const b = AITheme(chartTheme: ChartThemeData(seriesColors: [Color(0xFF112233)]));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AITheme()));
    });
  });
}
