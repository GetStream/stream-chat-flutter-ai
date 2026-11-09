import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_modal.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `Button`: its child in a button of its `variant`, which runs its
/// action when the person taps it.
///
/// A `primary` button is drawn in [A2UIThemeData.accent], a `borderless` one as
/// its child in the accent color, and any other on
/// [A2UIThemeData.subtleSurface]. While one of its checks fails and blocks it, it
/// is disabled and fainter, and the messages of its failing checks show
/// below it.
///
/// A tap closes the keyboard of a field being typed in and runs the action,
/// which also opens the `Modal` the button is the trigger of, if any.
///
/// Internal to the package.
@internal
Widget buildA2UIButton(BuildContext context, A2UIComponentScope scope) {
  final theme = A2UISurfaceScope.of(context).theme;
  final failures = a2uiCheckFailuresOf(scope);
  final accessibility = a2uiAccessibilityOf(scope);
  final child = scope.child();
  final variant = scope.hint('variant');
  // Each tap runs the action, as on iOS and Android: a second tap while the
  // first one's action runs sends a second event, so an agent that books
  // something treats a repeated event as a repeat.
  void handleTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(scope.performAction());
  }

  final isEnabled = !a2uiBlocks(failures);
  final (:background, :foreground, :padding) = switch (variant) {
    'primary' => (background: theme.accent, foreground: theme.onAccent, padding: _padding),
    'borderless' => (background: null, foreground: theme.accent, padding: _borderlessPadding),
    _ => (background: theme.subtleSurface, foreground: theme.text, padding: _padding),
  };
  final face = DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(theme.buttonCornerRadius),
    ),
    child: Padding(
      padding: padding,
      child: DefaultTextStyle.merge(
        style: theme.body.copyWith(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          // What the button holds doesn't open the modal again.
          child: A2UIModalOpener(onOpen: null, child: child == null ? const SizedBox.shrink() : scope.build(child)),
        ),
      ),
    ),
  );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      A2UIPressable(
        onTap: isEnabled ? handleTap : null,
        label: accessibility.label,
        hint: accessibility.description,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: Opacity(opacity: isEnabled ? 1 : _disabledOpacity, child: face),
        ),
      ),
      A2UIValidationMessages(failures: failures, theme: theme),
    ],
  );
}

// The space around the child of a button, except a borderless one.
const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

// The space above and below the child of a borderless button.
const _borderlessPadding = EdgeInsets.symmetric(vertical: 4);

// How strongly a disabled button shows.
const _disabledOpacity = 0.5;
