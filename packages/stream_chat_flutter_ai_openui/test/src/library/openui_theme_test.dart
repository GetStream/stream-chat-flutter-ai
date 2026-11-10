import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_core_flutter/core.dart';

import '../openui_test_app.dart';

// The theme the components draw with under [stream], with [data] in an
// OpenUITheme around when given.
Future<OpenUIResolvedTheme> _resolve(WidgetTester tester, {StreamTheme? stream, OpenUIThemeData? data}) async {
  late OpenUIResolvedTheme resolved;
  Widget child = Builder(
    builder: (context) {
      resolved = OpenUIResolvedTheme.resolve(context);
      return const SizedBox();
    },
  );
  if (data != null) child = OpenUITheme(data: data, child: child);
  await tester.pumpWidget(testApp(child, stream: stream));
  return resolved;
}

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

// Every color, size and style of an OpenUIThemeData, by field name.
OpenUIThemeData _all({Color color = _red, double size = 1, TextStyle style = const TextStyle(fontSize: 1)}) {
  return OpenUIThemeData(
    accent: color,
    onAccent: color,
    text: color,
    secondaryText: color,
    tertiaryText: color,
    surface: color,
    sunkenSurface: color,
    subtleFill: color,
    border: color,
    success: color,
    warning: color,
    error: color,
    info: color,
    neutral: color,
    chartPalette: [color],
    xsSpacing: size,
    sSpacing: size,
    mSpacing: size,
    lSpacing: size,
    xlSpacing: size,
    xxlSpacing: size,
    smallCornerRadius: size,
    mediumCornerRadius: size,
    cornerRadius: size,
    pillCornerRadius: size,
    title: style,
    heading: style,
    body: style,
    bodyLarge: style,
    bodySmall: style,
    caption: style,
    code: style,
    metric: style,
  );
}

// [data] with the field [name] replaced by [value], through copyWith.
OpenUIThemeData _with(OpenUIThemeData data, String name, Object value) {
  return switch (name) {
    'accent' => data.copyWith(accent: value as Color),
    'onAccent' => data.copyWith(onAccent: value as Color),
    'text' => data.copyWith(text: value as Color),
    'secondaryText' => data.copyWith(secondaryText: value as Color),
    'tertiaryText' => data.copyWith(tertiaryText: value as Color),
    'surface' => data.copyWith(surface: value as Color),
    'sunkenSurface' => data.copyWith(sunkenSurface: value as Color),
    'subtleFill' => data.copyWith(subtleFill: value as Color),
    'border' => data.copyWith(border: value as Color),
    'success' => data.copyWith(success: value as Color),
    'warning' => data.copyWith(warning: value as Color),
    'error' => data.copyWith(error: value as Color),
    'info' => data.copyWith(info: value as Color),
    'neutral' => data.copyWith(neutral: value as Color),
    'chartPalette' => data.copyWith(chartPalette: value as List<Color>),
    'xsSpacing' => data.copyWith(xsSpacing: value as double),
    'sSpacing' => data.copyWith(sSpacing: value as double),
    'mSpacing' => data.copyWith(mSpacing: value as double),
    'lSpacing' => data.copyWith(lSpacing: value as double),
    'xlSpacing' => data.copyWith(xlSpacing: value as double),
    'xxlSpacing' => data.copyWith(xxlSpacing: value as double),
    'smallCornerRadius' => data.copyWith(smallCornerRadius: value as double),
    'mediumCornerRadius' => data.copyWith(mediumCornerRadius: value as double),
    'cornerRadius' => data.copyWith(cornerRadius: value as double),
    'pillCornerRadius' => data.copyWith(pillCornerRadius: value as double),
    'title' => data.copyWith(title: value as TextStyle),
    'heading' => data.copyWith(heading: value as TextStyle),
    'body' => data.copyWith(body: value as TextStyle),
    'bodyLarge' => data.copyWith(bodyLarge: value as TextStyle),
    'bodySmall' => data.copyWith(bodySmall: value as TextStyle),
    'caption' => data.copyWith(caption: value as TextStyle),
    'code' => data.copyWith(code: value as TextStyle),
    'metric' => data.copyWith(metric: value as TextStyle),
    _ => throw ArgumentError(name),
  };
}

