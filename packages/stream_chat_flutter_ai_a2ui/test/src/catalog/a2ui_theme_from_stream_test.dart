import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

// A2UITheme.fromStream takes each value from the Stream design token it maps.
void main() {
  test('the accent is the accent primary color', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).accent, light.colorScheme.accentPrimary);
  });

  test('the color on the accent is the text on accent color', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).onAccent, light.colorScheme.textOnAccent);
  });

  test('the text color is the primary text color', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).text, light.colorScheme.textPrimary);
  });

  test('the secondary text color is the secondary text color', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).secondaryText, light.colorScheme.textSecondary);
  });

  test('the surface is the card background', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).surface, light.colorScheme.backgroundSurfaceCard);
  });

  test('the subtle surface is the surface background', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).subtleSurface, light.colorScheme.backgroundSurface);
  });

  test('the border is the default border color', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).border, light.colorScheme.borderDefault);
  });

  test('the error color is the error accent', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).error, light.colorScheme.accentError);
  });

  test('the warning color is the warning accent', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).warning, light.colorScheme.accentWarning);
  });

  test('the body style is the default body style', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).body, _sameButColor(light.textTheme.bodyDefault));
  });

  test('the caption style is the default metadata style', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).caption, _sameButColor(light.textTheme.metadataDefault));
  });

  test('the label style is the default caption style', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).label, _sameButColor(light.textTheme.captionDefault));
  });

  test('the headings are the four heading styles, largest first', () {
    final light = _light();
    final text = light.textTheme;

    expect(A2UITheme.fromStream(light).headings, [
      _sameButColor(text.headingLg),
      _sameButColor(text.headingMd),
      _sameButColor(text.headingSm),
      _sameButColor(text.headingXs),
    ]);
  });

  test("the text styles drop the color of the design system's styles", () {
    final light = _light();
    final text = light.textTheme;
    final theme = A2UITheme.fromStream(light);

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

    expect(A2UITheme.fromStream(stream).body, _sameButColor(style));
  });

  test('cards have the extra large radius', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).cornerRadius, light.radius.xl.x);
  });

  test('buttons are fully rounded', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).buttonCornerRadius, light.radius.max.x);
  });

  test('fields have the extra large radius', () {
    final light = _light();

    expect(A2UITheme.fromStream(light).controlCornerRadius, light.radius.xl.x);
  });

  test('the dark theme takes the dark card background', () {
    final dark = _dark();

    expect(A2UITheme.fromStream(dark).surface, dark.colorScheme.backgroundSurfaceCard);
  });

  test('the dark card background differs from the light one', () {
    final light = _light();
    final dark = _dark();

    expect(A2UITheme.fromStream(dark).surface, isNot(A2UITheme.fromStream(light).surface));
  });

  test('the dark theme takes the dark text on accent color', () {
    final dark = _dark();

    expect(A2UITheme.fromStream(dark).onAccent, dark.colorScheme.textOnAccent);
  });

  test('a theme with a custom accent takes it', () {
    final custom = StreamTheme(colorScheme: StreamColorScheme.light(accentPrimary: const Color(0xFFE65100)));

    expect(A2UITheme.fromStream(custom).accent, const Color(0xFFE65100));
  });
}

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
