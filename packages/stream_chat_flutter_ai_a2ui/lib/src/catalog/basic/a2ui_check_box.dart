import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
              // The row is read, focused and activated as the check box, with
              // its label, so the box itself is neither.
              ExcludeFocus(
                child: ExcludeSemantics(
                  // Drawn enabled when read-only, so the fade alone shows
                  // it, as for the other inputs; it writes nothing then.
                  child: StreamCheckbox(
                    value: isChecked,
                    onChanged: (value) {
                      if (canEdit) scope.write('value', value);
                    },
                  ),
                ),
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
