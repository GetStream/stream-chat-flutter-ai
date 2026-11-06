import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `CheckBox`: a box, checked in [A2UIThemeData.accent] while its
/// `value` is true, beside its `label`; a tap writes the other value.
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
      A2UIPressable(
        onTap: canEdit ? () => scope.write('value', !isChecked) : null,
        isButton: false,
        checked: isChecked,
        label: accessibility.label,
        hint: accessibility.description,
        child: Opacity(
          opacity: canEdit ? 1 : a2uiReadOnlyOpacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _labelSpacing,
            children: [
              Icon(
                isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: isChecked ? theme.accent : theme.secondaryText,
              ),
              Flexible(
                child: Text(label, style: theme.body.copyWith(color: theme.text)),
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
