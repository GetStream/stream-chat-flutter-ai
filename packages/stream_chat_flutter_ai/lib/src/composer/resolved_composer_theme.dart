import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// A [ComposerThemeData] with every field resolved.
///
/// Internal. [ComposerThemeData]'s fields are nullable, but the composer
/// widgets need a concrete value for each, so resolving once at the top of
/// `build` keeps the fallback table in one place.
@immutable
@internal
class ResolvedComposerTheme {
  const ResolvedComposerTheme._({
    required this.fillColor,
    required this.borderColor,
    required this.hintStyle,
    required this.iconColor,
    required this.disabledIconColor,
    required this.sendButtonColor,
    required this.stopButtonColor,
    required this.recordingButtonColor,
    required this.actionButtonForegroundColor,
    required this.selectedOptionColor,
    required this.selectedOptionForegroundColor,
    required this.selectionColor,
    required this.attachmentPlaceholderColor,
  });

  /// Resolves the theme at [context].
  factory ResolvedComposerTheme.resolve(BuildContext context) {
    final theme = ComposerTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = theme.iconColor ?? colorScheme.onSurface;

    return ResolvedComposerTheme._(
      fillColor: theme.fillColor ?? colorScheme.surfaceContainerHigh,
      borderColor: theme.borderColor ?? colorScheme.outlineVariant,
      hintStyle: mergeTextStyle(
        TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        theme.hintStyle,
      ),
      iconColor: iconColor,
      // Derived from the *resolved* icon color, not the scheme's: a host that
      // sets only `iconColor` gets a matching disabled shade for free, rather
      // than a dimmed `onSurface` that no longer relates to it.
      disabledIconColor: theme.disabledIconColor ?? iconColor.withValues(alpha: 0.3),
      sendButtonColor: theme.sendButtonColor ?? colorScheme.primary,
      stopButtonColor: theme.stopButtonColor ?? colorScheme.error,
      recordingButtonColor: theme.recordingButtonColor ?? colorScheme.error,
      actionButtonForegroundColor: theme.actionButtonForegroundColor ?? Colors.white,
      selectedOptionColor: theme.selectedOptionColor ?? colorScheme.primaryContainer,
      selectedOptionForegroundColor: theme.selectedOptionForegroundColor ?? colorScheme.onPrimaryContainer,
      selectionColor: theme.selectionColor ?? colorScheme.primary,
      attachmentPlaceholderColor: theme.attachmentPlaceholderColor ?? colorScheme.surface,
    );
  }

  /// See [ComposerThemeData.fillColor].
  final Color fillColor;

  /// See [ComposerThemeData.borderColor].
  final Color borderColor;

  /// See [ComposerThemeData.hintStyle]. Always carries a color.
  final TextStyle hintStyle;

  /// See [ComposerThemeData.iconColor].
  final Color iconColor;

  /// See [ComposerThemeData.disabledIconColor].
  final Color disabledIconColor;

  /// See [ComposerThemeData.sendButtonColor].
  final Color sendButtonColor;

  /// See [ComposerThemeData.stopButtonColor].
  final Color stopButtonColor;

  /// See [ComposerThemeData.recordingButtonColor].
  final Color recordingButtonColor;

  /// See [ComposerThemeData.actionButtonForegroundColor].
  final Color actionButtonForegroundColor;

  /// See [ComposerThemeData.selectedOptionColor].
  final Color selectedOptionColor;

  /// See [ComposerThemeData.selectedOptionForegroundColor].
  final Color selectedOptionForegroundColor;

  /// See [ComposerThemeData.selectionColor].
  final Color selectionColor;

  /// See [ComposerThemeData.attachmentPlaceholderColor].
  final Color attachmentPlaceholderColor;

  /// The icon color for a control in the given enabled state.
  Color iconColorFor({required bool enabled}) => enabled ? iconColor : disabledIconColor;
}