// The value of the field [name] of [data].
Object? _read(OpenUIThemeData d, String name) => switch (name) {
  'accent' => d.accent,
  'onAccent' => d.onAccent,
  'text' => d.text,
  'secondaryText' => d.secondaryText,
  'tertiaryText' => d.tertiaryText,
  'surface' => d.surface,
  'sunkenSurface' => d.sunkenSurface,
  'subtleFill' => d.subtleFill,
  'border' => d.border,
  'success' => d.success,
  'warning' => d.warning,
  'error' => d.error,
  'info' => d.info,
  'neutral' => d.neutral,
  'chartPalette' => d.chartPalette,
  'xsSpacing' => d.xsSpacing,
  'sSpacing' => d.sSpacing,
  'mSpacing' => d.mSpacing,
  'lSpacing' => d.lSpacing,
  'xlSpacing' => d.xlSpacing,
  'xxlSpacing' => d.xxlSpacing,
  'smallCornerRadius' => d.smallCornerRadius,
  'mediumCornerRadius' => d.mediumCornerRadius,
  'cornerRadius' => d.cornerRadius,
  'pillCornerRadius' => d.pillCornerRadius,
  'title' => d.title,
  'heading' => d.heading,
  'body' => d.body,
  'bodyLarge' => d.bodyLarge,
  'bodySmall' => d.bodySmall,
  'caption' => d.caption,
  'code' => d.code,
  'metric' => d.metric,
  _ => throw ArgumentError(name),
};

// The value of the field [name] of the resolved theme [d].
Object? _readResolved(OpenUIResolvedTheme d, String name) => switch (name) {
  'accent' => d.accent,
  'onAccent' => d.onAccent,
  'text' => d.text,
  'secondaryText' => d.secondaryText,
  'tertiaryText' => d.tertiaryText,
  'surface' => d.surface,
  'sunkenSurface' => d.sunkenSurface,
  'subtleFill' => d.subtleFill,
  'border' => d.border,
  'success' => d.success,
  'warning' => d.warning,
  'error' => d.error,
  'info' => d.info,
  'neutral' => d.neutral,
  'chartPalette' => d.chartPalette,
  'xsSpacing' => d.xsSpacing,
  'sSpacing' => d.sSpacing,
  'mSpacing' => d.mSpacing,
  'lSpacing' => d.lSpacing,
  'xlSpacing' => d.xlSpacing,
  'xxlSpacing' => d.xxlSpacing,
  'smallCornerRadius' => d.smallCornerRadius,
  'mediumCornerRadius' => d.mediumCornerRadius,
  'cornerRadius' => d.cornerRadius,
  'pillCornerRadius' => d.pillCornerRadius,
  'title' => d.title,
  'heading' => d.heading,
  'body' => d.body,
  'bodyLarge' => d.bodyLarge,
  'bodySmall' => d.bodySmall,
  'caption' => d.caption,
  'code' => d.code,
  'metric' => d.metric,
  _ => throw ArgumentError(name),
};

const _colorNames = [
  'accent', 'onAccent', 'text', 'secondaryText', 'tertiaryText', 'surface', 'sunkenSurface', 'subtleFill', 'border',
  'success', 'warning', 'error', 'info', 'neutral', //
];
const _sizeNames = [
  'xsSpacing', 'sSpacing', 'mSpacing', 'lSpacing', 'xlSpacing', 'xxlSpacing', 'smallCornerRadius',
  'mediumCornerRadius', 'cornerRadius', 'pillCornerRadius', //
];
const _styleNames = ['title', 'heading', 'body', 'bodyLarge', 'bodySmall', 'caption', 'code', 'metric'];

// A value to replace the field [name] with, different from [_all]'s.
Object _other(String name) {
  if (name == 'chartPalette') return [_blue];
  if (_colorNames.contains(name)) return _blue;
  if (_sizeNames.contains(name)) return 9.0;
  return const TextStyle(fontSize: 9);
}

final _allNames = [..._colorNames, 'chartPalette', ..._sizeNames, ..._styleNames];

