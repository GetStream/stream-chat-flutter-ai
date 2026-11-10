import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Button`: its `label` in a button of its `variant` (`primary`,
/// the default, `secondary` or `tertiary`), `type` (`destructive` draws it in
/// the danger color) and `size`, that runs its `action`.
///
/// A primary button in a `Form` checks the form's fields first and runs
/// nothing while one fails; only an action whose steps neither talk to the
/// assistant nor run a mutation skips the check. It can't be tapped while the
/// reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIButton(BuildContext context, OpenUIComponentScope scope) {
  final label = scope.text('label') ?? '';
  final variant = scope.string('variant') ?? 'primary';
  return StreamButton(
    style: _style(variant, destructive: scope.string('type') == 'destructive'),
    type: _type(variant),
    size: _size(scope.string('size')),
    onPressed: scope.isStreaming
        ? null
        : () {
            final action = scope.prop('action');
            final validation = OpenUIFormScope.maybeOf(context)?.validation;
            if (variant == 'primary' && validation != null && _needsValidation(action) && !validation.validateForm()) {
              return;
            }
            triggerOpenUIAction(context, scope, label: label, action: action);
          },
    child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
  );
}

/// Builds `Buttons`: its `buttons` in a row, or in a column when its
/// `direction` is `column` or the row doesn't fit.
///
/// Internal to the package.
@internal
Widget buildOpenUIButtons(BuildContext context, OpenUIComponentScope scope) {
  final spacing = OpenUIViewScope.of(context).theme.sSpacing;
  final buttons = openUIChildWidgets(context, scope, scope.elements('buttons'));
  if (buttons.isEmpty) return const SizedBox.shrink();
  if (scope.string('direction') == 'column') {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: buttons);
  }
  return OverflowBar(spacing: spacing, overflowSpacing: spacing, children: buttons);
}

/// Builds an `IconButton`: its `icon` in a round button of its `variant`
/// (`secondary` by default) and `size`, that runs its `action` labelled with
/// its `name`, which is also what it reads as.
///
/// It never checks the form it is in, and can't be tapped while the reply
/// streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIIconButton(BuildContext context, OpenUIComponentScope scope) {
  final name = scope.text('name') ?? '';
  final icon = scope.elements('icon').firstOrNull;
  final iconName = icon == null ? '' : JS.toStringOrEmpty(icon.props['name']);
  final variant = scope.string('variant') ?? 'secondary';
  final iconData =
      openUIIconOf(context.streamIcons, iconName, switch (icon?.props['category']) {
        OpenUIString(:final value) => value,
        _ => null,
      }) ??
      context.streamIcons.bolt;
  return Semantics(
    label: name.isNotEmpty ? name : openUIIconLabel(iconName),
    child: StreamButton.icon(
      icon: Icon(iconData),
      style: _style(variant, destructive: false),
      type: _type(variant),
      size: _size(scope.string('size')),
      onPressed: scope.isStreaming
          ? null
          : () => triggerOpenUIAction(context, scope, label: name, action: scope.prop('action')),
    ),
  );
}

StreamButtonStyle _style(String variant, {required bool destructive}) {
  if (destructive) return StreamButtonStyle.destructive;
  return variant == 'secondary' || variant == 'tertiary' || variant == 'ghost'
      ? StreamButtonStyle.secondary
      : StreamButtonStyle.primary;
}

StreamButtonType _type(String variant) {
  return switch (variant) {
    'secondary' => StreamButtonType.outline,
    'tertiary' || 'ghost' => StreamButtonType.ghost,
    _ => StreamButtonType.solid,
  };
}

StreamButtonSize _size(String? size) {
  return switch (size) {
    'extra-small' || 'small' => StreamButtonSize.small,
    'large' => StreamButtonSize.large,
    _ => StreamButtonSize.medium,
  };
}

// Whether [action] checks the form first: any but a plan whose steps neither
// talk to the assistant nor run a mutation.
bool _needsValidation(OpenUIValue? action) {
  if (action case OpenUIObject(:final fields) when fields['steps'] is OpenUIArray) {
    return (fields['steps']! as OpenUIArray).items.any(
      (step) =>
          step is OpenUIObject &&
          (step.fields['type'] == const OpenUIString(ActionStepType.continueConversation) ||
              (step.fields['type'] == const OpenUIString(ActionStepType.run) &&
                  step.fields['refType'] == const OpenUIString('mutation'))),
    );
  }
  return true;
}
