import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// Makes the Stream design system's components below [child] draw with
/// [theme]: its colors, spacing, corner radii and text styles replace the
/// tokens they default from in the design system's theme, and an accent other
/// than the design system's colors links too. A text style replaces its token
/// as a whole, except that the design system's text color stays when it sets none.
///
/// So a [theme] of defaults only, as the design system's theme around gives
/// them, changes nothing. Everything else of the app's themes stays, the
/// component builders the app gives the design system among it.
///
/// Internal to the package.
@internal
class OpenUIStreamTheme extends StatelessWidget {
  /// Creates an [OpenUIStreamTheme].
  const OpenUIStreamTheme({super.key, required this.theme, required this.child});

  /// The theme the design system's components are drawn with.
  final OpenUIResolvedTheme theme;

  /// The widget below this one.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The design system keeps its theme among the Material theme's
    // extensions, so it is replaced there.
    final material = Theme.of(context);
    return Theme(
      data: material.copyWith(
        extensions: [
          for (final extension in material.extensions.values)
            if (extension is! StreamTheme) extension,
          _streamThemeOf(StreamTheme.of(context), theme),
        ],
      ),
      // A Theme sets the icon theme from its data, so the one around stays.
      child: IconTheme(data: IconTheme.of(context), child: child),
    );
  }
}

// The design system's [stream] theme with the tokens [theme] replaces.
StreamTheme _streamThemeOf(StreamTheme stream, OpenUIResolvedTheme theme) {
  final text = stream.textTheme;
  return stream.copyWith(
        colorScheme: stream.colorScheme.copyWith(
          accentPrimary: theme.accent,
          // Links take the accent, unless it is the design system's own,
          // whose links may have their own color.
          textLink: theme.accent == stream.colorScheme.accentPrimary ? stream.colorScheme.textLink : theme.accent,
          textOnAccent: theme.onAccent,
          textPrimary: theme.text,
          textSecondary: theme.secondaryText,
          textTertiary: theme.tertiaryText,
          backgroundSurfaceCard: theme.surface,
          backgroundSurface: theme.sunkenSurface,
          backgroundSurfaceSubtle: theme.subtleFill,
          borderDefault: theme.border,
          accentSuccess: theme.success,
          accentWarning: theme.warning,
          accentError: theme.error,
          accentNeutral: theme.neutral,
        ),
        spacing: stream.spacing.copyWith(
          xxs: theme.xsSpacing,
          xs: theme.sSpacing,
          sm: theme.mSpacing,
          md: theme.lSpacing,
          xl: theme.xlSpacing,
          xxl: theme.xxlSpacing,
        ),
        radius: stream.radius.copyWith(
          md: Radius.circular(theme.smallCornerRadius),
          lg: Radius.circular(theme.mediumCornerRadius),
          xl: Radius.circular(theme.cornerRadius),
          max: Radius.circular(theme.pillCornerRadius),
        ),
        textTheme: text.copyWith(
          headingMd: _replacing(text.headingMd, theme.title),
          headingSm: _replacing(text.headingSm, theme.heading),
          bodyDefault: _replacing(text.bodyDefault, theme.body),
          bodyEmphasis: _replacing(text.bodyEmphasis, theme.body.copyWith(fontWeight: text.bodyEmphasis.fontWeight)),
          captionDefault: _replacing(text.captionDefault, theme.bodySmall),
          metadataDefault: _replacing(text.metadataDefault, theme.caption),
        ),
      )
      as StreamTheme;
}

// [style] in place of the design system's [token], which keeps its color when
// [style] sets none: the OpenUI styles are colored by the components.
TextStyle _replacing(TextStyle token, TextStyle style) {
  if (style.color != null || style.foreground != null) return style;
  return style.copyWith(color: token.color);
}
