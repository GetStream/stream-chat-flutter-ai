import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `CheckBox`: the Stream design system's [StreamCheckbox], checked in
/// [A2UIThemeData.accent] while its `value` is true, beside its `label`; a tap on
/// either writes the other value.
///
/// The builder an app registers for check boxes through
/// [StreamComponentFactory] draws the box instead.
///
/// One whose `value` isn't bound to the data model shows fainter, and a tap
/// does nothing. The messages of its failing checks show below it.
///
/// Internal to the package.
@internal
Widget buildA2UICheckBox(BuildContext context, A2UIComponentScope scope) {
  final theme = A2UISurfaceScope.of(context).theme;
  final isChecked = scope.boolean('value') ?? false;
  final label = scope.string('label') ?? '';
  final accessibility = a2uiAccessibilityOf(scope);
  final canEdit = a2uiCanEdit(scope);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // The row is one tap target; the box is read and focused as the check
      // box, with the agent's label or the visible one.
      A2UIPressable(
        onTap: canEdit ? () => scope.write('value', !isChecked) : null,
        isButton: false,
        hint: accessibility.description,
        child: Opacity(
          opacity: canEdit ? 1 : a2uiReadOnlyOpacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _labelSpacing,
            children: [
              // The box needs a Material around it, which a surface may not
              // have. With no value to write, the box is drawn disabled, so an
              // app's check box builder draws it read-only too.
              // The row takes focus, so the box doesn't too.
              ExcludeFocus(
                child: Material(
                  type: MaterialType.transparency,
                  child: StreamCheckbox(
                    value: isChecked,
                    onChanged: canEdit ? (value) => scope.write('value', value) : null,
                    semanticLabel: accessibility.label ?? label,
                  ),
                ),
              ),
              Flexible(
                child: ExcludeSemantics(
                  child: Text(label, style: theme.body.copyWith(color: theme.text)),
                ),
              ),
            ],
          ),
        ),
      ),
      A2UIValidationMessages(failures: a2uiCheckFailuresOf(scope), theme: theme),
    ],
  );
}

// The space between the box and the label.
const _labelSpacing = 8.0;
