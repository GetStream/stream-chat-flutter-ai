import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_core_flutter/core.dart';

import '../openui_test_app.dart';

// What OpenUITheme.of gives under [stream], with [data] in an OpenUITheme
// around when given.
Future<OpenUIThemeData> _resolve(WidgetTester tester, {StreamTheme? stream, OpenUIThemeData? data}) async {
  late OpenUIThemeData resolved;
  Widget child = Builder(
    builder: (context) {
      resolved = OpenUITheme.of(context);
      return const SizedBox();
    },
  );
  if (data != null) child = OpenUITheme(data: data, child: child);
  await tester.pumpWidget(testApp(child, stream: stream));
  return resolved;
}

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

void main() {
  for (final (name, stream) in [('light', StreamTheme.light()), ('dark', StreamTheme.dark())]) {
    group('defaults ($name)', () {
      final colors = stream.colorScheme;
      final text = stream.textTheme;

      testWidgets('the colors come from the color scheme', (tester) async {
        final c = (await _resolve(tester, stream: stream)).colors!;
        expect(c.accent, colors.accentPrimary);
        expect(c.onAccent, colors.textOnAccent);
        expect(c.textPrimary, colors.textPrimary);
        expect(c.textSecondary, colors.textSecondary);
        expect(c.textTertiary, colors.textTertiary);
        expect(c.surface, colors.backgroundSurfaceCard);
        expect(c.sunkenSurface, colors.backgroundSurface);
        expect(c.subtleFill, colors.backgroundSurfaceSubtle);
        expect(c.border, colors.borderDefault);
        expect(c.success, colors.accentSuccess);
        expect(c.warning, colors.accentWarning);
        expect(c.danger, colors.accentError);
        expect(c.info, colors.accentPrimary);
        expect(c.neutral, colors.accentNeutral);
        expect(c.chartPalette, hasLength(8));
      });

      testWidgets('the text styles come from the text theme, without colors', (tester) async {
        final s = (await _resolve(tester, stream: stream)).textStyles!;
        void same(TextStyle? actual, TextStyle token, {FontWeight? weight}) {
          expect(actual!.fontSize, token.fontSize);
          expect(actual.fontWeight, weight ?? token.fontWeight);
          expect(actual.height, token.height);
          expect(actual.fontFamily, token.fontFamily);
          expect(actual.color, isNull);
          expect(actual.foreground, isNull);
          expect(actual.backgroundColor, isNull);
          expect(actual.decorationColor, isNull);
        }

        same(s.title, text.headingMd);
        same(s.heading, text.headingSm);
        same(s.body, text.bodyDefault);
        same(s.bodyLarge, text.headingMd, weight: text.bodyDefault.fontWeight);
        same(s.bodySmall, text.captionDefault);
        same(s.caption, text.metadataDefault);
        expect(s.code!.fontFamily, 'monospace');
        expect(s.code!.fontSize, 13);
        expect((s.metric!.fontSize, s.metric!.fontWeight), (22, FontWeight.w600));
      });
    });
  }

  testWidgets('the defaults the docs give hold for the default Stream theme', (tester) async {
    final theme = await _resolve(tester);
    final spacing = theme.spacing!;
    final radius = theme.radius!;

    expect([spacing.xs, spacing.s, spacing.m, spacing.l, spacing.xl, spacing.xxl], [4, 8, 12, 16, 24, 32]);
    expect([radius.small, radius.medium, radius.large], [8, 12, 16]);
  });

  testWidgets('spacing and radii come from the Stream tokens', (tester) async {
    final stream =
        StreamTheme.light().copyWith(
              spacing: const StreamSpacing(xxs: 1, xs: 2, sm: 3, md: 4, xl: 5, xxl: 6),
              radius: const StreamRadius(
                md: Radius.circular(7),
                lg: Radius.circular(8),
                xl: Radius.circular(9),
                max: Radius.circular(10),
              ),
            )
            as StreamTheme;
    final theme = await _resolve(tester, stream: stream);

    final s = theme.spacing!;
    expect([s.xs, s.s, s.m, s.l, s.xl, s.xxl], [1, 2, 3, 4, 5, 6]);
    final r = theme.radius!;
    expect([r.small, r.medium, r.large, r.pill], [7, 8, 9, 10]);
  });

  testWidgets('code, metric and the chart palette are the same for every Stream theme', (tester) async {
    final light = await _resolve(tester, stream: StreamTheme.light());
    final dark = await _resolve(tester, stream: StreamTheme.dark());

    expect(dark.textStyles!.code, light.textStyles!.code);
    expect(dark.textStyles!.metric, light.textStyles!.metric);
    expect(dark.colors!.chartPalette, light.colors!.chartPalette);
  });

  testWidgets('of fills only what the nearest OpenUITheme leaves null', (tester) async {
    final defaults = await _resolve(tester);
    final theme = await _resolve(
      tester,
      data: const OpenUIThemeData(
        colors: OpenUIColors(accent: _red),
        spacing: OpenUISpacing(m: 99),
        textStyles: OpenUITextStyles(body: TextStyle(fontSize: 31)),
      ),
    );

    expect(theme.colors!.accent, _red);
    expect(theme.colors!.surface, defaults.colors!.surface);
    expect(theme.spacing!.m, 99);
    expect(theme.spacing!.l, defaults.spacing!.l);
    expect(theme.radius, defaults.radius);
    expect(theme.textStyles!.body, const TextStyle(fontSize: 31));
    expect(theme.textStyles!.title, defaults.textStyles!.title);
  });

  testWidgets('a change of the OpenUITheme rebuilds what reads it', (tester) async {
    expect(
      (await _resolve(
        tester,
        data: const OpenUIThemeData(colors: OpenUIColors(accent: _red)),
      )).colors!.accent,
      _red,
    );
    expect(
      (await _resolve(
        tester,
        data: const OpenUIThemeData(colors: OpenUIColors(accent: _blue)),
      )).colors!.accent,
      _blue,
    );
  });

  testWidgets('wrap carries the theme to another route', (tester) async {
    late CapturedThemes captured;
    await tester.pumpWidget(
      testApp(
        OpenUITheme(
          data: const OpenUIThemeData(colors: OpenUIColors(accent: _red)),
          child: Builder(
            builder: (context) {
              captured = InheritedTheme.capture(from: context, to: null);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    late OpenUIThemeData resolved;
    await tester.pumpWidget(
      testApp(
        captured.wrap(
          Builder(
            builder: (context) {
              resolved = OpenUITheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(resolved.colors!.accent, _red);
  });

  group('merge', () {
    test('takes what the other sets, group by group and value by value', () {
      const a = OpenUIThemeData(
        colors: OpenUIColors(accent: _red, border: _red),
        spacing: OpenUISpacing(xs: 1, s: 2),
        radius: OpenUIRadius(small: 1),
        textStyles: OpenUITextStyles(body: TextStyle(fontSize: 1)),
      );
      const b = OpenUIThemeData(
        colors: OpenUIColors(accent: _blue),
        spacing: OpenUISpacing(s: 9),
        radius: OpenUIRadius(large: 9),
      );
      final merged = a.merge(b);

      expect(merged.colors, const OpenUIColors(accent: _blue, border: _red));
      expect(merged.spacing, const OpenUISpacing(xs: 1, s: 9));
      expect(merged.radius, const OpenUIRadius(small: 1, large: 9));
      expect(merged.textStyles, a.textStyles);
      expect(const OpenUIThemeData().merge(b), b);
      expect(a.merge(null), same(a));
    });

    test('of each group replaces each value the other sets', () {
      final colors = const OpenUIColors().merge(_allColors(_red));
      expect(colors, _allColors(_red));
      expect(_allColors(_blue).merge(const OpenUIColors()), _allColors(_blue));
      const spacing = OpenUISpacing(xs: 1, s: 2, m: 3, l: 4, xl: 5, xxl: 6);
      expect(const OpenUISpacing().merge(spacing), spacing);
      const radius = OpenUIRadius(small: 1, medium: 2, large: 3, pill: 4);
      expect(const OpenUIRadius().merge(radius), radius);
      final styles = _allStyles(const TextStyle(fontSize: 5));
      expect(const OpenUITextStyles().merge(styles), styles);
      expect(
        const OpenUITextStyles(
          body: TextStyle(fontWeight: FontWeight.bold),
        ).merge(const OpenUITextStyles(body: TextStyle(fontSize: 5))).body,
        const TextStyle(fontSize: 5),
      );
    });
  });

  group('copyWith', () {
    test('replaces each value and keeps the others', () {
      final c = _allColors(_red);
      expect(_colorFields(c.copyWith(accent: _blue)).first, _blue);
      expect(
        [
          c.copyWith(onAccent: _blue).onAccent,
          c.copyWith(textPrimary: _blue).textPrimary,
          c.copyWith(textSecondary: _blue).textSecondary,
          c.copyWith(textTertiary: _blue).textTertiary,
          c.copyWith(surface: _blue).surface,
          c.copyWith(sunkenSurface: _blue).sunkenSurface,
          c.copyWith(subtleFill: _blue).subtleFill,
          c.copyWith(border: _blue).border,
          c.copyWith(success: _blue).success,
          c.copyWith(warning: _blue).warning,
          c.copyWith(danger: _blue).danger,
          c.copyWith(info: _blue).info,
          c.copyWith(neutral: _blue).neutral,
        ],
        everyElement(_blue),
      );
      expect(c.copyWith(chartPalette: [_blue]).chartPalette, [_blue]);
      expect(c.copyWith(accent: _blue).border, _red);
      const s = OpenUISpacing();
      expect(
        [
          s.copyWith(xs: 9).xs,
          s.copyWith(s: 9).s,
          s.copyWith(m: 9).m,
          s.copyWith(l: 9).l,
          s.copyWith(xl: 9).xl,
          s.copyWith(xxl: 9).xxl,
        ],
        everyElement(9),
      );
      const r = OpenUIRadius();
      expect(
        [
          r.copyWith(small: 9).small,
          r.copyWith(medium: 9).medium,
          r.copyWith(large: 9).large,
          r.copyWith(pill: 9).pill,
        ],
        everyElement(9),
      );
      const style = TextStyle(fontSize: 9);
      expect(
        _styleFields(
          const OpenUITextStyles().copyWith(
            title: style,
            heading: style,
            body: style,
            bodyLarge: style,
            bodySmall: style,
            caption: style,
            code: style,
            metric: style,
          ),
        ),
        everyElement(style),
      );
      const data = OpenUIThemeData();
      expect(data.copyWith(colors: c).colors, c);
      expect(data.copyWith(spacing: s).spacing, s);
      expect(data.copyWith(radius: r).radius, r);
      expect(data.copyWith(textStyles: const OpenUITextStyles()).textStyles, const OpenUITextStyles());
      expect(data.copyWith(colors: c).copyWith(), data.copyWith(colors: c));
    });
  });

  group('lerp', () {
    test('blends values set on both sides and switches the others at the middle', () {
      const a = OpenUIThemeData(
        colors: OpenUIColors(accent: Color(0xFF000000), border: _red, chartPalette: [Color(0xFF000000)]),
        spacing: OpenUISpacing(m: 0, l: 1),
        radius: OpenUIRadius(small: 0),
        textStyles: OpenUITextStyles(body: TextStyle(fontSize: 10)),
      );
      const b = OpenUIThemeData(
        colors: OpenUIColors(accent: Color(0xFFFFFFFF), chartPalette: [Color(0xFFFFFFFF)]),
        spacing: OpenUISpacing(m: 10),
        radius: OpenUIRadius(small: 10),
        textStyles: OpenUITextStyles(body: TextStyle(fontSize: 20)),
      );

      final half = OpenUIThemeData.lerp(a, b, 0.5);
      expect(half.colors!.accent, Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5));
      expect(half.colors!.chartPalette!.single, Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5));
      expect(half.colors!.border, isNull);
      expect(OpenUIThemeData.lerp(a, b, 0.4).colors!.border, _red);
      expect(half.spacing!.m, 5);
      expect(half.spacing!.l, isNull);
      expect(OpenUIThemeData.lerp(a, b, 0.4).spacing!.l, 1);
      expect(half.radius!.small, 5);
      expect(half.textStyles!.body!.fontSize, 15);
      expect(OpenUIThemeData.lerp(a, a, 0.5), same(a));
    });

    test('a palette whose length changes switches at the middle', () {
      const a = OpenUIColors(chartPalette: [_red]);
      const b = OpenUIColors(chartPalette: [_blue, _blue]);

      expect(OpenUIColors.lerp(a, b, 0.4).chartPalette, [_red]);
      expect(OpenUIColors.lerp(a, b, 0.5).chartPalette, [_blue, _blue]);
    });

    test('a group set on only one side switches at the middle', () {
      const a = OpenUIThemeData(colors: OpenUIColors(accent: _red));
      const b = OpenUIThemeData();

      expect(OpenUIThemeData.lerp(a, b, 0.4).colors, a.colors);
      expect(OpenUIThemeData.lerp(a, b, 0.5).colors, isNull);
    });

    test('each color, size, radius and style blends', () {
      final colors = OpenUIColors.lerp(_allColors(const Color(0xFF000000)), _allColors(const Color(0xFFFFFFFF)), 1);
      expect(_colorFields(colors), everyElement(const Color(0xFFFFFFFF)));
      const s0 = OpenUISpacing(xs: 0, s: 0, m: 0, l: 0, xl: 0, xxl: 0);
      const s1 = OpenUISpacing(xs: 1, s: 1, m: 1, l: 1, xl: 1, xxl: 1);
      expect(OpenUISpacing.lerp(s0, s1, 1), s1);
      const r0 = OpenUIRadius(small: 0, medium: 0, large: 0, pill: 0);
      const r1 = OpenUIRadius(small: 1, medium: 1, large: 1, pill: 1);
      expect(OpenUIRadius.lerp(r0, r1, 1), r1);
      final styles = OpenUITextStyles.lerp(
        _allStyles(const TextStyle(fontSize: 0)),
        _allStyles(const TextStyle(fontSize: 10)),
        0.5,
      );
      expect(_styleFields(styles).map((style) => style!.fontSize), everyElement(5));
    });
  });

  group('equality', () {
    test('equal values are equal and share a hash code', () {
      OpenUIThemeData build() => OpenUIThemeData(
        colors: _allColors(_red).copyWith(chartPalette: [_red, _blue]),
        spacing: const OpenUISpacing(m: 1),
        radius: const OpenUIRadius(pill: 2),
        textStyles: _allStyles(const TextStyle(fontSize: 3)),
      );
      final (a, b) = (build(), build());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.colors.hashCode, b.colors.hashCode);
      expect(a.textStyles.hashCode, b.textStyles.hashCode);
    });

    test('a difference in any value makes values unequal', () {
      final c = _allColors(_red);
      expect([
        c.copyWith(accent: _blue),
        c.copyWith(onAccent: _blue),
        c.copyWith(textPrimary: _blue),
        c.copyWith(textSecondary: _blue),
        c.copyWith(textTertiary: _blue),
        c.copyWith(surface: _blue),
        c.copyWith(sunkenSurface: _blue),
        c.copyWith(subtleFill: _blue),
        c.copyWith(border: _blue),
        c.copyWith(success: _blue),
        c.copyWith(warning: _blue),
        c.copyWith(danger: _blue),
        c.copyWith(info: _blue),
        c.copyWith(neutral: _blue),
        c.copyWith(chartPalette: [_blue]),
      ], everyElement(isNot(_allColors(_red))));
      const s = OpenUISpacing(xs: 1, s: 1, m: 1, l: 1, xl: 1, xxl: 1);
      expect([
        s.copyWith(xs: 2),
        s.copyWith(s: 2),
        s.copyWith(m: 2),
        s.copyWith(l: 2),
        s.copyWith(xl: 2),
        s.copyWith(xxl: 2),
      ], everyElement(isNot(s)));
      const r = OpenUIRadius(small: 1, medium: 1, large: 1, pill: 1);
      expect([
        r.copyWith(small: 2),
        r.copyWith(medium: 2),
        r.copyWith(large: 2),
        r.copyWith(pill: 2),
      ], everyElement(isNot(r)));
      final t = _allStyles(const TextStyle(fontSize: 1));
      const style = TextStyle(fontSize: 2);
      expect([
        t.copyWith(title: style),
        t.copyWith(heading: style),
        t.copyWith(body: style),
        t.copyWith(bodyLarge: style),
        t.copyWith(bodySmall: style),
        t.copyWith(caption: style),
        t.copyWith(code: style),
        t.copyWith(metric: style),
      ], everyElement(isNot(t)));
      const data = OpenUIThemeData();
      expect([
        data.copyWith(colors: c),
        data.copyWith(spacing: s),
        data.copyWith(radius: r),
        data.copyWith(textStyles: t),
      ], everyElement(isNot(data)));
    });
  });
}

OpenUIColors _allColors(Color color) => OpenUIColors(
  accent: color,
  onAccent: color,
  textPrimary: color,
  textSecondary: color,
  textTertiary: color,
  surface: color,
  sunkenSurface: color,
  subtleFill: color,
  border: color,
  success: color,
  warning: color,
  danger: color,
  info: color,
  neutral: color,
  chartPalette: [color],
);

List<Color?> _colorFields(OpenUIColors c) => [
  c.accent,
  c.onAccent,
  c.textPrimary,
  c.textSecondary,
  c.textTertiary,
  c.surface,
  c.sunkenSurface,
  c.subtleFill,
  c.border,
  c.success,
  c.warning,
  c.danger,
  c.info,
  c.neutral,
  ...?c.chartPalette,
];

OpenUITextStyles _allStyles(TextStyle style) => OpenUITextStyles(
  title: style,
  heading: style,
  body: style,
  bodyLarge: style,
  bodySmall: style,
  caption: style,
  code: style,
  metric: style,
);

List<TextStyle?> _styleFields(OpenUITextStyles s) => [
  s.title,
  s.heading,
  s.body,
  s.bodyLarge,
  s.bodySmall,
  s.caption,
  s.code,
  s.metric,
];
