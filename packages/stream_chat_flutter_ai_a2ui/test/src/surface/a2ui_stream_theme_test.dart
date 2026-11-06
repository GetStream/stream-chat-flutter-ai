import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_stream_theme.dart';
import 'package:stream_core_flutter/core.dart';

import '../a2ui_test_app.dart';

void main() {
  for (final (name, token, value) in [
    ('accent', (StreamColorScheme colors) => colors.accentPrimary, _theme.accent),
    ('color on the accent', (StreamColorScheme colors) => colors.textOnAccent, _theme.onAccent),
    ('text color', (StreamColorScheme colors) => colors.textPrimary, _theme.text),
    ('secondary text color', (StreamColorScheme colors) => colors.textSecondary, _theme.secondaryText),
    ('card surface', (StreamColorScheme colors) => colors.backgroundSurfaceCard, _theme.surface),
    ('sheet surface', (StreamColorScheme colors) => colors.backgroundElevation1, _theme.surface),
    ('subtle surface', (StreamColorScheme colors) => colors.backgroundSurface, _theme.subtleSurface),
    ('border', (StreamColorScheme colors) => colors.borderDefault, _theme.border),
    ('focused border', (StreamColorScheme colors) => colors.borderActive, _theme.accent),
    ('error color', (StreamColorScheme colors) => colors.accentError, _theme.error),
    ('error border', (StreamColorScheme colors) => colors.borderError, _theme.error),
    ('warning color', (StreamColorScheme colors) => colors.accentWarning, _theme.warning),
  ]) {
    testWidgets("the design system's $name in a surface is the A2UI theme's", (tester) async {
      await _pumpThemed(tester);

      expect(token(_stream(tester).colorScheme), value);
    });
  }

  testWidgets("the design system's body text in a surface has the A2UI theme's size", (tester) async {
    await _pumpThemed(tester);

    expect(_stream(tester).textTheme.bodyDefault.fontSize, _theme.body.fontSize);
  });

  testWidgets("the design system's body text in a surface keeps its color", (tester) async {
    await _pumpThemed(tester);

    expect(_stream(tester).textTheme.bodyDefault.color, StreamTheme.light().textTheme.bodyDefault.color);
  });

  testWidgets("the design system's emphasized body text in a surface keeps its weight", (tester) async {
    await _pumpThemed(tester);

    expect(_stream(tester).textTheme.bodyEmphasis.fontWeight, StreamTheme.light().textTheme.bodyEmphasis.fontWeight);
  });

  testWidgets("the design system's emphasized body text in a surface has the A2UI theme's size", (tester) async {
    await _pumpThemed(tester);

    expect(_stream(tester).textTheme.bodyEmphasis.fontSize, _theme.body.fontSize);
  });

  testWidgets("the design system's corner radii in a surface stay the app's when the A2UI theme sets them", (
    tester,
  ) async {
    await _pumpThemed(tester);

    expect(_stream(tester).radius, StreamTheme.light().radius);
  });

  testWidgets("buttons in a surface have the A2UI theme's button corners", (tester) async {
    await _pumpThemed(tester);

    final buttons = _stream(tester).buttonTheme;
    for (final type in [buttons.primary, buttons.secondary, buttons.destructive]) {
      for (final style in [type?.solid, type?.outline, type?.ghost]) {
        final shape = style?.shape?.resolve({}) as RoundedSuperellipseBorder?;
        expect(shape?.borderRadius, BorderRadius.all(Radius.circular(_theme.buttonCornerRadius)));
      }
    }
  });

  testWidgets("fields in a surface have the A2UI theme's control corners", (tester) async {
    await _pumpThemed(tester);

    expect(
      _stream(tester).textInputTheme.style?.borderRadius,
      BorderRadius.all(Radius.circular(_theme.controlCornerRadius)),
    );
  });

  testWidgets("sheets in a surface have the A2UI theme's corners at their top", (tester) async {
    await _pumpThemed(tester);

    expect(_stream(tester).sheetTheme.borderRadius, BorderRadius.vertical(top: Radius.circular(_theme.cornerRadius)));
  });

  testWidgets("the app's button theme stays in a surface besides the A2UI theme's button corners", (tester) async {
    const minimumSize = WidgetStatePropertyAll<Size?>(Size(1, 1));
    const app = StreamButtonThemeData(
      primary: StreamButtonTypeStyle(solid: StreamButtonThemeStyle(minimumSize: minimumSize)),
    );
    await pumpSurface(
      tester,
      components: _text,
      theme: A2UIThemeData(buttonCornerRadius: 2),
      streamTheme: StreamTheme(buttonTheme: app),
    );

    final solid = _stream(tester).buttonTheme.primary?.solid;

    expect(solid?.minimumSize, minimumSize);
    expect(solid?.shape, isNotNull);
  });

  testWidgets("only buttons in a surface get the A2UI theme's button corners, not other fully round parts", (
    tester,
  ) async {
    await pumpSurface(tester, components: _text, theme: A2UIThemeData(buttonCornerRadius: 2));

    expect(_stream(tester).radius.max, StreamTheme.light().radius.max);
    expect(_stream(tester).textInputTheme, StreamTheme.light().textInputTheme);
    expect(_stream(tester).sheetTheme, StreamTheme.light().sheetTheme);
  });

  testWidgets("the design system's components in a surface without an A2UI theme have the app's corners", (
    tester,
  ) async {
    await pumpSurface(tester, components: _text);

    final outside = StreamTheme.light();
    final inside = _stream(tester);

    expect(inside.radius, outside.radius);
    expect(inside.buttonTheme, outside.buttonTheme);
    expect(inside.textInputTheme, outside.textInputTheme);
    expect(inside.sheetTheme, outside.sheetTheme);
  });

  testWidgets("the design system's other values in a surface are the app's", (tester) async {
    const spacing = StreamSpacing(md: 13);
    final inside = await _pumpBridge(tester, [StreamTheme(spacing: spacing)]);

    expect(StreamTheme.of(inside).spacing, spacing);
  });

  testWidgets("the app's component themes still apply in a surface", (tester) async {
    const checkboxTheme = StreamCheckboxThemeData(style: StreamCheckboxStyle(checkSize: 11));
    final inside = await _pumpBridge(tester, [StreamTheme(checkboxTheme: checkboxTheme)]);

    expect(StreamTheme.of(inside).checkboxTheme, checkboxTheme);
  });

  for (final (name, color, value) in [
    ('primary', (ColorScheme colors) => colors.primary, _theme.accent),
    ('color on primary', (ColorScheme colors) => colors.onPrimary, _theme.onAccent),
    ('surface', (ColorScheme colors) => colors.surface, _theme.surface),
    ('color on the surface', (ColorScheme colors) => colors.onSurface, _theme.text),
    ('quieter color on the surface', (ColorScheme colors) => colors.onSurfaceVariant, _theme.secondaryText),
    ('outline', (ColorScheme colors) => colors.outline, _theme.border),
    ('error color', (ColorScheme colors) => colors.error, _theme.error),
  ]) {
    testWidgets("the Material $name in a surface is the A2UI theme's", (tester) async {
      await _pumpThemed(tester);

      expect(color(Theme.of(_inSurface(tester)).colorScheme), value);
    });
  }

  testWidgets("the app's other theme extensions still apply in a surface", (tester) async {
    final inside = await _pumpBridge(tester, [StreamTheme.light(), const _AppExtension()]);

    expect(Theme.of(inside).extension<_AppExtension>(), isNotNull);
  });
}