void main() {
  for (final (name, stream) in [('light', StreamTheme.light()), ('dark', StreamTheme.dark())]) {
    group('defaults ($name)', () {
      final colors = stream.colorScheme;
      final text = stream.textTheme;

      testWidgets('the colors come from the color scheme', (tester) async {
        final c = await _resolve(tester, stream: stream);
        expect(c.accent, colors.accentPrimary);
        expect(c.onAccent, colors.textOnAccent);
        expect(c.text, colors.textPrimary);
        expect(c.secondaryText, colors.textSecondary);
        expect(c.tertiaryText, colors.textTertiary);
        expect(c.surface, colors.backgroundSurfaceCard);
        expect(c.sunkenSurface, colors.backgroundSurface);
        expect(c.subtleFill, colors.backgroundSurfaceSubtle);
        expect(c.border, colors.borderDefault);
        expect(c.success, colors.accentSuccess);
        expect(c.warning, colors.accentWarning);
        expect(c.error, colors.accentError);
        expect(c.info, colors.accentPrimary);
        expect(c.neutral, colors.accentNeutral);
        expect(c.chartPalette, hasLength(8));
      });

      testWidgets('the text styles come from the text theme, without colors', (tester) async {
        final s = await _resolve(tester, stream: stream);
        void same(TextStyle actual, TextStyle token, {FontWeight? weight}) {
          expect(actual.fontSize, token.fontSize);
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
        expect(s.code.fontFamily, 'monospace');
        expect(s.code.fontSize, 13);
        expect((s.metric.fontSize, s.metric.fontWeight), (22, FontWeight.w600));
      });
    });
  }

  testWidgets('every value is set', (tester) async {
    final theme = await _resolve(tester);

    for (final name in _allNames) {
      expect(_readResolved(theme, name), isNotNull, reason: name);
    }
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
    final t = await _resolve(tester, stream: stream);

    expect([t.xsSpacing, t.sSpacing, t.mSpacing, t.lSpacing, t.xlSpacing, t.xxlSpacing], [1, 2, 3, 4, 5, 6]);
    expect([t.smallCornerRadius, t.mediumCornerRadius, t.cornerRadius, t.pillCornerRadius], [7, 8, 9, 10]);
  });

  testWidgets('code, metric and the chart palette are the same for every Stream theme', (tester) async {
    final light = await _resolve(tester, stream: StreamTheme.light());
    final dark = await _resolve(tester, stream: StreamTheme.dark());

    expect(dark.code, light.code);
    expect(dark.metric, light.metric);
    expect(dark.chartPalette, light.chartPalette);
  });

  testWidgets('resolving fills only what the nearest OpenUITheme leaves null', (tester) async {
    final defaults = await _resolve(tester);
    final theme = await _resolve(
      tester,
      data: OpenUIThemeData(accent: _red, mSpacing: 99, body: const TextStyle(fontSize: 31)),
    );

    expect(theme.accent, _red);
    expect(theme.surface, defaults.surface);
    expect(theme.mSpacing, 99);
    expect(theme.lSpacing, defaults.lSpacing);
    expect(theme.cornerRadius, defaults.cornerRadius);
    expect(theme.body, const TextStyle(fontSize: 31));
    expect(theme.title, defaults.title);
  });

  testWidgets('of gives the nearest OpenUITheme data as it is, and empty data without one', (tester) async {
    late OpenUIThemeData inside;
    late OpenUIThemeData outside;
    final data = OpenUIThemeData(accent: _red);
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) {
            outside = OpenUITheme.of(context);
            return OpenUITheme(
              data: data,
              child: Builder(
                builder: (context) {
                  inside = OpenUITheme.of(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(outside, const OpenUIThemeData.empty());
    expect(inside, same(data));
    expect(inside.surface, isNull);
  });

  testWidgets('a change of the OpenUITheme rebuilds what reads it', (tester) async {
    expect((await _resolve(tester, data: OpenUIThemeData(accent: _red))).accent, _red);
    expect((await _resolve(tester, data: OpenUIThemeData(accent: _blue))).accent, _blue);
  });

  testWidgets('wrap carries the theme to another route', (tester) async {
    late CapturedThemes captured;
    await tester.pumpWidget(
      testApp(
        OpenUITheme(
          data: OpenUIThemeData(accent: _red),
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

    expect(resolved.accent, _red);
  });

  group('OpenUITheme.merge', () {
    testWidgets('layers its data over the enclosing theme', (tester) async {
      late OpenUIThemeData resolved;
      await tester.pumpWidget(
        testApp(
          OpenUITheme(
            data: OpenUIThemeData(accent: _red, border: _red),
            child: OpenUITheme.merge(
              data: OpenUIThemeData(accent: _blue),
              child: Builder(
                builder: (context) {
                  resolved = OpenUITheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(resolved.accent, _blue);
      expect(resolved.border, _red);
    });

    testWidgets('stands alone without an enclosing theme', (tester) async {
      late OpenUIThemeData resolved;
      await tester.pumpWidget(
        testApp(
          OpenUITheme.merge(
            data: OpenUIThemeData(accent: _blue),
            child: Builder(
              builder: (context) {
                resolved = OpenUITheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved.accent, _blue);
    });
  });

  group('empty', () {
    test('overrides nothing', () {
      const empty = OpenUIThemeData.empty();

      for (final name in _allNames) {
        expect(_read(empty, name), isNull, reason: name);
      }
      expect(empty, OpenUIThemeData());
    });
  });

  test('the chart palette is copied and not empty', () {
    final palette = [_red];
    final data = OpenUIThemeData(chartPalette: palette);
    palette.add(_blue);

    expect(data.chartPalette, [_red]);
    expect(() => data.chartPalette!.add(_blue), throwsUnsupportedError);
    expect(() => OpenUIThemeData(chartPalette: const []), throwsAssertionError);
  });

  group('merge', () {
    test('takes what the other sets and keeps the rest', () {
      final a = OpenUIThemeData(
        accent: _red,
        border: _red,
        xsSpacing: 1,
        sSpacing: 2,
        body: const TextStyle(fontSize: 1),
      );
      final b = OpenUIThemeData(accent: _blue, sSpacing: 9, cornerRadius: 9);
      final merged = a.merge(b);

      expect(merged.accent, _blue);
      expect(merged.border, _red);
      expect(merged.xsSpacing, 1);
      expect(merged.sSpacing, 9);
      expect(merged.cornerRadius, 9);
      expect(merged.body, a.body);
      expect(const OpenUIThemeData.empty().merge(b), b);
      expect(a.merge(null), same(a));
      expect(a.merge(a), same(a));
    });

    test('replaces each value the other sets', () {
      expect(const OpenUIThemeData.empty().merge(_all(color: _red)), _all(color: _red));
      expect(_all(color: _blue).merge(const OpenUIThemeData.empty()), _all(color: _blue));
    });

    test('replaces a text style as a whole', () {
      final merged = OpenUIThemeData(
        body: const TextStyle(fontWeight: FontWeight.bold),
      ).merge(OpenUIThemeData(body: const TextStyle(fontSize: 5)));

      expect(merged.body, const TextStyle(fontSize: 5));
    });
  });

  group('copyWith', () {
    for (final name in _allNames) {
      test('replaces $name and keeps the others', () {
        final base = _all();
        final copy = _with(base, name, _other(name));

        expect(_read(copy, name), _other(name));
        for (final other in _allNames.where((n) => n != name)) {
          expect(_read(copy, other), _read(base, other), reason: other);
        }
      });
    }

    test('keeps every value for null arguments', () {
      expect(_all().copyWith(), _all());
    });
  });

  group('lerp', () {
    test('blends values set on both sides and switches the others at the middle', () {
      final a = OpenUIThemeData(
        accent: _black,
        border: _red,
        chartPalette: const [_black],
        mSpacing: 0,
        lSpacing: 1,
        smallCornerRadius: 0,
        body: const TextStyle(fontSize: 10),
      );
      final b = OpenUIThemeData(
        accent: _white,
        chartPalette: const [_white],
        mSpacing: 10,
        smallCornerRadius: 10,
        body: const TextStyle(fontSize: 20),
      );

      final half = OpenUIThemeData.lerp(a, b, 0.5);
      final mid = Color.lerp(_black, _white, 0.5);
      expect(half.accent, mid);
      expect(half.chartPalette, [mid]);
      expect(half.border, isNull);
      expect(OpenUIThemeData.lerp(a, b, 0.4).border, _red);
      expect(half.mSpacing, 5);
      expect(half.lSpacing, isNull);
      expect(OpenUIThemeData.lerp(a, b, 0.4).lSpacing, 1);
      expect(half.smallCornerRadius, 5);
      expect(half.body!.fontSize, 15);
      expect(OpenUIThemeData.lerp(a, a, 0.5), same(a));
    });

    test('a palette whose length changes switches at the middle', () {
      final a = OpenUIThemeData(chartPalette: const [_red]);
      final b = OpenUIThemeData(chartPalette: const [_blue, _blue]);

      expect(OpenUIThemeData.lerp(a, b, 0.4).chartPalette, [_red]);
      expect(OpenUIThemeData.lerp(a, b, 0.5).chartPalette, [_blue, _blue]);
    });

    test('every value blends', () {
      final from = _all(color: _black, size: 0, style: const TextStyle(fontSize: 0));
      final to = _all(color: _white, size: 10, style: const TextStyle(fontSize: 10));
      final half = OpenUIThemeData.lerp(from, to, 0.5);

      for (final name in _colorNames) {
        expect(_read(half, name), Color.lerp(_black, _white, 0.5), reason: name);
      }
      expect(half.chartPalette, [Color.lerp(_black, _white, 0.5)]);
      for (final name in _sizeNames) {
        expect(_read(half, name), 5, reason: name);
      }
      for (final name in _styleNames) {
        expect((_read(half, name)! as TextStyle).fontSize, 5, reason: name);
      }
    });
  });

  group('equality', () {
    test('equal values are equal and share a hash code', () {
      final (a, b) = (_all().copyWith(chartPalette: [_red, _blue]), _all().copyWith(chartPalette: [_red, _blue]));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    for (final name in _allNames) {
      test('a different $name makes values unequal', () {
        final base = _all();
        final changed = _with(base, name, _other(name));

        expect(changed, isNot(base));
        expect(changed.hashCode, isNot(base.hashCode));
      });
    }
  });

  test('debugFillProperties lists the set values only', () {
    final builder = DiagnosticPropertiesBuilder();
    OpenUIThemeData(accent: _red, cornerRadius: 4).debugFillProperties(builder);
    final shown = builder.properties.where((p) => !p.isFiltered(DiagnosticLevel.info)).map((p) => p.name);

    expect(shown, ['accent', 'cornerRadius']);
  });
}
