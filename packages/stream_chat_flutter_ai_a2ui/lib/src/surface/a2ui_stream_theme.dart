import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// Makes the Stream design system's components below [child] draw with
/// [theme]: its colors, its body text and its corner radii replace the app's
/// in the design system's theme, and its colors the app's Material colors.
///
/// Everything else of the app's themes stays, the component themes the app
/// sets among it.
///
/// Internal to the package.
@internal
class A2UIStreamTheme extends StatelessWidget {
  /// Creates an [A2UIStreamTheme].
  const A2UIStreamTheme({super.key, required this.theme, required this.child});

  /// The theme the design system's components are drawn with.
  final A2UIResolvedTheme theme;

  /// The widget below this one.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final stream = StreamTheme.of(context);
    return Theme(
      data: material.copyWith(
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
          _streamThemeOf(stream, theme),
        ],
      ),
      child: child,
    );
  }
}

// The design system's [stream] theme with the colors, body text and corner
// radii of [theme].
StreamTheme _streamThemeOf(StreamTheme stream, A2UIResolvedTheme theme) {
  final colors = stream.colorScheme;
  final text = stream.textTheme;
  // The radii the design system's buttons, fields and sheets are drawn with.
  final radius = stream.radius.copyWith(
    max: Radius.circular(theme.buttonCornerRadius),
    lg: Radius.circular(theme.controlCornerRadius),
    xxxxl: Radius.circular(theme.cornerRadius),
  );
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
        radius: radius,
      )
      as StreamTheme;
}
