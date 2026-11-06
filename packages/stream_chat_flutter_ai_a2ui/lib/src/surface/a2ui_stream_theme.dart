import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// Makes the Stream design system's components below [child] draw with
/// [theme]: its colors and its body text replace the app's in the design
/// system's theme, and its colors the app's Material colors.
///
/// The corner radii [data] sets shape the design system's buttons, fields and
/// sheets, through their component themes; one it leaves unset leaves them as
/// the app draws them. The design system's radius tokens stay the app's, so
/// its other components keep their corners.
///
/// The components are drawn under Material 3 even in a Material 2 app, as
/// the design system's components that are built on Material ones, such as
/// its checkbox, draw their look only there.
///
/// Everything else of the app's themes stays, the component themes the app
/// sets among it.
///
/// Internal to the package.
@internal
class A2UIStreamTheme extends StatelessWidget {
  /// Creates an [A2UIStreamTheme].
  const A2UIStreamTheme({super.key, required this.theme, this.data = const A2UIThemeData.empty(), required this.child});

  /// The theme the design system's components are drawn with.
  final A2UIResolvedTheme theme;

  /// The A2UI theme the app and the surface set, before its unset values are
  /// filled from the design system's, which says which corner radii they set.
  final A2UIThemeData data;

  /// The widget below this one.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final stream = StreamTheme.of(context);
    return Theme(
      data: material.copyWith(
        // ThemeData's constructors can't keep the rest of the app's theme.
        // ignore: deprecated_member_use
        useMaterial3: true,
        colorScheme: material.colorScheme.copyWith(
          primary: theme.accent,
          onPrimary: theme.onAccent,
          surface: theme.surface,
          onSurface: theme.text,
          onSurfaceVariant: theme.secondaryText,
          outline: theme.border,
          error: theme.error,
        ),
        extensions: [
          for (final extension in material.extensions.values)
            if (extension is! StreamTheme) extension,
          _streamThemeOf(stream, theme, data),
        ],
      ),
      child: child,
    );
  }
}

// The design system's [stream] theme with the colors and body text of
// [theme], and the corner radii [data] sets.
StreamTheme _streamThemeOf(StreamTheme stream, A2UIResolvedTheme theme, A2UIThemeData data) {
  final colors = stream.colorScheme;
  final text = stream.textTheme;
  return stream.copyWith(
        colorScheme: colors.copyWith(
          accentPrimary: theme.accent,
          textOnAccent: theme.onAccent,
          textPrimary: theme.text,
          textSecondary: theme.secondaryText,
          backgroundSurfaceCard: theme.surface,
          backgroundElevation1: theme.surface,
          backgroundSurface: theme.subtleSurface,
          borderDefault: theme.border,
          borderActive: theme.accent,
          accentError: theme.error,
          borderError: theme.error,
          accentWarning: theme.warning,
        ),
        // The A2UI styles have no color, so the design system's colors stay.
        textTheme: text.copyWith(
          bodyDefault: text.bodyDefault.merge(theme.body),
          bodyEmphasis: text.bodyEmphasis.merge(theme.body.copyWith(fontWeight: text.bodyEmphasis.fontWeight)),
        ),
        buttonTheme: _buttonThemeOf(stream.buttonTheme, data.buttonCornerRadius),
        textInputTheme: _textInputThemeOf(stream.textInputTheme, data.controlCornerRadius),
        sheetTheme: _sheetThemeOf(stream.sheetTheme, data.cornerRadius),
      )
      as StreamTheme;
}

// The app's button theme, with every button's corners [radius] round when it
// is set.
StreamButtonThemeData _buttonThemeOf(StreamButtonThemeData buttons, double? radius) {
  if (radius == null) return buttons;
  final shaped = StreamButtonThemeStyle(
    shape: WidgetStatePropertyAll(RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(radius)))),
  );
  final type = StreamButtonTypeStyle(solid: shaped, outline: shaped, ghost: shaped);
  return buttons.merge(StreamButtonThemeData(primary: type, secondary: type, destructive: type));
}

// The app's text input theme, with the fields' corners [radius] round when it
// is set.
StreamTextInputThemeData _textInputThemeOf(StreamTextInputThemeData inputs, double? radius) {
  if (radius == null) return inputs;
  return inputs.merge(
    StreamTextInputThemeData(style: StreamTextInputStyle(borderRadius: BorderRadius.all(Radius.circular(radius)))),
  );
}

// The app's sheet theme, with the sheets' top corners [radius] round when it
// is set.
StreamSheetThemeData _sheetThemeOf(StreamSheetThemeData sheets, double? radius) {
  if (radius == null) return sheets;
  return sheets.merge(StreamSheetThemeData(borderRadius: BorderRadius.vertical(top: Radius.circular(radius))));
}