// A theme whose every value differs from the light Stream theme's.
final _theme = A2UIResolvedTheme.fromData(_overrides, StreamTheme.light());

final _overrides = A2UIThemeData(
  accent: const Color(0xFF000001),
  onAccent: const Color(0xFF000002),
  text: const Color(0xFF000003),
  secondaryText: const Color(0xFF000004),
  surface: const Color(0xFF000005),
  subtleSurface: const Color(0xFF000006),
  border: const Color(0xFF000007),
  error: const Color(0xFF000008),
  warning: const Color(0xFF000009),
  body: const TextStyle(fontSize: 21),
  cornerRadius: 1,
  buttonCornerRadius: 2,
  controlCornerRadius: 3,
);

const _text = [
  {'id': 'root', 'component': 'Text', 'text': 'Inside'},
];

Future<void> _pumpThemed(WidgetTester tester) => pumpSurface(tester, components: _text, theme: _overrides);

BuildContext _inSurface(WidgetTester tester) => tester.element(find.text('Inside'));

StreamTheme _stream(WidgetTester tester) => StreamTheme.of(_inSurface(tester));

// Shows the A2UI theme's bridge in an app whose theme has [extensions], and
// returns a context inside it.
Future<BuildContext> _pumpBridge(WidgetTester tester, List<ThemeExtension<Object?>> extensions) async {
  late BuildContext inside;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: extensions),
      home: A2UIStreamTheme(
        theme: _theme,
        child: Builder(
          builder: (context) {
            inside = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return inside;
}

// A theme extension of the app's own.
class _AppExtension extends ThemeExtension<_AppExtension> {
  const _AppExtension();

  @override
  _AppExtension copyWith() => this;

  @override
  _AppExtension lerp(_AppExtension? other, double t) => this;
}
