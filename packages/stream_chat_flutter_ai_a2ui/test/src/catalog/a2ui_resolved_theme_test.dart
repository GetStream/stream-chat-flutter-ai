import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

// A theme that sets nothing takes each value from the Stream design token it
// maps; a value the theme sets wins.
void main() {
  test('a value the theme sets wins over the Stream token', () {
    final theme = A2UIResolvedTheme.fromData(A2UIThemeData(accent: const Color(0xFFE65100), cornerRadius: 3), _light());

    expect((theme.accent, theme.cornerRadius), (const Color(0xFFE65100), 3.0));
  });

  test('heading styles the theme sets win over the Stream ones', () {
    const style = TextStyle(fontSize: 40);

    expect(A2UIResolvedTheme.fromData(A2UIThemeData(headings: const [style]), _light()).headings, [style]);
  });

  test('heading 1 is the first heading style', () {
    final theme = _resolve(_light());

    expect(theme.heading(1), theme.headings.first);
  });

  test('heading 3 is the third heading style', () {
    final theme = _resolve(_light());

    expect(theme.heading(3), theme.headings[2]);
  });

  test('a level below 1 gives the first heading style', () {
    final theme = _resolve(_light());

    expect(theme.heading(0), theme.headings.first);
  });

  test('a level past the last gives the last heading style', () {
    final theme = _resolve(_light());

    expect(theme.heading(9), theme.headings.last);
  });

  testWidgets('resolve layers the override over the nearest A2UITheme over the Stream theme', (tester) async {
    late A2UIResolvedTheme theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [StreamTheme.light()]),
        home: A2UITheme(
          data: A2UIThemeData(accent: const Color(0xFF000001), cornerRadius: 3),
          child: Builder(
            builder: (context) {
              theme = A2UIResolvedTheme.resolve(context, override: A2UIThemeData(cornerRadius: 5));
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
      (theme.accent, theme.cornerRadius, theme.text),
      (
        const Color(0xFF000001),
        5.0,
        StreamTheme.light().colorScheme.textPrimary,
      ),
    );
  });

  test('the accent is the accent primary color', () {
    final light = _light();

    expect(_resolve(light).accent, light.colorScheme.accentPrimary);
  });

  test('the color on the accent is the text on accent color', () {
    final light = _light();

    expect(_resolve(light).onAccent, light.colorScheme.textOnAccent);
  });

  test('the text color is the primary text color', () {
    final light = _light();

    expect(_resolve(light).text, light.colorScheme.textPrimary);
  });

  test('the secondary text color is the secondary text color', () {
    final light = _light();

    expect(_resolve(light).secondaryText, light.colorScheme.textSecondary);
  });

  test('the surface is the card background', () {
    final light = _light();

    expect(_resolve(light).surface, light.colorScheme.backgroundSurfaceCard);
  });

  test('the subtle surface is the surface background', () {
    final light = _light();

    expect(_resolve(light).subtleSurface, light.colorScheme.backgroundSurface);
  });

  test('the border is the default border color', () {
    final light = _light();

    expect(_resolve(light).border, light.colorScheme.borderDefault);
  });

  test('the error color is the error accent', () {
    final light = _light();

    expect(_resolve(light).error, light.colorScheme.accentError);
  });

  test('the warning color is the warning accent', () {
    final light = _light();

    expect(_resolve(light).warning, light.colorScheme.accentWarning);
  });

  test('the body style is the default body style', () {
    final light = _light();

    expect(_resolve(light).body, _sameButColor(light.textTheme.bodyDefault));
  });

  test('the caption style is the default metadata style', () {
    final light = _light();

    expect(_resolve(light).caption, _sameButColor(light.textTheme.metadataDefault));
  });

  test('the label style is the default caption style', () {
    final light = _light();

    expect(_resolve(light).label, _sameButColor(light.textTheme.captionDefault));
  });

  test("the first heading is the largest heading style at the largest text size, with that style's line spacing", () {
    final light = _light();
    final typography = light.typography;
    final heading = _resolve(light).heading(1);

    expect(heading.fontSize, typography.fontSize.xxl);
    expect(heading.fontWeight, light.textTheme.headingLg.fontWeight);
    expect(heading.height, light.textTheme.headingLg.height);
    expect(heading.height, greaterThan(1));
    expect(heading.color, isNull);
  });

  test('the headings below the first are the heading styles, largest first, the small one twice', () {
    final light = _light();
    final text = light.textTheme;

    expect(_resolve(light).headings.skip(1), [
      _sameButColor(text.headingLg),
      _sameButColor(text.headingMd),
      _sameButColor(text.headingSm),
      _sameButColor(text.headingSm),
      _sameButColor(text.headingXs),
    ]);
  });

  test("the text styles drop the color of the design system's styles", () {
    final light = _light();
    final text = light.textTheme;
    final theme = _resolve(light);

    // The design system's styles carry a color, so a style without one is the
    // theme dropping it.
    expect(
      [
        text.bodyDefault,
        text.metadataDefault,
        text.captionDefault,
        text.headingLg,
        text.headingMd,
        text.headingSm,
        text.headingXs,
      ].map((style) => style.color),
      everyElement(isNotNull),
    );
    expect(
      [theme.body, theme.caption, theme.label, ...theme.headings].map((style) => style.color),
      everyElement(isNull),
    );
  });

  test("a text style keeps every value of the design system's style but its color", () {
    final style = _styleWithEveryValue();
    final stream = StreamTheme(textTheme: StreamTextTheme(bodyDefault: style));

    expect(_resolve(stream).body, _sameButColor(style));
  });

  test('cards have the extra large radius', () {
    final light = _light();

    expect(_resolve(light).cornerRadius, light.radius.xl.x);
  });

  test('buttons are fully rounded', () {
    final light = _light();

    expect(_resolve(light).buttonCornerRadius, light.radius.max.x);
  });

  test('fields have the extra large radius', () {
    final light = _light();

    expect(_resolve(light).controlCornerRadius, light.radius.xl.x);
  });

  test('the dark theme takes the dark card background', () {
    final dark = _dark();

    expect(_resolve(dark).surface, dark.colorScheme.backgroundSurfaceCard);
  });

  test('the dark card background differs from the light one', () {
    final light = _light();
    final dark = _dark();

    expect(_resolve(dark).surface, isNot(_resolve(light).surface));
  });

  test('the dark theme takes the dark text on accent color', () {
    final dark = _dark();

    expect(_resolve(dark).onAccent, dark.colorScheme.textOnAccent);
  });

  test('a theme with a custom accent takes it', () {
    final custom = StreamTheme(colorScheme: StreamColorScheme.light(accentPrimary: const Color(0xFFE65100)));

    expect(_resolve(custom).accent, const Color(0xFFE65100));
  });
}

A2UIResolvedTheme _resolve(StreamTheme stream) => A2UIResolvedTheme.fromData(const A2UIThemeData.empty(), stream);

StreamTheme _light() => StreamTheme.light();

StreamTheme _dark() => StreamTheme.dark();

// A style equal to [style] once given its color: the theme's copy of a design
// system style keeps all of it but the color.
Matcher _sameButColor(TextStyle style) {
  return isA<TextStyle>().having((it) => it.copyWith(color: style.color), 'the style with its color', style);
}

// A style that sets every value a text style has but a foreground and a
// background paint, which a style with a color can't have.
TextStyle _styleWithEveryValue() {
  return const TextStyle(
    inherit: false,
    color: Color(0xFF101010),
    backgroundColor: Color(0xFF202020),
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.5,
    wordSpacing: 2,
    textBaseline: TextBaseline.ideographic,
    height: 1.4,
    leadingDistribution: TextLeadingDistribution.even,
    locale: Locale('mk'),
    shadows: [Shadow(blurRadius: 3)],
    fontFeatures: [FontFeature.tabularFigures()],
    fontVariations: [FontVariation.weight(500)],
    decoration: TextDecoration.underline,
    decorationColor: Color(0xFF303030),
    decorationStyle: TextDecorationStyle.dotted,
    decorationThickness: 2,
    debugLabel: 'every value',
    fontFamily: 'Serif',
    fontFamilyFallback: ['Sans'],
    overflow: TextOverflow.fade,
  );
}
