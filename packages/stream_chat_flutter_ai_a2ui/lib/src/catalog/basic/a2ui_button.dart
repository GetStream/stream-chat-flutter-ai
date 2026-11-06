import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_modal.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Button`: its child in the Stream design system's [StreamButton]
/// of its `variant`, which runs its action when the person taps it.
///
/// A `primary` button is a solid button in [A2UIThemeData.accent], a `borderless`
/// one shows its child in the accent color with no background, and any other
/// is a solid button on [A2UIThemeData.subtleSurface]. The builder an app
/// registers for buttons through [StreamComponentFactory] draws it instead.
/// While one of its checks fails and blocks it, it is disabled, and the
/// messages of its failing checks show below it.
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
  // Each tap runs the action, as on iOS and Android: a second tap while the
  // first one's action runs sends a second event, so an agent that books
  // something treats a repeated event as a repeat.
  void handleTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(scope.performAction());
  }

  final isEnabled = !a2uiBlocks(failures);
  final (style, type, themeStyle) = switch (scope.hint('variant')) {
    'primary' => (StreamButtonStyle.primary, StreamButtonType.solid, _growingStyle),
    'borderless' => (StreamButtonStyle.primary, StreamButtonType.ghost, _linkStyle),
    _ => (StreamButtonStyle.secondary, StreamButtonType.solid, _growingStyle),
  };
  final onPressed = isEnabled ? handleTap : null;
  // An icon the agent labels is an icon button, read by its tooltip. It keeps
  // the design system's size and round shape for icon buttons.
  final Widget button;
  if ((child, accessibility.label) case (final child?, final label?) when a2uiTypeOf(child) == 'Icon') {
    button = _withDescription(
      accessibility.description,
      child: StreamButton.icon(
        onPressed: onPressed,
        style: style,
        type: type,
        tooltip: label,
        // The tooltip is what the button is read as, not the icon's name.
        icon: ExcludeSemantics(
          child: A2UIModalOpener(onOpen: null, child: scope.build(child)),
        ),
      ),
    );
  } else {
    button = _withAccessibility(
      accessibility,
      onTap: onPressed,
      child: StreamButton(
        onPressed: onPressed,
        style: style,
        type: type,
        themeStyle: themeStyle,
        // What the button holds doesn't open the modal again.
        child: A2UIModalOpener(onOpen: null, child: child == null ? const SizedBox.shrink() : scope.build(child)),
      ),
    );
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      button,
      A2UIValidationMessages(failures: failures, theme: theme),
    ],
  );
}

// TODO(FLU-1232): Drop this wrapper once `StreamButton` has a `semanticLabel`
// and a semantic hint in stream_core_flutter, and pass the agent's label and
// description to it.
//
// The button, read with the agent's accessibility label in place of its
// child's text, and with its description as a hint. A button of text is read
// by its text, and an icon button the agent labels by its tooltip, so the
// wrapper is only there for a label on another child, such as an image, and
// for a description.
Widget _withAccessibility(
  ({String? label, String? description}) accessibility, {
  required VoidCallback? onTap,
  required Widget child,
}) {
  if (accessibility.label case final label?) {
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: label,
      hint: accessibility.description,
      excludeSemantics: true,
      onTap: onTap,
      child: child,
    );
  }
  return _withDescription(accessibility.description, child: child);
}

// The button, read with [description] as a hint, if there is one.
Widget _withDescription(String? description, {required Widget child}) {
  if (description == null) return child;
  return MergeSemantics(
    child: Semantics(hint: description, child: child),
  );
}

// A button style with no fixed size, so the button is as tall as its child
// needs, and at least as tall as a button of text.
final _growingStyle = StreamButtonThemeStyle.from(
  fixedSize: Size.infinite,
  minimumSize: Size(0, StreamButtonSize.medium.value),
);

// A borderless button's style: a growing one whose child lines up with the
// text beside and above it, as a link does.
final _linkStyle = StreamButtonThemeStyle.from(
  fixedSize: Size.infinite,
  minimumSize: Size(0, StreamButtonSize.medium.value),
  padding: EdgeInsets.zero,
);
