import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// Makes the Stream design system's components below [child] draw with
/// [theme], whose values are all set: its colors, spacing, corner radii and
/// text styles replace the tokens [OpenUITheme.of] reads their defaults from in the design system's
/// theme, and an accent other than the design system's colors links too.
///
/// So a [theme] of defaults only, as [OpenUITheme.of] fills them in from the
/// design system's theme around, changes nothing. Everything else of the app's themes stays,
/// the component builders the app gives the design system among it.
///
/// Internal to the package.
@internal
class OpenUIStreamTheme extends StatelessWidget {
  /// Creates an [OpenUIStreamTheme].
  const OpenUIStreamTheme({super.key, required this.theme, required this.child});

  /// The theme the design system's components are drawn with.
  final OpenUIThemeData theme;

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
StreamTheme _streamThemeOf(StreamTheme stream, OpenUIThemeData theme) {
  final colors = theme.colors!;
  final spacing = theme.spacing!;
  final radius = theme.radius!;
  final styles = theme.textStyles!;
  final text = stream.textTheme;
  return stream.copyWith(
        colorScheme: stream.colorScheme.copyWith(
          accentPrimary: colors.accent,
          // Links take the accent, unless it is the design system's own,
          // whose links may have their own color.
          textLink: colors.accent == stream.colorScheme.accentPrimary ? stream.colorScheme.textLink : colors.accent!,
          textOnAccent: colors.onAccent,
          textPrimary: colors.textPrimary,
          textSecondary: colors.textSecondary,
          textTertiary: colors.textTertiary,
          backgroundSurfaceCard: colors.surface,
          backgroundSurface: colors.sunkenSurface,
          backgroundSurfaceSubtle: colors.subtleFill,
          borderDefault: colors.border,
          accentSuccess: colors.success,
          accentWarning: colors.warning,
          accentError: colors.danger,
          accentNeutral: colors.neutral,
        ),
        spacing: stream.spacing.copyWith(
          xxs: spacing.xs,
          xs: spacing.s,
          sm: spacing.m,
          md: spacing.l,
          xl: spacing.xl,
          xxl: spacing.xxl,
        ),
        radius: stream.radius.copyWith(
          md: Radius.circular(radius.small!),
          lg: Radius.circular(radius.medium!),
          xl: Radius.circular(radius.large!),
          max: Radius.circular(radius.pill!),
        ),
        // The default OpenUI styles have no color, so the design system's
        // colors stay.
        textTheme: text.copyWith(
          headingMd: text.headingMd.merge(styles.title),
          headingSm: text.headingSm.merge(styles.heading),
          bodyDefault: text.bodyDefault.merge(styles.body),
          bodyEmphasis: text.bodyEmphasis.merge(styles.body!.copyWith(fontWeight: text.bodyEmphasis.fontWeight)),
          captionDefault: text.captionDefault.merge(styles.bodySmall),
          metadataDefault: text.metadataDefault.merge(styles.caption),
        ),
      )
      as StreamTheme;
}
