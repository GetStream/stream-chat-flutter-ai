import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/composer/resolved_composer_theme.dart';
import 'package:stream_core_flutter/chat.dart';

/// A fixed-size, circular filled icon button.
///
/// Used for every state of the composer's trailing control (mic, send, and
/// stop) so that switching between them reads as one control morphing in
/// place, rather than several differently-sized buttons swapping out.
class ComposerActionButton extends StatelessWidget {
  /// Creates a [ComposerActionButton].
  const ComposerActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    this.foregroundColor,
  });

  /// The icon shown inside the button.
  final IconData icon;

  /// Called when the button is tapped. A `null` value disables the button.
  final VoidCallback? onPressed;

  /// The tooltip message shown on long-press/hover.
  final String tooltip;

  /// The button's fill color when enabled. A disabled button takes the
  /// Stream theme's disabled colors.
  final Color color;

  /// The icon's color. Falls back to the theme's
  /// `ComposerThemeData.actionButtonForegroundColor`.
  ///
  /// Set it alongside a [color] the theme's foreground was not chosen for — a
  /// pale fill, say, under the default `textOnAccent`.
  final Color? foregroundColor;

  /// The button's fixed diameter.
  ///
  /// Shared across every trailing-control state so mic/send/stop occupy
  /// exactly the same footprint.
  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.streamColorScheme;
    final foregroundColor = this.foregroundColor ?? ResolvedComposerTheme.resolve(context).actionButtonForegroundColor;
    Color? resolve(Set<WidgetState> states, Color enabled, Color disabled) =>
        states.contains(WidgetState.disabled) ? disabled : enabled;
    return StreamButton.icon(
      // `medium` is [size] across.
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
      themeStyle: StreamButtonThemeStyle(
        backgroundColor: .resolveWith((states) => resolve(states, color, colorScheme.backgroundDisabled)),
        foregroundColor: .resolveWith((states) => resolve(states, foregroundColor, colorScheme.textDisabled)),
      ),
    );
  }
}
